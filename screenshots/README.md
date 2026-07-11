# Screenshots

Add real screenshots here and they'll render in the top-level `README.md`.

Suggested captures (open the UIs after `make up` + `make demo-load`):

| File                    | What to capture                                                        |
| ----------------------- | ---------------------------------------------------------------------- |
| `grafana-red.png`       | Grafana → **demo-service — RED / USE** dashboard under load            |
| `grafana-slo.png`       | Grafana → **demo-service — SLO / Error Budget** dashboard              |
| `argocd-appofapps.png`  | Argo CD app tree: `root` → `demo-service` + `observability-config`     |
| `prometheus-alert.png`  | Prometheus/Alertmanager showing a firing `DemoService*BudgetBurn*`     |
| `grafana-traces.png`    | Grafana Explore → a Tempo trace, with the Loki→Tempo correlation link  |
