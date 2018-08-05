#!/bin/bash



: <<'COMMENT'

General CloudWatch Alarms creator script - version 1.0

The script creates CloudWatch Alarms for each EC2 instance which meets following conditions:
 > Running State &&
 > Production Stack && 
 > EC2 instance doesnt contain Tag [ CW_Alarms=Created ]

Conditions:
 > Script can be ran only from EC2 instance with Tags Family=AWS_Managed-EC2 && Mode=Master

What we monitor:
 > EC2 - 
	* CPU
		- CPUUtilization >= 90 for 1 datapoints within 5 minutes
		- CPUCreditBalance < 50 for 2 datapoints within 10 minutes
			+ only for EC2 T2 class instances 

		LongStanding
		- CPUUtilization >= 99 for 15 datapoints within 15 minutes


	* HDD
		- /encryptedEBS DiskSpaceUtilization >= 90 for 1 datapoints within 5 minutes
		- / root DiskSpaceUtilization >= 90 for 1 datapoints within 5 minutes
		
		LongStanding
		- /encryptedEBS DiskSpaceUtilization >= 90 for 15 datapoints within 15 minutes
		- / root DiskSpaceUtilization >= 90 for 15 datapoints within 15 minutes

	* Instance State
		- StatusCheckFailed_Instance > 0 for 2 datapoints within 2 minutes
		- StatusCheckFailed_System > 0 for 2 datapoints within 2 minutes
		- StatusCheckFailed > 0 for 2 datapoints within 2 minutes

		LongStanding
		- StatusCheckFailed > 0 for 15 datapoints within 15 minutes

	* Memory
	 	- MemoryUtilization >= 90 for 1 datapoints within 5 minutes

		LongStanding
	 	- MemoryUtilization >= 90 for 1 datapoints within 5 minutes


 > Billing -
	* Billing
	 	- {3250..32500..3250}

	 	LongStanding
	 	- {15000..50000..5000}

Communication Channels:
 > All emails from the standard CW Alarms are sent to SNS topic "NotifyMe" (usratingnotices@appliedsystems.com)
 > "LongStanding" AWS Alarms are sent to
 	* SNS topic "NotifyMe" (usratingnotices@appliedsystems.com)
	* SNS topic "pagerduty"
	* SNS topic "NotifyMe_Administrators" (Ondrej & Wesley)

 Note: Billing "LongStanding" AWS Alarms are sent additionally to
	* SNS topic "NotifyMe_AWS_SuperUsers" (Ondrej, Wesley, Britton, & Jeff)



AWS Knowladge Base:
http://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-alarm.html
http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/mon-scripts.html



TO DO
* LongStanding - MemoryUtilization
* Script can be run manually or with 1 argument (!)

* ELB checks
* RDS checks
* SNS
 - TopicName - NumberOfNotificationsFailed ???
* NAT Gateway



Examples:

$ mon-put-metric-alarm --alarm-name rds-alarm-acme-CPU --alarm-description "CPU alarm" --metric-name CPUUtilization --namespace AWS/RDS --statistic Average --period 60 --threshold 90 --comparison-operator GreaterThanThreshold --dimensions "DBInstanceIdentifier=acme" --evaluation-periods 10 --unit Percent --alarm-actions arn:aws:sns:us-east-1:XXXXXXXX:sns-acme-1

$ aws cloudwatch delete-alarms --alarm-names myalarm
$ aws cloudwatch describe-alarms --alarm-names "myalarm"

$ aws --region us-east-1 cloudwatch list-metrics --namespace System/Linux --dimensions Name=InstanceId,Value=i-XXXXXXXX
$ aws --region us-east-1 cloudwatch list-metrics --namespace AWS/EC2 --dimensions Name=InstanceId,Value=i-XXXXXXXX

