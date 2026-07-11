#!/usr/bin/env bash
# Generate traffic against the demo service so metrics/logs/traces flow and the
# SLO burn-rate alerts eventually fire (the /work endpoint returns ~10% 500s and
# a latency tail beyond the 300ms SLO).
#
# Usage: ./scripts/load.sh [DURATION_SECONDS] [CONCURRENCY]
#   DURATION_SECONDS  how long to run (default 300; 0 = forever)
#   CONCURRENCY       parallel request loops (default 8)
set -euo pipefail

NAMESPACE="${NAMESPACE:-demo}"
SERVICE="${SERVICE:-demo-service}"
LOCAL_PORT="${LOCAL_PORT:-18080}"
DURATION="${1:-300}"
CONCURRENCY="${2:-8}"

echo "==> Port-forwarding svc/${SERVICE} -> localhost:${LOCAL_PORT}"
kubectl -n "${NAMESPACE}" port-forward "svc/${SERVICE}" "${LOCAL_PORT}:8000" >/dev/null 2>&1 &
PF_PID=$!

cleanup() {
  echo -e "\n==> Stopping load; killing port-forward (${PF_PID})"
  kill "${PF_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# Wait for the port-forward to be ready.
for _ in $(seq 1 20); do
  if curl -sf "http://localhost:${LOCAL_PORT}/healthz" >/dev/null 2>&1; then break; fi
  sleep 0.5
done

echo "==> Generating load: concurrency=${CONCURRENCY}, duration=${DURATION}s (Ctrl-C to stop)"
END=$(( $(date +%s) + DURATION ))

worker() {
  while [ "${DURATION}" -eq 0 ] || [ "$(date +%s)" -lt "${END}" ]; do
    curl -s -o /dev/null "http://localhost:${LOCAL_PORT}/work" || true
  done
}

for _ in $(seq 1 "${CONCURRENCY}"); do
  worker &
done
wait
