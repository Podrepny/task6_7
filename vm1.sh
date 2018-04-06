#!/bin/bash

source vm1.config

if [ "$EXT_IP" == "DHCP" ]; then
     dhclient $EXTERNAL_IF
else
     ifconfig $EXTERNAL_IF $EXT_IP
     route add default gw `echo $EXT_GW | sed 's/\/.*$//g'`
fi

# Setup VLAN on INTERNAL_IF
apt-get -y install vlan
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF 0/0 up 2>/dev/null
ifconfig $INTERNAL_IF.$VLAN $VLAN_IP up

# step 3 setup routing for VM2
sysctl net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s `echo $APACHE_VLAN_IP | sed 's/\/.*$//g'` -o $EXTERNAL_IF -j MASQUERADE
