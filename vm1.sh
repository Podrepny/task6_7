#!/bin/bash

SCRIPT_DIR=`dirname $0`
cd $SCRIPT_DIR

source vm1.config
HOST_NAME="vm1"
APACHE_VLAN_IP="${APACHE_VLAN_IP//\/*/}"
SSL_PATH="/etc/ssl/certs"
VM2_INT_IP="`grep ^INT_IP= vm2.config | sed 's/^INT_IP=\(.*\)\/.*$/\1/g'`"
route del default
if [ "$EXT_IP" == "DHCP" ]; then
     dhclient $EXTERNAL_IF
else
     ifconfig $EXTERNAL_IF `echo ${EXT_IP//\/*/}` up
     route add default gw `echo ${EXT_GW//\/*/}`
fi

sed -i 's/^[[:space:]]*nameserver.*$//g' /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

EXT_IP_ADDR=`ip address show $EXTERNAL_IF | grep "inet " | awk '{print $2}' | tr '\n' ' ' | sed 's/\/.*$//g'`

# setup internet for VM2 pc
ifconfig $INTERNAL_IF $INT_IP up

# Install packages
apt-get -y install vlan ssh openssh-server openssl

# Setup VLAN on INTERNAL_IF
modprobe 8021q
vconfig add $INTERNAL_IF $VLAN
ifconfig $INTERNAL_IF.$VLAN $VLAN_IP up

# step 3 setup routing for VM2
sysctl net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s $VM2_INT_IP -o $EXTERNAL_IF -j MASQUERADE

# Edit hosts
cat <<EOF > /etc/hosts
$EXT_IP_ADDR       $HOST_NAME
127.0.0.1       localhost
EOF

# Edit hostname, change current hostname. Because we can )
echo "$HOST_NAME" > /etc/hostname
hostname --file /etc/hostname

# Install "nginx" and "curl"
apt-get -y install nginx

# Hardcode. Edit nginx config for vm1
cat <<EOF > /etc/nginx/sites-available/$HOST_NAME
server {

    listen $EXT_IP_ADDR:$NGINX_PORT;
    server_name vm1;

    ssl_certificate           $SSL_PATH/web.pem;
    ssl_certificate_key       $SSL_PATH/web.key;

    ssl on;
    ssl_session_cache  builtin:1000  shared:SSL:10m;
    ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
    ssl_prefer_server_ciphers on;

    access_log            /var/log/nginx/vm1.access.log;

    location / {

      proxy_set_header        Host \$host;
      proxy_set_header        X-Real-IP \$remote_addr;
      proxy_set_header        X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto \$scheme;

      # Fix the "It appears that your reverse proxy set up is broken" error.
      proxy_pass          http://$APACHE_VLAN_IP:80;

    }
}
EOF
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/$HOST_NAME /etc/nginx/sites-enabled/$HOST_NAME

mkdir -p $SSL_PATH

# Gen root CA key
openssl genrsa -out $SSL_PATH/root-ca.key 4096
# Gen root CA certivicate
openssl req -x509 -new -nodes -key $SSL_PATH/root-ca.key -sha256 -days 365 -out $SSL_PATH/root-ca.crt -subj "/C=UA/ST=Kharkov/L=Kharkov/O=Podrepny/OU=web/CN=root_cert/"
# Gen nginx key
openssl genrsa -out $SSL_PATH/web.key 2048
# Gen nginx certificate signing request
openssl req -new -out $SSL_PATH/web.csr -key $SSL_PATH/web.key -subj "/C=UA/ST=Kharkov/L=Kharkov/O=Podrepny/OU=web/CN=$HOST_NAME/"
# Signing a nginx CSR with a root certificate
openssl x509 -req -in $SSL_PATH/web.csr -CA $SSL_PATH/root-ca.crt -CAkey $SSL_PATH/root-ca.key -CAcreateserial -out $SSL_PATH/web.crt -days 365 -sha256 -extfile <(echo -e "authorityKeyIdentifier=keyid,issuer\nbasicConstraints=CA:FALSE\nkeyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment\nsubjectAltName = @alt_names\n[ alt_names ]\nDNS.1 = $HOST_NAME\nDNS.2 = $EXT_IP_ADDR\nIP.1 = $EXT_IP_ADDR")
# Combining two certificates (nginx and root CA) to web.pem
cat $SSL_PATH/web.crt $SSL_PATH/root-ca.crt > $SSL_PATH/web.pem

service nginx restart

exit 0
