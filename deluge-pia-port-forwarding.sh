#!/usr/bin/env bash
# Source: http://www.htpcguides.com
# Adapted from https://github.com/blindpet/piavpn-portforward/
# Author: Mike

USERNAME=piauser
PASSWORD=piapass
VPNINTERFACE=tun0
VPNLOCALIP=$(ifconfig $VPNINTERFACE | awk '/inet / {print $2}' | awk 'BEGIN { FS = ":" } {print $(NF)}')
CURL_TIMEOUT=5
CLIENT_ID=$(uname -v | sha1sum | awk '{ print $1 }')

DELUGEUSER=delugeuser
DELUGEPASS=delugepass
DELUGEHOST=localhost

#get VPNIP
VPNIP=$(curl -m $CURL_TIMEOUT --interface $VPNINTERFACE "http://ipinfo.io/ip" --silent --stderr -)
echo $VPNIP

#request new port
PORTFORWARDJSON=$(curl -m $CURL_TIMEOUT --silent --interface $VPNINTERFACE  'https://www.privateinternetaccess.com/vpninfo/port_forward_assignment' -d "user=$USERNAME&pass=$PASSWORD&client_id=$CLIENT_ID&local_ip=$VPNLOCALIP" | head -1)
#trim VPN forwarded port from JSON
PORT=$(echo $PORTFORWARDJSON | awk 'BEGIN{r=1;FS="{|:|}"} /port/{r=0; print $3} END{exit r}')
echo $PORT  

#change firewall rules if necessary
IPTABLERULETWO=$(iptables -L INPUT -n --line-numbers | grep -E "2.*reject-with icmp-port-unreachable" | awk '{ print $8 }')
if [ -z $IPTABLERULETWO ]; then
    sudo iptables -D INPUT 2
    sudo iptables -I INPUT 2 -i $VPNINTERFACE -p tcp --dport $PORT -j ACCEPT
else
    sudo iptables -I INPUT 2 -i $VPNINTERFACE -p tcp --dport $PORT -j ACCEPT
fi

#change deluge port on the fly

deluge-console "connect $DELUGEHOST:58846 $DELUGEUSER $DELUGEPASS; config --set listen_ports ($PORT,$PORT)"
