#!/bin/sh

# General HDD checker which notifys us when the /root partion
# has less than 5% of free disc space
# this is a backup script which can be ran above of the traditional monitoring system

# location of script 
## /scripts/hdd_checker/hdd-checker.sh

# location of cron
## /etc/cron.d/hdd-checker-job
## /scripts/hdd_checker/hdd-checker-job

copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/hdd_checker/hdd-checker-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/hdd-checker-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

hdd_check() {
  HOST=$(hostname)

  df -H | grep -vE '^Filesystem|tmpfs|cdrom' | awk '{ print $5 " " $1 }' | grep "/dev" | grep -v "/dev/xvdb" | while read -r output;
  do
    #echo $output
    usep=$(echo "$output" | awk '{ print $1}' | cut -d'%' -f1)
    partition=$(echo "$output" | awk '{ print $2 }' )
    if [ "$usep" -ge 95 ]; then
      echo "Running out of space \"$partition ($usep%)\" on $HOST as on $(date)" |
       mail -s "$HOST - Alert: Almost out of disk space $usep%" -a "From: $HOST@domain.net" "recepient@company.com"
    fi   
  done
}

copy_cronjob
hdd_check
