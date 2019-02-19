#!/bin/bash

# configurable
SESSION_ID=$1
CROSSDATA_SERVER=$2
TLS=$3
CERT=$4

# ---------------------
# api functions
# heartbeat
function executeheartbeat()
{
  # launch query via api
  if [ "$TLS" = "true" ]; then
    query_res=$(curl -s --cacert certs/ca-bundle.pem --cert certs/$CERT.pem --key certs/$CERT.key -H "Content-Type: application/json" -X POST -d '{"sourceId":{"$uuid":"'$SESSION_ID'"}}' $CROSSDATA_SERVER/sessions)
  else
    query_res=$(curl -s -H "Content-Type: application/json" -X POST -d '{"sourceId":{"$uuid":"'$SESSION_ID'"}}' $CROSSDATA_SERVER/sessions)
  fi
}

# MAIN
while kill -0 $PPID >/dev/null 2>&1; do
    executeheartbeat;
    sleep 30;
done
