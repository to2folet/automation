#!/bin/bash

ENVIRONMENT=$1


: <<'COMMENT'

Centralize General EBS backup solution script - version 1.0

This script will check Tags of EC2 instances and it will create a snapshot of EBS volumes which are attached to an EC2 instance.
If we will not use an argument, the script will start with the menu for manual creating of EBS snapshots.
EC2 instances use AWS tags Backup=Daily or Backup=Weekly on the Master instance and on one Slave instance.

Main description:
  - Script can be run manually or with 1 argument (!)
  - Script can make EBS snapshots from one specific EC2 instance or we can run it against a group of EC2 instances
  - If the script has generated any STDERR we will be notified by email

Conditions:
  - Script can be ran only from EC2 instance with Tags Family=BackupInstance && Mode=Master

  - EBS snapshot is created from an EC2 instance only if
    * EC2 instance is in running state && 
    * with the AWS Tag Stack=Production &&
    * with the AWS Tag Backup=Daily || Backup=Weekly

  - EBS snapshot will be removed only if
    * EBS snapshot age meets the RetentionPolicy age condition &&
    * contains Tag Creator=AutomatedBackup &&
    * contains Tag RetentionPolicy=Yes &&
    * contains Tag Backup=Daily || Backup=Weekly || Backup=Monthly

This script follows our Retention Policy:
  - EBS snapshots
    * daily snapshots: keep last 32 days
    * weekly snapshots: keep last 4 weeks
    * keep 1st day of each month up to 1 year
    * keep 1st day of each year

Using:
$ sudo /scripts/aws-scripts/ebs-general-backup.sh
$ sudo /scripts/aws-scripts/ebs-general-backup.sh auto_ebs_snapshot_daily

The options are:
 - auto_ebs_snapshot_daily, auto_ebs_snapshot_weekly, auto_ebs_snapshot_monthly auto_ebs_snapshot_annually"
 - auto_ebs_snapshot_cleaner_daily, auto_ebs_snapshot_cleaner_weekly, auto_ebs_snapshot_cleaner_monthly"

We can use only one argument

Location of cronjob : /etc/cron.d/ebs-general-backup-job
Location of script : /scripts/aws-scripts/ebs-general-backup.sh

TO DO:
* copy EBS snapshots into different region
* copy EBS snapshots into secondary AWS account


COMMENT


