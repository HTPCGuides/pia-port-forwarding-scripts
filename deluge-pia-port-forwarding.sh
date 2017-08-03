#!/usr/bin/env bash
# Source: http://www.htpcguides.com
# Adapted from https://github.com/blindpet/piavpn-portforward/
# Author: Mike and George
# Based on https://github.com/crapos/piavpn-portforward

# Set path for root Cron Job
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

VPNINTERFACE=tun0
CURL_TIMEOUT=5
CLIENT_ID=$(head -n 100 /dev/urandom | sha256sum | tr -d " -")

# set to 1 if using VPN Split Tunnel
SPLITVPN=""

DELUGEUSER=delugeuser
DELUGEPASS=delugepass
DELUGEHOST=localhost

#get VPNIP
VPNIP=$(curl -m $CURL_TIMEOUT --interface $VPNINTERFACE "http://ipinfo.io/ip" --silent --stderr -)
echo $VPNIP

#request new port
PORTFORWARDJSON=$(curl --interface $VPNINTERFACE "http://209.222.18.222:2000/?client_id=$CLIENT_ID" 2>/dev/null)
#trim VPN forwarded port from JSON
PORT=$(echo $PORTFORWARDJSON | awk 'BEGIN{r=1;FS="{|:|}"} /port/{r=0; print $3} END{exit r}')
echo $PORT  

#change firewall rules if SPLITVPN is set to 1
if [ "$SPLITVPN" -eq "1" ]; then
    #change firewall rules if necessary
    IPTABLERULETWO=$(iptables -L INPUT -n --line-numbers | grep -E "2.*reject-with icmp-port-unreachable" | awk '{ print $8 }')
    if [ -z $IPTABLERULETWO ]; then
        sudo iptables -D INPUT 2
        sudo iptables -I INPUT 2 -i $VPNINTERFACE -p tcp --dport $PORT -j ACCEPT
    else
        sudo iptables -I INPUT 2 -i $VPNINTERFACE -p tcp --dport $PORT -j ACCEPT
    fi
fi

#print VPNIP and PORT to text file for easy viewing
echo $VPNIP > /etc/openvpn/status.txt
echo $PORT >> /etc/openvpn/status.txt

#change deluge port on the fly
deluge-console "connect $DELUGEHOST:58846 $DELUGEUSER $DELUGEPASS; config --set listen_ports ($PORT,$PORT)"
