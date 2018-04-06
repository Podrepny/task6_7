#!/bin/bash

source vm2.config

# setup internet routing
ifconfig $INTERNAL_IF $INTERNAL_IP up
route add default gw `grep ^INT_IP= vm1.config | sed 's/^INT_IP=\(.*\)\/.*$/\1/g'`
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Setup VLAN on INTERNAL_IF
apt-get -y install vlan
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $APACHE_VLAN_IP up

