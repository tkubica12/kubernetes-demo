from flask import Flask
import socket
import os

app = Flask(__name__)

@app.route("/")
def hello():
        return "Hello World v2 from " + socket.gethostname()

app.run(host='0.0.0.0', port=os.getenv('PORT', 8080), threaded=True)