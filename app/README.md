# demo-service

A tiny FastAPI microservice that emits the three pillars of observability so the
platform's dashboards, SLOs and alerts have real data.

| Endpoint    | Purpose                                                        |
| ----------- | -------------------------------------------------------------- |
| `GET /`     | Landing/liveness, logs a line                                  |
| `GET /healthz` | Health check (never fails, never slow)                      |
| `GET /work` | Variable latency + ~10% `500`s — drives SLO burn-rate alerts   |
| `GET /metrics` | Prometheus exposition (RED metrics)                         |

## Signals

- **Metrics** — `http_requests_total`, `http_request_duration_seconds` (histogram
  with buckets around the 300 ms SLO), `http_requests_in_progress`.
- **Logs** — structured JSON on stdout including `trace_id`/`span_id`; Promtail
  ships them to Loki. The `trace_id` field powers the Grafana Loki→Tempo link.
- **Traces** — OpenTelemetry spans exported over OTLP gRPC to Tempo
  (`OTEL_EXPORTER_OTLP_ENDPOINT`, default `http://tempo.monitoring.svc:4317`).

## Run locally (no cluster)

```bash
pip install -r requirements.txt
# Point traces somewhere or expect connection warnings if Tempo isn't running:
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
uvicorn main:app --reload --port 8000

curl localhost:8000/work
curl localhost:8000/metrics
```

## Environment variables

| Var                           | Default                                              |
| ----------------------------- | ---------------------------------------------------- |
| `OTEL_SERVICE_NAME`           | `demo-service`                                       |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://tempo.monitoring.svc.cluster.local:4317`     |
