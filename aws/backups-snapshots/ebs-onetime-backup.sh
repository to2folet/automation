#!/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

: <<'COMMENT'
ONE TIME EBS snapshot script for servers which use Aurora RDS instances
!! If MySQL DB is stored at EBS we need to use different script /scripts/EBS_snapshot_with_local_MySQL.sh !!

** location of script
$ /scripts/aws-scripts/ebs-onetime-backup.sh

** run command
$ sudo vi /scripts/aws-scripts/ebs-onetime-backup.sh && sudo /scripts/aws-scripts/ebs-onetime-backup.sh 2>>/var/log/aws_ebs-onetime-backup-stderr.log >>/var/log/aws_ebs-onetime-backup-stdout.log

** troubleshooting
$ bash -x /scripts/aws-scripts/ebs-onetime-backup.sh

COMMENT


AWS_REGION=$(wget -q -O- http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\([1-9]\).$/\1/g')
AWS_INSTANCE_ID=$(wget -q -O- http://169.254.169.254/latest/meta-data/instance-id)
AWS_COMMAND="/usr/bin/aws --region $AWS_REGION"
VOLUME_LIST=$(${AWS_COMMAND} ec2 describe-instances --instance-ids "${AWS_INSTANCE_ID}" --output text | grep EBS | grep False | awk '{print $5}')

TAG01=Stack
VALUE01=Production

TAG02=Period
VALUE02="One-time"

LOG_FILE_STDOUT=/var/log/aws_ebs-onetime-backup-stdout.log
LOG_FILE_STDERR=/var/log/aws_ebs-onetime-backup-stderr.log
LOG_TEMP_SNAPSHOT_ID=/var/log/aws_ebs-onetime-backup-snapshot_id.tmp
LOG_FILE_STDOUT_SIZE=$(stat -c %s ${LOG_FILE_STDOUT})

EMAIL_RECIPIENT="email@address.com"
HOST=$(hostname)
DATE=$(date +%Y-%m-%d-%T)
SNAPSHOT_DESC=$HOST'_'$DATE

###################################################################

# to clean a log file (LOG_FILE_STDOUT=/var/log/aws_ebs-onetime-backup-stdout.log) if the size is more than 10MB
if [ -f "$LOG_FILE_STDOUT_SIZE" ] && [ "$LOG_FILE_STDOUT_SIZE" -ge 10000 ] ; then
    echo > $LOG_FILE_STDOUT
fi

# to clear a file into which script temporary saves snapshot IDs for TAG purpose
if [ -f "$LOG_TEMP_SNAPSHOT_ID" ]; then
    echo > $LOG_TEMP_SNAPSHOT_ID
fi

echo "Create EBS Volume Snapshot - Process started at $DATE" >>$LOG_FILE_STDOUT
echo ''>>$LOG_FILE_STDOUT
echo "$VOLUME_LIST" 2>>$LOG_FILE_STDERR >>$LOG_FILE_STDOUT
echo '-----------------' >>$LOG_FILE_STDOUT

for volume in $VOLUME_LIST; do
    echo "Creating snapshot for volume: $volume with description: $SNAPSHOT_DESC" >>$LOG_FILE_STDOUT
    # to create snapshot from EBS
    ${AWS_COMMAND} ec2 create-snapshot --description "$SNAPSHOT_DESC-onetime" --volume-id "$volume" --output=text | awk '{print $4}' 2>>$LOG_FILE_STDERR >>$LOG_TEMP_SNAPSHOT_ID
    echo '' >>$LOG_FILE_STDOUT
    sleep 1s
done

AWS_SNAPSHOT_ID=$(cat $LOG_TEMP_SNAPSHOT_ID)

# to tag new snapshots of EBS
echo ''>>$LOG_FILE_STDOUT
echo 'Tagging of new snapshots:' >>$LOG_FILE_STDOUT
echo "${AWS_SNAPSHOT_ID}" 2>>$LOG_FILE_STDERR >>$LOG_FILE_STDOUT
echo '-----------------' >>$LOG_FILE_STDOUT

sleep 60s
${AWS_COMMAND} ec2 create-tags \
 --resource "${AWS_SNAPSHOT_ID}" \
 --tags Key=${TAG01},Value=${VALUE01} 2>>$LOG_FILE_STDERR >>$LOG_FILE_STDOUT

${AWS_COMMAND} ec2 create-tags \
 --resource "${AWS_SNAPSHOT_ID}" \
 --tags Key=${TAG02},Value=${VALUE02} 2>>$LOG_FILE_STDERR >>$LOG_FILE_STDOUT
 
sleep 60s

# following condition checks if aws_snapshot-stderr.log contents something, if yes, it will send an email notification
if [ -f $LOG_FILE_STDERR ]; then
    if [ -s $LOG_FILE_STDERR ]; then
        {
            printf "\\nbackup ISSUE @ $DATE on $HOST\\n"
            printf "After troubleshooting please delete this *aws_snapshot-stderr.log* log file\\n"
            echo "$ sudo rm -rf /var/log/aws_ebs-onetime-backup-stderr.log"
        } >>$LOG_FILE_STDERR
        sudo cat $LOG_FILE_STDERR | mail -s "$HOST - EBS snapshot PROBLEM" -a "From: $HOST@address.com" $EMAIL_RECIPIENT
    else
        {
            printf "\\n******* Ran backup @ $DATE on $HOST\\n"
            printf "Completed\\n"
        } >>$LOG_FILE_STDOUT
    fi
fi


exit 0
