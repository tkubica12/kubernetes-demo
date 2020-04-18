#!/bin/bash
filename=${1:-myfile.json}
curl -X POST http://localhost:3500/v1.0/bindings/binding-blob \
	-H "Content-Type: application/json" \
	-d '{ "metadata": {"blobName" : "'$filename'"}, 
      "data": {"mykey": "This is my value"}}'