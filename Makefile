KIND_CLUSTER_NAME=mlops-kind

.PHONY: kind-up bootstrap argocd-install image-updater-install prometheus-install loki-install keda-install load-test load-test-stop

### =========================
### KIND
### =========================

kind-up:
	kind create cluster \
		--name $(KIND_CLUSTER_NAME) \
		--config environments/kind/kind-config.yaml
	$(MAKE) bootstrap

### =========================
### BOOTSTRAP
### =========================

bootstrap: argocd-install image-updater-install prometheus-install loki-install keda-install

### =========================
### ARGO CD
### =========================

argocd-install:
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd \
		-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

### =========================
### IMAGE UPDATER
### =========================

image-updater-install:
	kubectl apply -n argocd \
		-f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml

	@if [ -z "$$GITHUB_TOKEN" ]; then \
		echo "⚠️ GITHUB_TOKEN not set. Skipping git credentials secret."; \
	else \
		kubectl create secret generic github-token \
		  -n argocd \
		  --from-literal=token=$$GITHUB_TOKEN \
		  --dry-run=client -o yaml | kubectl apply -f - ; \
	fi

### =========================
### Prometheus Platform
### =========================

prometheus-install:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

	helm install monitoring prometheus-community/kube-prometheus-stack \
  	-n monitoring \
  	-f k8s/platform/monitoring/values-prometheus.yaml \
  	--create-namespace

loki-install:
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update

	helm install loki grafana/loki-stack \
	-n observability \
	-f k8s/platform/observability/loki/values.yaml

keda-install:
	@echo "➡️ Installing KEDA..."
	helm repo add kedacore https://kedacore.github.io/charts >/dev/null 2>&1 || true
	helm repo update
	helm upgrade --install keda kedacore/keda \
		--namespace keda --create-namespace

load-test:
	kubectl -n mlops-inference-app delete job locust-load-test --ignore-not-found
	kubectl apply -f k8s/loadtest/

load-test-stop:
	kubectl -n mlops-inference-app delete job locust-load-test




