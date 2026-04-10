#!/bin/bash
# Deploy the full stack to a local kind cluster.
# Creates the cluster if it doesn't exist, loads the Docker image into
# kind (so it doesn't need a registry), then applies all K8s manifests.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CLUSTER_NAME="devops-cluster"
IMAGE="goldenbutter/devops-api:latest"

# ---- Create the kind cluster if it doesn't already exist ----
if ! kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "==> Creating kind cluster: ${CLUSTER_NAME}"
  cat <<EOF | kind create cluster --name "${CLUSTER_NAME}" --config -
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30300
        hostPort: 30300
        protocol: TCP
      - containerPort: 80
        hostPort: 8081
        protocol: TCP
      - containerPort: 443
        hostPort: 8443
        protocol: TCP
EOF
else
  echo "==> Kind cluster '${CLUSTER_NAME}' already exists"
fi

# ---- Load the Docker image into kind ----
# kind load avoids pulling from a remote registry.
echo "==> Loading Docker image into kind..."
kind load docker-image "${IMAGE}" --name "${CLUSTER_NAME}"

# ---- Apply base application manifests ----
echo "==> Applying base K8s manifests..."
kubectl apply -f "$PROJECT_ROOT/deploy/k8s/base/"

# ---- Apply monitoring stack ----
echo "==> Applying Prometheus manifests..."
kubectl apply -f "$PROJECT_ROOT/deploy/k8s/monitoring/prometheus/"

echo "==> Applying Grafana manifests..."
kubectl apply -f "$PROJECT_ROOT/deploy/k8s/monitoring/grafana/"

# ---- Wait for the deployment to become ready ----
echo "==> Waiting for devops-api deployment to be ready..."
kubectl rollout status deployment/devops-api --timeout=120s

echo ""
echo "==> Deployment complete!"
echo "    API:        http://localhost:8080  (or via ingress at devops-api.local)"
echo "    Prometheus: kubectl port-forward svc/prometheus 9090:9090"
echo "    Grafana:    http://localhost:30300 (admin / admin)"
