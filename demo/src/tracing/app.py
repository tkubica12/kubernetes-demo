from opencensus.trace.tracer import Tracer
from opencensus.trace.samplers import AlwaysOnSampler
from opencensus.ext.ocagent import trace_exporter
from opencensus.ext.flask.flask_middleware import FlaskMiddleware
from opencensus.trace.propagation.b3_format import B3FormatPropagator
from opencensus.trace import config_integration
import time
import random
import socket
import os
import flask
import requests

exporter=trace_exporter.TraceExporter(
        service_name=os.getenv('SERVICE_NAME'),
        endpoint=os.getenv('COLLECTOR'))

tracer = Tracer(sampler=AlwaysOnSampler(), exporter=exporter, propagator=B3FormatPropagator())

integration = ['requests']

config_integration.trace_integrations(integration)

app = flask.Flask(__name__)
middleware = FlaskMiddleware(app, exporter=exporter, sampler=AlwaysOnSampler(), propagator=B3FormatPropagator(), blacklist_paths=['_ah/health'])

@app.route('/')
def init():
    with tracer.span(name='Initiate'):
        time.sleep(random.random())
        with tracer.span(name='GetDataFromOutside'):
            response = requests.get(os.getenv('REMOTE_ENDPOINT'))
        with tracer.span(name='ProcessData'):
            time.sleep(random.random())
    return 'OK'

@app.route('/data')
def data():
    with tracer.span(name='ReturnData'):
        time.sleep(random.random())
    return 'OK'

@app.route('/test')
def test():
    return 'OK'

app.run(host='0.0.0.0', port=8080, threaded=True)
