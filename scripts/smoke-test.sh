#!/usr/bin/env bash
# Smoke test: assert the platform came up healthy. Used by `make test` and by
# the GitHub Actions kind-based CI job.
set -euo pipefail

TIMEOUT="${TIMEOUT:-300s}"

fail=0

check_ns_ready() {
  local ns="$1"
  echo "==> [${ns}] waiting for pods to be Ready (timeout ${TIMEOUT})..."
  if ! kubectl -n "${ns}" wait --for=condition=Ready pods --all --timeout="${TIMEOUT}"; then
    echo "!! [${ns}] not all pods became Ready"
    kubectl -n "${ns}" get pods
    fail=1
  fi
}

echo "== Cluster nodes =="
kubectl get nodes

check_ns_ready monitoring

# argocd is present in a full `make up`, but not in the lighter CI smoke test.
if kubectl get ns argocd >/dev/null 2>&1 && [ -n "$(kubectl -n argocd get pods -o name 2>/dev/null)" ]; then
  check_ns_ready argocd
fi

# demo namespace is optional (only present after `make apply-config`).
if kubectl get ns demo >/dev/null 2>&1 && [ -n "$(kubectl -n demo get pods -o name 2>/dev/null)" ]; then
  check_ns_ready demo
fi

echo "==> Asserting key deployments are Available..."
for d in kube-prometheus-stack-grafana kube-prometheus-stack-kube-state-metrics; do
  if ! kubectl -n monitoring rollout status "deploy/${d}" --timeout="${TIMEOUT}"; then
    echo "!! deploy/${d} not Available"
    fail=1
  fi
done

if [ "${fail}" -ne 0 ]; then
  echo "SMOKE TEST FAILED"
  exit 1
fi
echo "SMOKE TEST PASSED ✅"