# Variables of the EC2 machine which runs backups
BACKUP_EC2_AWS_REGION=$(wget -q -O- http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\([1-9]\).$/\1/g')
BACKUP_EC2_INSTANCE_ID=$(wget -q -O- http://169.254.169.254/latest/meta-data/instance-id)
BACKUP_EC2_HOSTNAME=$(hostname)
AWS_COMMAND="/usr/local/bin/aws"

# Since we use only one the primary AWS Region us-east-1
# We use the same region in which is Backup Instance (BackupInstance instance) located
AWS_REGION=$BACKUP_EC2_AWS_REGION

EMAIL_RECIPIENT="email@company.com"

LOG_FILE_STDOUT="/var/log/aws_backup-stdout.log"
LOG_FILE_STDERR="/var/log/aws_backup-stderr.log"

LOG_FILE_STDOUT_max_lines="50000"
LOG_TEMP_SNAPSHOT_ID="/var/log/aws_backup-snapshot_id.tmp"
LOG_TEMP_EC2_LIST="/var/log/aws_backup-ec2_list.tmp"

# How many days should the EBS backups retain for
RETENTION_DAYS_daily="32"
RETENTION_DAYS_weekly="32"
RETENTION_DAYS_monthly="366"
RETENTION_DATE_IN_SECONDS_daily=$(date +%s --date "$RETENTION_DAYS_daily days ago")
RETENTION_DATE_IN_SECONDS_weekly=$(date +%s --date "$RETENTION_DAYS_weekly days ago")
RETENTION_DATE_IN_SECONDS_monthly=$(date +%s --date "$RETENTION_DAYS_monthly days ago")


DATE_LONG=$(date +%Y-%m-%d-%T)

# EC2 Tags
EC2_TAG00_KEY=Family
EC2_TAG00_VALUE_BackupInstance=BackupInstance

EC2_TAG01_KEY=Backup
EC2_TAG01_VALUE_Daily=Daily
EC2_TAG01_VALUE_Weekly=Weekly

EC2_TAG02_KEY=Stack
EC2_TAG02_VALUE=Production

EC2_TAG03_KEY=Family

EC2_TAG04_KEY=Mode
EC2_TAG04_VALUE_Master=Master

EC2_STATE_NAME=instance-state-name
EC2_STATE_VALUE_running=running
EC2_STATE_VALUE_stopped=stopped


# EBS Tags
EBS_TAG00_KEY=Name

EBS_TAG01_KEY=Stack
EBS_TAG01_VALUE=Production

EBS_TAG02_KEY=Period
EBS_TAG02_VALUE_Daily=Daily
EBS_TAG02_VALUE_Weekly=Weekly
EBS_TAG02_VALUE_OneTime=One-Time
EBS_TAG02_VALUE_Monthly=Monthly
EBS_TAG02_VALUE_Annually=Annually

EBS_TAG03_KEY=Creator
EBS_TAG03_VALUE=AutomatedBackup

EBS_TAG04_KEY=RetentionPolicy
EBS_TAG04_VALUE=Yes

function upgrade_of_CLI_package() {
    # upgrading of AWS Command Line Interface
    # http://docs.aws.amazon.com/cli/latest/userguide/installing.html
    pip install awscli --upgrade --user > /dev/null
    echo -n "[$DATE_LONG]: AWS CLI version: "
	$AWS_COMMAND --version
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

	# to clear a file into which script temporary saves list of EC2 instances for TAGGING purposes
	if [ -f $LOG_TEMP_EC2_LIST ]; then
	    rm -rf $LOG_TEMP_EC2_LIST
	fi

	# Check if LOG_FILE_STDOUT exists and is writable
	# Setup logfile and redirect stdout/stderr.
	( [ -e "$LOG_FILE_STDOUT" ] || touch "$LOG_FILE_STDOUT" ) && [ ! -w "$LOG_FILE_STDOUT" ] && \
		echo "ERROR: Cannot write to $LOG_FILE_STDOUT. Check permissions or sudo access." && exit 1

	tmplog=$(tail -n $LOG_FILE_STDOUT_max_lines $LOG_FILE_STDOUT 2>/dev/null) && echo "${tmplog}" > $LOG_FILE_STDOUT
}

function log() {
    # Log an event
    echo "[$(date +%Y-%m-%d-%T)]: $*"
}

function copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/aws-scripts/ebs-general-backup.sh"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/ebs-general-backup.sh"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

function press_enter() {
    echo ""
    echo -n "Press Enter to continue"
    read -r
    clear
}

function email_notification() {
    # following condition checks if /var/log/aws_backup-stderr.log contents something, if yes, it will send an email notification
    if [ -f $LOG_FILE_STDERR ] && [ -s $LOG_FILE_STDERR ]; then
        {
	        log "WARNING"
	        log "       backup ISSUE @ $DATE_LONG on $BACKUP_EC2_HOSTNAME ($BACKUP_EC2_INSTANCE_ID)"
	        log "       After troubleshooting please delete this */var/log/aws_backup-stderr.log* log file"
	        log "       $ sudo rm -rf /var/log/aws_backup-stderr.log"
	        log "Email was sent to $EMAIL_RECIPIENT"
        	log "====================================================================================================================="
        	log ""	        
        } | tee -a $LOG_FILE_STDERR >> $LOG_FILE_STDOUT
        sudo cat $LOG_FILE_STDERR | mail -s "$BACKUP_EC2_HOSTNAME - EBS snapshot PROBLEM" -a "From: $BACKUP_EC2_HOSTNAME@domain.net" $EMAIL_RECIPIENT
    else
        if [ -f $LOG_TEMP_EC2_LIST ]; then
	        log "The script was ran against the following EC2 instances:"
	        cat $LOG_TEMP_EC2_LIST
	fi
        	log "******* End of script which has started @ $DATE_LONG on $BACKUP_EC2_HOSTNAME ($BACKUP_EC2_INSTANCE_ID) - COMPLETED"
        	log "====================================================================================================================="
        	log ""
    fi
}

function _creating_snapshot() {
	# Get the attached device name to add to the description (ie /dev/sdh)
	DEVICE_NAME=$($AWS_COMMAND ec2 describe-volumes --region "$AWS_REGION" --output text \
		--volume-ids "$VOLUME_ID" --query 'Volumes[0].{Devices:Attachments[0].Device}')

	# Take a snapshot of the current volume, and capture the resulting snapshot ID
	SNAPSHOT_DESCRIPTION_creating="$EC2_TAG03_VALUE-$EC2_TAG04_VALUE with device: $DEVICE_NAME, $DATE_LONG"

	SNAPSHOT_ID=$($AWS_COMMAND ec2 create-snapshot --region "$AWS_REGION" --output text \
		--description "$SNAPSHOT_DESCRIPTION_creating" --volume-id "$VOLUME_ID" --query SnapshotId)
 	
	log " The EBS snapshot $SNAPSHOT_ID was created from EBS volume $VOLUME_ID which is attached to EC2 Instance $EC2_instance"

	# Add EBS general TAGs
	_tagging_snapshots_general_tags
}

function _date_comparing_condition_daily() {
	if (( $SNAPSHOT_DATE_in_seconds <= $RETENTION_DATE_IN_SECONDS_daily )); then
		log "DELETING snapshot $SNAPSHOT_ID. Description: $SNAPSHOT_DESCRIPTION_calling ..."
		$AWS_COMMAND ec2 delete-snapshot --region "$AWS_REGION" --snapshot-id "$SNAPSHOT_ID"
	else
		log "Not deleting snapshot $SNAPSHOT_ID. Description: $SNAPSHOT_DESCRIPTION_calling ..."
	fi
}

function _date_comparing_condition_weekly() {
	if (( $SNAPSHOT_DATE_in_seconds <= $RETENTION_DATE_IN_SECONDS_weekly )); then
		log "DELETING snapshot $SNAPSHOT_ID. Description: $SNAPSHOT_DESCRIPTION_calling ..."
		$AWS_COMMAND ec2 delete-snapshot --region "$AWS_REGION" --snapshot-id "$SNAPSHOT_ID"
	else
		log "Not deleting snapshot $SNAPSHOT_ID. Description: $SNAPSHOT_DESCRIPTION_calling ..."
	fi
}

function _date_comparing_condition_monthly() {
	if (( $SNAPSHOT_DATE_in_seconds <= $RETENTION_DATE_IN_SECONDS_monthly )); then
		log "DELETING snapshot $SNAPSHOT_ID. Description: $SNAPSHOT_DESCRIPTION_calling ..."
		$AWS_COMMAND ec2 delete-snapshot --region "$AWS_REGION" --snapshot-id "$SNAPSHOT_ID"
	else
		log "Not deleting snapshot $SNAPSHOT_ID. Description: $SNAPSHOT_DESCRIPTION_calling ..."
	fi
}

function _ec2_instances_list_DailyBackup() {
	LIST_OF_EC2_instances=$($AWS_COMMAND ec2 describe-instances --region "$AWS_REGION" --output text \
		--filters "Name=$EC2_STATE_NAME,Values=$EC2_STATE_VALUE_running" \
		"Name=tag-key,Values=$EC2_TAG01_KEY" "Name=tag-value,Values=$EC2_TAG01_VALUE_Daily" \
		"Name=tag-key,Values=$EC2_TAG02_KEY" "Name=tag-value,Values=$EC2_TAG02_VALUE" \
		--query 'Reservations[*].Instances[*].[InstanceId]')
}

function _ec2_instances_list_WeeklyBackup() {
	LIST_OF_EC2_instances=$($AWS_COMMAND ec2 describe-instances --region "$AWS_REGION" --output text \
		--filters "Name=$EC2_STATE_NAME,Values=$EC2_STATE_VALUE_running" \
		"Name=tag-key,Values=$EC2_TAG01_KEY" "Name=tag-value,Values=$EC2_TAG01_VALUE_Weekly" \
		"Name=tag-key,Values=$EC2_TAG02_KEY" "Name=tag-value,Values=$EC2_TAG02_VALUE" \
		--query 'Reservations[*].Instances[*].[InstanceId]')
}

function _ec2_instance_name_description() {
	EC2_TAG03_VALUE=$($AWS_COMMAND ec2 describe-tags --region "$AWS_REGION" --output text \
    		--filters "Name=resource-id,Values=$EC2_instance" "Name=key,Values=$EC2_TAG03_KEY" | cut -f5)
	EC2_TAG04_VALUE=$($AWS_COMMAND ec2 describe-tags --region "$AWS_REGION" --output text \
		--filters "Name=resource-id,Values=$EC2_instance" "Name=key,Values=$EC2_TAG04_KEY" | cut -f5)
}

function _ec2_instance_verification_BackupInstance() {
	# This function check if the script starts at BackupInstance instance
	# in Master Mode
	EC2_BackupInstance_VERIFICATION=$($AWS_COMMAND ec2 describe-instances --region "$BACKUP_EC2_AWS_REGION" --output text \
    		--instance-ids "$BACKUP_EC2_INSTANCE_ID" \
    		--filters "Name=tag-key,Values=$EC2_TAG00_KEY" "Name=tag-value,Values=$EC2_TAG00_VALUE_BackupInstance" \
    		"Name=tag-key,Values=$EC2_TAG04_KEY" "Name=tag-value,Values=$EC2_TAG04_VALUE_Master" \
    		--query 'Reservations[*].Instances[*].[InstanceId]')
}

function _running_EC2() {
	# show running instances
	${AWS_COMMAND} ec2 describe-instances --region "$AWS_REGION" --output table \
		--filters "Name=$EC2_STATE_NAME,Values=$EC2_STATE_VALUE_running" \
		--query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value | [0], State.Name]' | sort -k3f
}

function _snapshot_age() {
	# Check age of snapshot
	SNAPSHOT_DATE=$($AWS_COMMAND ec2 describe-snapshots --region "$AWS_REGION" --output text \
		--snapshot-ids "$SNAPSHOT_ID" --query Snapshots[].StartTime | awk -F "T" '{printf "%s\n", $1}')
	SNAPSHOT_DATE_in_seconds=$(date "--date=$SNAPSHOT_DATE" +%s)

	# Check description of snapshot
	SNAPSHOT_DESCRIPTION_calling=$($AWS_COMMAND ec2 describe-snapshots --region "$AWS_REGION" --output text \
		--snapshot-id "$SNAPSHOT_ID" --query Snapshots[].Description)
}

function _snapshot_list_cleaning_daily() {
	# List of EBS snapshots which meet the condition
	## Tag - Creator = AutomatedBackup &
	## Tag - RetentionPolicy = Yes
	SNAPSHOT_LIST_CLEANING=$($AWS_COMMAND ec2 describe-snapshots --region "$AWS_REGION" --output text \
		--filters "Name=tag-key,Values=$EBS_TAG02_KEY" "Name=tag-value,Values=$EBS_TAG02_VALUE_Daily" \
		"Name=tag-key,Values=$EBS_TAG03_KEY" "Name=tag-value,Values=$EBS_TAG03_VALUE" \
		"Name=tag-key,Values=$EBS_TAG04_KEY" "Name=tag-value,Values=$EBS_TAG04_VALUE" --query Snapshots[].SnapshotId)
}

function _snapshot_list_cleaning_weekly() {
	# List of EBS snapshots which meet the condition
	## Tag - Creator = AutomatedBackup &
	## Tag - RetentionPolicy = Yes
	SNAPSHOT_LIST_CLEANING=$($AWS_COMMAND ec2 describe-snapshots --region "$AWS_REGION" --output text \
		--filters "Name=tag-key,Values=$EBS_TAG02_KEY" "Name=tag-value,Values=$EBS_TAG02_VALUE_Weekly" \
		"Name=tag-key,Values=$EBS_TAG03_KEY" "Name=tag-value,Values=$EBS_TAG03_VALUE" \
		"Name=tag-key,Values=$EBS_TAG04_KEY" "Name=tag-value,Values=$EBS_TAG04_VALUE" --query Snapshots[].SnapshotId)
}

function _snapshot_list_cleaning_onetime() {
	# List of EBS snapshots which meet the condition
	## Tag - Creator = AutomatedBackup &
	## Tag - RetentionPolicy = Yes
	SNAPSHOT_LIST_CLEANING=$($AWS_COMMAND ec2 describe-snapshots --region "$AWS_REGION" --output text \
		--filters "Name=tag-key,Values=$EBS_TAG02_KEY" "Name=tag-value,Values=$EBS_TAG02_VALUE_OneTime" \
		"Name=tag-key,Values=$EBS_TAG03_KEY" "Name=tag-value,Values=$EBS_TAG03_VALUE" \
		"Name=tag-key,Values=$EBS_TAG04_KEY" "Name=tag-value,Values=$EBS_TAG04_VALUE" --query Snapshots[].SnapshotId)
}

function _snapshot_list_cleaning_monthly() {
	# List of EBS snapshots which meet the condition
	## Tag - Creator = AutomatedBackup &
	## Tag - RetentionPolicy = Yes
	SNAPSHOT_LIST_CLEANING=$($AWS_COMMAND ec2 describe-snapshots --region "$AWS_REGION" --output text \
		--filters "Name=tag-key,Values=$EBS_TAG02_KEY" "Name=tag-value,Values=$EBS_TAG02_VALUE_Monthly" \
		"Name=tag-key,Values=$EBS_TAG03_KEY" "Name=tag-value,Values=$EBS_TAG03_VALUE" \
		"Name=tag-key,Values=$EBS_TAG04_KEY" "Name=tag-value,Values=$EBS_TAG04_VALUE" --query Snapshots[].SnapshotId)
}

function _stopped_EC2() {
	# show stopped instances
	${AWS_COMMAND} ec2 describe-instances --region "$AWS_REGION" --output table \
		--filters "Name=instance-state-name,Values=$EC2_STATE_VALUE_stopped" \
		--query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value | [0], State.Name]' | sort -k3f
}

