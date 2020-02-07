#!/bin/bash
#
# Alejandro Revilla 07022020
#
# Script per activar la funcionalitat warning/critical del plugin de prometheus per memoria de contenidors k8s

usage () {

    echo -e "Usage: $0 <HOSTNAME> <URL PATH> <PROTOCOL> <PORT> <CONTAINER> <WARNING> <CRITICAL>"
    exit 1
}

getused () {

    VAR=$(echo $1 | cut -d '=' -f2 | cut -d 'B' -f1)
    echo $VAR 
}
export -f getused

getname() {

    VAR=$(echo $1 | cut -d " " -f3 | cut -d '=' -f1 | sed -e "s/cache_//g" )
    echo $VAR
}
export -f getname

getwarning() {

    VAR=$(echo $1 | cut -d ':' -f2 | cut -d ';' -f1)
    echo $VAR
}
export -f getwarning

getcritical() {

    VAR=$(echo $1 | cut -d ':' -f3 | cut -d ';' -f1)
    echo $VAR
}
export -f getcritical

treatdata () {

    NAME=$(getname "$1")
    USED=$(getused "$1")
    WARNING=$(getwarning "$1")
    CRITICAL=$(getcritical "$1")

    MESSAGE=""
    if [[ $USED -ge $CRITICAL ]];then
        MESSAGE="CRITICAL - Container $NAME is CRITICAL: 'used'= $USED , and critical threshold is $CRITICAL"
        GLOBALCODE=2
    elif [[ $USED -ge $WARNING ]]; then
        MESSAGE="WARNING - Container $NAME is WARNING: 'used'= $USED , and warning threshold is $WARNING"
        if [[ $GLOBALCODE -eq 0 ]];then
            GLOBALCODE=1
        fi
    else 
        MESSAGE="Container $NAME OK: 'used'= $USED , 'warning'= $WARNING , 'critical'= $CRITICAL"
    fi

    echo "$MESSAGE;"
}
export -f treatdata

if [[ $# -ne 7 ]];then
    usage
fi


HOSTNAME=$1
URLPATH=$2
PROTO=$3
PORT=$4
CONTAINER=$5
WARNING=$6
CRITICAL=$7

GLOBALCODE=0

TPLCOMMAND="/usr/lib/nagios/plugins/centreon-plugins/centreon_plugins.pl --plugin=cloud::prometheus::exporters::cadvisor::plugin --mode=memory --hostname=$HOSTNAME --url-path=$URLPATH --proto=$PROTO --port=$PORT --container=$CONTAINER --warning-usage=$WARNING --critical-usage=$CRITICAL"

OUTPUT=$($TPLCOMMAND 2>/dev/null)

GLOBALMESSAGE=$(echo $OUTPUT | sed "s/'used'/\n'used'/g" | awk '{if(NR>1)print}' | xargs -I {} bash -c 'treatdata "$@"' _ {})

ISCRIT=$(echo "$GLOBALMESSAGE" | grep -w "CRITICAL")
ISWARN=$(echo "$GLOBALMESSAGE" | grep -w "WARNING")

if [[ "$ISCRIT" != "" ]];then
    echo -e "CRITICAL - One or more containers are in critical state"
    GLOBALCODE=2
elif [[ "$ISWARN" != "" ]];then
    echo -e "WARNING - One or more containers are in warning state"
    GLOBALCODE=1
else
    echo -e "OK - All containers are ok"
fi

echo $GLOBALMESSAGE
exit $GLOBALCODE
