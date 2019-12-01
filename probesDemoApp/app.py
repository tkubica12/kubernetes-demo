from flask import Flask
import time
import os
import signal

app = Flask(__name__)

ready = True
alive = True

@app.route('/')
def hello():
    if (alive and ready):
        time.sleep(5)
        return "OK\n"
    elif (alive):
        time.sleep(15)
        return "OK\n"
    else:
        while True:
            x = 12345678 * 8765432

@app.route('/hang')
def hang():
    global alive
    alive = False
    return "Will hang\n"

@app.route('/kill')
def kill():
    os._exit(1)

@app.route('/setReady')
def ready():
    global ready
    ready = True
    return "Ready\n"

@app.route('/setNotReady')
def notready():
    global ready
    ready = False
    return "Not ready\n"

@app.route('/health')
def health():
    if (alive):
        return "OK\n"
    else:
        while True:
            x = 12345678 * 87654321

@app.route('/readiness')
def readiness():
    if (ready):
        return "OK\n"
    else:
        return "Not ready\n", 503

if __name__ == '__main__':
    app.run(host='0.0.0.0')