function _tagging_snapshots_general_tags() {
	# General EBS Tags which are same for all automated EBS snapshots
	EBS_TAG00_VALUE="$EC2_TAG03_VALUE-$EC2_TAG04_VALUE-$DEVICE_NAME-$DATE_LONG"

	# Tag key = Name
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
        	--resource "$SNAPSHOT_ID" \
        	--tags Key=${EBS_TAG00_KEY},Value=${EBS_TAG00_VALUE}

	# Tag key = Backup [One-Time, DailyWeekly,..]
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
        	--resource "$SNAPSHOT_ID" \
        	--tags Key=${EBS_TAG01_KEY},Value=${EBS_TAG01_VALUE}

	# Tag key = Creator [AutomatedBackup]
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
		--resource "$SNAPSHOT_ID" \
		--tags Key=${EBS_TAG03_KEY},Value=${EBS_TAG03_VALUE}

	# Tag key = Family [Cast, Store...]
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
		--resource "$SNAPSHOT_ID" \
		--tags Key=${EC2_TAG03_KEY},Value=${EC2_TAG03_VALUE}

	# Tag key = Mode [Master/Slave]
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
		--resource "$SNAPSHOT_ID" \
		--tags Key=${EC2_TAG04_KEY},Value=${EC2_TAG04_VALUE}
}

