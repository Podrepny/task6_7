#!/bin/bash

source vm1.config
HOST_NAME="vm1"
HOSTS_STR="`echo "$VLAN_IP" | sed 's/\/.*$//g'`       $HOST_NAME"
APACHE_VLAN_IP="`echo "$APACHE_VLAN_IP" | sed 's/\/.*$//g'`"
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

# Install packages
apt-get -y install vlan ssh openssh-server openssl

# Setup VLAN on INTERNAL_IF
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $VLAN_IP up

# step 3 setup routing for VM2
sysctl net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s `grep ^INT_IP= vm2.config | sed 's/^INT_IP=\(.*\)\/.*$/\1/g'` -o $EXTERNAL_IF -j MASQUERADE

# Edit host name and nameservers
sudo sed -i -e "1 s/^/$HOSTS_STR\n/" /etc/hosts
echo "$HOST_NAME" > /etc/hostname
sudo hostname --file /etc/hostname

# Install "nginx" and "curl"
apt-get -y install nginx curl

cat <<EOF > /etc/nginx/sites-available/vm1
server {

    listen $NGINX_PORT;
    server_name vm1;

#    ssl_certificate           /etc/nginx/cert.crt;
#    ssl_certificate_key       /etc/nginx/cert.key;

#    ssl on;
#    ssl_session_cache  builtin:1000  shared:SSL:10m;
#    ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
#    ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
#    ssl_prefer_server_ciphers on;
#
    access_log            /var/log/nginx/vm1.access.log;

    location / {

      proxy_set_header        Host \$host;
      proxy_set_header        X-Real-IP \$remote_addr;
      proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto \$scheme;

      # Fix the "It appears that your reverse proxy set up is broken" error.
      proxy_pass          http://$APACHE_VLAN_IP:80;
#      proxy_read_timeout  90;

    }
}
EOF
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/vm1 /etc/nginx/sites-enabled/vm1
service nginx restart

