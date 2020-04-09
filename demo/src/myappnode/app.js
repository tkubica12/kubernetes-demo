const express = require('express')
const http = require('http')
const { ServiceBusClient } = require("@azure/service-bus"); 
const connectionString = process.env.SERVICEBUS_TODO_CONNECTION;
const queueName = process.env.QUEUE_NAME; 
const url = process.env.URL; 
const retryurl = process.env.RETRY_URL; 
const app = express()
const port = 3000

const sbClient = ServiceBusClient.createFromConnectionString(connectionString); 
const queueClient = sbClient.createQueueClient(queueName);
const sender = queueClient.createSender();
const message= {
    body: `Message sent`,
    label: `test`
  };

app.get('/api/node', async function(req, res) {
    console.log('Calling todo API...');
    http.get(url, (resp) => {
      let data = '';
      resp.on('data', (chunk) => {
        data += chunk;
      });
    
      resp.on('end', () => {
        console.log(data);
      });

      }).on("error", (err) => {
        console.log("Error: " + err.message);
      });
    
    console.log('Calling retry service...');
    http.get(retryurl, (rresp) => {
      let rdata = '';
      rresp.on('data', (rchunk) => {
        rdata += rchunk;
      });
    
      rresp.on('end', () => {
        console.log(rdata);
      });
    
      }).on("error", (err) => {
        console.log("Error: " + err.message);
      });

    console.log('Sending message to queue...');
    sender.send(message);
    res.send('Sent');
  });

app.get('/', function(req, res) {
  res.send('OK');
});

app.listen(port, () => console.log(`App is listening`))