function _tagging_snapshots_retention_tag() {
	# Tag key = RetentionPolicy [Yes]
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
		--resource "$SNAPSHOT_ID" \
		--tags Key=${EBS_TAG04_KEY},Value=${EBS_TAG04_VALUE}
}

function _tagging_snapshots_onetime_tag() {
	# Tag snapshot with a TAG Period=One-Time
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
		--resource "$SNAPSHOT_ID" \
		--tags Key=${EBS_TAG02_KEY},Value=${EBS_TAG02_VALUE_OneTime}
}

function _tagging_snapshots_mass_onetime_tag() {
	SNAPSHOT_ID_FOR_TAGGING=`cat $LOG_TEMP_SNAPSHOT_ID`
  	# Tag key = Backup [One-Time, Daily, Weekly]
	# Tag snapshot with a TAG VALUE=ONETIME
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
        	--resource ${SNAPSHOT_ID_FOR_TAGGING} \
        	--tags Key=${EBS_TAG02_KEY},Value=${EBS_TAG02_VALUE_OneTime}
}

function _tagging_snapshots_mass_daily_tag() {
	SNAPSHOT_ID_FOR_TAGGING=`cat $LOG_TEMP_SNAPSHOT_ID`
  	# Tag key = Backup [One-Time, Daily, Weekly,..]
	# Tag snapshot with a TAG VALUE=Daily
	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
        	--resource ${SNAPSHOT_ID_FOR_TAGGING} \
        	--tags Key=${EBS_TAG02_KEY},Value=${EBS_TAG02_VALUE_Daily}
}

