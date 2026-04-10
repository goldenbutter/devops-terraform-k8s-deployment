# Scaling Tests Guide

How to test Horizontal Pod Autoscaler (HPA) and Vertical Pod Autoscaler (VPA) behaviour.

## Prerequisites

- Running kind cluster with the devops-api deployment applied
- Metrics server installed (required for HPA to read CPU/memory data)

### Install Metrics Server on kind

kind does not include metrics-server by default. Install it with:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch for kind (self-signed certificates)
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Verify it's running
kubectl get pods -n kube-system | grep metrics-server
```

## Test 1: HPA Scale-Up Under Load

### Step 1 — Confirm baseline

```bash
# Should show 2/2 replicas, low CPU
kubectl get hpa devops-api
kubectl top pods -l app=devops-api
```

### Step 2 — Run the load test

```bash
# Open a second terminal to watch HPA in real-time
kubectl get hpa devops-api -w

# In the first terminal, start the load test
bash scripts/load-test.sh http://localhost:8080 50 60
```

### Step 3 — Observe scaling

Within 30–60 seconds you should see:

```
NAME         REFERENCE              TARGETS          MINPODS   MAXPODS   REPLICAS
devops-api   Deployment/devops-api  82%/50%, 45%/70%   2         10        2
devops-api   Deployment/devops-api  82%/50%, 45%/70%   2         10        6
devops-api   Deployment/devops-api  55%/50%, 45%/70%   2         10        8
```

### Step 4 — Verify scale-down

After the load test ends, wait 5 minutes (the `stabilizationWindowSeconds`):

```bash
# Pods should gradually return to 2
kubectl get hpa devops-api -w
kubectl get pods -l app=devops-api
```

### Expected Results

| Phase       | Replicas | CPU Utilisation |
|-------------|----------|-----------------|
| Baseline    | 2        | < 10%           |
| Under load  | 4–10     | 50–90%          |
| Cool-down   | 2        | < 10%           |

## Test 2: HPA with Custom Concurrency

Adjust the load test parameters to see different scaling curves:

```bash
# Light load — may not trigger scale-up
bash scripts/load-test.sh http://localhost:8080 10 30

# Heavy load — should hit max replicas quickly
bash scripts/load-test.sh http://localhost:8080 100 90
```

## Test 3: VPA Recommendations

The VPA is in "Off" mode — it only produces recommendations.

```bash
# View current recommendations
kubectl describe vpa devops-api

# Look for the "Recommendation" section:
#   Target:
#     Cpu:     100m
#     Memory:  80Mi
#   Lower Bound:
#     Cpu:     50m
#     Memory:  64Mi
#   Upper Bound:
#     Cpu:     200m
#     Memory:  128Mi
```

Use these recommendations to adjust the deployment's resource requests/limits for better resource efficiency.

## Test 4: Manual Scaling (Comparison)

```bash
# Scale manually to compare behaviour
kubectl scale deployment devops-api --replicas=5
kubectl get pods -l app=devops-api

# Reset back — HPA will resume control
kubectl scale deployment devops-api --replicas=2
```

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| HPA shows `<unknown>` targets | Metrics server not installed | Install metrics-server (see above) |
| Pods not scaling up | CPU below threshold | Increase concurrency in load test |
| Pods stuck at max replicas | Load still running | Stop load test and wait 5 minutes |
| VPA shows no recommendations | Not enough data collected | Wait 5–10 minutes after deployment |
