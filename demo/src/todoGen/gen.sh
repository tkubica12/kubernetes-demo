#!/bin/bash
if [[ -z "${FQDN}" ]]; then
  echo FQDN environmental variable not set
  exit 1
else
  echo Generating load to $FWDN
fi


data='{"comment":"tfgen","category":"tfgen"}'

echo Creating one...
output=$(curl -X POST https://${FQDN}/api/todo -s -d $data -H 'Content-Type: application/json')
id=$(echo $output | jq .itemId -r)

while true
do

    # List all
    echo
    echo Reading all...
    curl https://${FQDN}/api/todo -s
    sleep $(expr $RANDOM % 30)

    # Get one
    echo
    echo Reading one...
    curl https://${FQDN}/api/todo/${id} -s
    sleep $(expr $RANDOM % 30)

    # Modify one
    echo
    echo Changing one...
    curl -X PUT https://${FQDN}/api/todo/${id} -s -d $output -H 'Content-Type: application/json'
    sleep $(expr $RANDOM % 30)

    # Calling node
    echo
    echo Calling node...
    curl https://${FQDN}/api/node -s
    sleep $(expr $RANDOM % 30)

done