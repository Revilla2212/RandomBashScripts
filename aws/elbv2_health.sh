#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

[[ $# -ne 2 || "${1:-}" == "-h" || "${1:-}" == "--help" ]] && echo "Usage: ${0:-} <target-group-arn> <profile>" && exit 1

TGARN=${1:-}
PROFILE=${2:-}

set +e
QUERY=`aws elbv2 describe-target-health --target-group-arn $TGARN --profile $PROFILE`
retval=$?
set +e

if [[ $retval -ne 0 ]]; then
    echo $QUERY
    exit $retval
fi

STATUSINFO=`echo "$QUERY"| egrep "Id|State"`
STATUSINFO=`echo -e "$STATUSINFO"| sed 's/ //g'| sed 's/"//g'`

LINES=`printf "$STATUSINFO \n"|wc -l`
IT=2

while [ $IT -le $LINES ]
do
    IDIT=$(( $IT - 1 ))
    ID=`printf "$STATUSINFO \n"|awk "NR==$IDIT"`
    LINE=`printf "$STATUSINFO \n"|awk "NR==$IT"`
    ISHEALTHY=`echo $LINE|grep healthy`
    if [[ -z "$ISHEALTHY" ]];then
        FAILS="${FAILS:-} $ID"
    fi

    IT=$(( $IT + 2 ))
done 

if [[ -z "${FAILS:-}" ]];then
    FAILS="OK - All target groups are healthy"
    EXITSTATUS=0
else
    FAILS="CRITICAL - Errors in target groups: $FAILS"
    EXITSTATUS=2
fi

echo $FAILS
exit $EXITSTATUS

