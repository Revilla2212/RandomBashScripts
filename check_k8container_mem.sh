#!/bin/bash
#
# Alejandro Revilla 07022020
#
# Script per activar la funcionalitat warning/critical del plugin de prometheus per memoria de contenidors k8s

set -euo pipefail
IFS=$'\n\t'

usage () {

    echo -e "Usage: $(basename "$0") [-h] [-H] [-u] [-P] [-p] [-f] [-w] [-c] [-t] -- Script per activar la funcionalitat warning/critical del plugin de prometheus per memoria de contenidors k8s
    on:
    -h  mostra aquest missatge
    -H  indica Hostname
    -u  indica urlpath
    -P  indica Protocol (ex: http,https)
    -p  indica port
    -f  indica filtre de pod
    -e  extra filtre de pod
    -w  indica valor de warning (%)
    -c  indica valor de critical (%)
    -t  fixa la memoria total al valor donat
"
    exit 1
}

if [[ $# -lt 14 ]];then
    usage
fi

while getopts "h:t:H:u:P:p:f:e:w:c:" OPTION; do
  case "$OPTION" in
    h) usage
       ;;
    t) _TOTAL="$OPTARG"
       ;;
    H) _HOSTNAME="$OPTARG"
       ;;
    u) _URLPATH="$OPTARG"
       ;;
    P) _PROTO="$OPTARG"
       ;;
    p) _PORT="$OPTARG"
       ;;
    f) _POD="$OPTARG"
       ;;
    e) _EXTRAPOD="$OPTARG"
       ;;
    w) _WARNING="$OPTARG"
       ;;
    c) _CRITICAL="$OPTARG"
       ;;
    ?) usage
       ;;
  esac
done
shift "$(($OPTIND -1))"

getused () {

    VAR=$(echo $1 | cut -d '=' -f2 | cut -d 'B' -f1)
    echo $VAR 
}
export -f getused

getname() {
    if [[ "false" != "$2" ]];then
        VAR=$3
    else
        VAR=$(echo $1 | cut -d " " -f3 | cut -d '=' -f1 | sed -e "s/rss_//g" )
    fi
    echo $VAR
}
export -f getname

getwarning() {

    _TOTAL=${2:-}
    VAR=$(echo $1 | cut -d ':' -f2 | cut -d ';' -f1)

    if [[ "-1" -ne "$_TOTAL" ]];then
        echo "($3/100)*$_TOTAL"|bc -l|cut -d '.' -f1
    else
        echo $VAR
    fi
}
export -f getwarning

getcritical() {

    _TOTAL=${2:-}
    VAR=$(echo $1 | cut -d ':' -f3 | cut -d ';' -f1)

    if [[ "-1" -ne "$_TOTAL" ]];then
        echo "($3/100)*$_TOTAL"|bc -l|cut -d '.' -f1
    else
        echo $VAR
    fi
}
export -f getcritical

gettotal() {
    _TOTAL=${2:-}
    VAR=$(echo $1 | cut -d ':' -f3 | cut -d ';' -f3 | cut -d ' ' -f1)
    test  "-1" -ne "$_TOTAL" && echo $_TOTAL || echo $VAR
}
export -f gettotal

treatdata () {

    NAME=$(getname "$1" "$5" "$6")
    USED=$(getused "$1")
    WARNING=$(getwarning "$1" "$2" "$3")
    CRITICAL=$(getcritical "$1" "$2" "$4")
    TOTAL=$(gettotal "$1" "$2")
    
    VALUE=$(echo "scale=3; ($USED/$TOTAL)*100"|bc -l)

    if [[ $USED -ge $CRITICAL ]];then
        MESSAGE="CRITICAL - Container #$NAME is CRITICAL ($VALUE% working)#: #\'working_$NAME\'=$USED;$WARNING;$CRITICAL;$TOTAL"
    elif [[ $USED -ge $WARNING ]];then
        MESSAGE="WARNING - Container #$NAME is WARNING ($VALUE% working)#: #\'working_$NAME\'=$USED;$WARNING;$CRITICAL;$TOTAL"
    else 
        MESSAGE="Container $NAME OK: ###\'working_$NAME\'=$USED;$WARNING;$CRITICAL;$TOTAL"
    fi

    echo "$MESSAGE"
}
export -f treatdata

#Inici de funcio principal
if [[ -z ${_EXTRAPOD:-} ]];then
    OUTPUT=`/usr/lib/nagios/plugins/centreon-plugins/centreon_plugins.pl --plugin=cloud::prometheus::exporters::cadvisor::plugin --mode=memory --hostname=$_HOSTNAME --url-path=$_URLPATH --proto=$_PROTO --port=$_PORT --pod=$_POD --warning-working=$_WARNING --critical-working=$_CRITICAL 2>/dev/null`
else
    set +e
    OUTPUT=`/usr/lib/nagios/plugins/centreon-plugins/centreon_plugins.pl --plugin=cloud::prometheus::exporters::cadvisor::plugin --mode=memory --hostname=$_HOSTNAME --url-path=$_URLPATH --proto=$_PROTO --port=$_PORT --pod=$_POD --extra-filter=$_EXTRAPOD --warning-working=$_WARNING --critical-working=$_CRITICAL`
    retval=$?
    set -e
    if [[ $retval -ne 0 ]];then
        echo "$OUTPUT"
        exit $retval
    fi
fi


NOTALONE=$(echo "$OUTPUT" | grep "containers" || true)
if [[ -z "$NOTALONE" ]];then
     _ONLYONE=true
     _ONAME=$(echo $OUTPUT | cut -d " " -f5 | cut -d ']' -f1)
fi

GLOBALMESSAGE=$(echo $OUTPUT | sed "s/'working'/\n'working'/g" | awk '{if(NR>1)print}' | xargs -I {} bash -c 'treatdata "$@"' _ {} ${_TOTAL:--1} $_WARNING $_CRITICAL ${_ONLYONE:-false} ${_ONAME:-null})

ISCRIT=$(echo -e "$GLOBALMESSAGE" | grep -w "CRITICAL" || true)
ISWARN=$(echo -e "$GLOBALMESSAGE" | grep -w "WARNING"|| true)

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
exit ${GLOBALCODE:-0}
