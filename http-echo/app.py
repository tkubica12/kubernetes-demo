from flask import Flask
from flask import request
import os
import socket

app = Flask(__name__)

@app.route('/')
def response():
    res = "Pod Name: " + os.environ['POD_NAME'] + "\n"
    res = res + "Pod IP: " + os.environ['POD_IP'] + "\n"
    res = res + "Node Name: " + os.environ['NODE_NAME'] + "\n"
    res = res + "Node IP: " + os.environ['NODE_IP'] + "\n"
    res = res + "Client IP: " + request.remote_addr + "\n"
    res = res + "------\nHeaders: \n" + str(request.headers) + "\n"
    return res

if __name__ == '__main__':
    app.run(host='0.0.0.0')