KIND_CLUSTER_NAME=jr-mlops-inference-cluster
AWS_REGION=us-east-1

.PHONY: kind-up eks-up bootstrap argocd-install argocd-port platform-install apps-install

### =========================
### KIND
### =========================

kind-up:
	kind create cluster \
		--name $(KIND_CLUSTER_NAME) \
		--config environments/kind/kind-config.yaml
	$(MAKE) bootstrap

kind-down:
	kind delete cluster --name $(KIND_CLUSTER_NAME)

### =========================
### EKS
### =========================

eks-up:
	cd environments/eks/terraform && terraform init && terraform apply -auto-approve
	$(MAKE) bootstrap

### =========================
### BOOTSTRAP
### =========================

bootstrap: argocd-install platform-install apps-install

### =========================
### ARGO CD
### =========================

argocd-install:
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd \
		-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

argocd-port:
	kubectl port-forward svc/argocd-server -n argocd 8080:443

### =========================
### PLATFORM
### =========================

platform-install:
	kubectl apply -f k8s/platform/namespaces.yaml

### =========================
### APPS (GitOps Entry Point)
### =========================

apps-install:
	kubectl apply -f k8s/platform/argocd/application.yaml
