# Both providers talk to the local kind cluster via the kubeconfig context that
# `kind create cluster` writes. We deliberately do NOT manage the cluster
# lifecycle from Terraform (see README "Design decisions") — the cluster is
# created by `make cluster` / kind, Terraform manages everything *inside* it.

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}
