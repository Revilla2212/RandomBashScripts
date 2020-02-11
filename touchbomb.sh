#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

DIR=$(pwd)
NAME=$0
DATEDIR="$DIR/dates"

function finish {
  $0
}
trap finish EXIT
trap finish INT
trap finish TERM

test ! -d $DIR/dates && mkdir dates

touch $DATEDIR/$(date +"%N")
exit
