ENV ?= dev
TF_DIR := terraform/envs/$(ENV)

.PHONY: help bootstrap init plan apply destroy test lint monitoring dashboard

help: ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'

bootstrap: ## Create the versioned GCS state bucket (BUCKET=..., PROJECT=...)
	gcloud storage buckets create gs://$(BUCKET) --project=$(PROJECT) --location=asia-south1 --uniform-bucket-level-access
	gcloud storage buckets update gs://$(BUCKET) --versioning

init: ## terraform init with remote state (BUCKET=...)
	terraform -chdir=$(TF_DIR) init -backend-config="bucket=$(BUCKET)"

plan: ## terraform plan
	terraform -chdir=$(TF_DIR) plan -out=tfplan

apply: ## terraform apply the saved plan
	terraform -chdir=$(TF_DIR) apply tfplan

destroy: ## tear everything down (stop paying)
	terraform -chdir=$(TF_DIR) destroy

test: ## Go tests
	cd app && go vet ./... && go test -race ./...

lint: ## fmt/validate/lint everything locally
	terraform fmt -check -recursive terraform
	terraform -chdir=$(TF_DIR) init -backend=false -input=false >/dev/null && terraform -chdir=$(TF_DIR) validate
	helm lint helm/demo-app
	cd app && test -z "$$(gofmt -l .)"

monitoring: ## Install kube-prometheus-stack
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
	  -n monitoring --create-namespace -f monitoring/kube-prometheus-stack-values.yaml

dashboard: ## Load the Grafana dashboard
	kubectl -n monitoring create configmap demo-app-dashboard \
	  --from-file=monitoring/dashboards/demo-app.json --dry-run=client -o yaml \
	  | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -
