#!/bin/bash

env -i env
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

export AWS_DEFAULT_REGION=us-east-1

##############################################
######### EC2-operator REBOOT script #########
##############################################

# location for NON-encrypted & encrypted partition
# /scripts/aws-scripts/ec2-reboot_by_TAGS.sh

# The script is using IAM role with limited access only to the resources which have TAG *EC2-operator=ENABLED*

TAG_KEY_MAIN="EC2-operator"
TAG_VALUE_MAIN="ENABLED"

TAG_KEY_FUNCTION="AutoReboot"
TAG_VALUE_FUNCTION="YES"

TAG_KEY_WebApp="Family"
TAG_VALUE_WebApp="WebApp"

ELB_WebApp=WebApp

copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/aws-scripts/ec2-reboot_by_TAGS-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/ec2-reboot_by_TAGS-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

# Script will reboot WebApp servers which has 

LIST_OF_EC2_ELB=$(/usr/local/bin/aws ec2 describe-instances --output text --filters "Name=tag-key,Values=$TAG_KEY_MAIN" "Name=tag-value,Values=$TAG_VALUE_MAIN" "Name=tag-key,Values=$TAG_KEY_FUNCTION" "Name=tag-value,Values=$TAG_VALUE_FUNCTION" "Name=tag-key,Values=$TAG_KEY_WebApp" "Name=tag-value,Values=$TAG_VALUE_WebApp" --query 'Reservations[*].Instances[*].[InstanceId, State.Name]' | grep "running" | awk '{print $1}')

copy_cronjob

echo "Starting of rebooting process" 
for elb_instance in $LIST_OF_EC2_ELB; do
  
  # Deregister instances from the load balancer of the WebApp FAMILY
  /usr/local/bin/aws elb deregister-instances-from-load-balancer --load-balancer-name $ELB_WebApp --instances "$elb_instance"
  sleep 5m
  
  # Reboot instance
  /usr/local/bin/aws ec2 reboot-instances --instance-ids "$elb_instance"
  sleep 5m

  # Register instances to the load balancer of the WebApp FAMILY
  /usr/local/bin/aws elb register-instances-with-load-balancer --load-balancer-name $ELB_WebApp --instances "$elb_instance"
  sleep 5m

done
