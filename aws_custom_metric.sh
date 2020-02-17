#!/bin/bash
#
# Alejandro Revilla 20200212
#

set -euo pipefail
IFS=$'\n\t'

usage="$(basename "$0") [-h] [-r] [-n] [-m] [-s] [-e] [-p] [-S] [-d] [-P] -- program to get metrics values for Custom Namespaces in AWS

where:
    -h  show this help text
    -r  *region      ex:eu-west-1  
    -n  *namespace   ex:CustomNamespace
    -m  *metric      ex:CustomMetric
    -s  *start time of the period desired passed as days ago
    -e  *end time of the period desired passed as days ago
    -p  *period in seconds
    -S  *statistics  ex:Average
    -d  *dimensions  ex:Name=name,Value=value
    -P  *aws profile
    -w  desired warning value
    -c  desired critical value
* means that the flag is required for the correct behaviour of the program  
"

if [[ $# -lt 18 ]];then
   echo "$usage"
   exit
fi


while getopts "h:r:n:m:o:s:e:p:S:d:P:w:c:" OPTION; do
  case "$OPTION" in
    h) echo "$usage"
       exit;;
    r) _REGION="$OPTARG"
       ;;
    n) _NAMESPACE="$OPTARG"
       ;;
    m) _METRIC="$OPTARG"
       ;;
    s) _START="$OPTARG"
       ;;
    e) _END="$OPTARG"
       ;;
    p) _PERIOD="$OPTARG"
       ;;
    S) _STATISTICS="$OPTARG"
       ;;
    d) _DIMENSIONS="$OPTARG"
       ;;
    P) _PROFILE="$OPTARG"
       ;;
    w) _WFLAG=true
       _WARNING="$OPTARG"
       ;;
    c) _CFLAG=true
       _CRITICAL="$OPTARG"
       ;;
    ?) echo "$usage"
       exit
       ;;
  esac
done
shift "$(($OPTIND -1))"

COM=`/usr/bin/aws cloudwatch get-metric-statistics --region $_REGION --namespace $_NAMESPACE --metric-name $_METRIC --output text --start-time $(date -Iseconds --date="$_START days ago") --end-time $(date -Iseconds --date="$_END days ago") --period $_PERIOD --statistics $_STATISTICS --dimensions $_DIMENSIONS  --profile $_PROFILE`

DATA=$(echo -e "$COM"|awk '$1 == "DATAPOINTS" {print $2}')

if [[ -z "$DATA" ]];then
  echo -e "UNKNOWN - There are not any datapoints for the given timeperiod"
  exit 3
fi

for x in $DATA; do
    INT=$(echo "$x/1"|bc)
    if [[ ${_CFLAG:-false} && "$INT" -ge "${_CRITICAL:-}" ]];then
        echo -e "CRITICAL - Metric $_METRIC is greater or equal critical threshold ($_CRITICAL) | '$_METRIC'=$INT"
        exit 2
    elif [[ ${_WFLAG:-false} && "$INT" -ge "${_WARNING:-}" ]];then
        echo -e "WARNING - Metric $_METRIC is greater or equal warning threshold ($_WARNING) | '$_METRIC'=$INT"
        exit 1
    fi
done

echo -e "OK - Metric $_METRIC is OK | '$_METRIC'=$INT"
exit 0

