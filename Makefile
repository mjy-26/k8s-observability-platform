# ============================================================================
# k8s-observability-platform — one-command bootstrap
# ----------------------------------------------------------------------------
# Quick start:  make up      (create cluster + install everything)
#               make demo-load   (generate traffic so alerts fire)
#               make down    (tear everything down)
#
# Override the image owner once you fork/push:  make image GH_USER=<you>
# ============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ---- Configuration (override on the CLI, e.g. `make image GH_USER=alice`) ---
CLUSTER_NAME ?= obs-platform
KIND_CONFIG  ?= kind/kind-cluster.yaml
GH_USER      ?= mjy-26
IMAGE_NAME   ?= k8s-observability-platform-demo
TAG          ?= dev
IMG          := ghcr.io/$(GH_USER)/$(IMAGE_NAME):$(TAG)

MONITORING_NS := monitoring
ARGOCD_NS     := argocd
DEMO_NS       := demo

TF_DIR := terraform

# Colours for readable output
BLUE  := \033[0;34m
GREEN := \033[0;32m
YEL   := \033[0;33m
NC    := \033[0m

.PHONY: help
help: ## Show this help
	@echo ""
	@echo "$(BLUE)k8s-observability-platform$(NC) — available targets:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}'
	@echo ""

# ---------------------------------------------------------------------------
# Top-level lifecycle
# ---------------------------------------------------------------------------
.PHONY: up
up: cluster image load-image platform apply-config info ## Full bootstrap: cluster + stack + demo app
	@echo -e "$(GREEN)==> Platform is up. Run 'make demo-load' to generate traffic.$(NC)"

.PHONY: down
down: ## Destroy the Terraform-managed stack and delete the kind cluster
	-cd $(TF_DIR) && terraform destroy -auto-approve
	-kind delete cluster --name $(CLUSTER_NAME)
	@echo -e "$(GREEN)==> Torn down.$(NC)"

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------
.PHONY: cluster
cluster: ## Create the 3-node kind cluster (idempotent)
	@if kind get clusters 2>/dev/null | grep -qx "$(CLUSTER_NAME)"; then \
		echo -e "$(YEL)==> kind cluster '$(CLUSTER_NAME)' already exists, skipping.$(NC)"; \
	else \
		echo -e "$(BLUE)==> Creating kind cluster '$(CLUSTER_NAME)'...$(NC)"; \
		kind create cluster --config $(KIND_CONFIG) --wait 120s; \
	fi
	kubectl cluster-info --context kind-$(CLUSTER_NAME)

# ---------------------------------------------------------------------------
# Demo app image
# ---------------------------------------------------------------------------
.PHONY: image
image: ## Build the demo microservice image
	@echo -e "$(BLUE)==> Building $(IMG)...$(NC)"
	docker build -t $(IMG) ./app

.PHONY: load-image
load-image: ## Load the demo image into the kind cluster (no registry needed)
	@echo -e "$(BLUE)==> Loading $(IMG) into kind...$(NC)"
	kind load docker-image $(IMG) --name $(CLUSTER_NAME)

.PHONY: push
push: ## Push the demo image to GHCR (requires `docker login ghcr.io`)
	docker push $(IMG)

# ---------------------------------------------------------------------------
# Platform (Terraform: helm + kubernetes providers)
# ---------------------------------------------------------------------------
.PHONY: platform
platform: ## terraform init + apply (installs kps, loki, tempo, argocd)
	@echo -e "$(BLUE)==> Provisioning platform with Terraform...$(NC)"
	cd $(TF_DIR) && terraform init -upgrade
	cd $(TF_DIR) && terraform apply -auto-approve -var "gh_user=$(GH_USER)"

.PHONY: plan
plan: ## terraform plan
	cd $(TF_DIR) && terraform init -upgrade && terraform plan -var "gh_user=$(GH_USER)"

# ---------------------------------------------------------------------------
# GitOps config / workloads
# ---------------------------------------------------------------------------
.PHONY: apply-config
apply-config: ## Apply demo app + dashboards + alerts locally (kustomize)
	@echo -e "$(BLUE)==> Applying demo app, dashboards and alert rules...$(NC)"
	kustomize build k8s/demo-app | kubectl apply -f -
	kustomize build --load-restrictor LoadRestrictionsNone k8s/config | kubectl apply -f -
	@echo -e "$(GREEN)==> Config applied. Argo CD will reconcile these once the repo is pushed.$(NC)"

.PHONY: dashboards
dashboards: ## (Re)apply Grafana dashboards-as-code
	kustomize build --load-restrictor LoadRestrictionsNone k8s/config | kubectl apply -f -
	@echo -e "$(GREEN)==> Dashboards reloaded (Grafana sidecar picks them up within ~30s).$(NC)"

.PHONY: set-owner
set-owner: ## Rewrite the `mjy-26` placeholder repo-wide (run: make set-owner GH_USER=<you>)
	@if [ "$(GH_USER)" = "mjy-26" ]; then echo "Pass your GitHub user: make set-owner GH_USER=<you>"; exit 1; fi
	@echo -e "$(BLUE)==> Replacing 'mjy-26' -> '$(GH_USER)' across the repo...$(NC)"
	@grep -rl --exclude-dir=.git "mjy-26" . | xargs sed -i '' "s/mjy-26/$(GH_USER)/g"
	@echo -e "$(GREEN)==> Done. Commit & push, then run 'make argocd-bootstrap'.$(NC)"

.PHONY: argocd-bootstrap
argocd-bootstrap: ## Hand reconciliation to GitOps: apply the app-of-apps root (after `git push`)
	@echo -e "$(BLUE)==> Bootstrapping Argo CD app-of-apps...$(NC)"
	kubectl apply -f k8s/argocd/root-app.yaml
	@echo -e "$(GREEN)==> Root Application applied. Argo CD now reconciles demo app + config from Git.$(NC)"

# ---------------------------------------------------------------------------
# Traffic generation
# ---------------------------------------------------------------------------
.PHONY: demo-load
demo-load: load ## Alias for `make load`

.PHONY: load
load: ## Generate traffic against the demo app so metrics/alerts fire
	@echo -e "$(BLUE)==> Generating load (Ctrl-C to stop)...$(NC)"
	./scripts/load.sh

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
.PHONY: test
test: ## Smoke test: assert all platform pods become Ready
	./scripts/smoke-test.sh

# ---------------------------------------------------------------------------
# Linting / validation
# ---------------------------------------------------------------------------
.PHONY: lint
lint: lint-tf lint-k8s ## Run all linters

.PHONY: lint-tf
lint-tf: ## terraform fmt + validate (+ tflint if installed)
	cd $(TF_DIR) && terraform fmt -check -recursive
	cd $(TF_DIR) && terraform init -backend=false && terraform validate
	@command -v tflint >/dev/null 2>&1 && (cd $(TF_DIR) && tflint) || echo "tflint not installed, skipping"

.PHONY: lint-k8s
lint-k8s: ## Validate rendered manifests with kubeconform
	@command -v kubeconform >/dev/null 2>&1 || { echo "install kubeconform: https://github.com/yannh/kubeconform"; exit 1; }
	kustomize build k8s/demo-app | kubeconform -strict -ignore-missing-schemas -summary
	kustomize build --load-restrictor LoadRestrictionsNone k8s/config | kubeconform -strict -ignore-missing-schemas -summary

# ---------------------------------------------------------------------------
# Access helpers
# ---------------------------------------------------------------------------
.PHONY: info
info: ## Print URLs and default credentials
	@echo ""
	@echo -e "$(GREEN)Access:$(NC)"
	@echo "  Grafana       http://localhost:30300   (admin / $$(make -s grafana-password))"
	@echo "  Argo CD       http://localhost:30080   (admin / $$(make -s argocd-password))"
	@echo "  Prometheus    http://localhost:30900"
	@echo "  Alertmanager  http://localhost:30093"
	@echo ""

.PHONY: grafana-password
grafana-password: ## Print the Grafana admin password
	@kubectl -n $(MONITORING_NS) get secret kube-prometheus-stack-grafana \
		-o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d; echo

.PHONY: argocd-password
argocd-password: ## Print the Argo CD admin password
	@kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' 2>/dev/null | base64 -d; echo

.PHONY: status
status: ## Show pods across all platform namespaces
	kubectl get pods -n $(MONITORING_NS)
	kubectl get pods -n $(ARGOCD_NS)
	kubectl get pods -n $(DEMO_NS)
