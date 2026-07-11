output "grafana_url" {
  description = "Grafana UI (NodePort exposed via kind extraPortMappings)."
  value       = "http://localhost:30300"
}

output "argocd_url" {
  description = "Argo CD UI (NodePort)."
  value       = "http://localhost:30080"
}

output "prometheus_url" {
  value = "http://localhost:30900"
}

output "alertmanager_url" {
  value = "http://localhost:30093"
}

output "argocd_repo_url" {
  description = "Git repo Argo CD reconciles from."
  value       = local.repo_url
}

output "argocd_target_revision" {
  description = "Git revision (branch/tag/sha) the Argo CD app-of-apps tracks."
  value       = var.target_revision
}

output "next_steps" {
  value = <<-EOT
    Platform installed. Access:
      Grafana       http://localhost:30300  (admin / prom-operator)
      Argo CD       http://localhost:30080  (admin / `make argocd-password`)
      Prometheus    http://localhost:30900
      Alertmanager  http://localhost:30093

    Then:  make apply-config   # seed demo app + dashboards + alerts locally
           make argocd-bootstrap  # (after git push) hand reconciliation to GitOps
           make demo-load       # generate traffic so SLO alerts fire
  EOT
}
