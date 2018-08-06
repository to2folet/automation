#!/bin/bash

env -i env
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

export AWS_DEFAULT_REGION=us-east-1

##############################################
########## EC2-operator STOP script ##########
##############################################

# location for NON-encrypted & encrypted partition
# /scripts/aws-scripts/ec2-saving-stop.sh

# The script is using IAM role with limited access only to the resources which have TAG *EC2-operator=ENABLED*

TAG_KEY_MAIN="EC2-operator"
TAG_VALUE_MAIN="ENABLED"

TAG_KEY_FUNCTION="AutoShutdown"
TAG_VALUE_FUNCTION="YES"

copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/aws-scripts/ec2-saving-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/ec2-saving-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

copy_cronjob

LIST_OF_REGIONS=$(aws ec2 describe-regions --output text | cut -f 3)

echo "Stopping EC2 instances with the TAG *EC2-operator=ENABLED* across all AWS Regions"
for region in $LIST_OF_REGIONS; do
    echo $'\n======================================================================'
    echo "Region - $region"

    LIST_OF_EC2=$(/usr/local/bin/aws ec2 describe-instances --region "$region" --output text --filters "Name=tag-key,Values=$TAG_KEY_MAIN" "Name=tag-value,Values=$TAG_VALUE_MAIN" "Name=tag-key,Values=$TAG_KEY_FUNCTION" "Name=tag-value,Values=$TAG_VALUE_FUNCTION" --query 'Reservations[*].Instances[*].[InstanceId]')
   
    for instance in $LIST_OF_EC2; do
        /usr/local/bin/aws ec2 stop-instances --instance-ids "$instance" --region "$region"
    done

done
