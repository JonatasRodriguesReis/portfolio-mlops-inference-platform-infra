KIND_CLUSTER_NAME=mlops-kind

.PHONY: kind-up bootstrap argocd-install image-updater-install

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

bootstrap: argocd-install image-updater-install platform-install apps-install

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
