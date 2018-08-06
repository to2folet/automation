#!/bin/bash

# Cleaning script for ADMIN UI

# location
## SCRIPT
## /scripts/lock_file_cleaner.sh

## CRONtab JOB
## /etc/cron.d/lock_file_cleaner-job

## LOG (only at the Scripting Servers)
## /var/log/lock_file_cleaner.log


ADMIN_UI_location="/var/www/html/admin"
LOCK_FILE_LOCATION="$ADMIN_UI_location/tmp/process_new_lock"

HOST=$(hostname)
DATE=$(date +%Y-%m-%d-%T)
LOGFILE=/var/log/lock_file_cleaner.log


copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/lock_file_cleaner-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/lock_file_cleaner-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

copy_cronjob

if [ -d "$ADMIN_UI_location" ] && [ -s "$LOCK_FILE_LOCATION" ]; then

    touch $LOGFILE
    find $LOCK_FILE_LOCATION -type f -mmin +60 -exec rm -f {} + && echo "The $LOCK_FILE_LOCATION file was removed on $HOST at $DATE" | 
      mail -s "$HOST - the *process_new_lock* file was removed" -a "From: $HOST@ec2-instance.com" email@address.com

fi
