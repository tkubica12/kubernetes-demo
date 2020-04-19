from azure.servicebus import QueueClient, Message
import os
import urllib.request
import json

servicebus = json.loads(urllib.request.urlopen("http://localhost:3500/v1.0/secrets/azurekeyvault/servicebus-dapr-connection").read())['servicebus-dapr-connection']

# Create the QueueClient
queue_client = QueueClient.from_connection_string(servicebus, "binding")

for x in range(20):
    print("Sending message number ", x)
    msg = Message(b'{"text":"This is my message"}')
    queue_client.send(msg)