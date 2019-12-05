#!/bin/bash

export HOST=$( curl -s http://169.254.169.254/latest/meta-data/public-ipv4 )
export PORT=$( sudo minikube service list | grep voyager-edge | grep -oP ':\K(\d+)' )

echo https://$HOST:$PORT

# 1
export GREYMATTER_API_HOST="$HOST:$PORT"
# 2 
export GREYMATTER_API_PREFIX='/services/gm-control-api/latest'
# 3
export GREYMATTER_API_SSLCERT="/etc/ssl/quickstart/certs/quickstart.crt"
# 4
export GREYMATTER_API_SSLKEY="/etc/ssl/quickstart/certs/quickstart.key"
# 5
export GREYMATTER_CONSOLE_LEVEL='debug'
# 6
export GREYMATTER_API_SSL='true'
# 7
export GREYMATTER_API_INSECURE='true'