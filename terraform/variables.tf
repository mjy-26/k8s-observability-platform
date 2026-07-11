variable "kubeconfig_path" {
  description = "Path to the kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context for the kind cluster (kind prefixes with 'kind-')."
  type        = string
  default     = "kind-obs-platform"
}

variable "gh_user" {
  description = "GitHub username/org. Used for the Argo CD repo URL and image references."
  type        = string
  default     = "mjy-26"
}

variable "repo_url" {
  description = "Git repository URL Argo CD reconciles from. Defaults to the public GitHub repo derived from gh_user."
  type        = string
  default     = ""
}

variable "target_revision" {
  description = "Git revision (branch/tag/sha) Argo CD tracks."
  type        = string
  default     = "main"
}

# ---- Pinned chart versions (reproducibility). Bump deliberately. ----------
variable "chart_versions" {
  description = "Pinned Helm chart versions."
  type        = map(string)
  default = {
    kube_prometheus_stack = "61.9.0" # app: Prometheus Operator ~v0.75, Grafana ~11.1
    loki_stack            = "2.10.2" # Loki + Promtail
    tempo                 = "1.10.3" # single-binary Tempo
    argo_cd               = "7.4.1"  # Argo CD ~v2.11
  }
}

variable "namespaces" {
  description = "Namespaces created and used by the platform."
  type        = map(string)
  default = {
    monitoring = "monitoring"
    argocd     = "argocd"
    demo       = "demo"
  }
}
