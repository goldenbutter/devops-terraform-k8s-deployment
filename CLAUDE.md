# DevOps Terraform K8s Deployment — Project Instructions

## Project Overview
A portfolio-grade DevOps project: Go backend API deployed to a kind Kubernetes cluster on AWS EC2 (free-tier), provisioned by Terraform, with HPA/VPA autoscaling and Prometheus + Grafana monitoring.

- **GitHub user:** goldenbutter
- **Docker Hub user:** goldenbutter
- **Developer credit:** Bithun (portfolio: https://portfolio.ibithun.com/)

## Tech Stack
- **App:** Go 1.22, Prometheus client_golang
- **Container:** Multi-stage Docker build (golang:1.22-alpine → alpine:3.19)
- **Orchestration:** Kubernetes (kind for local, deployable to any cluster)
- **IaC:** Terraform 1.5+ with modular structure (networking, iam, ec2)
- **Monitoring:** Prometheus + Grafana (auto-provisioned datasource)
- **CI/CD:** GitHub Actions (ci.yaml for test/build, cd.yaml for Docker Hub push)

## Project Structure
```
app/                    → Go backend (cmd/server, internal/handlers, metrics, services)
deploy/k8s/base/        → Core K8s manifests (deployment, service, ingress, hpa, vpa, configmap)
deploy/k8s/monitoring/  → Prometheus + Grafana deployments
deploy/k8s/kustomize/   → Dev and prod overlays
infra/terraform/        → AWS infrastructure (modular: networking, iam, ec2)
scripts/                → Build, deploy, and load-test shell scripts
.github/workflows/      → CI/CD pipelines
docs/                   → Architecture, scaling, monitoring, and Terraform guides
assets/images/          → Screenshots for README
```

## Key Conventions
- **Labels:** All K8s resources use `app: devops-api`
- **Image:** `goldenbutter/devops-api:latest` with `imagePullPolicy: IfNotPresent` for kind
- **Ports:** API on 8080, Prometheus on 9090, Grafana on 3000 (NodePort 30300)
- **Kind cluster name:** `devops-cluster`
- **Local port mappings:** 8081→80, 8443→443, 30300→30300 (avoids conflicts)

## Security Rules
- No hardcoded secrets — Docker Hub creds via GitHub Secrets, AWS via CLI/env
- `.env` and `terraform.tfvars` are in `.gitignore`
- Grafana default admin/admin is acceptable for local dev only

## Attribution
- Never mention AI tools in code, comments, or commits
- Footer: `© Bithun` with link to portfolio
- All commit credit to Bithun

## Running Locally
```bash
bash scripts/docker-build.sh       # Build Docker image
bash scripts/deploy-kind.sh        # Create kind cluster + deploy everything
kubectl port-forward svc/devops-api 8080:80   # Access API
# Grafana: http://localhost:30300 (admin/admin)
```

## Load Testing
```bash
bash scripts/load-test.sh          # 50 concurrent workers, 60s
kubectl get hpa devops-api -w      # Watch autoscaling
```
