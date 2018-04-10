#!/bin/bash

source vm1.config
HOST_NAME="vm1"
HOSTS_STR="`echo "$VLAN_IP" | sed 's/\/.*$//g'`       $HOST_NAME"

if [ "$EXT_IP" == "DHCP" ]; then
     dhclient $EXTERNAL_IF
else
     ifconfig $EXTERNAL_IF $EXT_IP
     route add default gw `echo $EXT_GW | sed 's/\/.*$//g'`
     echo "nameserver 8.8.4.4" >> /etc/resolv.conf
     echo "nameserver 8.8.8.8" >> /etc/resolv.conf
fi

# setup internet for VM2
ifconfig $INTERNAL_IF $INT_IP up

# Setup VLAN on INTERNAL_IF
apt-get -y install vlan
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $VLAN_IP up

# step 3 setup routing for VM2
sysctl net.ipv4.ip_forward=1
#iptables -t nat -A POSTROUTING -s `echo $APACHE_VLAN_IP | sed 's/\/.*$//g'` -o $EXTERNAL_IF -j MASQUERADE
iptables -t nat -A POSTROUTING -s `grep ^INTERNAL_IP= vm2.config | sed 's/^INTERNAL_IP=\(.*\)\/.*$/\1/g'` -o $EXTERNAL_IF -j MASQUERADE

# Edit host name and nameservers
sudo sed -i -e "1 s/^/$HOSTS_STR\n/" /etc/hosts
echo "$HOST_NAME" > /etc/hostname
sudo hostname --file /etc/hostname


