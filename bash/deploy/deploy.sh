#!/bin/bash

: <<'COMMENT'
* Sample Deploy Script for a local Github Repo for a Ruby project

* Script will check if there are any scheduled, delayed, whenever, cron jobs active and if the instance
is in Master mode, it will activate / update them
(based on AWS tags which are assigned to every EC2 instance)

* Script allows you to deploy 
 - master branch or 
 - specific branch

* you can also use one argument, for example  deploy.sh <name_of_branch>
* if the argument is not used, we can choose the action from the simple menu

COMMENT

GIT_BRANCH=$1

DIR="/var/www/<SET_THE_FAMILY_NAME>"
LOG_DEPLOYMENT="$DIR/last-deployment.log"
WHENEVER_jobs="$DIR/config/schedule.rb"
DELAYED_jobs="$DIR/god/delayed_jobs.rb"

AWS_REGION=$(wget -q -O- http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\([1-9]\).$/\1/g')
AWS_EC2_INSTANCE_ID=$(wget -q -O- http://169.254.169.254/latest/meta-data/instance-id)
AWS_COMMAND="/usr/local/bin/aws"

EC2_TAG00_KEY=Family
EC2_TAG00_VALUE="<SET_THE_FAMILY_NAME>"
EC2_TAG02_KEY=Stack
EC2_TAG02_VALUE=Production
EC2_TAG04_KEY=Mode
EC2_TAG04_VALUE=Master

function _notification_header() {
    clear
    echo "-------------------------------------------------------"
    echo "The code of $GIT_BRANCH branch will be deployed to $EC2_TAG00_VALUE instance"
    printf '\n%.0s' {1..6}

    echo "Parameters:"
    echo "Service = $EC2_TAG00_VALUE"
    echo "GIT_BRANCH = $GIT_BRANCH"

    printf '\n%.0s' {1..5}
    sleep 2s
}

function _log_deployment() {
    # log the deployment
    LOG_OVERVIEW="$DIR/deployments.txt"
    DATE=$(date)
    USER=$(who am i | awk '{ print $1 }')
    BRANCH=$(git status -sb | head -n 1)
    LAST_COMMIT=$(git log --format="%H" -n 1)
    echo "$DATE | $USER | $BRANCH | $LAST_COMMIT | $EC2_TAG00_VALUE" >> $LOG_OVERVIEW
}

function _perform_deployment() {
    # Deploy branch
    cd "$DIR" || exit 1
    git pull
    git checkout "$input_Git_branch_name" -f
    git reset --hard origin/"$input_Git_branch_name"

    git fetch origin
    git pull
    bundle install --deployment
    _update_crontab_if_ec2_is_master
    _log_deployment

    touch tmp/restart.txt
}

function _website_monitoring() {
    # Run a one time check of the Local Website
    # if the check is not passed it will send email & hipchat notification
    sudo /scripts/website_checker/website_bash_monitoring.sh
}

function _update_crontab_if_ec2_is_master() {
    # This function check if the script has been starting at Master EC2 Instance by its AWS Tags
    EC2_AWSCLI_VERIFICATION=$($AWS_COMMAND ec2 describe-instances --region "$AWS_REGION" --output text \
        --instance-ids "$AWS_EC2_INSTANCE_ID" \
        --filters "Name=tag-key,Values=$EC2_TAG00_KEY" "Name=tag-value,Values=$EC2_TAG00_VALUE" \
        "Name=tag-key,Values=$EC2_TAG02_KEY" "Name=tag-value,Values=$EC2_TAG02_VALUE" \
        "Name=tag-key,Values=$EC2_TAG04_KEY" "Name=tag-value,Values=$EC2_TAG04_VALUE" \
        --query 'Reservations[*].Instances[*].[InstanceId]')
    
    # Following condition will allow to run WHENEVER and God only on Master Production EC2 Instance
    if [[ $EC2_AWSCLI_VERIFICATION =~ .*i-.* ]]; then
        echo " Scheduled Tasks (Cron, whenever, god, ...) will be started - Server is in MASTER Mode"

        if [ -f "$DELAYED_jobs" ]; then
            # start the delayed jobs daemon
            gem install god
            god -c "$DELAYED_jobs"
            RAILS_ENV=production ruby $DIR/script/delayed_job restart
        fi

        if [ -f $WHENEVER_jobs ]; then
            # update whenever jobs daemon
            bundle exec whenever --update-crontab
        fi

        service cron restart
    else
        echo " Scheduled Tasks (Cron, whenever, god, ...) will NOT be started - Server is in SLAVE Mode"
        sed -i '/.*/s/^/#/g' $DIR/cron/*

        if [ -f "$DELAYED_jobs" ]; then
            sed -i '/.*/s/^/#/g' "$DELAYED_jobs"
            RAILS_ENV=production ruby $DIR/script/delayed_job restart
        fi
        service cron restart
    fi
}


function check_root_permission() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root. Please retry using \`sudo\`." 2>&1
        echo "Exiting without performing deployment." 2>&1
        exit 1
    fi
}

function deploy_master() {

    input_Git_branch_name=master

    _perform_deployment 2>&1 | tee "$LOG_DEPLOYMENT"
    _website_monitoring
}

function deploy_specific_branch() {
    _perform_deployment 2>&1 | tee "$LOG_DEPLOYMENT"
    _website_monitoring
}

clear
check_root_permission

# condition which will check if the argument was set
if [ "$#" -eq 0 ]; then
    clear
    _notification_header

    selection_main_menu=
    until [ "$selection_main_menu" = "0" ]; do
        echo $'\nDeployment script'
        echo $'\nMain Menu'
        echo "1 - Deploy master branches"
        echo "2 - Deploy specific branches"
        echo ""
        echo "0 - exit program"
        echo ""
        echo -n "Please enter your choice: "
        read -r selection_main_menu
        echo ""
        case $selection_main_menu in
            1 ) 
                echo "Your choice:"
                echo $' - Deploy Master branch:\n'
                deploy_master
                exit ;;

            2 ) 
                echo "Your choice:"
                echo $' - Deploy Specific branch:\n'
                echo $'\nPlease type bellow a name of branch which you would like to deploy'
                echo $' the name of the branch has to be identical as it is at GitHub'
                echo ""
                echo -n "The name of Git branch: "
                read -r input_Git_branch_name

                deploy_specific_branch  
                exit ;;

            0 ) 
                echo "Script was terminated"
                exit ;;
            
            * ) echo "Please enter 1, 2, or 0";
        esac
    done
    exit 1

elif [ "$#" -gt 1 ]; then
   echo "More than 1 argument. Please, write only 1 argument."
   exit 1

else
    input_Git_branch_name=$GIT_BRANCH
    
    _notification_header

    if [ "$GIT_BRANCH" == "master" ]; then
        deploy_master
        exit 0

    else
        deploy_specific_branch
        exit 0
    fi
fi
