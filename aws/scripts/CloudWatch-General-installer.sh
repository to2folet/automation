#!/bin/bash

# Installer for CloudWatch custom metrics which will send performance data to CloudWatch
# With its own check for proper sending data to AWS CloudWatch

# location
## SCRIPT
## /scripts/aws-scripts/CloudWatch-General-installer.sh

## CRONtab JOB
## /etc/cron.d/CloudWatch-General-job

sudo apt-get update && sudo apt-get dist-upgrade -y
sudo apt-get install unzip -y
sudo apt-get install libwww-perl libdatetime-perl -y

mkdir -p /etc/CloudWatch
cd /etc/CloudWatch

# http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/mon-scripts.html
curl https://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.1.zip -O
unzip -o CloudWatchMonitoringScripts-1.2.1.zip
rm -rf CloudWatchMonitoringScripts-1.2.1.zip

cd /etc/CloudWatch/aws-scripts-mon

# Creating of a cronjob

cat <<EOF >/etc/cron.d/CloudWatch-General-job 

# Installer for CloudWatch custom metrics which will send performance data to CloudWatch
# With its own check for proper sending data to AWS CloudWatch

# location
## SCRIPT Installer
## /scripts/aws-scripts/CloudWatch-ScriptingSRV-installer.sh
#
## CloudWatch custom SCRIPT 
## /etc/CloudWatch/aws-scripts-mon/mon-put-instance-data.pl

## CRONtab JOB
## /etc/cron.d/CloudWatch-General-job

# Cron schedule for metrics reported to CloudWatch
*/5 * * * * root /etc/CloudWatch/aws-scripts-mon/mon-put-instance-data.pl --memory-units=megabytes --disk-space-units=megabytes --mem-util --mem-used --mem-avail --disk-path=/ --disk-path=/vol --disk-space-util --disk-space-used --disk-space-avail --swap-util --swap-used --from-cron

# Collect aggregated metrics for an Auto Scaling group and send them to Amazon CloudWatch without reporting individual instance metrics
*/5 * * * * root /etc/CloudWatch/aws-scripts-mon/mon-put-instance-data.pl --memory-units=megabytes --disk-space-units=megabytes --mem-util --mem-used --mem-avail --auto-scaling=only --from-cron

# CloudWatch checker job - if there is an issue with a sending data to AWS CloudWatch, the email will be sent to notice us 
*/20 * * * * root /etc/CloudWatch/aws-scripts-mon/mon-put-instance-data.pl --disk-space-units=megabytes --disk-path=/ --disk-space-util 2>&1 > /dev/null | mail --exec 'set nonullbody' -s "$(hostname) - Alert: CloudWatch error" -a "From: $(hostname)@ec2-instance.net" email@domain.net


EOF
