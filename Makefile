CLUSTER_NAME=jr-mlops-inference-cluster

.PHONY: kind-up bootstrap argocd-install prometheus-install loki-install keda-install load-test load-test-stop grafana grafana-password prometheus kind-down

### =========================
### KIND
### =========================

kind-up:
	kind create cluster \
		--name $(CLUSTER_NAME) \
		--config environments/kind/kind-config.yaml
	$(MAKE) bootstrap

kind-down:
	@echo "🧹 Deleting KIND cluster..."
	kind delete cluster --name $(CLUSTER_NAME) || true

### =========================
### BOOTSTRAP (Platform)
### =========================

bootstrap: \
	argocd-install \
	prometheus-install \
	loki-install \
	keda-install



### =========================
### ARGO CD
### =========================

argocd-install:
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd \
		-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl apply -f k8s/platform/argocd/application.yaml

### =========================
### MONITORING (Prometheus + Grafana)
### =========================

prometheus-install:
	@echo "➡️ Installing kube-prometheus-stack..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
	helm repo update

	helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
		-n observability \
		-f k8s/platform/observability/prometheus/values.yaml \
		--create-namespace

	@echo " Applying Grafana dashboards..."
	kubectl apply -f k8s/platform/observability/grafana/dashboard-configmap.yaml

### =========================
### LOGGING (Loki + Promtail)
### =========================

loki-install:
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update

	helm install loki grafana/loki-stack \
	-n observability \
	-f k8s/platform/observability/loki/values.yaml

### =========================
### AUTOSCALING
### =========================

keda-install:
	@echo "➡️ Installing KEDA..."
	helm repo add kedacore https://kedacore.github.io/charts >/dev/null 2>&1 || true
	helm repo update
	helm upgrade --install keda kedacore/keda \
		--namespace keda --create-namespace

### =========================
### LOAD TEST
### =========================

load-test:
	@echo "🔥 Starting load test..."
	kubectl -n mlops-inference-app delete job locust-load-test --ignore-not-found
	kubectl apply -f k8s/loadtest/

load-test-stop:
	@echo "🛑 Stopping load test..."
	kubectl -n mlops-inference-app delete job locust-load-test --ignore-not-found

### =========================
### Port forwarding grafana
### ========================
grafana:
	echo "📊 Port-forward Grafana → http://localhost:3000"
	kubectl -n observability port-forward svc/kube-prometheus-grafana 3000:80

grafana-password:
	@echo "🔐 Grafana admin password:"
	kubectl -n observability get secret kube-prometheus-grafana \
		-o jsonpath="{.data.admin-password}" | base64 --decode

### =========================
### Port forwarding prometheus
### =========================
prometheus:
	@echo "📈 Port-forward Prometheus → http://localhost:9090"
	kubectl -n observability port-forward svc/monitoring-kube-prometheus-prometheus 9090


