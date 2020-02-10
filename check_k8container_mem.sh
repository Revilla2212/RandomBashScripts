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

gettotal() {

    VAR=$(echo $1 | cut -d ':' -f3 | cut -d ';' -f3 | cut -d ' ' -f1)
    echo $VAR
}
export -f gettotal

treatdata () {

    NAME=$(getname "$1")
    USED=$(getused "$1")
    WARNING=$(getwarning "$1")
    CRITICAL=$(getcritical "$1")
    TOTAL=$(gettotal "$1")

    VALUE=$(echo "scale=3; ($USED/$TOTAL)*100"|bc -l)

    if [[ $USED -ge $CRITICAL ]];then
        MESSAGE="CRITICAL - Container #$NAME is CRITICAL ($VALUE% used)#: #\'used_$NAME\'=$USED;$WARNING;$CRITICAL;$TOTAL"
    elif [[ $USED -ge $WARNING ]];then
        MESSAGE="WARNING - Container #$NAME is WARNING ($VALUE% used)#: #\'used_$NAME\'=$USED;$WARNING;$CRITICAL;$TOTAL"
    else 
        MESSAGE="Container $NAME OK: ###\'used_$NAME\'=$USED;$WARNING;$CRITICAL;$TOTAL"
    fi

    echo "$MESSAGE"
}
export -f treatdata

if [[ $# -ne 7 ]];then
    usage
fi


HOSTNAME=$1
URLPATH=$2
PROTO=$3
PORT=$4
POD=$5
WARNING=$6
CRITICAL=$7

GLOBALCODE=0

TPLCOMMAND="/usr/lib/nagios/plugins/centreon-plugins/centreon_plugins.pl --plugin=cloud::prometheus::exporters::cadvisor::plugin --mode=memory --hostname=$HOSTNAME --url-path=$URLPATH --proto=$PROTO --port=$PORT --pod=$POD --warning-usage=$WARNING --critical-usage=$CRITICAL"

OUTPUT=$($TPLCOMMAND 2>/dev/null)
GLOBALMESSAGE=$(echo $OUTPUT | sed "s/'used'/\n'used'/g" | awk '{if(NR>1)print}' | xargs -I {} bash -c 'treatdata "$@"' _ {})

ISCRIT=$(echo -e "$GLOBALMESSAGE" | grep -w "CRITICAL")
ISWARN=$(echo -e "$GLOBALMESSAGE" | grep -w "WARNING")

CRITNAMES="CRITICAL -"
WARNNAMES="WARNING -"

CRITNAMES="$CRITNAMES $(echo -e "$ISCRIT"|xargs -I {} echo "{}" | cut -d"#" -f2 | tr '\n' ' ' )"
WARNNAMES="$WARNNAMES $(echo -e "$ISWARN"|xargs -I {} echo "{}" | cut -d"#" -f2 | tr '\n' ' ' )"

if [[ "$ISCRIT" != "" ]];then
    echo -n "$CRITNAMES"
    GLOBALCODE=2
    if [[ "$ISWARN" != "" ]];then
        echo -n "$WARNNAMES"
    fi
    echo -n "| "
elif [[ "$ISWARN" != "" ]];then
    echo -n "$WARNNAMES | "
    GLOBALCODE=1
else
    echo -n "OK - All containers are ok | "
fi

echo "$GLOBALMESSAGE" | xargs -I {} echo "{}" | cut -d "#" -f4 | tr '\n' ' '
echo -e "\n"
exit $GLOBALCODE
