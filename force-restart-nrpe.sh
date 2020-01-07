#!/bin/bash

PID=$(ps -A | grep nrpe | awk '{print $1}')
echo -e "nrpe service PID : $PID "
kill -9 $PID
echo -e "$PID killed"
if [ $(service nrpe restart) != 0 ]; then 
	echo -e "No s'ha pogut reiniciar el servei nrpe"
else
	echo -e "nrpe restarted"


