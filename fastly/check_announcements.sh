#!/bin/bash
#
# Author Alejandro Revilla 02/03/2020

set -euo pipefail
IFS=$'\n\t'

URL="https://status.fastly.com/history.rss"
OKmsg="OK - There are not any new IP Announcements yet"


OUTPUT=`curl -s $URL | sed -e 's/</ /g' -e 's/>/ /g' | grep -E 'pubDate|title'`

MATCH=$(echo "$OUTPUT" | awk '{ if ($2$3$4 == "IPAddressAnnouncements") {print;getline;print} }')
if [[ -z $MATCH ]];then
    echo $OKmsg
    exit 0
else
    echo "CRITICAL - New data:"
    echo "$MATCH"
    exit 2
fi