function _tagging_snapshots_mass_weekly_tag() {
	SNAPSHOT_ID_FOR_TAGGING=`cat $LOG_TEMP_SNAPSHOT_ID`
  	# Tag key = Backup [One-Time, Daily, Weekly,..]
    	# Tag snapshot with a TAG VALUE=Weekly
    	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
        	--resource ${SNAPSHOT_ID_FOR_TAGGING} \
        	--tags Key=${EBS_TAG02_KEY},Value=${EBS_TAG02_VALUE_Weekly}
}

function _tagging_snapshots_mass_monthly_tag() {
	#SNAPSHOT_ID_FOR_TAGGING=$(cat $LOG_TEMP_SNAPSHOT_ID)
	SNAPSHOT_ID_FOR_TAGGING=`cat $LOG_TEMP_SNAPSHOT_ID`
  	# Tag key = Backup [One-Time, Daily, Weekly,..]
    	# Tag snapshot with a TAG VALUE=Monthly
    	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
        	--resource ${SNAPSHOT_ID_FOR_TAGGING} \
        	--tags Key=${EBS_TAG02_KEY},Value=${EBS_TAG02_VALUE_Monthly}
}

function _tagging_snapshots_mass_annually_tag() {
	#SNAPSHOT_ID_FOR_TAGGING=$(cat $LOG_TEMP_SNAPSHOT_ID)
	SNAPSHOT_ID_FOR_TAGGING=`cat $LOG_TEMP_SNAPSHOT_ID`
  	# Tag key = Backup [One-Time, Daily, Weekly,..]
    	# Tag snapshot with a TAG VALUE=Monthly
    	${AWS_COMMAND} ec2 create-tags --region "$AWS_REGION" \
        	--resource ${SNAPSHOT_ID_FOR_TAGGING} \
        	--tags Key=${EBS_TAG02_KEY},Value=${EBS_TAG02_VALUE_Annually}
}

