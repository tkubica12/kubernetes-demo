import flask
import requests
import os
import time
import pymysql
import random

# Import Open Telemetry tracing
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (
    ConsoleSpanExporter,
    SimpleExportSpanProcessor,
)
from opentelemetry.ext.flask import FlaskInstrumentor
from opentelemetry.ext.requests import RequestsInstrumentor
from opentelemetry.ext.pymysql import PyMySQLInstrumentor

# Import Azure Monitor
from azure_monitor import AzureMonitorSpanExporter
from azure_monitor import AzureMonitorMetricsExporter
from azure_monitor.sdk.auto_collection import AutoCollection
from opentelemetry.ext.wsgi import OpenTelemetryMiddleware

# Gather configurations
appInsightsConnectionString = "InstrumentationKey=%s" % os.getenv('APPINSIGHTS_INSTRUMENTATIONKEY')
mySqlHost = os.getenv('MYSQL_HOST')
mySqlPassword = os.getenv('MYSQL_PASSWORD')
mySqlUsername = os.getenv('MYSQL_USERNAME')

# Setup instrumentation with Console exporter
trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    SimpleExportSpanProcessor(ConsoleSpanExporter())
)

# Exporter metadata configuration
def azure_monitor_metadata(envelope):
    envelope.tags['ai.cloud.role'] = os.getenv('APP_NAME')
    envelope.data.base_data.properties['app_version'] = os.getenv('APP_VERSION')
    envelope.data.base_data.properties['kube_pod_name'] = os.getenv('POD_NAME')
    envelope.data.base_data.properties['kube_node_name'] = os.getenv('NODE_NAME')
    envelope.data.base_data.properties['kube_namespace'] = os.getenv('POD_NAMESPACE')
    envelope.data.base_data.properties['kube_cpu_limit'] = os.getenv('CPU_LIMIT')
    envelope.data.base_data.properties['kube_memory_limit'] = os.getenv('MEMORY_LIMIT')
    # Read labels
    f = open("/podinfo/labels")
    for line in f:
        key,value = line.partition("=")[::2]
        envelope.data.base_data.properties['labels.%s' % key] = value.replace('"', '')
    return True

# Add Azure Monitor exporter
exporterAzure = AzureMonitorSpanExporter(
    connection_string=appInsightsConnectionString
)
exporterAzure.add_telemetry_processor(azure_monitor_metadata)
trace.get_tracer_provider().add_span_processor(
    SimpleExportSpanProcessor(exporterAzure)
)

# Create Flask object
app = flask.Flask(__name__)

# Add automatic instrumentation
RequestsInstrumentor().instrument()
FlaskInstrumentor().instrument_app(app)
PyMySQLInstrumentor().instrument()

# Prepare database
conn = pymysql.connect(host=mySqlHost, user=mySqlUsername, password=mySqlPassword)
conn.cursor().execute('create database if not exists myotdb')
conn.select_db("myotdb") 
conn.cursor().execute('create table if not exists mytable (mynumber INT)')

# Get tracer
tracer = trace.get_tracer(__name__)

# Flask routing
@app.route('/')
def init():
    trace.get_current_span().set_attribute("order_id", "00123456")
    response = requests.get(os.getenv('REMOTE_ENDPOINT', default="http://127.0.0.1:8080/data"))
    return "Response from data API: %s" % response.content.decode("utf-8") 

@app.route('/data')
def data():
    # Custom span
    with tracer.start_as_current_span(name="processData"):
        result = processData()
    return result

# Processing
def processData():
    time.sleep(0.2)
    randomNumber = int(random.random()*100)
    try:
        conn.cursor().execute("insert into mytable values (%d)" % randomNumber)
        conn.commit()
    except Exception as e:
        print("Exeception occured:{}".format(e))
    return "Your integer is %d" % randomNumber

# Run Flask
app.run(host='0.0.0.0', port=8080, threaded=True)