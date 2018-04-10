#!/bin/bash

source vm2.config
HOST_NAME="vm2"
HOSTS_STR="`echo "$APACHE_VLAN_IP" | sed 's/\/.*$//g'`       $HOST_NAME"

# setup internet routing
ifconfig $INTERNAL_IF $INTERNAL_IP up
route add default gw `grep ^INT_IP= vm1.config | sed 's/^INT_IP=\(.*\)\/.*$/\1/g'`
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Setup VLAN on INTERNAL_IF
apt-get -y install vlan
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $APACHE_VLAN_IP up

# Edit host name and nameservers
sudo sed -i -e "1 s/^/$HOSTS_STR\n/" /etc/hosts
echo "$HOST_NAME" > /etc/hostname
sudo hostname --file /etc/hostname


