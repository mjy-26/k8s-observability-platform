# kube-prometheus-stack: Prometheus + Alertmanager + Grafana + node/kube metrics.
# Grafana datasources (Prometheus/Loki/Tempo) are declared as code in the values
# file — no click-ops. Dashboards are delivered as ConfigMaps and picked up by
# the Grafana sidecar (managed by Argo CD, see k8s/config).

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_versions.kube_prometheus_stack
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  # Wait for the operator + CRDs to be Ready before other releases depend on it.
  wait          = true
  timeout       = 900
  atomic        = false
  wait_for_jobs = true

  values = [file("${path.module}/values/kube-prometheus-stack.yaml")]
}
