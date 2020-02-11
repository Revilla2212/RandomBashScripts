#!/bin/bash

set -euo pipefail
IFS="\t\n"

function finish {
  /home/alejandro.revilla/traptest.sh
}
trap finish EXIT

touch /home/alejandro.revilla/dates/$(date +"%N")
exit
