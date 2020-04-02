#!/bin/bash
export POSTGRESQL_URL=$(cat /keyvault/psql-jdbc)
java -Djava.security.egd=file:/dev/./urandom -Duser.home=/home/user -jar app.jar