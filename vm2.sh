#!/bin/bash

SCRIPT_DIR=`dirname $0`
cd $SCRIPT_DIR
source vm2.config
HOST_NAME="vm2"
HOST_IP=`echo "$APACHE_VLAN_IP" | sed 's/\/.*$//g'`
HOSTS_STR="$HOST_IP $HOST_NAME"

# setup internet routing
route del default
ifconfig $INTERNAL_IF $INT_IP up
route add default gw `echo $GW_IP | sed 's/\/.*$//g'`
sed -i 's/^[[:space:]]*nameserver.*$//g' /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Setup VLAN on INTERNAL_IF
modprobe 8021q
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $APACHE_VLAN_IP up

# Edit hosts
sed -i -e "1 s/^/$HOSTS_STR\n/" /etc/hosts

# Edit hostname, change current hostname. Because we can )
echo "$HOST_NAME" > /etc/hostname
hostname --file /etc/hostname

# Install Apache and Curl
apt-get -y install apache2

# Set apache to listen only on APACHE_VLAN_IP
cp -p /etc/apache2/ports.conf /etc/apache2/ports.conf.bak
cat <<EOF > /etc/apache2/ports.conf
Listen $HOST_IP:80
EOF

# Hardcode. Generate apache conf for vm2
cat <<EOF > /etc/apache2/sites-available/$HOST_NAME.conf
<VirtualHost $HOST_IP:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
#        ErrorLog \${APACHE_LOG_DIR}/error.log
#        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Disable apache default conf
a2dissite 000-default
# Enable new apache conf
a2ensite $HOST_NAME

service apache2 restart

exit 0
