#!/bin/bash

# location
# /scripts/aws-scripts/awslogs-agent-install.sh
#
## sudo vi /scripts/aws-scripts/awslogs-agent-install.sh && sudo chmod 700 /scripts/aws-scripts/awslogs-agent-install.sh && sudo /scripts/aws-scripts/awslogs-agent-install.sh
#
## troubleshooting
# https://pypi.python.org/pypi/awscli-cwlogs
# echo "Hello World" | aws logs push --log-group-name MyLogGroup --log-stream-name MyLogStream --region us-east-1
# cat /var/log/auth.log | aws logs push --log-group-name system_logs-auth.log --log-stream-name ec2_instance --region us-east-1 --datetime-format '%Y-%m-%d %H:%M:%S,%f' --time-zone LOCAL --encoding ascii

AWSlog_LOCATION="/etc/CloudWatch/awslogs"

mkdir -p $AWSlog_LOCATION/
cd $AWSlog_LOCATION/

echo "Creating cloudwatch config file in $AWSlog_LOCATION/awslogs.conf"
cat <<EOF > $AWSlog_LOCATION/awslogs.conf

#
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ======================== >>>>>> NOTE <<<<<<========================
#
# If you change something in CONF file, it is necessary 
# to change it also in installation script, 
# just copy & paste the whole conf file
# 
# location of Installation Script at GitHub:
# deployment/scripts/AWS/scripts/awslogs-agent-install.sh
# 
# location of Conf File at GitHub:
# deployment/etc/awslogs-agent.conf
# 
# ======================== >>>>>> NOTE <<<<<<========================
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

#
# ------------------------------------------
# CLOUDWATCH LOGS AGENT CONFIGURATION FILE
# ------------------------------------------
#
# --- DESCRIPTION ---
# This file is used by the CloudWatch Logs Agent to specify what log data to send to the service and how.
# You can modify this file at any time to add, remove or change configuration.
#
# NOTE: A running agent must be stopped and restarted for configuration changes to take effect.
#
# --- CLOUDWATCH LOGS DOCUMENTATION ---
# https://aws.amazon.com/documentation/cloudwatch/
#
# --- CLOUDWATCH LOGS CONSOLE ---
# https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logs:
#
# --- AGENT COMMANDS ---
# To check or change the running status of the CloudWatch Logs Agent, use the following:
#
# To check running status: /etc/init.d/awslogs status
# To stop the agent: /etc/init.d/awslogs stop
# To start the agent: /etc/init.d/awslogs start
#
# --- AGENT LOG OUTPUT ---
# You can find logs for the agent in /var/log/awslogs.log
# You can find logs for the agent script in /var/log/awslogs-agent-setup.log
#

# ------------------------------------------
# CONFIGURATION DETAILS
# ------------------------------------------
# Refer to http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/AgentReference.html for details.

[general]
# Path to the CloudWatch Logs agent's state file. The agent uses this file to maintain
# client side state across its executions.
state_file = /var/awslogs/state/agent-state

