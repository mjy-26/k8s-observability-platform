# Namespaces are created by Terraform so Helm releases and Argo CD apps have a
# stable target. `demo` is created here too, but the demo *workload* is owned by
# Argo CD (GitOps), not Terraform — see README "Design decisions".

locals {
  # If repo_url isn't set explicitly, derive the public GitHub URL from gh_user.
  repo_url = var.repo_url != "" ? var.repo_url : "https://github.com/${var.gh_user}/k8s-observability-platform.git"
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespaces.monitoring
    labels = {
      "app.kubernetes.io/part-of" = "obs-platform"
    }
  }
}

resource "kubernetes_namespace" "demo" {
  metadata {
    name = var.namespaces.demo
    labels = {
      "app.kubernetes.io/part-of" = "obs-platform"
    }
  }
}

# argocd namespace is created by the Argo CD helm release (create_namespace=true).