function _volume_list() {
	VOLUME_LIST=$($AWS_COMMAND ec2 describe-instances --region "$AWS_REGION" --output text \
		--instance-ids "$EC2_instance" \
		--query 'Reservations[*].Instances[].[BlockDeviceMappings[*].[DeviceName,Ebs.VolumeId]]' | \
		grep -v "/dev/sda1" | cut -f2)
}

function menu_onetime_snapshot_specificEC2() {
	selection_onetime_snapshot_specificEC2=
	until [ "$selection_onetime_snapshot_specificEC2" = "0" ]; do
	    echo $'\nONE-TIME EBS snapshot of specific EC2 instance'
	    echo $'\nOPTIONS'
	    echo "1 - List of running EC2 Instances in US-EAST-1"
	    echo "2 - List of stopped EC2 Instances in US-EAST-1"
	    echo "3 - Complete list of EC2 Instances (running & stopped) in US-EAST-1"
	    echo ""
	    echo "0 - exit program"
	    echo ""
	    echo -n "Please enter your choice: "
	    read -r selection_onetime_snapshot_specificEC2
	    echo "" 

	    case $selection_onetime_snapshot_specificEC2 in
	        1 ) 
	        echo "List of running EC2 Instances in US-EAST-1:"
	        _running_EC2
	        snapshot_volumes_onetime_specificEC2
	        
	        exit ;;

	        2 ) 
	        echo "List of stopped EC2 Instances in US-EAST-1:"
	        _stopped_EC2
	        snapshot_volumes_onetime_specificEC2
	        
	        exit ;;

	        3 ) 
	        echo "Complete list of EC2 Instances (running & stopped) in US-EAST-1:"
	        _running_EC2
	        _stopped_EC2
			snapshot_volumes_onetime_specificEC2
	        
	        exit ;;

	        0 ) 
			echo "Script was terminated"
			exit ;;
			
	        * ) echo "Please enter 1, 2, 3, or 0"; press_enter
	    esac
	done
}

function optional_adding_retention_tag() {
	# This function will ask if we wanna add the tag RetentionPolicy=Yes
	# into manually ran snapshots, 
	# so on these new one-time snapshots will be applied EBS RetentionPolicy
	echo $'\nDo you wish to associate the Tag RetentionPolicy=Yes with these new snapshots?'
	echo $'	Type   Y   , if script should apply RetentionPolicy on these new One-Time snapshots'
	echo $'	Type   n   , if these snapshots should not be automatically removed in the future'
	echo ""
	echo -n "Your choice ( Y / n ): "
	read -r input_variable_adding_retention_tag
	
	if [[ "$input_variable_adding_retention_tag" =~ ^(yes|y|Y|YES|Yes)$ ]]; then
		echo $'\nThe RetentionPolicy tag will be added'
	else
		echo $'\nThe RetentionPolicy tag will NOT be added'
	fi
	echo ""
}

# Snapshot all volumes attached to the running instances which meet the conditions:
# Production Stack & Backup Enabled (Daily or Weekly)
function snapshot_volumes_general() {
	# in case if we would like to extend our backup solution across more regions
	### list of all AWS regions
	### LIST_OF_REGIONS=$($AWS_COMMAND ec2 --region $BACKUP_EC2_AWS_REGION describe-regions --output text | cut -f 3)
	### for AWS_REGION in $LIST_OF_REGIONS; do
	### {
	###	  ...
	### }
	### done

	for EC2_instance in $LIST_OF_EC2_instances; do
	    
	    _volume_list
	    _ec2_instance_name_description		
		log "Running EBS snapshots on $EC2_TAG03_VALUE $EC2_TAG04_VALUE - $EC2_instance:"

		for VOLUME_ID in $VOLUME_LIST; do
			
			_creating_snapshot
			
			# save SNAPSHOT_ID of the new snapshot for the further Tagging Purposes
			echo "$SNAPSHOT_ID" >> $LOG_TEMP_SNAPSHOT_ID

			_tagging_snapshots_retention_tag

	        # TODO: Copy an EBS snapshot to a different REGION

		done
		log "EBS Snapshots of $EC2_TAG03_VALUE $EC2_TAG04_VALUE - $EC2_instance were created"
		log ""

		# redirect of EC2 description for the final list
		echo "$EC2_TAG03_VALUE $EC2_TAG04_VALUE - $EC2_instance" >> $LOG_TEMP_EC2_LIST
	done
}

