#!/bin/bash

source vm2.config

# Setup VLAN on INTERNAL_IF
apt-get -y install vlan
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF 0/0 up 2>/dev/null
ifconfig $INTERNAL_IF.$VLAN $APACHE_VLAN_IP up
route add default gw `grep ^VLAN_IP= vm1.config | sed 's/^VLAN_IP=\(.*\)\/.*$/\1/g'`

