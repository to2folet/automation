#!/bin/bash


# AWS Security Best Practices Assessment, Auditing, Hardening and Forensics Readiness Tool
# https://github.com/toniblyx/prowler

sudo apt-get update && sudo apt-get dist-upgrade -y
sudo apt-get install -y awscli
sudo apt install -y python-pip
sudo apt-get install -y zip
sudo apt-get install -y jq

pip install -y awscli
pip install -y ansi2html

git clone https://github.com/Alfresco/prowler /etc/prowler

# Generate report
/etc/prowler/prowler | ansi2html -la > /etc/prowler/prowler-report.html &
/etc/prowler/prowler -M json > /etc/prowler/prowler-output.json &
/etc/prowler/prowler -M mono > /etc/prowler/prowler-report.txt &
