from azure.servicebus import QueueClient, Message
import os

servicebus = os.environ['SERVICEBUS']

# Create the QueueClient
queue_client = QueueClient.from_connection_string(servicebus, "binding")

for x in range(20):
    print("Sending message number ", x)
    msg = Message(b'{"text":"This is my message"}')
    queue_client.send(msg)