#!/bin/sh

apt-get -y install perl libnet-ssleay-perl libauthen-pam-perl libpam-runtime openssl libio-pty-perl apt-show-versions python

cat >> /etc/apt/sources.list <<-EOF
deb http://download.webmin.com/download/repository sarge contrib
deb http://webmin.mirror.somersettechsolutions.co.uk/repository sarge contrib
EOF

wget http://www.webmin.com/jcameron-key.asc -O /tmp/webmin-key.asc
apt-key add /tmp/webmin-key.asc

apt-get update 2> /tmp/apt-update.txt

KEYS=`egrep -o -e '([0-9a-fA-F]{2}){8}$' /tmp/apt-update.txt`

for k in $KEYS ; do 
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $k
done

apt-get install webmin