function snapshot_volumes_onetime_specificEC2() {

	# Function for onetime snapshot of a specific EC2 instance
	echo $'\n\n\nPlease type bellow an EC2 InstanceID of the EC2 instance which you would like to backup'
	echo $'	for example: i-0fg012a8a87bcd626'
	echo ""
	echo -n "The EC2 InstanceID: "
	read -r input_variable
	echo "You entered: $input_variable"

	optional_adding_retention_tag

	EC2_instance=$input_variable  
	_volume_list
	_ec2_instance_name_description

	for VOLUME_ID in $VOLUME_LIST; do

		_creating_snapshot

	    # Tag snapshot with a TAG Period=One-Time
		_tagging_snapshots_onetime_tag
		
		if [[ "$input_variable_adding_retention_tag" =~ ^(yes|y|Y|YES|Yes)$ ]]; then
			_tagging_snapshots_retention_tag
		fi

	    # TODO: Copy an EBS snapshot to a different REGION

	done
}

function snapshot_volumes_onetime_mass() {
	_ec2_instances_list_WeeklyBackup
	snapshot_volumes_general

	_ec2_instances_list_DailyBackup
	snapshot_volumes_general
	_tagging_snapshots_mass_onetime_tag

	email_notification
}

function snapshot_volumes_daily_mass() {
	_ec2_instances_list_DailyBackup
	snapshot_volumes_general
	_tagging_snapshots_mass_daily_tag
	email_notification
}

function snapshot_volumes_weekly_mass() {
	_ec2_instances_list_WeeklyBackup
	snapshot_volumes_general

	# We would like to store weekly snapshots of instances with daily backups, as well
	_ec2_instances_list_DailyBackup
	snapshot_volumes_general
	_tagging_snapshots_mass_weekly_tag

	email_notification
}

function snapshot_volumes_monthly_mass() {
	# We would like to store monthly snapshots of instances with daily & weekly backups
	_ec2_instances_list_WeeklyBackup
	snapshot_volumes_general
	_ec2_instances_list_DailyBackup
	snapshot_volumes_general
	_tagging_snapshots_mass_monthly_tag

	email_notification
}

function snapshot_volumes_annually_mass() {
	# We would like to store annual snapshots of instances with daily & weekly backups
	_ec2_instances_list_WeeklyBackup
	snapshot_volumes_general
	_ec2_instances_list_DailyBackup
	snapshot_volumes_general
	_tagging_snapshots_mass_annually_tag

	email_notification
}

function snapshots_cleaner_daily() {
	log "FUNCTION snapshots_cleaner DAILY will be started"

	_snapshot_list_cleaning_daily
	for SNAPSHOT_ID in $SNAPSHOT_LIST_CLEANING; do
		log "Checking $SNAPSHOT_ID..."
		# Check age of snapshot
		_snapshot_age

		_date_comparing_condition_daily
	done

	email_notification
}

function snapshots_cleaner_weekly() {
	log "FUNCTION snapshots_cleaner WEEKLY will be started"

	_snapshot_list_cleaning_weekly
	for SNAPSHOT_ID in $SNAPSHOT_LIST_CLEANING; do
		log "Checking $SNAPSHOT_ID..."
		# Check age of snapshot
		_snapshot_age
		
		_date_comparing_condition_weekly
	done
	
	log "FUNCTION snapshots_cleaner One-Time with RetentionPolicy=Yes will be started"
	_snapshot_list_cleaning_onetime
	for SNAPSHOT_ID in $SNAPSHOT_LIST_CLEANING; do
		log "Checking $SNAPSHOT_ID..."
		# Check age of snapshot
		_snapshot_age
		
		_date_comparing_condition_weekly
	done

	email_notification
}

function snapshots_cleaner_monthly() {
	log "FUNCTION snapshots_cleaner MONTHLY will be started"

	_snapshot_list_cleaning_monthly
	for SNAPSHOT_ID in $SNAPSHOT_LIST_CLEANING; do
		log "Checking $SNAPSHOT_ID..."
		# Check age of snapshot
		_snapshot_age

		_date_comparing_condition_monthly
	done

	email_notification
}

function text_help() {
	echo "Possible options of the argument: "
	echo "	-	auto_ebs_snapshot_daily, auto_ebs_snapshot_weekly, auto_ebs_snapshot_monthly auto_ebs_snapshot_annually"
	echo "	-	auto_ebs_snapshot_cleaner_daily, auto_ebs_snapshot_cleaner_weekly, auto_ebs_snapshot_cleaner_monthly"
	echo
}

#######
log "==> EBS Script starts @ $DATE_LONG on $BACKUP_EC2_HOSTNAME ($BACKUP_EC2_INSTANCE_ID)"
log "Note: by design on all snapshots will be applied RetentionPolicy=Yes, except of EBS snapshots of the specific EC2 instance running manually"

