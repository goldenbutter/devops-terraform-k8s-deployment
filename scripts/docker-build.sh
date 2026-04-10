#!/bin/bash
# Build the Docker image with two tags:
#   1. goldenbutter/devops-api:latest       — rolling tag for dev convenience
#   2. goldenbutter/devops-api:<short-sha>  — immutable tag tied to the commit
# The git-based tag ensures every push to the registry is traceable.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE="goldenbutter/devops-api"
GIT_SHA=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "dev")

echo "==> Building Docker image: ${IMAGE}:latest and ${IMAGE}:${GIT_SHA}"
docker build \
  -t "${IMAGE}:latest" \
  -t "${IMAGE}:${GIT_SHA}" \
  "$PROJECT_ROOT/app"

echo "==> Docker build complete"
docker images "${IMAGE}"
