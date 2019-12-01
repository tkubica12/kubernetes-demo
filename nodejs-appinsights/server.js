const http = require('http');
const appInsights = require('applicationinsights');

const port = process.env.PORT;
appInsights.setup();
appInsights.start();

const server = http.createServer((req, res) => {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain');
    res.end('I am alive');
});

server.listen(port, '0.0.0.0', () => {});