#!/bin/bash
data='{"comment":"tfgen","category":"tfgen"}'

echo Creating one...
output=$(curl -X POST http://${FQDN}/api/todo -s -d $data -H 'Content-Type: application/json')
id=$(echo $output | jq .itemId -r)

while true
do

    # List all
    echo
    echo Reading all...
    curl http://${FQDN}/api/todo
    sleep $(expr $RANDOM % 30)

    # Get one
    echo
    echo Reading one...
    curl http://${FQDN}/api/todo/${id}
    sleep $(expr $RANDOM % 30)

    # Modify one
    echo
    echo Changing one...
    curl -X PUT http://${FQDN}/api/todo/${id} -d $output -H 'Content-Type: application/json'
    sleep $(expr $RANDOM % 30)

    # Calling node
    echo
    echo Calling node...
    curl -X PUT http://${FQDN}/api/node
    sleep $(expr $RANDOM % 30)

done