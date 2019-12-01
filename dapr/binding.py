import flask
from flask import request, jsonify
from flask_cors import CORS
import json
import sys

app = flask.Flask(__name__)
CORS(app)

@app.route('/binding-eventhub', methods=['POST'])
def a_subscriber():
    print(f'message: {request.json}', flush=True)
    return "OK", 200

app.run()