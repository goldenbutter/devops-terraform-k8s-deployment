# EC2 Testing Guide

Step-by-step walkthrough of deploying and testing the full stack on AWS EC2. This guide covers infrastructure provisioning with Terraform, deploying to a kind Kubernetes cluster on EC2, verifying all services, running load tests to trigger HPA autoscaling, and checking VPA recommendations.

## Prerequisites

- AWS CLI configured (`aws configure`) with a user that has EC2, VPC, and IAM permissions
- An EC2 key pair created in the target region (e.g., `terra-ec2-key-pair` in `us-east-1`)
- Terraform 1.5+ installed locally
- Your public IPv4 address (run `curl -4 ifconfig.me`)

## 1. Provision Infrastructure with Terraform

Create a `terraform.tfvars` file in `infra/terraform/`:

```bash
cat > infra/terraform/terraform.tfvars <<EOF
aws_region       = "us-east-1"
instance_type    = "t3.medium"
key_name         = "terra-ec2-key-pair"
allowed_ssh_cidr = "YOUR_IP/32"
EOF
```

> **Note:** Use `t3.medium` (2 vCPU, 4 GB RAM) or larger. `t2.micro` does not have enough resources to run all pods (API + Prometheus + Grafana).

Initialize and apply:

```bash
cd infra/terraform
terraform init
terraform plan    # Review: 11 resources (VPC, subnet, IGW, SG, IAM role, EC2)
terraform apply   # Type 'yes' to confirm
```

Save the outputs:

```bash
terraform output ec2_public_ip      # e.g., 100.54.121.34
terraform output ec2_instance_id    # e.g., i-0070be2a3deaec522
```

## 2. Wait for Bootstrap to Complete

The EC2 user-data script automatically installs Docker, kubectl, kind, and creates a Kubernetes cluster. Wait for it to finish:

```bash
ssh -i ~/.ssh/terra-ec2-key-pair.pem ec2-user@<EC2_PUBLIC_IP> "cloud-init status --wait"
# Expected output: status: done
```

## 3. Verify the Toolchain

```bash
ssh -i ~/.ssh/terra-ec2-key-pair.pem ec2-user@<EC2_PUBLIC_IP>

# On the EC2 instance:
docker --version        # Docker 25.x
kubectl version --client # v1.35.x
kind version            # v0.22.0
kind get clusters       # devops-cluster
kubectl get nodes       # 1 node, Ready
```

## 4. Build and Deploy the Application

```bash
# Install git and clone the repo
sudo dnf install -y git
git clone https://github.com/goldenbutter/devops-terraform-k8s-deployment.git
cd devops-terraform-k8s-deployment

# Build the Docker image
docker build -t goldenbutter/devops-api:latest -f app/Dockerfile app/

# Load the image into kind (no registry needed)
kind load docker-image goldenbutter/devops-api:latest --name devops-cluster

# Deploy base manifests (skip vpa.yaml — VPA controller not yet installed)
kubectl apply -f deploy/k8s/base/configmap.yaml
kubectl apply -f deploy/k8s/base/deployment.yaml
kubectl apply -f deploy/k8s/base/service.yaml
kubectl apply -f deploy/k8s/base/ingress.yaml
kubectl apply -f deploy/k8s/base/hpa.yaml

# Deploy monitoring stack
kubectl apply -f deploy/k8s/monitoring/prometheus/
kubectl apply -f deploy/k8s/monitoring/grafana/

# Wait for all deployments
kubectl rollout status deployment/devops-api --timeout=120s
kubectl rollout status deployment/prometheus --timeout=120s
kubectl rollout status deployment/grafana --timeout=120s
```

## 5. Verify All Services

```bash
# Check all pods are running
kubectl get pods
# Expected: 2 devops-api pods, 1 prometheus, 1 grafana — all Running

# Test API endpoints
kubectl exec deploy/devops-api -- wget -qO- http://localhost:8080/
# {"status":"ok"}

kubectl exec deploy/devops-api -- wget -qO- http://localhost:8080/api/data
# {"hostname":"devops-api-...","message":"DevOps Terraform K8s Deployment API","timestamp":"...","version":"1.0.0"}

kubectl exec deploy/devops-api -- wget -qO- http://localhost:8080/api/calc
# {"computation_time":"14.116629ms","limit":100000,"primes_found":9592}

# Check services
kubectl get svc
# devops-api   ClusterIP   ...   80/TCP
# grafana      NodePort    ...   3000:30300/TCP
# prometheus   ClusterIP   ...   9090/TCP

# Check HPA
kubectl get hpa
# devops-api   Deployment/devops-api   <unknown>/50%, <unknown>/70%   2   10   2
```

