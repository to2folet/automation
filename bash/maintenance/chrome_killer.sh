#!/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

# /scripts/chrome_killer.sh
# /etc/cron.d/chrome_killer-job
# This script will kill CHROME processes which are running more than 10 minutes

EMAIL_RECIPIENT=email@address.com
HOST=$(hostname)
APP_REPO=/var/www/html
LOG_FILE="/var/log/chrome_killer.log"

PIDS="`ps axo etime,pid,comm | grep chrome | grep -v grep | grep -v "0[0-9]:" | awk '{print $2}'`"
LOG_COUNT="`ps axo etime,pid,comm | grep -c chrome | grep -v grep | grep -v "0[0-9]:" | awk '{print $2}'`"
LOG_LIST="`ps axo etime,pid,comm | grep -c chrome | grep -v grep | grep -v "0[0-9]:" | awk '{print $2}'`"


copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/chrome_killer-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/chrome_killer-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

copy_cronjob

if [ -d $APP_REPO ]; then
    # Kill the CHROME processes
    echo "$HOST" > $LOG_FILE
    echo "Number of processes which were automatically killed:" >> $LOG_FILE
    $LOG_COUNT >> $LOG_FILE
    echo "List of processes which were automatically killed:" >> $LOG_FILE
    $LOG_LIST >> $LOG_FILE
    echo "##############################################" >> $LOG_FILE
    echo "Killing chrome processes running more than 10min..."
    for i in ${PIDS}; do { echo "Killing $i"; kill -9 $i; }; done
fi

