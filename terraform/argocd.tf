# Argo CD — the GitOps engine. Terraform only *installs* Argo CD (platform
# bootstrap). The app-of-apps root Application is applied on top (see
# `make argocd-bootstrap` and k8s/argocd/root-app.yaml) so that Git becomes the
# source of truth for workloads/config. This is the canonical Argo CD bootstrap
# pattern: install once with IaC, then hand ongoing reconciliation to GitOps.

resource "helm_release" "argo_cd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_versions.argo_cd
  namespace        = var.namespaces.argocd
  create_namespace = true

  wait    = true
  timeout = 600

  values = [file("${path.module}/values/argocd.yaml")]
}
