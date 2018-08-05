#!/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

# location
# /scripts/instance-info.sh
# nohup ./instance-info.sh > /dev/null 2>&1 &

HOST=$(hostname)

AWS_INSTANCE_METADATA_IP="http://169.254.169.254"

AWS_AZ=$(curl $AWS_INSTANCE_METADATA_IP/latest/meta-data/placement/availability-zone)
AWS_REGION=$(wget -q -O- $AWS_INSTANCE_METADATA_IP/latest/meta-data/placement/availability-zone | sed 's/\([1-9]\).$/\1/g')

AWS_AMI_ID=$(curl $AWS_INSTANCE_METADATA_IP/latest/meta-data/ami-id)
AWS_INSTANCE_ID=$(curl $AWS_INSTANCE_METADATA_IP/latest/meta-data/instance-id)
AWS_INSTANCE_TYPE=$(curl $AWS_INSTANCE_METADATA_IP/latest/meta-data/instance-type)
AWS_LOCAL_IP=$(curl $AWS_INSTANCE_METADATA_IP/latest/meta-data/local-ipv4)


AWS_SG="curl $AWS_INSTANCE_METADATA_IP/latest/meta-data/security-groups"

AWS_HOSTNAME_LOCAL=$(curl $AWS_INSTANCE_METADATA_IP/latest/meta-data/local-hostname)
AWS_HOSTNAME_PUBLIC=$(curl $AWS_INSTANCE_METADATA_IP/latest/meta-data/public-hostname)

AWS_IAM="curl $AWS_INSTANCE_METADATA_IP/latest/meta-data/iam/info"

AWS_INFO_TEMP_FILE="/var/log/instance-info.temp"
INSTANCE_INFO="/var/log/instance.info"

copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/instance-info-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/instance-info-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

##########################

copy_cronjob

rm -rf $INSTANCE_INFO

#echo "Instance info about $HOST : $AWS_INSTANCE_ID @ $DATE" >> $INSTANCE_INFO
echo "Client Hostname - $HOST" >> $INSTANCE_INFO

echo "Availability Zone - $AWS_AZ" >> $INSTANCE_INFO
echo "AWS Region - $AWS_REGION" >> $INSTANCE_INFO


echo -n $'\nAMI ID - ' >> $INSTANCE_INFO
echo "$AWS_AMI_ID" >> $INSTANCE_INFO
echo -n $'Instance ID - ' >> $INSTANCE_INFO
echo "$AWS_INSTANCE_ID" >> $INSTANCE_INFO
echo -n $'Instance Type - ' >> $INSTANCE_INFO
echo "$AWS_INSTANCE_TYPE" >> $INSTANCE_INFO

echo -n $'\nLocal IP - ' >> $INSTANCE_INFO
echo "$AWS_LOCAL_IP" >> $INSTANCE_INFO
echo -n $'Hostname Local - ' >> $INSTANCE_INFO
echo "$AWS_HOSTNAME_LOCAL" >> $INSTANCE_INFO
echo -n $'Hostname Public - ' >> $INSTANCE_INFO
echo "$AWS_HOSTNAME_PUBLIC" >> $INSTANCE_INFO

$AWS_SG > $AWS_INFO_TEMP_FILE && echo "" >> $AWS_INFO_TEMP_FILE
echo -n $'\nSecurity Groups - ' >> $INSTANCE_INFO
echo $(cat $AWS_INFO_TEMP_FILE) >> $INSTANCE_INFO

$AWS_IAM | grep "InstanceProfileArn" > $AWS_INFO_TEMP_FILE
echo -n $'AWS IAM role attached ProfileARN - ' >> $INSTANCE_INFO
echo $(cat $AWS_INFO_TEMP_FILE) >> $INSTANCE_INFO

$AWS_IAM | grep "InstanceProfileId" > $AWS_INFO_TEMP_FILE
echo -n $'AWS IAM role attached ProfileID - ' >> $INSTANCE_INFO
echo $(cat $AWS_INFO_TEMP_FILE) >> $INSTANCE_INFO
echo ""

rm -rf $AWS_INFO_TEMP_FILE
