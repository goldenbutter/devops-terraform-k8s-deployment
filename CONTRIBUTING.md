# Contributing

Thanks for your interest in contributing to this project! This document outlines the workflow and rules to keep the codebase clean, stable, and professional.

## Ground Rules

- **Never push directly to `main`.** All changes go through pull requests.
- **One feature per branch, one branch per PR.** Keep changes focused.
- **Every PR must be linked to an issue.** No drive-by changes without context.
- **Write meaningful commit messages.** Explain *why*, not just *what*.
- **Test your changes locally** before opening a PR.

## Getting Started

1. **Fork** the repository
2. **Clone** your fork locally
3. Set the upstream remote:
   ```bash
   git remote add upstream https://github.com/goldenbutter/devops-terraform-k8s-deployment.git
   ```

## Workflow

### 1. Create an Issue First

Before writing any code, open a GitHub issue describing:
- **What** you want to change or add
- **Why** (motivation, bug report, or feature request)
- **How** you plan to implement it (optional but helpful)

Use the appropriate label: `bug`, `enhancement`, `documentation`, `question`.

### 2. Create a Feature Branch

Always branch from the latest `main`:

```bash
git checkout main
git pull upstream main
git checkout -b feature/your-feature-name
```

Branch naming convention:

| Prefix | Use |
|--------|-----|
| `feature/` | New features or enhancements |
| `fix/` | Bug fixes |
| `docs/` | Documentation changes |
| `refactor/` | Code restructuring without behavior changes |
| `test/` | Adding or updating tests |

Examples: `feature/add-redis-cache`, `fix/hpa-memory-threshold`, `docs/update-terraform-guide`

### 3. Make Your Changes

- Follow the existing code style and conventions
- Keep commits atomic — each commit should represent one logical change
- Run the application locally to verify your changes work:
  ```bash
  bash scripts/docker-build.sh
  bash scripts/deploy-kind.sh
  kubectl get pods   # All pods should be Running
  ```

### 4. Commit Messages

Use this format:

```
<type>: <short description>

<optional longer explanation>

Closes #<issue-number>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

Examples:
```
feat: add Redis caching for /api/data endpoint

Reduces response time from ~50ms to ~2ms for repeated queries.
Cache TTL is configurable via APP_CACHE_TTL environment variable.

Closes #42
```

```
fix: correct HPA memory threshold calculation

The memory target was set to 70% of limits instead of requests,
causing premature scaling. Updated to use requests as the baseline.

Closes #15
```

### 5. Open a Pull Request

Push your branch and open a PR against `main`:

```bash
git push origin feature/your-feature-name
```

In the PR description, include:
- **Summary** — What does this PR do? (1-3 bullet points)
- **Related Issue** — `Closes #<number>`
- **Test Plan** — How did you verify the changes work?
- **Screenshots** — If applicable (UI changes, new API responses, etc.)

### 6. Code Review

- At least one approval is required before merging
- Address all review comments before requesting re-review
- Keep the PR up to date with `main`:
  ```bash
  git fetch upstream
  git rebase upstream/main
  git push --force-with-lease
  ```

### 7. Merge

PRs are merged via **Squash and Merge** to keep `main` history clean. The maintainer will handle the merge after approval.

## Branch Protection Rules

The `main` branch has the following protections:

- Require pull request before merging
- Require at least 1 approval
- Require status checks to pass (CI pipeline)
- No direct pushes allowed
- No force pushes allowed

## What to Contribute

Here are some areas where contributions are welcome:

- **New API endpoints** — Add useful endpoints to the Go backend
- **Dashboard templates** — Pre-built Grafana dashboards for the existing metrics
- **Helm chart** — Package the K8s manifests as a Helm chart
- **Multi-node kind** — Add support for multi-node local clusters
- **Test coverage** — Add unit and integration tests for the Go handlers
- **Documentation** — Improve guides, fix typos, add diagrams

## What NOT to Submit

- Changes that break the existing CI pipeline
- Large refactors without prior discussion (open an issue first)
- Dependencies with restrictive licenses
- Hardcoded secrets, credentials, or API keys
- Auto-generated files or IDE-specific configurations

## Local Development Setup

```bash
# Prerequisites: Go 1.22+, Docker, kind, kubectl

# 1. Build and deploy locally
bash scripts/docker-build.sh
bash scripts/deploy-kind.sh

# 2. Verify
kubectl get pods                    # All pods Running
curl http://localhost:8080/         # {"status":"ok"}
curl http://localhost:8080/api/data # System info
curl http://localhost:8080/api/calc # Prime calculation

# 3. Access monitoring
# Grafana: http://localhost:30300 (admin/admin)

# 4. Run load test
bash scripts/load-test.sh
kubectl get hpa devops-api -w       # Watch autoscaling
```

## Code of Conduct

Be respectful, constructive, and professional. We're all here to learn and build something useful.

---

Questions? Open a [discussion](https://github.com/goldenbutter/devops-terraform-k8s-deployment/discussions) or reach out via an issue.
