#!/bin/bash
#
# Alejandro Revilla 20200219
#
# Script per activar la funcionalitat warning/critical del plugin de prometheus per memoria de contenidors k8s

set -euo pipefail
IFS=$'\n\t'

usage () {

    echo -e "Usage: $(basename "$0") [-h] [-H] [-u] [-P] [-p] [-f] [-w] [-c] [-t] -- Script per activar la funcionalitat warning/critical del plugin de prometheus per cpu de contenidors k8s
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
    -t  indica el nombre total de cpu
    -C  indica el nombre de cpu que es volen utilitzar
"
    exit 1
}

if [[ $# -lt 14 ]];then
    usage
fi

while getopts "h:t:C:H:u:P:p:f:e:w:c:" OPTION; do
  case "$OPTION" in
    h) usage
       ;;
    t) _TOTALCPU="$OPTARG"
       ;;
    C) _DESIREDCPU="$OPTARG"
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

    VAR=$(echo $1 | cut -d '=' -f2 | cut -d '%' -f1)
    echo $VAR 
}
export -f getused

getname() {
    if [[ "false" != "$2" ]];then
        VAR=$3
    else
        VAR=$(echo $1 | cut -d "=" -f1 | cut -d '_' -f2- )
    fi
    echo $VAR
}
export -f getname

getratio() {
    _TOTALCPU=$2
    _DESIREDCPU=$3
    RATIO=$(echo "scale=3; $_DESIREDCPU/$_TOTALCPU" | bc -l)
    echo $RATIO
}
export -f getratio

treatdata () {

    NAME=$(getname "$1" "$6" "$7")
    USED=$(getused "$1")
    #WARNING=$(getwarning "$1" "$2" "$3")
    #CRITICAL=$(getcritical "$1" "$2" "$4")
    RATIO=$(getratio "$1" "$2" "$3")
    VALUEF=$(echo "scale=3; ($USED/$RATIO)"|bc -l)
    VALUE=$(echo "($VALUEF+0.5)/1" | bc)
    if [[ $VALUE -ge $5 ]];then
        MESSAGE="CRITICAL - Container #$NAME cpu is CRITICAL ($VALUE% used)#: #\'usage_$NAME\'=$VALUE%;$4;$5;100"
    elif [[ $VALUE -ge $4 ]];then
        MESSAGE="WARNING - Container #$NAME cpu is WARNING ($VALUE% used)#: #\'usage_$NAME\'=$VALUE%;$4;$5;100"
    else 
        MESSAGE="Container $NAME cpu OK: ###\'usage_$NAME\'=$VALUE%;$4;$5;100"
    fi

    echo "$MESSAGE"
}
export -f treatdata

#Inici de funcio principal


if [[ -z ${_EXTRAPOD:-} ]];then

    OUTPUT=`/usr/lib/nagios/plugins/centreon-plugins/centreon_plugins.pl --plugin=cloud::prometheus::exporters::cadvisor::plugin --mode=cpu --hostname=$_HOSTNAME --url-path=$_URLPATH --proto=$_PROTO --port=$_PORT --pod=$_POD --warning-usage=$_WARNING --critical-usage=$_CRITICAL --cpu-attribute='cpu=""' 2>/dev/null`
else
    set +e
    OUTPUT=`/usr/lib/nagios/plugins/centreon-plugins/centreon_plugins.pl --plugin=cloud::prometheus::exporters::cadvisor::plugin --mode=cpu --hostname=$_HOSTNAME --url-path=$_URLPATH --proto=$_PROTO --port=$_PORT --pod=$_POD --extra-filter=$_EXTRAPOD --warning-usage=$_WARNING --critical-usage=$_CRITICAL --cpu-attribute='cpu=""'`
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
    GLOBALMESSAGE=$(echo $OUTPUT | sed "s/usage/\nusage/g;s/'//g" | awk '{if(NR>1)print}' | xargs -I {} bash -c 'treatdata "$@"' _ {} ${_TOTALCPU:--1} ${_DESIREDCPU} $_WARNING $_CRITICAL ${_ONLYONE:-false} ${_ONAME:-null})
else
    GLOBALMESSAGE=$(echo $OUTPUT | sed "s/usage/\nusage/g;s/'//g" | awk '{if(NR>2)print}' | xargs -I {} bash -c 'treatdata "$@"' _ {} ${_TOTALCPU:--1} ${_DESIREDCPU} $_WARNING $_CRITICAL ${_ONLYONE:-false} ${_ONAME:-null})
fi


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
    echo -n "OK - All containers cpu are ok | "
fi

echo "$GLOBALMESSAGE" | xargs -I {} echo "{}" | cut -d "#" -f4 | tr '\n' ' '
echo -e "\n"
exit ${GLOBALCODE:-0}
