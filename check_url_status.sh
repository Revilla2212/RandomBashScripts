#!/bin/bash

### Version 1.0 by Alejandro Revilla 20191218

if test "$#" -ne 1;then 
    echo -e "Usage: check_url_status.sh <url>"
    exit 1
fi

STATUS=$(/usr/bin/curl -I "$1" 2>/dev/null | head -n 1 | grep "200 OK" 1>/dev/null && echo "OK - Status 200 OK" || echo "CRITICAL - Status is not OK")
echo $STATUS
