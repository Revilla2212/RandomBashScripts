#!/bin/bash

### Version 1.0 by Alejandro Revilla 20191209

if test "$#" -ne 2;then
    echo -e "Usage: sqs_ping.sh <sqs_url> <aws_profile>"
    exit 1
fi

URL=$1
PROFILE=$2

/usr/bin/aws sqs get-queue-attributes --queue-url $URL --profile $PROFILE --region eu-west-1 --attribute-names All 2>&1 | grep "An error occurred" 1>/dev/null && echo "1" || echo "0"
