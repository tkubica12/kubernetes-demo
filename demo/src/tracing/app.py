from opencensus.trace.tracer import Tracer
from opencensus.trace.samplers import AlwaysOnSampler
from opencensus.ext.ocagent import trace_exporter
from opencensus.ext.flask.flask_middleware import FlaskMiddleware
from opencensus.trace.propagation.trace_context_http_header_format import TraceContextPropagator
import time
import random
import socket
import os
import flask
import requests

exporter=trace_exporter.TraceExporter(
        service_name=os.getenv('SERVICE_NAME'),
        endpoint=os.getenv('COLLECTOR'))

tracer = Tracer(sampler=AlwaysOnSampler(), exporter=exporter)

app = flask.Flask(__name__)
middleware = FlaskMiddleware(app, exporter=exporter, sampler=AlwaysOnSampler(), propagator=TraceContextPropagator(), blacklist_paths=['_ah/health'])

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
