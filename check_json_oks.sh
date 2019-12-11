#!/bin/bash

### Version 1.0 by Alejandro Revilla 20191211

JSON=$(curl -XGET "URL" 2>/dev/null)
MAINSTATUS=$(echo $JSON | cut -d '"' -f4 2>/dev/null)
DATA=$(echo $JSON | cut -d '"' -f6,10,12,16,18,22,24,28,30,34,36,40,42,46)
ERRORS='OK - All status ok'
FAILED=''

if [[ $MAINSTATUS != "ok" ]];
then
	ERRORS="CRITICAL - Main status not ok, affected items: "
fi

IFS='"' read -r -a array <<< "$DATA"

for index in "${!array[@]}"
do
	if [[ $((${index}%2)) -eq 1 ]] && [[ ${array[index]} != "ok" ]];
	then
		FAILED="$FAILED ${array[$((${index}-1))]}"
	fi
done

echo "$ERRORS$FAILED"

