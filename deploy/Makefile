# Makefile for the devops-terraform-k8s-deployment project.
# Each target delegates to a shell script in scripts/ so the logic
# lives in one place and works both locally and in CI.

SCRIPTS_DIR := ../scripts

.PHONY: build docker-build docker-push deploy-kind deploy-monitoring load-test clean

## build: Compile the Go binary
build:
	@bash $(SCRIPTS_DIR)/build.sh

## docker-build: Build the Docker image with :latest and :sha tags
docker-build:
	@bash $(SCRIPTS_DIR)/docker-build.sh

## docker-push: Push Docker image tags to Docker Hub
docker-push:
	@bash $(SCRIPTS_DIR)/docker-push.sh

## deploy-kind: Create kind cluster and apply all K8s manifests
deploy-kind:
	@bash $(SCRIPTS_DIR)/deploy-kind.sh

## deploy-monitoring: Apply only the monitoring stack (Prometheus + Grafana)
deploy-monitoring:
	@kubectl apply -f k8s/monitoring/prometheus/
	@kubectl apply -f k8s/monitoring/grafana/
	@echo "Monitoring stack deployed"

## load-test: Run a 60-second load test against /api/calc
load-test:
	@bash $(SCRIPTS_DIR)/load-test.sh

## clean: Delete the kind cluster and remove build artifacts
clean:
	@echo "==> Deleting kind cluster..."
	@kind delete cluster --name devops-cluster 2>/dev/null || true
	@echo "==> Removing build artifacts..."
	@rm -f ../app/devops-api
	@echo "==> Clean complete"