## Each log file is defined in its own section. The section name doesn't
## matter as long as its unique within this file.
#[kern.log]
#
## Path of log file for the agent to monitor and upload.
#file = /var/log/kern.log
#
## Name of the destination log group.
#log_group_name = kern.log
#
## Name of the destination log stream. You may use {hostname} to use target machine's hostname.
#log_stream_name = {hostname} # Defaults to ec2 instance id
#
## Format specifier for timestamp parsing. Here are some sample formats:
## Use '%b %d %H:%M:%S' for syslog (Apr 24 08:38:42)
## Use '%d/%b/%Y:%H:%M:%S' for apache log (10/Oct/2000:13:55:36)
## Use '%Y-%m-%d %H:%M:%S,%f' for rails log (2008-09-08 11:52:54)
#datetime_format = %b %d %H:%M:%S # Specification details in the table below.
#
## A batch is buffered for buffer-duration amount of time or 32KB of log events.
## Defaults to 5000 ms and its minimum value is 5000 ms.
#buffer_duration =  5000
#
# Use 'end_of_file' to start reading from the end of the file.
# Use 'start_of_file' to start reading from the beginning of the file.
#initial_position = end_of_file
#
## Encoding of file
#encoding = utf-8 # Other supported encodings include: ascii, latin-1
#
#
#
# Following table documents the detailed datetime format specification:
# ----------------------------------------------------------------------------------------------------------------------
# Directive     Meaning                                                                                 Example
# ----------------------------------------------------------------------------------------------------------------------
# %a            Weekday as locale's abbreviated name.                                                   Sun, Mon, ..., Sat (en_US)
# ----------------------------------------------------------------------------------------------------------------------
#  %A           Weekday as locale's full name.                                                          Sunday, Monday, ..., Saturday (en_US)
# ----------------------------------------------------------------------------------------------------------------------
#  %w           Weekday as a decimal number, where 0 is Sunday and 6 is Saturday.                       0, 1, ..., 6
# ----------------------------------------------------------------------------------------------------------------------
#  %d           Day of the month as a zero-padded decimal numbers.                                      01, 02, ..., 31
# ----------------------------------------------------------------------------------------------------------------------
#  %b           Month as locale's abbreviated name.                                                     Jan, Feb, ..., Dec (en_US)
# ----------------------------------------------------------------------------------------------------------------------
#  %B           Month as locale's full name.                                                            January, February, ..., December (en_US)
# ----------------------------------------------------------------------------------------------------------------------
#  %m           Month as a zero-padded decimal number.                                                  01, 02, ..., 12
# ----------------------------------------------------------------------------------------------------------------------
#  %y           Year without century as a zero-padded decimal number.                                   00, 01, ..., 99
# ----------------------------------------------------------------------------------------------------------------------
#  %Y           Year with century as a decimal number.                                                  1970, 1988, 2001, 2013
# ----------------------------------------------------------------------------------------------------------------------
#  %H           Hour (24-hour clock) as a zero-padded decimal number.                                   00, 01, ..., 23
# ----------------------------------------------------------------------------------------------------------------------
#  %I           Hour (12-hour clock) as a zero-padded decimal numbers.                                  01, 02, ..., 12
# ----------------------------------------------------------------------------------------------------------------------
#  %p           Locale's equivalent of either AM or PM.                                                 AM, PM (en_US)
# ----------------------------------------------------------------------------------------------------------------------
#  %M           Minute as a zero-padded decimal number.                                                 00, 01, ..., 59
# ----------------------------------------------------------------------------------------------------------------------
#  %S           Second as a zero-padded decimal numbers.                                                00, 01, ..., 59
# ----------------------------------------------------------------------------------------------------------------------
#  %f           Microsecond as a decimal number, zero-padded on the left.                               000000, 000001, ..., 999999
# ----------------------------------------------------------------------------------------------------------------------
#  %z           UTC offset in the form +HHMM or -HHMM (empty string if the the object is naive).        (empty), +0000, -0400, +1030
# ----------------------------------------------------------------------------------------------------------------------
#  %j           Day of the year as a zero-padded decimal number.                                        001, 002, ..., 365
# ----------------------------------------------------------------------------------------------------------------------
#  %U           Week number of the year (Sunday as the first day of the week) as a zero padded          00, 01, ..., 53
#               decimal number. All days in a new year preceding the first Sunday are considered
#               to be in week 0.
# ----------------------------------------------------------------------------------------------------------------------
#  %W           Week number of the year (Monday as the first day of the week) as a decimal number.      00, 01, ..., 53
#               All days in a new year preceding the first Monday are considered to be in week 0.
# ----------------------------------------------------------------------------------------------------------------------
#  %c           Locale's appropriate date and time representation.                                      Tue Aug 16 21:30:00 1988 (en_US)
# ----------------------------------------------------------------------------------------------------------------------


# Path
# sudo vi /var/awslogs/etc/awslogs.conf

########### Identification of instance
[log/instance.info]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file = /var/log/instance.info
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = identification


###########################################################################
########### System Logs
[log/auth.log]
datetime_format = %b %d %H:%M:%S
file = /var/log/auth.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-auth.log

[log/cron.log]
datetime_format = %b %d %H:%M:%S
file = /var/log/cron.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-cron.log

[log/dmesg]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/dmesg
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-dmesg

