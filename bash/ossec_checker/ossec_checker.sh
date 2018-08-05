#!/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

# location
# /scripts/ossec_checker/ossec_checker.sh
# /scripts/ossec_checker/ossec_checker-job
# /etc/cron.d/ossec_checker-job

# Script is running by cron every 5 min
# Script checks if OSSEC service is running
# if the OSSEC service is not running, the script will automatically start this service,
# send email notification, and write a record to the /var/log/syslog
# if there is any problem to start this service, script will send email notification
# and write record to the /var/log/syslog

LOCATION_SCRIPT="/scripts/ossec_checker.sh"
LOCATION_LOG="/var/log/syslog"
SERVICE_OSSEC_PATH="/var/ossec/bin/ossec-control"
EMAIL_RECIPIENT="<paste_email_address>"
HOST=$(hostname)

copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/ossec_checker/ossec_checker-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/ossec_checker-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

# to check running OSSEC service
check_ossec() {
    if "$SERVICE_OSSEC_PATH" status | grep "is running" > /dev/null; then
        echo "OSSEC service is running"
    else
        "$SERVICE_OSSEC_PATH" start
        sleep 15s
        if "$SERVICE_OSSEC_PATH" status | grep "is running" > /dev/null; then
            echo "On $HOST -> service $SERVICE_OSSEC_PATH WAS successfully started by the $LOCATION_SCRIPT . This action was also recorded into $LOCATION_LOG "| mail -s "$SERVICE_OSSEC_PATH on $HOST was started" -a "From: $HOST@domain.net" "$EMAIL_RECIPIENT"
            logger "OSSEC service WAS successfully started"
        else
            echo "On $HOST -> service $SERVICE_OSSEC_PATH WAS NOT successfully started by the $LOCATION_SCRIPT. It is neccessary to start it manually!! This action was also recorded into $LOCATION_LOG " | mail -s "$SERVICE_OSSEC_PATH on $HOST WAS NOT started" -a "From: $HOST@domain.net" "$EMAIL_RECIPIENT"
            logger "OSSEC service WAS NOT successfully started"
        fi
    fi
}

copy_cronjob
check_ossec
