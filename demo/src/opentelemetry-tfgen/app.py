from azure_monitor import AzureMonitorSpanExporter
from azure_monitor import AzureMonitorMetricsExporter
from opentelemetry import trace
from opentelemetry import metrics
from opentelemetry.sdk.metrics import Counter, MeterProvider
from opentelemetry.sdk.metrics.export.controller import PushController
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchExportSpanProcessor
from opentelemetry.ext.requests import RequestsInstrumentor
import time
import random
import socket
import os
import requests

# Setup distributed tracing
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

trace_exporter = AzureMonitorSpanExporter(
    instrumentation_key = os.environ['APPINSIGHTS_INSTRUMENTATION_KEY']
)

span_processor = BatchExportSpanProcessor(trace_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

RequestsInstrumentor().instrument()

# Setup metrics
metrics_exporter = AzureMonitorMetricsExporter(
    instrumentation_key = os.environ['APPINSIGHTS_INSTRUMENTATION_KEY']
)
metrics.set_meter_provider(MeterProvider())
meter = metrics.get_meter(__name__)
PushController(meter, metrics_exporter, 10)

tfgen_counter = meter.create_metric(
    name="tfgen_counter",
    description="mydemo namespace",
    unit="1",
    value_type=int,
    metric_type=Counter,
)

# Define cloud role
def callback_function(envelope):
    envelope.tags['ai.cloud.role'] = os.getenv('APP_NAME')
    return True

trace_exporter.add_telemetry_processor(callback_function)
metrics_exporter.add_telemetry_processor(callback_function)

while True:
    tfgen_counter.add(1, {"destination": "endpoint1"})
    requests.get(os.getenv('REMOTE_ENDPOINT1'))
    time.sleep(random.random()*60)
    tfgen_counter.add(1, {"destination": "endpoint2"})
    requests.get(os.getenv('REMOTE_ENDPOINT2'))
    time.sleep(random.random()*60)
