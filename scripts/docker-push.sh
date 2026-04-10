#!/bin/bash
# Push both Docker image tags to Docker Hub.
# Requires a prior "docker login" or DOCKER_USERNAME / DOCKER_PASSWORD
# environment variables (used in CI/CD).
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE="goldenbutter/devops-api"
GIT_SHA=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "dev")

echo "==> Pushing ${IMAGE}:latest"
docker push "${IMAGE}:latest"

echo "==> Pushing ${IMAGE}:${GIT_SHA}"
docker push "${IMAGE}:${GIT_SHA}"

echo "==> Push complete"