* To specify multiple dimensions
 - The following example illustrates how to specify multiple dimensions. Each dimension is specified as a Name/Value pair, with a comma between the name and the value. Multiple dimensions are separated by a space:
 $ aws cloudwatch put-metric-alarm --alarm-name "Default_Test_Alarm3" --alarm-description "The default example alarm" --namespace "CW EXAMPLE METRICS" --metric-name Default_Test --statistic Average --period 60 --evaluation-periods 3 --threshold 50 --comparison-operator GreaterThanOrEqualToThreshold --dimensions Name=key1,Value=value1 Name=key2,Value=value2

 - The action looks for any Cloudwatch alarms which are in an “INSUFFICIENT_DATA” state, and optionally, possess a matching namespace (such as AWS/EC2). Compatible alarms are checked for compatible metrics or metric data, and if none are found, then, the alarm is deleted.


https://gist.github.com/jonathanwcrane/5a00812201af9ea1222e

* test alarm
 $ aws cloudwatch --region us-east-1 set-alarm-state --alarm-name "test_CPU_exceeds_70" --state-reason "testing" --state-value ALARM

* Change the alarm state from INSUFFICIENT_DATA to OK:
 $ aws cloudwatch --region us-east-1 set-alarm-state --alarm-name cpu-mon --state-reason "initializing" --state-value OK

* Change the alarm state from OK to ALARM:
 $ aws cloudwatch --region us-east-1 set-alarm-state --alarm-name cpu-mon --state-reason "initializing" --state-value ALARM
 $ aws cloudwatch --region us-east-1 set-alarm-state --alarm-name EC2_CPU90_i-XXXXXXXX --state-reason "initializing" --state-value ALARM

COMMENT


####################

