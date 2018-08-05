#!/bin/bash
#run-emerging-threats.sh
#start the script to update the emerging threats firewall rules if it isn't running

process="emerging-iptables-update.pl"
makerun="/usr/local/bin/"$process

if ps ax | grep -v grep | grep $process > /dev/null; then
  exit
else
  $makerun &
fi
exit
