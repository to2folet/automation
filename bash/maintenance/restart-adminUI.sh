#!/bin/bash

: <<'COMMENT'
Restarting Admin UI:
the script will be started every day at 8pm

COMMENT


copy_cronjob() {
  LOCATION_OF_CRONJOB_ORIGINAL="/scripts/restart-adminUI-job"
  LOCATION_OF_CRONJOB_DESTINATION="/etc/cron.d/restart-adminUI-job"

  # we would like to copy the cronjob file into
  # into /etc/cron.d/ directory if the file doesnt exist
  if [ ! -f "$LOCATION_OF_CRONJOB_DESTINATION" ]; then
      $(command -v cp) "$LOCATION_OF_CRONJOB_ORIGINAL" "$LOCATION_OF_CRONJOB_DESTINATION" > /dev/null 2>&1 &
      $(command -v service) cron restart > /dev/null 2>&1 &
  fi
}

copy_cronjob

# restarting ADMIN UI
cd /var/www/html/admin/
sudo touch tmp/restart.txt
sleep 10s
curl -k https://localhost >/dev/null 2>&1
echo