[log/dpkg.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/dpkg.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-dpkg.log

[log/kern.log]
datetime_format = %b %d %H:%M:%S
file =/var/log/kern.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-kern.log

[log/syslog]
datetime_format = %b %d %H:%M:%S
file = /var/log/syslog
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-syslog

[log/mail.log]
datetime_format = %b %d %H:%M:%S
file =/var/log/mail.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-mail.log

[log/memcached.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/memcached.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-memcached.log

[log/boot.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/boot.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-boot.log

[log/cloud-init.log]
datetime_format = %b %d %H:%M:%S
file =/var/log/cloud-init.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-cloud-init.log

[log/cloud-init-output.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/cloud-init-output.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = cloud-init-output.log

[log/pigsty.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/pigsty.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-pigsty.log

[log/alternatives.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/alternatives.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-alternatives.log

[log/apt/history.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/apt/history.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-history.log

[log/apt/term.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/apt/term.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-term.log

[log/landscape/sysinfo.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/landscape/sysinfo.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = system_logs-sysinfo.log


###########################################################################
########### MySQL Logs
[log/mysql.err]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/mysql.err
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = mysql-mysql.err

[log/mysql.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/mysql.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = mysql-mysql.log

[log/mysql/error.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/mysql/error.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = mysql-error.log

[log/mysql/mysql-slow.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/log/mysql/mysql-slow.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = mysql-mysql-slow.log


###########################################################################
########### Webserver Logs - NGINX
[nginx/access.log]
datetime_format = %d/%b/%Y:%H:%M:%S
file =/var/log/nginx/access.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = nginx_access.log

[nginx/error.log]
datetime_format = %d/%b/%Y:%H:%M:%S
file =/var/log/nginx/error.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = nginx_error.log


###########################################################################
########### Webserver Logs - Apache2
[apache2/access.log]
datetime_format = %d/%b/%Y:%H:%M:%S %z
file =/var/log/apache2/access.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}.access.log
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = apache2-access.log

[apache2/other_vhosts_access.log]
datetime_format = %d/%b/%Y:%H:%M:%S %z
file =/var/log/apache2/other_vhosts_access.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}.other_vhosts_access.log
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = apache2-access.log

[apache2/error.log]
datetime_format = %d/%b/%Y:%H:%M:%S %z
file =/var/log/apache2/error.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = apache2-error.log


###########################################################################
########### Security Logs - OSSEC
[ossec/rules/log-entries/vpn.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/ossec/rules/log-entries/vpn.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}.vpn.log
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = ossec_logs

[ossec/logs/ossec.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/ossec/logs/ossec.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}.ossec.log
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = ossec_logs

[ossec/logs/active-responses.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/ossec/logs/active-responses.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}.active-responses.log
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = ossec_logs

[ossec/logs/alerts/alerts.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/ossec/logs/alerts/alerts.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}.alerts.log
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = ossec_logs

[ossec/logs/archives/archives.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/ossec/logs/archives/archives.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}.archives.log
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = ossec_logs

[ossec/logs/firewall/firewall.log]
datetime_format = %Y-%m-%d %H:%M:%S,%f
file =/var/ossec/logs/firewall/firewall.log
buffer_duration = 5000
batch_size = 1048576
batch_count = 10000
log_stream_name = {hostname}.firewall.log
multi_line_start_pattern = {datetime_format}
initial_position = end_of_file
log_group_name = ossec_logs

EOF

# following steps are important if we would like to use AWS IAM user
#echo Creating aws credentials in /root/.aws/credentials
#mkdir /root/.aws/
#cat <<EOF > /root/.aws/credentials
#[default]
#aws_access_key_id =
#aws_secret_access_key =
#EOF

# but is not a recommended procedure, we would like to use IAM ROLE (!)

echo "Downloading the newest version of cloudwatch logs setup agent"
wget -N https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py -O $AWSlog_LOCATION/awslogs-agent-setup.py

echo "running non-interactive cloudwatch-logs setup script"
python $AWSlog_LOCATION/awslogs-agent-setup.py --region us-east-1 --non-interactive --configfile=$AWSlog_LOCATION/awslogs.conf

sudo service awslogs restart
