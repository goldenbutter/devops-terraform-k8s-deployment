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
deploy/helm/devops-api/ → Helm chart (alternative to raw manifests)
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

## Git Workflow
- **Never push directly to `main`.** All changes go through pull requests.
- Branch from `main` using naming convention: `feature/`, `fix/`, `docs/`, `refactor/`, `test/`
- Create a GitHub issue first, then reference it in the PR with `Closes #N`
- Assign PRs and issues to `goldenbutter` with appropriate labels (`enhancement`, `bug`, `documentation`)
- Commit messages follow: `<type>: <short description>` (types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`)
- PRs are **squash merged** to keep `main` history clean
- **Delete feature branch** after merge (both remote and local)
- Keep commit messages concise — no verbose descriptions

## CI/CD Pipeline
- **CI** (`ci.yaml`): Runs on all pushes and PRs — Go vet, test, Docker build
- **CD** (`cd.yaml`): Runs on push to `main` — builds and pushes to Docker Hub
- GitHub Secrets configured: `DOCKER_USERNAME`, `DOCKER_PASSWORD` (Docker Hub access token)
- `gh` CLI is installed and authenticated as `goldenbutter`

## Security Rules
- No hardcoded secrets — Docker Hub creds via GitHub Secrets, AWS via CLI/env
- `.env` and `terraform.tfvars` are in `.gitignore`
- `/ec2/` folder is gitignored (contains .pem keys and local-only files)
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

## EC2 Deployment
- Use `t3.medium` (2 vCPU, 4 GB) or larger — `t2.micro` is too small for full stack
- EC2 root volume must be ≥30 GB (AMI requirement)
- Full walkthrough: [docs/ec2-testing-guide.md](docs/ec2-testing-guide.md)
- Always `terraform destroy` after testing to avoid charges
- EC2-specific files (`.pem`, HTML templates) go in `/ec2/` folder (gitignored)
