# Loki (log store) + Promtail (node-level log shipper). Promtail tails every pod
# on every node and ships to Loki; our demo app emits structured JSON logs so
# they're queryable/filterable in Grafana Explore.

resource "helm_release" "loki_stack" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = var.chart_versions.loki_stack
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  wait    = true
  timeout = 600

  values = [file("${path.module}/values/loki-stack.yaml")]
}
