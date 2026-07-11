# Tempo (distributed tracing backend). Single-binary mode is plenty for a local
# demo. OTLP receivers (gRPC 4317 / HTTP 4318) are enabled so the demo app can
# push OpenTelemetry spans directly.

resource "helm_release" "tempo" {
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = var.chart_versions.tempo
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  wait    = true
  timeout = 600

  values = [file("${path.module}/values/tempo.yaml")]
}
