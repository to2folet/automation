#!/bin/bash

# script will automatically update a chrome-driver
# it is only necessary to edit row with *wget* command, and to put there the link on the current version

chromedriver --version

# to prepare an Environment
sudo apt-get update && sudo apt-get dist-upgrade -y
sudo apt-get install xvfb -y
sudo apt-get install unzip -y 
# sudo apt-get install python-pip -y 

# storage of versions
# https://sites.google.com/a/chromium.org/chromedriver/downloads
# also
# http://chromedriver.storage.googleapis.com/index.html

# Install ChromeDriver
wget -N http://chromedriver.storage.googleapis.com/2.22/chromedriver_linux64.zip
unzip chromedriver_linux64.zip

sudo mv -f chromedriver /usr/local/share/chromedriver

sudo rm -rf /usr/local/bin/chromedriver && sudo rm -rf /usr/bin/chromedriver 

sudo ln -s /usr/local/share/chromedriver /usr/local/bin/chromedriver
sudo ln -s /usr/local/share/chromedriver /usr/bin/chromedriver 

# To install dependencies for Selenium
# pip install pyvirtualdisplay selenium

chromedriver --version

