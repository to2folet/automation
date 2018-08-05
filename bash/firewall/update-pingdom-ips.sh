#!/bin/bash

CHAIN_NAME="PINGDOM"

iptables -F $CHAIN_NAME

for IP in $(wget --quiet -O- https://my.pingdom.com/probes/feed | grep "pingdom:ip" | sed -e 's|</.*||' -e 's|.*>||')
do
    iptables -A $CHAIN_NAME -p tcp --dport 443 --src $IP -j ACCEPT
done
