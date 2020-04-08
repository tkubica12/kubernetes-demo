const express = require('express')
const https = require('https')
const { ServiceBusClient } = require("@azure/service-bus"); 
const connectionString = process.env.SERVICEBUS_TODO_CONNECTION;
const queueName = process.env.QUEUE_NAME; 
const app = express()
const port = 3000

const sbClient = ServiceBusClient.createFromConnectionString(connectionString); 
const queueClient = sbClient.createQueueClient(queueName);
const sender = queueClient.createSender();
const message= {
    body: `Message sent`,
    label: `test`
  };
const options = {
  //  hostname: 'todo-myapp-todo',
    hostname: 'todo-myapp-todo',
    port: 8080,
    path: '/api/todo',
    method: 'GET'
  }

app.get('/api/node', function(req, res) {
    console.log('Calling todo API...');
    const apireq = https.request(options, apires => {
        console.log(`statusCode: ${apires.statusCode}`)
      
        apires.on('data', d => {
          process.stdout.write(d)
        })
      });
    console.log('Sending message...');
    sender.send(message);
    res.send('Sent');
  });

app.get('/', function(req, res) {
  res.send('OK');
});

app.listen(port, () => console.log(`App is listening`))