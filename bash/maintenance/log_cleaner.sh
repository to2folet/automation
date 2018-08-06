#!/bin/bash

function auto_cleaning {
    # to clean /tmp directory - to clean files which are older than 1 day
    find /tmp -ctime +1 -exec rm -rf {} +
    echo "/tmp was cleaned from files which were older than 1 day"

    # to uninstall old kernels
    echo $'\n ** Curent version of KERNEL is'
    echo -e "$CURRENT_KERNEL_VERSION\\n"
    echo -e "\\n ** OLD versions of KERNEL, which will be deleted:\\n"
    echo "$OLD_KERNEL_VERSIONS"

    dpkg --list | grep linux-image | awk '{ print $2 }' | sort -V | sed -n '/'"$(uname -r)"'/q;p' |
     xargs apt-get -y purge

    update-grub2

    export DEBIAN_FRONTEND=noninteractive
    apt-get autoremove -y && apt-get autoclean

    # find System log files archives and delete them
    echo $'\n ** Removing of Systems Logs archives\n\n'
    echo $'These Systems logs will be deleted:\n'
    find /var/log/ -type f \( -iname \*.gz -o -iname \*.1 \)
    find /var/log/ -type f \( -iname \*.gz -o -iname \*.1 \) -exec rm -f {} +

    # Cleaning of System log files
    echo $'\n ** Cleaning of System Log Files in /var/log \n\n'

    # clear logs in /var/log
    for i in /var/log/*; do cat /dev/null > "$i"; done > /dev/null 2>&1

    # clear all logs in /var/log
    for i in /var/log/*.log; do cat /dev/null > "$i"; done
    find /var/log/ -type f \( -iname \*.gz -o -iname \*.1 \) -exec rm -f {} +

    # clear all logs in nested directories /var/log
    for i in /var/log/**/*.log; do cat /dev/null > "$i"; done
    find /var/log/**/ -type f \( -iname \*.gz -o -iname \*.1 \) -exec rm -f {} +

	# Clear .Bash_History
	shred -u /home/*/.bash_history && shred -u /root/.bash_history

}

auto_cleaning
