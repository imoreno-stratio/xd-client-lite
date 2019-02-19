#!/bin/bash

# configurable
LOCAL="false"
TLS="false"
VERBOSE="true"

CERT="crossdata-1"
USER="crossdata-1"

CROSSDATA_SERVER_EOS="https://crossdata-1.marathon.mesos:$PORT0"
CROSSDATA_SERVER_LOCAL="http://localhost:13422"

if [ "true" = "$LOCAL" ]; then
  CROSSDATA_SERVER=$CROSSDATA_SERVER_LOCAL
else
  CROSSDATA_SERVER=$CROSSDATA_SERVER_EOS
fi

if [ "true" = "$VERBOSE" ]; then
  CURL_VERBOSE_OPTIONS=" -v "
else
  CURL_VERBOSE_OPTIONS=" -s "
fi

echo "LOCAL: $LOCAL"
echo "VERBOSE: $VERBOSE"
echo "CROSSDATA_SERVER: $CROSSDATA_SERVER"

# ---------------------
# global
#
# query uuid management
q_counter=0
q_prefix="aaaaaaaa-bbbb-cccc-dddd"
function inc_query_uuid()
{
  ((q_counter++))
  printf -v q_suffix_incremental "%012d" $q_counter
  QUERY_UUID="$q_prefix-$q_suffix_incremental"
}

# queries file vs interactive mode
queriesfile=$1
interactive=true
if [ -n "$queriesfile" ]; then
  if [ ! -f "$queriesfile" ]; then
    echo "Specified queries file does not exist: $queriesfile"
    exit -1
  fi
  interactive=false
fi

# ---------------------
# api functions
# get crossdata session
function getsession()
{
  inc_query_uuid
  if [ "$TLS" = "true" ]; then
    curl $CURL_VERBOSE_OPTIONS --cacert certs/ca-bundle.pem --cert certs/$CERT.pem --key certs/$CERT.key -H "Content-Type: application/json" -X POST -d '{"command":"OpenSessionCommand","details":{"user":"'$USER'"}}' $CROSSDATA_SERVER/query/$QUERY_UUID | jq -r -cMS ".session.id | .[\"\$uuid\"]"
  else
    curl $CURL_VERBOSE_OPTIONS -H "Content-Type: application/json" -X POST -d '{"command":"OpenSessionCommand","details":{"user":"'$USER'"}}' $CROSSDATA_SERVER/query/$QUERY_UUID | jq -r -cMS ".session.id | .[\"\$uuid\"]"
  fi
}
# execute crossdata query
function executequery()
{
  QUERY=$1
  # launch query via api
  echo "Executing query: $QUERY"
  # Execute Query
  inc_query_uuid
  if [ "$TLS" = "true" ]; then
    query_res=$(curl $CURL_VERBOSE_OPTIONS --cacert certs/ca-bundle.pem --cert certs/$CERT.pem --key certs/$CERT.key -H "Content-Type: application/json" -X POST -d '{"command":"SQLCommand","details":{"sql": "'"$QUERY"'","session":{"id":{"$uuid":"'$sess_id'"}},"queryId":{"$uuid":"'$QUERY_UUID'"},"flattenResults":false,"packageSize":1}}' $CROSSDATA_SERVER/query/$QUERY_UUID)
  else
    query_res=$(curl $CURL_VERBOSE_OPTIONS -H "Content-Type: application/json" -X POST -d '{"command":"SQLCommand","details":{"sql": "'"$QUERY"'","session":{"id":{"$uuid":"'$sess_id'"}},"queryId":{"$uuid":"'$QUERY_UUID'"},"flattenResults":false,"packageSize":1}}' $CROSSDATA_SERVER/query/$QUERY_UUID)
  fi

  if [ "true" = "$VERBOSE" ]; then
    echo $query_res
  fi

  # Parse result
  if [ "$query_res" != null ]; then
    # check error
    errormsg=$(echo "$query_res" | jq -cMSr ".errorMessage?")
    if [ "$errormsg" != null ]; then
      echo "ERROR: $errormsg"
    else
      # parse result
      echo "$query_res" | head -1 | jq -cMSr "[.streamedSchema.structType.fields[].name]"
      echo "$query_res" | tail -n+2 | jq -cMSr ".[].streamedRow .values"
    fi
  else
    echo "Empty result"
  fi
}


# ---------------------
# MAIN

# Open Session
sess_id=$(getsession)
echo "Session id: $sess_id"

# Launch heartbeats
./xd-clite-heartbeat.sh "$sess_id" "$CROSSDATA_SERVER" "$TLS" "$CERT" &

# Interactive mode
if $interactive ; then
  printf "xd-clite >> "
  while read QUERY; do
    # exit
    if [ "$QUERY" == "quit" ]; then
      echo "Bye bye!"
      exit 0
    fi
    executequery "$QUERY"
    printf "xd-clite >> "
  done

# From-file mode
else
  while IFS='' read -r QUERY || [[ -n "$line" ]]; do
    executequery "$QUERY"
  done < "$queriesfile"

fi
