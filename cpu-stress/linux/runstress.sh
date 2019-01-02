#!/bin/bash
timeout=${STRESS_TIMEOUT:-60}
while true
do
  date=$(date +%s)
  doubletime=$(expr $timeout \* 2)
  modulo=$(expr $date % $doubletime)
  if [ $modulo -ge $timeout ]
  then
    echo Generating stress
    stress -c 1 -t 2
  else
    echo Idle
    sleep 2
  fi