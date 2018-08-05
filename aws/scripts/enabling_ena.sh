#!/bin/bash

# Enabling ENA
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/enhanced-networking-ena.html

# Run commands below on the EC2 Instance which we need to enable for the ENA Support

# the ena module is not loaded if the listed driver is vif.
ethtool -i eth0


sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y build-essential dkms
git clone https://github.com/amzn/amzn-drivers
sudo mv amzn-drivers /usr/src/amzn-drivers-1.0.0
sudo touch /usr/src/amzn-drivers-1.0.0/dkms.conf

cat <<EOF > /usr/src/amzn-drivers-1.0.0/dkms.conf
PACKAGE_NAME="ena"
PACKAGE_VERSION="1.0.0"
CLEAN="make -C kernel/linux/ena clean"
MAKE="make -C kernel/linux/ena/ BUILD_KERNEL=${kernelver}"
BUILT_MODULE_NAME[0]="ena"
BUILT_MODULE_LOCATION="kernel/linux/ena"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ena"
AUTOINSTALL="yes"
EOF

sudo dkms add -m amzn-drivers -v 1.0.0
sudo dkms build -m amzn-drivers -v 1.0.0
sudo dkms install -m amzn-drivers -v 1.0.0
sudo update-initramfs -c -k all

update-initramfs -u -k all

modinfo ena





# From AWS CLI Instance:
# the EC2 Instance where we would like to enabled the ENS support on, has to be in the STOPPED state

INSTANCE_ID=<paste_an_EC2_InstanceID>
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep "region" | awk -F\" '{print $4}')

aws ec2 modify-instance-attribute --region $REGION --instance-id $INSTANCE_ID --ena-support

# Verify that ENA support is enabled
aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --query 'Reservations[].Instances[].EnaSupport'