## 6. Access Grafana

Open in your browser:

```
http://<EC2_PUBLIC_IP>:30300
```

- Login: `admin` / `admin` (skip password change)
- Prometheus is auto-provisioned as the default datasource
- Navigate to **Explore** → select **Prometheus** → query `http_requests_total`

## 7. Install Metrics Server (Required for HPA)

HPA needs real CPU/memory metrics. Install metrics-server and patch it for kind:

```bash
# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch for kind (skip TLS verification for kubelet)
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# Wait for it to be ready
kubectl rollout status deployment/metrics-server -n kube-system --timeout=60s

# Verify metrics are flowing (wait ~30 seconds after rollout)
kubectl top pods
# NAME                          CPU(cores)   MEMORY(bytes)
# devops-api-...                1m           4Mi
# devops-api-...                1m           6Mi
# grafana-...                   4m           97Mi
# prometheus-...                1m           22Mi

# HPA should now show real percentages
kubectl get hpa
# devops-api   Deployment/devops-api   2%/50%, 8%/70%   2   10   2
```

## 8. Load Test — Trigger HPA Autoscaling

Run a CPU-intensive load test against `/api/calc`:

```bash
# Generate heavy load (50 concurrent requests x 20 rounds)
for i in $(seq 1 20); do
  for j in $(seq 1 50); do
    kubectl exec deploy/devops-api -- wget -qO- http://localhost:8080/api/calc > /dev/null 2>&1 &
  done
  wait
done
```

Watch HPA scale up in real-time:

```bash
# In a separate terminal
kubectl get hpa -w
# NAME         REFERENCE               TARGETS            MINPODS   MAXPODS   REPLICAS
# devops-api   Deployment/devops-api   120%/50%, 7%/70%   2         10        5

kubectl get pods
# You should see 3-5+ devops-api pods (scaled up from 2)

kubectl top pods
# One or more pods will show high CPU (e.g., 120m)
```

**Expected behavior:**
- CPU spikes above 50% threshold
- HPA increases replicas (2 → 3 → 5)
- Load gets distributed, CPU per pod drops toward 50%
- After load stops, HPA waits 300s (stabilization window) then scales back down to 2

## 9. VPA Recommendations

Install the Vertical Pod Autoscaler controller:

```bash
git clone https://github.com/kubernetes/autoscaler.git /tmp/autoscaler
cd /tmp/autoscaler/vertical-pod-autoscaler
bash hack/vpa-up.sh
```

Apply the VPA manifest and check recommendations:

```bash
cd ~/devops-terraform-k8s-deployment
kubectl apply -f deploy/k8s/base/vpa.yaml

# Wait ~60 seconds for recommendations
kubectl describe vpa devops-api
```

**Expected output:**

```
Recommendation:
  Container Recommendations:
    Container Name:  devops-api
    Lower Bound:
      Cpu:     25m
      Memory:  250Mi
    Target:
      Cpu:     25m
      Memory:  250Mi
    Upper Bound:
      Cpu:     1
      Memory:  512Mi
```

> Our VPA runs in `Off` mode — it recommends resource adjustments but does not auto-apply them. This is the safe default for production. The recommendation above suggests the container needs 25m CPU (we set 50m — slightly over-provisioned) and 250Mi memory (we set 64Mi — under-provisioned for the recommendation).

## 10. Grafana — View Load Test Metrics

After the load test, check the request rate spike in Grafana:

1. Open `http://<EC2_PUBLIC_IP>:30300/explore`
2. Select **Prometheus** datasource
3. Switch to **Code** mode
4. Enter: `rate(http_requests_total[1m])`
5. Set time range to **Last 30 minutes**
6. Click **Run query**

You should see a clear spike during the load test period, then a drop back to baseline.

## 11. Clean Up — Destroy Infrastructure

**Important:** Destroy all resources when done to avoid AWS charges.

```bash
# From your local machine (not EC2)
cd infra/terraform
terraform destroy   # Type 'yes' to confirm
```

This removes all 11 resources: EC2 instance, VPC, subnet, security group, IGW, route table, IAM role, and instance profile.

## Cost Estimate

| Resource | Cost |
|----------|------|
| EC2 t3.medium | ~$0.0416/hour |
| EBS 30 GB gp3 | ~$0.08/month |
| Data transfer | Minimal |

For a 1-hour testing session: **~$0.05 total**.

> `t2.micro` is free-tier eligible but too small for this stack. Use `t3.medium` for testing, then `terraform destroy` immediately after.
