#!/bin/bash

# Auto maintenance script for staging ENV

# location
## SCRIPT
## /scripts/maintenance/auto_maintenance_staging.sh

## CRONtab JOB
## /etc/cron.d/auto_maintenance_staging-job

## LOG (only at the Staging Servers)
## /var/log/auto_maintenance_staging.log

HOST=$(hostname)
DATE=$(date +%Y-%m-%d-%T)

LOG_FILE="/var/log/auto_maintenance_staging.log"
LOG_FILE_SIZE=`stat -c %s ${LOG_FILE}`

CURRENT_KERNEL_VERSION=$(uname -a)

function auto_maintenance {
    sudo apt-get update &&
     sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade -y

}

function auto_cleaning {
    # to clean /tmp directory - to clean files which are older than 5days
    find /tmp -ctime +5 -exec rm -rf {} +
    echo "/tmp was cleaned from files which were older than 5 days"

    # to uninstall old kernels
    echo ""
    echo "Current version of KERNEL is"
    echo -e "$CURRENT_KERNEL_VERSION\n"
    echo -e "OLD versions of KERNEL, which will be deleted:\n"
    echo "$OLD_KERNEL_VERSIONS"

    dpkg --list | grep linux-image | awk '{ print $2 }' | sort -V | sed -n '/'`uname -r`'/q;p' |
     xargs sudo apt-get -y purge

    sudo update-grub2

    sudo apt-get autoremove -y &&
     sudo apt-get autoclean

}

function copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/maintenance/auto_maintenance_staging-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/auto_maintenance_staging-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

copy_cronjob

# to clean a log file (LOG_FILE stdout = /var/log/auto_maintenance_staging.log) if the size is more than 10MB
touch $LOG_FILE
if [ "$LOG_FILE_SIZE" -ge 10000 ]; then
    > $LOG_FILE
fi

echo "The script auto_maintenance on $HOST @ $DATE" &> $LOG_FILE
echo $'\n' &>> $LOG_FILE
if  grep -q "staging" "/etc/hostname"; then
    echo "Starting of the script" &>> $LOG_FILE
    # update & upgrade of instance
    echo $'\n\n ** Updating of packages\n\n' &>> $LOG_FILE
    auto_maintenance &>> $LOG_FILE

    # OS cleaning of the instance
    echo $'\n\n ** OS cleaning of the instance\n\n' &>> $LOG_FILE
    auto_cleaning &>> $LOG_FILE
    echo $'\n\n ************************************\n\n' &>> $LOG_FILE
    echo " Script was successfully finished on $HOST @ $DATE " &>> $LOG_FILE
    echo $'\n\n ************************************\n\n' &>> $LOG_FILE

else
    echo "Script was terminated - server is not from Staging STACK"

fi
