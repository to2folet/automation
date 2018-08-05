#!/bin/bash

sudo apt-get update > /dev/null 2>&1

# list of Node & Ruby packages
dpkg --get-selections | grep node
dpkg --get-selections | grep ruby

whereis ruby


# Purge the old versions of Node6 package
sudo apt-get remove -y --purge node nodejs

# Uninstall of old versions of ruby
sudo apt-get remove -y libruby1.* ruby1.* ruby1.*-dev rubygems1.*
sudo apt-get remove -y libruby2.* ruby2.* ruby2.*-dev rubygems2.*

GEM_FILE="/usr/local/bin/gem"
if [ -f "$GEM_FILE" ]; then
	sudo rm -rf $GEM_FILE
fi

sudo apt-get autoremove -y
sudo apt-get autoclean -y


# install Node6.X
# https://nodejs.org/en/download/package-manager/



curl -sL https://deb.nodesource.com/setup_6.x | sudo -E bash -

sudo apt-get install -y nodejs
sudo apt-get install -y build-essential
node -v
nodejs -v

###############


# install Ruby2.3
# https://www.brightbox.com/blog/2016/01/06/ruby-2-3-ubuntu-packages/
# https://www.brightbox.com/docs/ruby/ubuntu/#installing-the-packages

sudo apt-get install -y software-properties-common
sudo apt-add-repository -y ppa:brightbox/ruby-ng

sudo apt-get update > /dev/null 2>&1

sudo apt-get install -y ruby2.3 ruby2.3-dev
ruby -v
ruby2.3 -v 
gem -v
bundle -v

sudo dpkg --configure -a
sudo apt-get install -f
sudo apt-get dist-upgrade -y

##############

# Install PASSENGER

# Install PGP key, etc
sudo apt-get install -y dirmngr gnupg
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
sudo apt-get install -y apt-transport-https ca-certificates

# Add our APT repository
sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main > /etc/apt/sources.list.d/passenger.list'
sudo apt-get update > /dev/null 2>&1

# Install Passenger + Nginx
sudo apt-get install -y nginx-extras passenger

