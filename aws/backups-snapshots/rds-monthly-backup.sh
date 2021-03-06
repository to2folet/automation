#!/bin/bash

: <<'COMMENT'

RDS snapshot script, which will create snapshot of production DB clusters,
the script will be started first day of month

This script works only if the right AWS IAM ROLE is attached

** location of script
$ /scripts/aws-scripts/rds-monthly-backup.sh

** location of cronjob
$ /etc/cron.d/rds-monthly-backup-job

** run command
$ sudo vi /scripts/aws-scripts/rds-monthly-backup.sh && sudo /scripts/aws-scripts/rds-monthly-backup.sh 2>/var/log/aws_rds_snapshot-stderr.log >>/var/log/aws_rds_snapshot-stdout.log

** troubleshooting
bash -x /scripts/aws-scripts/rds-monthly-backup.sh

** describe DB Cluster Snapshots
$ /usr/local/bin/aws rds describe-db-cluster-snapshots --region us-east-1 --output table \
--query 'DBClusterSnapshots[*].[DBClusterSnapshotIdentifier,SnapshotCreateTime]'

$ /usr/local/bin/aws --region us-east-1 rds create-db-cluster-snapshot --output text \
     --db-cluster-identifier aurora-cluster-rds\
     --db-cluster-snapshot-identifier one-time-aurora-cluster-rds

COMMENT

AWS_REGION=$(wget -q -O- http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\([1-9]\).$/\1/g')
AWS_INSTANCE_ID=$(wget -q -O- http://169.254.169.254/latest/meta-data/instance-id)
AWS_COMMAND="/usr/local/bin/aws --region $AWS_REGION"

EMAIL_RECIPIENT=email@address.com
LOG_FILE_STDOUT=/var/log/aws_rds_snapshot-stdout.log
LOG_FILE_STDERR=/var/log/aws_rds_snapshot-stderr.log
TEMP_SNAPSHOT_LIST=/var/log/aws_rds_snapshot-list.tmp

HOST=$(hostname)
DATE=$(date +%Y-%m-%d)
# Date 12 months back
datecheck_366d=$(date +%Y-%m-%d --date '366 days ago')

DB_CLUSTER01_IDENTIFIER="aurora-cluster-rds-01"
DB_CLUSTER02_IDENTIFIER="aurora-cluster-rds-02"

# EC2 Tags
EC2_TAG00_KEY=Family
EC2_TAG00_VALUE_BackupInstance=BackupInstance

EC2_TAG04_KEY=Mode
EC2_TAG04_VALUE_Master=Master

function _ec2_instance_verification_BackupInstance() {
    # This function check if the script starts at BackupInstance instance
    # in Master Mode
    EC2_BackupInstance_VERIFICATION=$($AWS_COMMAND ec2 describe-instances --output text \
            --instance-ids "$AWS_INSTANCE_ID" \
            --filters "Name=tag-key,Values=$EC2_TAG00_KEY" "Name=tag-value,Values=$EC2_TAG00_VALUE_BackupInstance" \
            "Name=tag-key,Values=$EC2_TAG04_KEY" "Name=tag-value,Values=$EC2_TAG04_VALUE_Master" \
            --query 'Reservations[*].Instances[*].[InstanceId]')
}

function cleaning_logs() {
    # clean a STDOUT file if the size is more than 10MB
    if [ -f "$LOG_FILE_STDOUT" ]; then
        LOG_FILE_STDOUT_SIZE=$(stat -c %s ${LOG_FILE_STDOUT})
        if [ "$LOG_FILE_STDOUT_SIZE" -ge 10000 ] ; then
            echo > $LOG_FILE_STDOUT
        fi
    fi

    # clean a STDERR file if the size is more than 10MB
    if [ -f "$LOG_FILE_STDERR" ]; then
        LOG_FILE_STDERR_SIZE=$(stat -c %s ${LOG_FILE_STDERR})
        if [ "$LOG_FILE_STDERR_SIZE" -ge 10000 ] ; then
            rm -rf $LOG_FILE_STDERR
        fi
    fi
}

function copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/aws-scripts/rds-backup-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/rds-backup-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}


function upgrade_of_CLI() {
    # upgrading of AWS Command Line Interface
    # http://docs.aws.amazon.com/cli/latest/userguide/installing.html
    pip install awscli --upgrade --user > /dev/null
    echo -n "AWS CLI version: " 
    $AWS_COMMAND --version
}  

function creating_snapshots() {
    # Creating of Snapshots of DB Clusters
    $AWS_COMMAND rds create-db-cluster-snapshot --output text \
     --db-cluster-identifier $DB_CLUSTER01_IDENTIFIER \
     --db-cluster-snapshot-identifier monthly-"$DATE"-"$DB_CLUSTER01_IDENTIFIER"

    sleep 10s
    $AWS_COMMAND rds create-db-cluster-snapshot --output text \
     --db-cluster-identifier $DB_CLUSTER02_IDENTIFIER \
     --db-cluster-snapshot-identifier monthly-"$DATE"-"$DB_CLUSTER02_IDENTIFIER"
}

function removing_old_snapshots() {
    $AWS_COMMAND rds describe-db-cluster-snapshots --output text \
     --query 'DBClusterSnapshots[?SnapshotCreateTime<=`'$datecheck_366d'`].[DBClusterSnapshotIdentifier]' \
     | grep "monthly" > $TEMP_SNAPSHOT_LIST

    for snapshots in $(cat $TEMP_SNAPSHOT_LIST); do
        echo $'\nDeleting snapshot $snapshots\n'
        $AWS_COMMAND rds delete-db-cluster-snapshot --region us-east-1 --output text \
        --db-cluster-snapshot-identifier "$snapshots"
        sleep 10s
    done
    rm -rf $TEMP_SNAPSHOT_LIST
}


function email_notification() {
    # following condition checks if aws_rds_snapshot-stderr.log contents something, if yes, it will send an email notification
    if [ -f $LOG_FILE_STDERR ] && [ -s $LOG_FILE_STDERR ]; then
        {
            echo $'\n-----------------\n'
            echo "RDS snapshot ISSUE @ $DATE"
            echo $'After troubleshooting please delete this *aws_rds_snapshot-stderr.log* log file\n'
            echo "$ sudo rm -rf $LOG_FILE_STDERR"
            echo "The AWS RDS Snapshot script WAS NOT successfully finished. Email notification was sent to email@address.com"
            echo $'\n-----------------\n'
        }
        sudo cat $LOG_FILE_STDERR | mail -s "$HOST - RDS snapshot PROBLEM" -a "From: RDS.snapshot@address.com" $EMAIL_RECIPIENT
    else
        {
            echo $'\nNew snapshots were successfully finished\n'
            echo "******* Ran RDS backup @ $DATE"
            echo $'Completed\n-----------------\n'
        } 
    fi
}

###############################################

_ec2_instance_verification_BackupInstance

# Following condition will allow to run this script only from Central Unit Maintenance Server - BackupInstance
if [[ $EC2_BackupInstance_VERIFICATION =~ .*i-.* ]]; then

    copy_cronjob

    cleaning_logs

    upgrade_of_CLI

    creating_snapshots

    email_notification

else
    echo "Script was terminated - server is not Central Unit Maintenance Server"

fi

exit 0
