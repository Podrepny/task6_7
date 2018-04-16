#!/bin/bash

source vm2.config
HOST_NAME="vm2"
HOST_IP=`echo "$APACHE_VLAN_IP" | sed 's/\/.*$//g'`
HOSTS_STR="$HOST_IP $HOST_NAME"

# setup internet routing
ifconfig $INTERNAL_IF $INT_IP up
route add default gw `grep ^INT_IP= vm1.config | sed 's/^INT_IP=\(.*\)\/.*$/\1/g'`
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Setup VLAN on INTERNAL_IF
apt-get -y install vlan
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $APACHE_VLAN_IP up

# Edit host name and nameservers
sed -i -e "1 s/^/$HOSTS_STR\n/" /etc/hosts
echo "$HOST_NAME" > /etc/hostname
hostname --file /etc/hostname

# Install Apache and Curl
apt-get -y install apache2 curl

# Set apache to listen only on APACHE_VLAN_IP
sed -i 's/Listen\ \(.*\)$/Listen\ '$HOST_IP':\1/g' /etc/apache2/ports.conf

# Generate apache conf
cat <<EOF > /etc/apache2/sites-available/$HOST_NAME.conf
<VirtualHost $HOST_IP:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html
#        ErrorLog ${APACHE_LOG_DIR}/error.log
#        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Disable apache default conf
a2dissite 000-default
# Enable new apache conf
a2ensite $HOST_NAME

service apache2 restart

exit 0
