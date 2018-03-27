#!/bin/bash

# configurable
CROSSDATA_SERVER="https://crossdata-1.marathon.mesos:10082"
#CURL_VERBOSE_OPTIONS=" -s "
CURL_VERBOSE_OPTIONS=" -v "

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
  curl $CURL_VERBOSE_OPTIONS --cacert certs/ca-bundle.pem --cert certs/crossdata-1.pem --key certs/crossdata-1.key -H "Content-Type: application/json" -X POST -d '{"command":"OpenSessionCommand","details":{"user":"crossdata-1"}}' $CROSSDATA_SERVER/query/$QUERY_UUID | jq -r -cMS ".session.id | .[\"\$uuid\"]"
}
# execute crossdata query
function executequery()
{
  QUERY=$1
  # launch query via api
  echo "Executing query: $QUERY"                                                                                                  
  # Execute Query
  inc_query_uuid                                                                                                                     
  query_res=$(curl $CURL_VERBOSE_OPTIONS --cacert certs/ca-bundle.pem --cert certs/crossdata-1.pem --key certs/crossdata-1.key -H "Content-Type: application/json" -X POST -d '{"command":"SQLCommand","details":{"sql": "'"$QUERY"'","session":{"id":{"$uuid":"'$sess_id'"}},"queryId":{"$uuid":"'$QUERY_UUID'"},"flattenResults":false,"packageSize":1}}' $CROSSDATA_SERVER/query/$QUERY_UUID)

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
