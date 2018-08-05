#!/bin/bash

#################################################
#
# location /scripts/install_aws-cli.sh
#
# Script will install AWS CLI
# It is necessary to set AWS user with correct AIM permissions
# OR
# to assign a AMI role during the launching process of EC2 instance
#
#################################################

# downloads and updates the package lists from the repositories and upgrades of packages 
sudo apt-get update && sudo apt-get dist-upgrade -y

# install package of AWS CLI and package for manipulating of archives
sudo apt-get install -y awscli unzip cloud-utils ec2-api-tools python-dev python2.7 nfs-common

# download the AWS CLI Bundled Installer using curl, unzip the package and we run the install executable
sudo mkdir -p /root/aws-cli
cd /root/aws-cli/
sudo curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
sudo unzip -o awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    
# To check python version    
# python --version

# Test the AWS CLI installation
# /usr/local/bin/aws --version

# upgrading of AWS Command Line Interface
# http://docs.aws.amazon.com/cli/latest/userguide/installing.html
# pip install awscli --upgrade --user > /dev/null
# echo -n "AWS CLI version: " 
# /usr/local/bin/aws --version
