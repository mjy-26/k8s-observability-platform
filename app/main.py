"""
Demo microservice for the k8s-observability-platform.

Emits the "three pillars" of observability so the dashboards, SLOs and alerts
have real signal:

  * METRICS  — Prometheus RED metrics on /metrics
               (request count, latency histogram, error rate)
  * LOGS     — structured JSON logs (with trace_id) shipped to Loki via Promtail
  * TRACES   — OpenTelemetry spans exported over OTLP to Tempo

Endpoints:
  GET /            — liveness landing page
  GET /healthz     — health check (never errors, never slow)
  GET /work        — variable latency + ~10% 500s so SLO burn-rate alerts fire
  GET /metrics     — Prometheus exposition
"""

import logging
import os
import random
import time

from fastapi import FastAPI, Response
from fastapi.responses import JSONResponse
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)
from pythonjsonlogger import jsonlogger
from starlette.requests import Request

# --- OpenTelemetry (traces -> Tempo over OTLP) ------------------------------
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "demo-service")
OTLP_ENDPOINT = os.getenv(
    "OTEL_EXPORTER_OTLP_ENDPOINT",
    "http://tempo.monitoring.svc.cluster.local:4317",
)

# ---------------------------------------------------------------------------
# Tracing setup
# ---------------------------------------------------------------------------
resource = Resource.create({"service.name": SERVICE_NAME})
provider = TracerProvider(resource=resource)
provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=OTLP_ENDPOINT, insecure=True))
)
trace.set_tracer_provider(provider)
tracer = trace.get_tracer(SERVICE_NAME)


# ---------------------------------------------------------------------------
# Structured JSON logging, enriched with the active trace/span IDs so log lines
# can be correlated with traces in Grafana (Loki derived field -> Tempo).
# ---------------------------------------------------------------------------
class TraceContextFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        span = trace.get_current_span()
        ctx = span.get_span_context() if span else None
        if ctx and ctx.is_valid:
            record.trace_id = format(ctx.trace_id, "032x")
            record.span_id = format(ctx.span_id, "016x")
        else:
            record.trace_id = ""
            record.span_id = ""
        record.service = SERVICE_NAME
        return True


def configure_logging() -> logging.Logger:
    handler = logging.StreamHandler()
    handler.setFormatter(
        jsonlogger.JsonFormatter(
            "%(asctime)s %(levelname)s %(name)s %(message)s "
            "%(service)s %(trace_id)s %(span_id)s"
        )
    )
    handler.addFilter(TraceContextFilter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(logging.INFO)
    return logging.getLogger(SERVICE_NAME)


log = configure_logging()

# ---------------------------------------------------------------------------
# Prometheus metrics (RED: Rate, Errors, Duration)
# ---------------------------------------------------------------------------
REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests.",
    ["method", "path", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds.",
    ["method", "path"],
    # Buckets tuned around our 300ms SLO threshold.
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1.0, 2.5, 5.0),
)
IN_PROGRESS = Gauge(
    "http_requests_in_progress",
    "In-flight HTTP requests.",
    ["path"],
)

app = FastAPI(title="demo-service", version="1.0.0")


@app.middleware("http")
async def record_metrics(request: Request, call_next):
    path = request.url.path
    if path == "/metrics":  # don't measure the scrape endpoint itself
        return await call_next(request)

    method = request.method
    IN_PROGRESS.labels(path=path).inc()
    start = time.perf_counter()
    status = 500
    try:
        response = await call_next(request)
        status = response.status_code
        return response
    finally:
        elapsed = time.perf_counter() - start
        LATENCY.labels(method=method, path=path).observe(elapsed)
        REQUESTS.labels(method=method, path=path, status=str(status)).inc()
        IN_PROGRESS.labels(path=path).dec()


@app.get("/")
async def root():
    log.info("root requested")
    return {"service": SERVICE_NAME, "status": "ok"}


@app.get("/healthz")
async def healthz():
    return {"status": "healthy"}


@app.get("/work")
async def work():
    """
    Simulates real work: variable latency + occasional failures so that the
    SLO burn-rate alerts (99% < 300ms, error rate < 1%) actually trip under
    load (`make demo-load`).
    """
    with tracer.start_as_current_span("do-work") as span:
        # ~10% error rate, biased so alerts fire under sustained load.
        fail = random.random() < 0.10
        # Latency: mostly fast, with a heavy tail that breaches the 300ms SLO.
        latency = random.choices(
            population=[0.05, 0.15, 0.35, 0.8],
            weights=[0.6, 0.2, 0.15, 0.05],
        )[0]
        span.set_attribute("work.simulated_latency_s", latency)
        span.set_attribute("work.will_fail", fail)
        time.sleep(latency)

        if fail:
            log.error("work failed", extra={"latency_s": latency})
            span.set_attribute("error", True)
            return JSONResponse(
                status_code=500,
                content={"error": "simulated failure", "latency_s": latency},
            )

        log.info("work completed", extra={"latency_s": latency})
        return {"result": "done", "latency_s": latency}


@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


# Auto-instrument FastAPI (server spans for every request).
FastAPIInstrumentor.instrument_app(app)
