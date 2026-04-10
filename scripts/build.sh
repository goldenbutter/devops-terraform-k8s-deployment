#!/bin/bash
# Build the Go binary from the app/ directory.
# Produces a statically-linked Linux binary at app/devops-api,
# suitable for copying into a scratch or Alpine container.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Building Go binary..."
cd "$PROJECT_ROOT/app"

# CGO_ENABLED=0 removes the C library dependency so the binary
# runs on minimal images like alpine or distroless.
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -ldflags="-s -w" -o "$PROJECT_ROOT/app/devops-api" ./cmd/server

echo "==> Build complete: app/devops-api"
