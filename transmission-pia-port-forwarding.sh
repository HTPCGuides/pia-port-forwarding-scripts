#!/usr/bin/env bash
# Source: http://www.htpcguides.com
# Adapted from https://github.com/blindpet/piavpn-portforward/
# Author: Mike and Drake
# Based on https://github.com/crapos/piavpn-portforward
# Updated by inspector71

# Set path for root Cron Job
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

SPLITVPN="" # set to 1 if using VPN Split Tunnel

VPNINTERFACE=tun0

CURL_TIMEOUT=5


###########################
### Local machine       ###
###########################

if [ -c /dev/urandom ]; then

  if [ "$(uname)" == "Linux" ]; then
    LM_ID=`head -n 100 /dev/urandom | sha256sum | tr -d " -"`
  elif [ "$(uname)" == "Darwin" ]; then
    LM_ID=`head -n 100 /dev/urandom | shasum -a 256 | tr -d " -"`
  else
    echo "ERR: 'Linux' or 'Darwin' required (incompatable with Windows)."
    exit 1
  fi

  echo ${LM_ID}

else
  echo "ERR: Creating a client_id (LM_ID) requires /dev/urandom which is unavailable."
  exit 1
fi


###########################
### PIA PF API          ###
###########################

PIA_PF_API_URL=http://209.222.18.222:2000/?client_id

echo 'Requesting open port assignment from PIA ...'

PIA_API_JSON_RESPONSE=`curl "${PIA_PF_API_URL}=${LM_ID}" -m ${CURL_TIMEOUT} 2> /dev/null`

if [ "${PIA_API_JSON_RESPONSE}" == "" ]; then
  echo "Hmmm: did not get a port from PIA. Maybe ..."
  echo "- This script was run after the 2 minute post-connection PIA timeout"
  echo "- The PIA server location you are connected to does not support port forwarding"
  exit 1
fi

# Trim PIA PF API JSON response
OPEN_PORT=$(echo $PIA_API_JSON_RESPONSE | awk 'BEGIN{r=1;FS="{|:|}"} /port/{r=0; print $3} END{exit r}')

echo ${OPEN_PORT}


###########################
### Firewall            ###
###########################


if [ "$SPLITVPN" -eq "1" ]; then

    IPTABLERULETWO=$(iptables -L INPUT -n --line-numbers | grep -E "2.*reject-with icmp-port-unreachable" | awk '{ print $8 }')
    
    if [ -z $IPTABLERULETWO ]; then
        sudo iptables -D INPUT 2
        sudo iptables -I INPUT 2 -i $VPNINTERFACE -p tcp --dport $OPEN_PORT -j ACCEPT
    else
        sudo iptables -I INPUT 2 -i $VPNINTERFACE -p tcp --dport $OPEN_PORT -j ACCEPT
    fi
    
fi


###########################
### Transmission        ###
###########################

#change transmission port on the fly

TRANSUSER=user
TRANSPASS=pass
TRANSHOST=localhost

CURLOUT=$(curl -u $TRANSUSER:$TRANSPASS ${TRANSHOST}:9091/transmission/rpc 2>/dev/null)
REGEX='X-Transmission-Session-Id\: (\w*)'
 
if [[ $CURLOUT =~ $REGEX ]]; then
    SESSIONID=${BASH_REMATCH[1]}
else
    exit 1
fi

DATA='{ "method": "session-set", "arguments": { "peer-port" :'"$OPEN_PORT"' } }' 
 
curl --user $TRANSUSER:$TRANSPASS 'http://${TRANSHOST}:9091/transmission/rpc' --data "$DATA" --header "X-Transmission-Session-Id: $SESSIONID"
