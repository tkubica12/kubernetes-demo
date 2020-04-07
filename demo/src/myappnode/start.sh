#!/bin/bash
export SERVICEBUS_TODO_CONNECTION=$(cat /keyvault/servicebus-todo-connection)
node app.js