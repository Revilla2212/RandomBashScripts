#!/bin/bash
#
# Author Alejandro Revilla 28/01/2020
# Adapted from cron job: https://github.com/jondade/Fastly-IP-whitelist-notify/blob/master/whitelist-cron.sh

function fetchIPData () {
  curl -s 'https://api.fastly.com/public-ip-list'
}

function trim_sum_data () {
  echo $1 | sed -e 's/^\([A-Za-z0-9]\+\)\s.*/\1/'
}

function run () {
  OLD_MD5=$( trim_sum_data $(cat ${CURRENT_IP_MD5}) )
  NEW_DATA=$(fetchIPData)

  NEW_MD5=$( trim_sum_data $(echo ${NEW_DATA} | md5sum ) )

  if [ "${OLD_MD5}" == "${NEW_MD5}" ]; then
    echo "OK - No ip changes."
    exit 0;
  else
    UPDATED_MESSAGE=$(cat <<-EOM 
The fastly whitelist checksum did not match in the latest check. An update to the whitelisting rules may be required.
The lastest json data is:
${NEW_DATA}
EOM
)
    echo ${NEW_MD5} > ${CURRENT_IP_MD5}
    echo ${NEW_DATA} > ${CURRENT_IP_DATA}
    echo "CRITICAL - ${UPDATED_MESSAGE}" 
    exit 2
  fi
}

API_URL="https://api.fastly.com/list-all-ips"
SCRIPTNAME="/usr/lib/nagios/plugins/fastly/check_fastly_ips.sh"
DATA_PATH="/usr/lib/nagios/plugins/fastly"
CURRENT_IP_MD5="${DATA_PATH}/fastly-IP.md5"
CURRENT_IP_DATA="${DATA_PATH}/fastly-IP.json"

run
