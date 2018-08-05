#!/bin/bash

####
# OLD and non-recommended way
####

# ONLY FOR STAGING ENV
# Script checks if the Apache2 Access log file has been changed in last 10min
# and also if there is any active SSH session
# if NOT - script will shutdown the server
# if YES - script will try it again in 5min


# netstat -an | grep ESTABLISHED | grep ":[portname] " | wc -l


HOSTNAME=$(hostname)
ssh=$(netstat -an | grep ESTABLISHED | grep -c ':22')
ssh_startvalue="1"

file=/var/log/apache2/other_vhosts_access.log
current_time=`date +%s`
last_modified=`stat -c "%Y" $file`

if [[ $HOSTNAME = *-staging ]] || [ -f /scripts/staging ]; then
    while true; do
        if [ $(($current_time - $last_modified)) -gt 600 ]; then
            
            if [[ "$ssh" -lt "$ssh_startvalue" ]]; then
                echo "The apache2 log file other_vhosts_access.log has not been changed in last 10min AND there is no active SSH session"
                /sbin/shutdown -h now
            else
            echo "The apache2 log file other_vhosts_access.log has not been changed in last 10min BUT there is one or more SSH session"
            fi
            
            else
            echo "The apache2 log file other_vhosts_access.log has been recently changed"
        fi

        sleep 300

    done
fi