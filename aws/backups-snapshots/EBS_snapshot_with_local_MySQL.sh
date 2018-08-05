#!/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

# We need to fill out MySQL credentials
# Because we will be storing a sensitive credentials int this script
# we should store this script in some Encryption EBS volume

## /encrypted_EBS/EBS_snapshot_with_local_MySQL.sh
## /encrypted_EBS/deps/cron/aws_snapshot-job
## sudo vi /encrypted_EBS/EBS_snapshot_with_local_MySQL.sh && sudo chmod 700 /encrypted_EBS/EBS_snapshot_with_local_MySQL.sh && sudo /encrypted_EBS/EBS_snapshot_with_local_MySQL.sh 2>/var/log/aws_snapshot-stderr.log >>/var/log/aws_snapshot-stdout.log

# official GIT repository of an ec2-consistent-snapshot
## https://github.com/alestic/ec2-consistent-snapshot

# installation
## sudo add-apt-repository ppa:alestic
## sudo apt-get update -y && sudo apt-get install ec2-consistent-snapshot -y

AWS_REGION=$(wget -q -O- http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\([1-9]\).$/\1/g')
AWS_INSTANCE_ID=$(wget -q -O- http://169.254.169.254/latest/meta-data/instance-id)
AWS_COMMAND="/usr/bin/aws --region $AWS_REGION"
VOLUME_LIST=$(${AWS_COMMAND} ec2 describe-instances --instance-ids ${AWS_INSTANCE_ID} --output text | grep EBS | grep False | awk '{print $5}')
TAG01=ENV
TAG02=Stack
VALUE01=VPC
VALUE02=Production

MYSQL_USER="<to_paste_the-MySQL_USERNAME>"
MYSQL_PASS="<to_paste_the-MySQL_PASSWORD>"

LOG_FILE_STDOUT="/var/log/aws_snapshot-stdout.log"
LOG_FILE_STDERR="/var/log/aws_snapshot-stderr.log"
LOG_FILE_STDOUT_SIZE=`stat -c %s ${LOG_FILE_STDOUT}`

EMAIL_RECIPIENT="email@address.com"
HOST=$(hostname)
DATE=$(date +%Y-%m-%d-%T)
SNAPSHOT_DESC=$HOST'_'$DATE

# to clean a log file (LOG_FILE_STDOUT=/var/log/aws_snapshot-stdout.log) if the size is more than 10MB
touch $LOG_FILE_STDOUT
if [ "$LOG_FILE_STDOUT_SIZE" -ge 10000 ]; then
    > $LOG_FILE_STDOUT
fi

# with following condition we will create a snapshot only on production ENV
if [[ ! "$HOST" = *-staging ]] || [ ! -f /encrypted_EBS/staging ] ; then
    echo "Create EBS Volume Snapshot - Process started at $DATE" >>$LOG_FILE_STDOUT 
    echo "List of the volumes:" >>$LOG_FILE_STDOUT 
    echo "$VOLUME_LIST" 2>>$LOG_FILE_STDERR >>$LOG_FILE_STDOUT  
    echo $'\n-----------------' >>$LOG_FILE_STDOUT 

    echo "Creating the snapshots with the following description: $SNAPSHOT_DESC" >>$LOG_FILE_STDOUT 
    # to create snapshot from EBS
    ec2-consistent-snapshot --use-iam-role --mysql --mysql-username $MYSQL_USER --mysql-password $MYSQL_PASS --xfs-filesystem /encrypted_EBS $VOLUME_LIST --region $AWS_REGION --description "$SNAPSHOT_DESC" --tag "$TAG01=$VALUE01;$TAG02=$VALUE02" 2>>$LOG_FILE_STDERR >>$LOG_FILE_STDOUT
    sleep 10s

    # following condition checks if aws_snapshot-stderr.log contents something, if yes, it will send an email notification
    if [ -f $LOG_FILE_STDERR ] && [ -s $LOG_FILE_STDERR ]; then
        echo $'\n-----------------\n' >>$LOG_FILE_STDERR 
        echo "backup ISSUE @ $DATE on $HOST" >>$LOG_FILE_STDERR 
        echo $'After troubleshooting please delete this *aws_snapshot-stderr.log* log file\n' >>$LOG_FILE_STDERR
        echo "$ sudo rm -rf $LOG_FILE_STDERR" >>$LOG_FILE_STDERR
        sudo cat $LOG_FILE_STDERR | mail -s "$HOST - EBS snapshot PROBLEM" -a "From: $HOST@semcat.net" $EMAIL_RECIPIENT
        echo "The AWS Snapshot script WAS NOT successfully finished. Email notification was sent to $EMAIL_RECIPIENT" >>$LOG_FILE_STDOUT 
        echo $'\n-----------------\n' >>$LOG_FILE_STDERR
    else
        echo $'\nTagging of new snapshots were successfully finished\n' >>$LOG_FILE_STDOUT  
        echo "******* Ran backup @ $DATE on $HOST" >>$LOG_FILE_STDOUT 
        echo $'Completed\n-----------------\n' >>$LOG_FILE_STDOUT
    fi

fi

exit 0