CURRENT_AWS_REGION=$(wget -q -O- http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\([1-9]\).$/\1/g')
CURRENT_EC2_INSTANCE_ID=$(wget -q -O- http://169.254.169.254/latest/meta-data/instance-id)
CURRENT_EC2_HOSTNAME=$(hostname)
AWS_COMMAND="/usr/local/bin/aws"

# Since we use only one the primary AWS Region us-east-1
# We use the same region in which is AWS_Managed-EC2instance located
AWS_REGION=$CURRENT_AWS_REGION

# EC2 Tags
EC2_TAG00_KEY=Family
EC2_TAG00_VALUE_AWS_Managed-EC2=AWS_Managed-EC2

EC2_TAG01_KEY=Name

EC2_TAG02_KEY=Stack
EC2_TAG02_VALUE=Production

EC2_TAG03_KEY=Family

EC2_TAG04_KEY=Mode
EC2_TAG04_VALUE_Master=Master

EC2_TAG05_KEY=CW_Alarms
EC2_TAG05_VALUE=Created

EC2_STATE_NAME=instance-state-name
EC2_STATE_VALUE_running=running
EC2_STATE_VALUE_stopped=stopped


SNS_TOPIC_Email_Support="arn:aws:sns:us-east-1:XXXXXXX:YYYYY"
SNS_TOPIC_PagerDuty="arn:aws:sns:us-east-1:XXXXXXX:pagerduty"
SNS_TOPIC_Email_Admins="arn:aws:sns:us-east-1:XXXXXXX:YYYYY_Administrators"
SNS_TOPIC_Email_AWS_SuperUsers="arn:aws:sns:us-east-1:XXXXXXX:YYYYY_AWS_SuperUsers"


STATISTIC_VALUE_avarage=Average
STATISTIC_VALUE_minimum=Minimum
STATISTIC_VALUE_maximum=Maximum
STATISTIC_VALUE_sum=Sum

PERIOD_60s=60
PERIOD_300s=300
PERIOD_21600s=21600 # 6 hours

THRESHOLD_90percent=90
THRESHOLD_99percent=99
THRESHOLD_0=0
THRESHOLD_1=1
THRESHOLD_50=50

EVALUATION_PERIOD_1=1
EVALUATION_PERIOD_2=2
EVALUATION_PERIOD_15=15


LOG_FILE_STDOUT=/var/log/cloudwatch-stdout.log
LOG_FILE_STDERR=/var/log/cloudwatch-stderr.log

LOG_FILE_STDOUT_max_lines="50000"
LOG_TEMP_SNAPSHOT_ID=/var/log/cloudwatch-snapshot_id.tmp
LOG_TEMP_EC2_LIST=/var/log/cloudwatch-ec2_list.tmp


function _sub_alarm_option_billing_general() {
	echo "
		--namespace AWS/Billing
		--metric-name EstimatedCharges
		--evaluation-periods $EVALUATION_PERIOD_1
		--period $PERIOD_21600s
		--statistic $STATISTIC_VALUE_maximum
		--comparison-operator GreaterThanOrEqualToThreshold
		--dimensions "Name=Currency,Value=USD"
		--treat-missing-data ignore
		--actions-enabled
		$(_sub_alarm_option_SNS_actions_enabled_all)
	"
}

function _sub_alarm_option_billing_long_standing() {
	echo "
		--namespace AWS/Billing
		--metric-name EstimatedCharges
		--evaluation-periods $EVALUATION_PERIOD_1
		--period $PERIOD_21600s
		--statistic $STATISTIC_VALUE_maximum
		--comparison-operator GreaterThanOrEqualToThreshold
		--dimensions "Name=Currency,Value=USD"
		--treat-missing-data ignore
		--actions-enabled
		$(_sub_alarm_option_SNS_actions_extremely_critical)
	"
}

function _sub_alarm_option_EC2general_resources_monitoring() {
	echo "
		--comparison-operator GreaterThanOrEqualToThreshold
		--threshold $THRESHOLD_90percent
		--statistic $STATISTIC_VALUE_avarage
		--period $PERIOD_300s
		--evaluation-periods $EVALUATION_PERIOD_1 --unit Percent
	"
}

function _sub_alarm_option_EC2general_resources_monitoring_long_standing() {
	echo "
		--comparison-operator GreaterThanOrEqualToThreshold
		--threshold $THRESHOLD_99percent
		--statistic $STATISTIC_VALUE_avarage
		--period $PERIOD_60s
		--evaluation-periods $EVALUATION_PERIOD_15 --unit Percent
	"
}

function _sub_alarm_option_EC2status_monitoring() {
	echo "
		--comparison-operator GreaterThanThreshold  --dimensions "Name=InstanceId,Value=$EC2_instance"
		--statistic $STATISTIC_VALUE_minimum --period $PERIOD_60s --threshold $THRESHOLD_0
		--evaluation-periods $EVALUATION_PERIOD_2 --unit Count
	"
}

function _sub_alarm_option_SNS_actions_enabled_all() {
	# SNS subscription for an
	# Medium severe issue - US Rating Technology Admin email 
	echo "
		--actions-enabled
		--alarm-actions $SNS_TOPIC_Email_Support
		--ok-actions $SNS_TOPIC_Email_Support
		--insufficient-data-actions $SNS_TOPIC_Email_Support
	"
}

function _sub_alarm_option_SNS_actions_long_standing() {
	# SNS subscription for an
	# High critical severe issue - Administrators, PagerDuty, etc. 
	echo "
		--actions-enabled
		--alarm-actions "$SNS_TOPIC_Email_Support $SNS_TOPIC_PagerDuty $SNS_TOPIC_Email_Admins"
		--ok-actions "$SNS_TOPIC_Email_Support $SNS_TOPIC_PagerDuty $SNS_TOPIC_Email_Admins"
		--insufficient-data-actions "$SNS_TOPIC_Email_Support $SNS_TOPIC_PagerDuty $SNS_TOPIC_Email_Admins"
	"
}

function _sub_alarm_option_SNS_actions_extremely_critical() {
	# SNS subscription for an
	# Extremely critical severe issue - AWS Super Users, PagerDuty, etc. 
	echo "
		--actions-enabled
		--alarm-actions "$SNS_TOPIC_Email_Support $SNS_TOPIC_PagerDuty $SNS_TOPIC_Email_AWS_SuperUsers"
		--ok-actions "$SNS_TOPIC_Email_Support $SNS_TOPIC_PagerDuty $SNS_TOPIC_Email_AWS_SuperUsers"
		--insufficient-data-actions "$SNS_TOPIC_Email_Support $SNS_TOPIC_PagerDuty $SNS_TOPIC_Email_AWS_SuperUsers"
	"
}


function _put_alarm_billing() {
	# sets alarms from $3.25k to $13k at increments of $3.25k
	for amount in {3250..32500..3250}; do

		log "Creating new AWS billing alarm: \$$amount"
		#echo amount=$amount
		$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
			--alarm-name "Billing-\$$amount" \
			--alarm-description "Auto CW Billing Alarm: \$$amount" \
			--threshold "$amount"\
			$(_sub_alarm_option_billing_general)
	done

	# sets alarms from $15k to $20k at increments of $5k
	for amount in {15000..50000..5000}; do
		log "Creating new AWS billing alarm: \$$amount"
		$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
			--alarm-name "Billing-\$$amount" \
			--alarm-description "Auto CW Billing Alarm: \$$amount" \
			--threshold "$amount"\
			$(_sub_alarm_option_billing_long_standing)
	done
}

function _put_alarm_CPU90() {
	$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
		--alarm-name "EC2_CPU90_$ALARM_NAME_general" \
		--alarm-description "Auto CW Alarm when CPU utilization exceeds 90percent at $ALARM_DESCRIPTION_general" \
		--metric-name CPUUtilization --namespace AWS/EC2 \
		--dimensions "Name=InstanceId,Value=$EC2_instance" \
		--treat-missing-data breaching \
		$(_sub_alarm_option_EC2general_resources_monitoring) \
		$(_sub_alarm_option_SNS_actions_enabled_all)
}

function _put_alarm_CPU99() {
	$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
		--alarm-name "EC2_CPU99_$ALARM_NAME_general" \
		--alarm-description "LongStanding Auto CW Alarm when CPU utilization exceeds 99percent at $ALARM_DESCRIPTION_general" \
		--metric-name CPUUtilization --namespace AWS/EC2 \
		--dimensions "Name=InstanceId,Value=$EC2_instance" \
		--treat-missing-data breaching \
		$(_sub_alarm_option_EC2general_resources_monitoring_long_standing) \
		$(_sub_alarm_option_SNS_actions_long_standing)
}

function _put_alarm_CPUcredit() {
	# TO DO 
	# figure out the condition
	_ec2_class_verification
	
	# Following condition checks if EC2 instance is T2 class
	echo "$EC2_CLASS_VERIFICATION" | grep "t2" > /dev/null
	if [[ $? -eq 0 ]] ; then
		$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
			--alarm-name "EC2_CPUcredit_$ALARM_NAME_general" \
			--alarm-description "Auto CW Alarm when CPUcredits exceeds the last CPUcredit at $ALARM_DESCRIPTION_general" \
			--metric-name CPUCreditBalance --namespace AWS/EC2 \
			--dimensions "Name=InstanceId,Value=$EC2_instance" \
			--statistic $STATISTIC_VALUE_sum \
			--comparison-operator LessThanThreshold \
			--threshold $THRESHOLD_50 \
			--period $PERIOD_300s \
			--evaluation-periods $EVALUATION_PERIOD_2 --unit Percent \
			$(_sub_alarm_option_SNS_actions_enabled_all)
	else
		log "This EC2 Instance $EC2_instance is not from T2 Class, the CPUcredit alarm was not created."
	fi
}

function _put_alarm_HDD90_vol() {
	echo "$CW_CUSTOM_METRICS_VERIFICATION" | grep "/dev/md1" > /dev/null
	if [[ $? -eq 0 ]] ; then
		$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
			--alarm-name "EC2_HDD90-/encryptedEBS_$ALARM_NAME_general" \
			--alarm-description "Auto CW Alarm when free disc space of /encryptedEBS partition is less than 10percent at $ALARM_DESCRIPTION_general" \
			--metric-name DiskSpaceUtilization --namespace System/Linux \
			--dimensions "Name=Filesystem,Value=/dev/md1" "Name=MountPath,Value=/encryptedEBS" "Name=InstanceId,Value=$EC2_instance" \
			$(_sub_alarm_option_EC2general_resources_monitoring) \
			$(_sub_alarm_option_SNS_actions_enabled_all)
	else
		log "This EC2 Instance $EC2_instance does not have set CloudWatch Custom Metric for HDD /encryptedEBS partition, the HDD utilization alarm was not created."
	fi
}

function _put_alarm_HDD99_vol() {
	echo "$CW_CUSTOM_METRICS_VERIFICATION" | grep "/dev/md1" > /dev/null
	if [[ $? -eq 0 ]] ; then
		$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
			--alarm-name "EC2_HDD99-/encryptedEBS_$ALARM_NAME_general" \
			--alarm-description "LongStanding Auto CW Alarm when free disc space of /encryptedEBS partition is less than 1percent at $ALARM_DESCRIPTION_general" \
			--metric-name DiskSpaceUtilization --namespace System/Linux \
			--dimensions "Name=Filesystem,Value=/dev/md1" "Name=MountPath,Value=/encryptedEBS" "Name=InstanceId,Value=$EC2_instance" \
			$(_sub_alarm_option_EC2general_resources_monitoring_long_standing) \
			$(_sub_alarm_option_SNS_actions_long_standing)
	else
		log "This EC2 Instance $EC2_instance does not have set CloudWatch Custom Metric for HDD /encryptedEBS partition, the HDD utilization alarm was not created."
	fi
}

function _put_alarm_HDD90_xvda1() {
	echo "$CW_CUSTOM_METRICS_VERIFICATION" | grep "/dev/xvda1" > /dev/null
	if [[ $? -eq 0 ]] ; then
		$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
			--alarm-name "EC2_HDD90-/xvda1_$ALARM_NAME_general" \
			--alarm-description "Auto CW Alarm when free disc space of / root partition is less than 10percent at $ALARM_DESCRIPTION_general" \
			--metric-name DiskSpaceUtilization --namespace System/Linux \
			--dimensions "Name=Filesystem,Value=/dev/xvda1" "Name=MountPath,Value=/" "Name=InstanceId,Value=$EC2_instance" \
			$(_sub_alarm_option_EC2general_resources_monitoring) \
			$(_sub_alarm_option_SNS_actions_enabled_all)
	else
		log "This EC2 Instance $EC2_instance does not have set CloudWatch Custom Metric for HDD / root partition, the HDD utilization alarm was not created."
	fi
}

function _put_alarm_HDD99_xvda1() {
	echo "$CW_CUSTOM_METRICS_VERIFICATION" | grep "/dev/xvda1" > /dev/null
	if [[ $? -eq 0 ]] ; then
		$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
			--alarm-name "EC2_HDD99-/xvda1_$ALARM_NAME_general" \
			--alarm-description "LongStanding Auto CW Alarm when free disc space of / root partition is less than 1percent at $ALARM_DESCRIPTION_general" \
			--metric-name DiskSpaceUtilization --namespace System/Linux \
			--dimensions "Name=Filesystem,Value=/dev/xvda1" "Name=MountPath,Value=/" "Name=InstanceId,Value=$EC2_instance" \
			$(_sub_alarm_option_EC2general_resources_monitoring_long_standing) \
			$(_sub_alarm_option_SNS_actions_long_standing)
	else
		log "This EC2 Instance $EC2_instance does not have set CloudWatch Custom Metric for HDD / root partition, the HDD utilization alarm was not created."
	fi
}

function _put_alarm_memory90() {
	echo "$CW_CUSTOM_METRICS_VERIFICATION" | grep "MemoryUtilization" > /dev/null
	if [[ $? -eq 0 ]] ; then
		$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
			--alarm-name "EC2_Memory90_$ALARM_NAME_general" \
			--alarm-description "Auto CW Alarm when Memory utilization exceeds 90percent at $ALARM_DESCRIPTION_general" \
			--metric-name MemoryUtilization --namespace System/Linux \
			--dimensions "Name=InstanceId,Value=$EC2_instance" \
			$(_sub_alarm_option_EC2general_resources_monitoring) \
			$(_sub_alarm_option_SNS_actions_enabled_all)
	else
		log "This EC2 Instance $EC2_instance does not have set CloudWatch Custom Metric for Memory, the MemoryUtilization alarm was not created."
	fi
}

function _put_alarm_memory99() {
	echo "$CW_CUSTOM_METRICS_VERIFICATION" | grep "MemoryUtilization" > /dev/null
	if [[ $? -eq 0 ]] ; then
		$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
			--alarm-name "EC2_Memory99_$ALARM_NAME_general" \
			--alarm-description "Auto CW Alarm when Memory utilization exceeds 99percent at $ALARM_DESCRIPTION_general" \
			--metric-name MemoryUtilization --namespace System/Linux \
			--dimensions "Name=InstanceId,Value=$EC2_instance" \
			$(_sub_alarm_option_EC2general_resources_monitoring_long_standing) \
			$(_sub_alarm_option_SNS_actions_long_standing)
	else
		log "This EC2 Instance $EC2_instance does not have set CloudWatch Custom Metric for Memory, the MemoryUtilization alarm was not created."
	fi
}

function _put_alarm_status_check_system() {
	# TO DO Adding Recover Actions to Amazon CloudWatch Alarms

	$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
		--alarm-name "EC2_StatusCheck-System_$ALARM_NAME_general" \
		--alarm-description "Auto CW Alarm when StatusCheck-System is Failed at $ALARM_DESCRIPTION_general" \
		--metric-name StatusCheckFailed_System --namespace AWS/EC2 \
		$(_sub_alarm_option_EC2status_monitoring) \
		$(_sub_alarm_option_SNS_actions_enabled_all)
}

function _put_alarm_status_check_instance() {
	# TODO Adding Reboot Actions to Amazon CloudWatch Alarms

	$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
		--alarm-name "EC2_StatusCheck-Instance_$ALARM_NAME_general" \
		--alarm-description "Auto CW Alarm when StatusCheck-Instance is Failed at $ALARM_DESCRIPTION_general" \
		--metric-name StatusCheckFailed_Instance --namespace AWS/EC2 \
		$(_sub_alarm_option_EC2status_monitoring) \
		$(_sub_alarm_option_SNS_actions_enabled_all)
}

function _put_alarm_status_check() {
	$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
		--alarm-name "EC2_StatusCheck_$ALARM_NAME_general" \
		--alarm-description "Auto CW Alarm when StatusCheck is Failed at $ALARM_DESCRIPTION_general" \
		--metric-name StatusCheckFailed --namespace AWS/EC2 \
		--treat-missing-data breaching \
		$(_sub_alarm_option_EC2status_monitoring) \
		$(_sub_alarm_option_SNS_actions_enabled_all)
}

function _put_alarm_status_check_long_standing() {
	$AWS_COMMAND cloudwatch put-metric-alarm --region "$AWS_REGION" --output text \
		--alarm-name "EC2_StatusCheck_LongStanding_$ALARM_NAME_general" \
		--alarm-description "LongStanding Auto CW Alarm when StatusCheck is Failed at $ALARM_DESCRIPTION_general" \
		--metric-name StatusCheckFailed --namespace AWS/EC2 \
		--treat-missing-data breaching \
		--comparison-operator GreaterThanThreshold  --dimensions "Name=InstanceId,Value=$EC2_instance" \
		--statistic $STATISTIC_VALUE_minimum --period $PERIOD_60s --threshold $THRESHOLD_0 \
		--evaluation-periods $EVALUATION_PERIOD_15 --unit Count \
		$(_sub_alarm_option_SNS_actions_long_standing)
}


function _ec2_class_verification() {
	# This function checks the EC2 instance class
	EC2_CLASS_VERIFICATION=$($AWS_COMMAND ec2 describe-instances --region "$AWS_REGION" --output text \
		--instance-ids $EC2_instance \
		--query 'Reservations[*].Instances[*].[InstanceType]')
	}

function _ec2_instance_name_description() {
	# aws ec2 describe-tags --region us-east-1 --output text --filters "Name=resource-id,Values=i-XXXXXXXXXXXXX" "Name=key,Values=Name" | cut -f5
	# TAG name
	EC2_TAG01_VALUE=$($AWS_COMMAND ec2 describe-tags --region "$AWS_REGION" --output text \
		--filters "Name=resource-id,Values=$EC2_instance" "Name=key,Values=$EC2_TAG01_KEY" | cut -f5)		

	# TAG Family
	EC2_TAG03_VALUE=$($AWS_COMMAND ec2 describe-tags --region "$AWS_REGION" --output text \
		--filters "Name=resource-id,Values=$EC2_instance" "Name=key,Values=$EC2_TAG03_KEY" | cut -f5)

	# TAG Mode
	EC2_TAG04_VALUE=$($AWS_COMMAND ec2 describe-tags --region "$AWS_REGION" --output text \
		--filters "Name=resource-id,Values=$EC2_instance" "Name=key,Values=$EC2_TAG04_KEY" | cut -f5)

	ALARM_NAME_general=${EC2_TAG03_VALUE}'_'$EC2_TAG04_VALUE'_'$EC2_instance
	ALARM_DESCRIPTION_general="$EC2_TAG01_VALUE $EC2_instance"
}

function _ec2_instance_verification_AWS_Managed-EC2() {
	# This function checks if the script starts at AWS CLI instance
	# in Master Mode
	EC2_AWS_Managed-EC2_VERIFICATION=$($AWS_COMMAND ec2 describe-instances --region "$AWS_REGION" --output text \
		--instance-ids "$CURRENT_EC2_INSTANCE_ID" \
		--filters "Name=tag-key,Values=$EC2_TAG00_KEY" "Name=tag-value,Values=$EC2_TAG00_VALUE_AWS_Managed-EC2" \
		"Name=tag-key,Values=$EC2_TAG04_KEY" "Name=tag-value,Values=$EC2_TAG04_VALUE_Master" \
		--query 'Reservations[*].Instances[*].[InstanceId]')
}

function _ec2_tag_verification() {
	# This function checks if the EC2 instance has assigned
	# tags CW_Alarms = Created
	EC2_TAG_VERIFICATION=$($AWS_COMMAND ec2 describe-instances --region "$AWS_REGION" --output text \
		--instance-ids "$EC2_instance" \
		--filters "Name=tag-key,Values=$EC2_TAG05_KEY" "Name=tag-value,Values=$EC2_TAG05_VALUE" \
		--query 'Reservations[*].Instances[*].[InstanceId]')
}

function _cloudwatch_custom_metrics_verification() {
	# This function checks if there exists CloudWatch Custom metric
	CW_CUSTOM_METRICS_VERIFICATION=$($AWS_COMMAND cloudwatch list-metrics --region "$AWS_REGION" --output text \
		--namespace System/Linux \
		--dimensions "Name=InstanceId,Value=$EC2_instance")
}

function _running_EC2() {
	# show running instances

	LIST_OF_EC2_instances=$($AWS_COMMAND ec2 describe-instances --region "$AWS_REGION" --output text \
		--filters "Name=$EC2_STATE_NAME,Values=$EC2_STATE_VALUE_running" \
		"Name=tag-key,Values=$EC2_TAG02_KEY" "Name=tag-value,Values=$EC2_TAG02_VALUE" \
		--query 'Reservations[*].Instances[*].[InstanceId]')
}

function _tagging_ec2_cloudwatch_tag() {
	# as soon as the CloudWatch Alarms are created, we TAG the EC2 instance,
	# so next time the script will not re-create the same Alarms
	# Tag key = CW_Alarms [Created]
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
		--resource "$EC2_instance" \
		--tags Key=${EC2_TAG05_KEY},Value=${EC2_TAG05_VALUE}
}


function cleaning_logs() {
	# clean a STDOUT file if the size is more than 10MB
	if [ -f "$LOG_FILE_STDOUT" ]; then
		LOG_FILE_STDOUT_SIZE=$(stat -c %s ${LOG_FILE_STDOUT})
		if [ "$LOG_FILE_STDOUT_SIZE" -ge 10000 ] ; then
			echo > $LOG_FILE_STDOUT
		fi
	fi

	# to clear a file into which script temporary saves snapshot IDs for TAGGING purposes
	if [ -f $LOG_TEMP_SNAPSHOT_ID ]; then
		rm -rf $LOG_TEMP_SNAPSHOT_ID
	fi

	# to clear a file into which script temporary saves snapshot IDs for TAGGING purposes
	if [ -f $LOG_TEMP_EC2_LIST ]; then
		rm -rf $LOG_TEMP_EC2_LIST
	fi

	# Check if LOG_FILE_STDOUT exists and is writable
	# Setup logfile and redirect stdout/stderr.
	( [ -e "$LOG_FILE_STDOUT" ] || touch "$LOG_FILE_STDOUT" ) && [ ! -w "$LOG_FILE_STDOUT" ] && \
		echo "ERROR: Cannot write to $LOG_FILE_STDOUT. Check permissions or sudo access." && exit 1

	tmplog=$(tail -n $LOG_FILE_STDOUT_max_lines $LOG_FILE_STDOUT 2>/dev/null) && echo "${tmplog}" > $LOG_FILE_STDOUT
}

function creating_alarms_EC2() {

	_running_EC2

	for EC2_instance in $LIST_OF_EC2_instances; do

		_ec2_tag_verification

		# Following condition will allow to create CloudWatch alarms only on
		# new EC2 instances without the TAG - CW_Alarms=Created
		if [[ $EC2_TAG_VERIFICATION =~ .*i-.* ]]; then

			log "The CloudWatch Alarms are already assigned into EC2 instance $EC2_instance, the CW Alarms will not be re-created."

		else	
			_ec2_instance_name_description
			_cloudwatch_custom_metrics_verification

			_put_alarm_CPU90
			_put_alarm_CPUcredit
			_put_alarm_memory90
			_put_alarm_HDD90_xvda1
			_put_alarm_HDD90_vol
			_put_alarm_status_check
			_put_alarm_status_check_instance
			_put_alarm_status_check_system

			# Alarms for long-standing issues connected to PagerDuty, etc.
			_put_alarm_status_check_long_standing
			_put_alarm_CPU99
			_put_alarm_HDD99_vol
			_put_alarm_HDD90_xvda1
			_put_alarm_memory99

			#log "Running EBS snapshots on $EC2_TAG03_VALUE $EC2_TAG04_VALUE - $EC2_instance:"


			#log "EBS Snapshots of $EC2_TAG03_VALUE $EC2_TAG04_VALUE - $EC2_instance were created"
			#log ""

			# redirect of EC2 description for the final list
			#echo "$EC2_TAG03_VALUE $EC2_TAG04_VALUE - $EC2_instance" >> $LOG_TEMP_EC2_LIST

			_tagging_ec2_cloudwatch_tag

			log "The script has created new CloudWatch Alarms for the EC2 instance $EC2_instance."
		fi		 
	done
}

function creating_alarms_Billing() {

	_put_alarm_billing
	log "The script succesfully created new CloudWatch Billing Alarms."
}

function log() {
	# Log an event
	echo "[$(date +%Y-%m-%d-%T)]: $*"
}

function upgrade_of_CLI_package() {
	# upgrading of AWS Command Line Interface
	# http://docs.aws.amazon.com/cli/latest/userguide/installing.html
	pip install awscli --upgrade --user > /dev/null
	echo -n "[$DATE_LONG]: AWS CLI version: "
	$AWS_COMMAND --version
}


cleaning_logs
log "==> CloudWatch Alarm Creator Script starts @ $DATE_LONG on $CURRENT_EC2_HOSTNAME ($CURRENT_EC2_INSTANCE_ID)"

upgrade_of_CLI_package
_ec2_instance_verification_AWS_Managed-EC2

# Following condition will allow to run this script only from Central Unit Maintenance Servers
if [[ $EC2_AWS_Managed-EC2_VERIFICATION =~ .*i-.* ]]; then

	echo "condition OK"
	creating_alarms_EC2
	creating_alarms_Billing

else
	echo "condition FAIL"

fi
