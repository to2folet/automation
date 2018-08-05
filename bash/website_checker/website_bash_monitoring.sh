#!/bin/bash

: <<'COMMENT'
Website Bash Monitoring Script - version 1.0

Description:
* Script loads the file "website_bash_monitoring-list.txt" and run CURL against the listed endpoints
* if the CURL gets code in hedear other than 200, script sends Email & Hipchat notification 
################
# one-liner test of website
# /usr/bin/elinks -dump "https://localhost" --timeout 30 -O - 2>/dev/null | grep "Normal operation string" || /usr/bin/elinks -dump "https://localhost" --timeout 30 -O - 2>/dev/null | echo "Site is down" | /usr/bin/mail -s "Site is down" -a "From: service@ec2-hostname.net" <email@domain.net>
################
COMMENT

HOST=$(hostname)

MAIL_PATH="/usr/bin/mail"
CURL_PATH="/usr/bin/curl"

HIPCHAT_DIR="/etc/hipchat-cli"
HIPCHAT_CLI_FILE="/etc/hipchat-cli/hipchat_room_message"

EMAIL_RECEPIENTS="<email@domain.net>, <email2@domain.net>"

INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep "availabilityZone" | awk -F\" '{print $4}')
DEPLOYMENT_LOG=$(tail -1 /var/log/deployments.txt)

function _hipchat_notification() {
    $HIPCHAT_CLI_FILE -v v2 -t "$HIPCHAT_TOKEN" -r "$HIPCHAT_ROOM_ID" -l critical -n -c red -i "$MESSAGE_hipchat"
}

function _email_notification() {
    SUBJECT="$FAMILY - check of $site FAILED"
    echo "$MESSAGE_email" | $MAIL_PATH -s "$SUBJECT" -a "From: $FAMILY@ec2-hostname.net" "$EMAIL"
}

function _website_check() {
    while read -r site; do
    
        WEBSITE=$(awk '{print $1}' <<< "$site")
        if [ ! -z "${site}" ]; then
            CURL=$($CURL_PATH -is -k --head "$WEBSITE")
            if echo "$CURL" | grep "200 OK" > /dev/null
            then
                echo "The Web server for $site is up!"
            else

                MESSAGE_email="This is an alert that the $FAMILY health check of $site has failed to respond OK. 

This was probably caused by an incorrect Git Commit which was merged into Master Branch OR a local issue during the auto deployment process.This conflict has to be fixed asap.

Details:
    Affected Host:
        $HOST

    Instance-ID:
        $INSTANCE_ID

    AWS AZ:    
        $AZ

    Deployment Log:
        $DEPLOYMENT_LOG
"

                MESSAGE_hipchat="This is an alert that the <b>$FAMILY</b> health check of $site has failed to respond OK. 

This was probably caused by an incorrect Git Commit which was merged into Master Branch OR a local issue during the auto deployment process.
This conflict has to be fixed asap.

<b>Details:</b>
    <b>Affected Host</b>: <i>$HOST</i>
    <b>Instance-ID</b>: <i>$INSTANCE_ID</i>
    <b>AWS AZ</b>: <i>$AZ</i>
    <b>Deployment Log</b>: <i>$DEPLOYMENT_LOG</i>
"
                for EMAIL in $(echo "$EMAIL_RECEPIENTS" | tr "," " "); do
                    _email_notification
                    echo "$SUBJECT"
                    echo "Alert sent to $EMAIL"
                done
                _hipchat_notification
            fi
        fi
    done < "$SITESFILE"
}

function general_website_monitoring() {
    # list the sites we want to monitor in this file
    SITESFILE="/scripts/website_checker/website_bash_monitoring-list.txt"

    # AWS tag of EC2 instance
    FAMILY=$(ec2-describe-tags --filter "resource-type=instance" --filter "resource-id=$(ec2metadata --instance-id)" | grep "Family" | awk '{print $5}')

    ## Token for Exceptions Room
    HIPCHAT_TOKEN="<HIPCHAT_ROOM_TOKEN>"
    HIPCHAT_ROOM_ID="<HIPCHAT_ROOM_ID>"

    _website_check
}

function hipchat_cli() {
    # install HipChat CLI 

    if [ ! -f "$HIPCHAT_CLI_FILE" ]; then
        git clone https://github.com/hipchat/hipchat-cli.git $HIPCHAT_DIR > /dev/null
    fi
}

# Install HipChat CLI
hipchat_cli

general_website_monitoring