cleaning_logs
upgrade_of_CLI_package >> $LOG_FILE_STDOUT 2>&1
_ec2_instance_verification_BackupInstance

# Following condition will allow to run this script only from Central Unit Maintenance Server - BackupInstance
if [[ $EC2_BackupInstance_VERIFICATION =~ .*i-.* ]]; then
	copy_cronjob
	# condition which will check if the argument was set
	if [ "$#" -eq 0 ]; then
	    clear
	    echo "No arguments supplied, the script will start with the Main Menu"

		selection_main_menu=
		until [ "$selection_main_menu" = "0" ]; do
		    echo $'\nEBS snapshot script'
		    echo $'\nMain Menu'
		    echo "1 - Make EBS snapshots of EBS volumes attached to ALL EC2 instances (with tag Values = Production, Backup=Daily & Weekly) in US-EAST-1"
		    echo "2 - Make EBS snapshots of EBS volumes attached to EC2 instances (with tag Values = Production, Backup=Daily) in US-EAST-1"
		    echo "3 - Make EBS snapshots of EBS volumes attached to EC2 instances (with tag Values = Production, Backup=Weekly) in US-EAST-1"
		    echo "4 - Make EBS snapshots of EBS volumes attached to a specific EC2 instances in US-EAST-1"
		    echo ""
		    echo "0 - exit program"
		    echo ""
		    echo -n "Please enter your choice: "
		    read -r selection_main_menu
		    echo ""
		    case $selection_main_menu in
		        1 ) 
		        echo "Your choice:"
		        echo "	- Make EBS snapshots of EBS volumes attached to ALL EC2 instances (with tag Values = Production, Backup=Daily & Weekly) in US-EAST-1:"
		        
				snapshot_volumes_onetime_mass
		        exit ;;

		        2 ) 
	   	        echo "Your choice:"
		        echo "	- Make EBS snapshots of EBS volumes attached to EC2 instances (with tag Values = Production, Backup=Daily) in US-EAST-1:"
		        
				snapshot_volumes_daily_mass
		        exit ;;

		        3 ) 
		        echo "Your choice:"
		        echo "	- Make EBS snapshots of EBS volumes attached to EC2 instances (with tag Values = Production, Backup=Weekly) in US-EAST-1:"
		        
				snapshot_volumes_weekly_mass
		        exit ;;

		        4 ) 
				clear
		        echo "Your choice:"
		        echo "	- Make EBS snapshots of EBS volumes attached to a specific EC2 instances in US-EAST-1:"
		        echo
		        menu_onetime_snapshot_specificEC2

				email_notification

		        exit ;;

		        0 ) 
				echo "Script was terminated"
				exit ;;
				
		        * ) echo "Please enter 1, 2, 3, 4, or 0"; press_enter
		    esac
		done

	    exit 1

	elif [ "$#" -gt 1 ]; then
	   log "More than 1 argument. Please, write only 1 argument." | tee -a $LOG_FILE_STDERR >> $LOG_FILE_STDOUT
	   log & text_help
	   email_notification
	   exit 1

	else
		log "Script will start with the argument - $ENVIRONMENT"	

		if [ "$ENVIRONMENT" == "auto_ebs_snapshot_daily" ]; then 
			snapshot_volumes_daily_mass
			exit 0

		elif [ "$ENVIRONMENT" == "auto_ebs_snapshot_weekly" ]; then
			snapshot_volumes_weekly_mass
			exit 0

		elif [ "$ENVIRONMENT" == "auto_ebs_snapshot_monthly" ]; then
			snapshot_volumes_monthly_mass
			exit 0

		elif [ "$ENVIRONMENT" == "auto_ebs_snapshot_annually" ]; then
			snapshot_volumes_annually_mass
			exit 0

		elif [ "$ENVIRONMENT" == "auto_ebs_snapshot_cleaner_daily" ]; then
			snapshots_cleaner_daily
			exit 0

		elif [ "$ENVIRONMENT" == "auto_ebs_snapshot_cleaner_weekly" ]; then
			snapshots_cleaner_weekly
			exit 0
		
		elif [ "$ENVIRONMENT" == "auto_ebs_snapshot_cleaner_monthly" ]; then
			snapshots_cleaner_monthly
			exit 0

	    else
			log "Wrong argument" | tee -a $LOG_FILE_STDERR >> $LOG_FILE_STDOUT
			log & text_help
			email_notification
		    exit 1
		fi
	fi
else
	log "instance - $BACKUP_EC2_INSTANCE_ID doesn't meet the conditions (appropriate AWS Tags) for running this script"
fi
