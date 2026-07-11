# OPTIONAL — "full GitOps" platform apps (Argo CD manages the Helm stack too)

By default this repo splits responsibilities:

- **Terraform** installs the *platform* (kube-prometheus-stack, Loki, Tempo, Argo
  CD) — a clear `plan`/`apply` workflow for cluster-critical infrastructure.
- **Argo CD** continuously reconciles *workloads + config* (`k8s/argocd/apps/`:
  the demo app and observability config).

The manifests **in this folder** show the alternative: managing the entire
observability stack as Argo CD `Application`s (the "everything is GitOps" model).
They are intentionally **not** wired into the `root` app-of-apps to avoid
*double-management* (Terraform and Argo CD fighting over the same Helm releases).

They cleverly **reuse the exact same values files** as Terraform
(`terraform/values/*.yaml`) via Argo CD multi-source `$values`, so there is a
single source of truth for configuration.

## To switch to full GitOps

1. Remove the Helm releases from Terraform (comment out `prometheus.tf`,
   `loki.tf`, `tempo.tf`) so only Argo CD is installed by Terraform.
2. Point the root app-of-apps at this directory as well, or copy these files
   into `k8s/argocd/apps/`.
3. `terraform apply` then `make argocd-bootstrap`.

Trade-off discussed in the top-level README → "Design decisions & trade-offs".
