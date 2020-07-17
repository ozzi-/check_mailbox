#!/bin/bash
# Author: ozzi-
# Description: Icinga 2 check imap & pop3 mailboxes

# startup checks
if [ -z "$BASH" ]; then
  echo "Please use BASH."
  exit 3
fi
if [ ! -e "/usr/bin/which" ]; then
  echo "/usr/bin/which is missing."
  exit 3
fi
if [ ! -e "/usr/bin/bc" ]; then
  echo "/usr/bin/bc is missing."
  exit 3
fi
curl=$(which curl)
if [ $? -ne 0 ]; then
  echo "Please install curl"
  exit 3
fi

# Default Values
warning=2000
critical=3500
fqhost=""
mailbox="INBOX"
credential=""
imap=1
insecure=0
ssl=0
verbose=0
min_messages=0
max_messages=100000000

# Usage Info
usage() {
  echo '''Usage: check_imap [OPTIONS]
  [OPTIONS]:
  -H HOST           Full host string, i.E. "imaps://mail.local.ch:993" OR "pop3://mail.local.ch:143"
  -C CREDENTIAL     Username:Password, i.E. "user2:horsestaplebattery" (default: no auth)
  -M MAILBOX        Mailbox Name, needed for IMAP(s) only (default: INBOX)
  -I INSECURE       Allow insecure connections using IMAPs and POP3s (default: OFF)
  -S SSL            Try to use SSL/TLS for the connection (default: OFF)
  -V VERBOSE        Use verbose mode of CURL for debugging (default: OFF)
  -c CRITICAL       Critical threshold for execution in milliseconds (default: 3500)
  -w WARNING        Warning threshold for execution in milliseconds (default: 2000)
  -n MIN_MESSAGES   Minimum expected number of messages in inbox (default: 0)
  -N MAX_MESSAGES   Maximum expected number of messages in inbox (default: 100000000)
  '''
}

#main
#get options
while getopts "H:C:M:ISVc:w:n:N:" opt; do
  case $opt in
    H)
      fqhost=$OPTARG
      ;;
    C)
      credential=$OPTARG
      ;;
    M)
      mailbox=$OPTARG
      ;;
    I)
      insecure=1
      ;;
    S)
      ssl=1
      ;;
    V)
      verbose=1
      ;;
    c)
      critical=$OPTARG
      ;;
    w)
      warning=$OPTARG
      ;;
    n)
      min_messages=$OPTARG
      ;;
    N)
      max_messages=$OPTARG
      ;;
    *)
      usage
      exit 3
      ;;
  esac
done

#Required params
if [ -z "$fqhost" ]; then
  echo "Error: HOST is required"
  echo ""
  usage
  exit 3
fi
if [ ! -z "$credential" ] && [[ $credential != *":"* ]]; then
  echo "Error: CREDENTIAL needs to contain colon (:) between username and password"
  echo ""
  usage
  exit 3
fi

fqhostl=$(echo "$fqhost" | tr '[:upper:]' '[:lower:]')
if [[ $fqhostl == "imap"* ]]; then
  imap=1
elif [[ $fqhostl == "pop3"* ]]; then
  imap=0
else
  echo "Error: HOST needs to use one of the following protocols imap:// imaps:// pop3:// pop3s://"
  usage
  exit 3
fi


maxwait=$(bc <<< "scale = 10; ($critical+1500) / 1000")

# Build the arg parameters
insecurearg=""
if [ $insecure -eq 1 ]; then
 insecurearg=" --insecure "
fi
sslarg=""
if [ $ssl -eq 1 ]; then
 sslarg=" --ssl "
fi
verbosearg=""
if [ $verbose -eq 1 ]; then
 verbosearg=" --verbose "
fi
credentialarg=""
if [ ! -z "$credential" ] ; then
  credentialarg=' --user "'$credential'"'
fi
commandarg='"LIST"'
if [ $imap -eq 1 ] ; then
  commandarg='"EXAMINE '$mailbox'"'
fi

#The actual curl
start=$(echo $(($(date +%s%N)/1000000)))

if [ $imap -eq 0 ]; then
  body=$(eval curl --url "$fqhost" -X $commandarg $credentialarg -s --max-time $maxwait $sslarg $insecurearg $verbosearg)
  status=$?
  body=$(echo "$body" | tail -1 | cut -d " " -f1)
else
  body=$(eval curl --url "$fqhost" -X $commandarg $credentialarg -s --max-time $maxwait $sslarg $insecurearg $verbosearg)
  status=$?
  body=$(echo "$body" | grep "EXISTS" | head -1 | cut -d " " -f2)
fi

end=$(echo $(($(date +%s%N)/1000000)))
runtime=$(($end-$start))

messagecount=$body
if [ -z "$messagecount" ]; then
  messagecount=0
fi

getCode () {
  case $1 in
    1)
      echo "UNSUPPORTED PROTOCOL"
      ;;
    2)
      echo "FAILED INIT"
      ;;
    3)
      echo "URL MALFORMAT"
      ;;
    6)
      echo "COULDN'T RESOLVE HOST"
      ;;
    7)
      echo "COULDN'T CONNECT"
      ;;
    21)
      echo "QUOTE ERROR - Unsuccessful completion of command (maybe send credentials?)"
      ;;
    23)
      echo "WRITE ERROR"
      ;;
    26)
      echo "READ ERROR"
      ;;
    28)
      echo "OPERATION TIMED OUT"
      ;;
    35)
      echo "SSL CONNECT ERROR"
      ;;
    55)
      echo "SEND ERROR"
      ;;
    56)
      echo "RECEIVE ERROR - (maybe send credentials?)"
      ;;
    67)
      echo "LOGIN DENIED"
      ;;
    *)
      echo "Check https://curl.haxx.se/libcurl/c/libcurl-errors.html"
      exit 3
      ;;
  esac
}


#decide output by return code
if [ $status -eq 0 ] ; then
  if (( $messagecount < $min_messages || $max_messages < $messagecount )) ; then
    echo "CRITICAL: $messagecount messages are in inbox, expected between $min_messages and $max_messages | runtime="$runtime"ms;$warning;$critical;0;$critical messagecount=$messagecount;$max_messages;$max_messages;$min_messages;$max_messages"
    exit 2;
  fi;
  if [ $runtime -gt $critical ] ; then
    echo "CRITICAL: runtime "$runtime" bigger than critical runtime '"$critical"' | runtime="$runtime"ms;$warning;$critical;0;$critical messagecount=$messagecount;$max_messages;$max_messages;$min_messages;$max_messages"
    exit 2;
  fi;
  if [ $runtime -gt $warning ] ; then
    echo "WARNING: runtime "$runtime" bigger than warning runtime '"$warning"' | runtime="$runtime"ms;$warning;$critical;0;$critical messagecount=$messagecount;$max_messages;$max_messages;$min_messages;$max_messages"
    exit 1;
  fi;
  echo "OK: MAILBOX LIST in "$runtime" ms | runtime="$runtime"ms;$warning;$critical;0;$critical messagecount=$messagecount;$max_messages;$max_messages;$min_messages;$max_messages"
  exit 0;
else
  message=$(getCode $status)
  echo "CRITICAL: MAILBOX LIST failed with return code '"$status"' = '"$message"' in "$runtime" ms | runtime="$runtime"ms;$warning;$critical;0;$critical messagecount=$messagecount;$max_messages;$max_messages;$min_messages;$max_messages"
  exit 2;
fi;
