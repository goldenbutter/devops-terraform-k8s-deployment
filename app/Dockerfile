# ============================================================
# Stage 1: Build the Go binary inside a full Go toolchain image.
# Using a multi-stage build keeps the final image small (~15 MB)
# because only the compiled binary is copied forward.
# ============================================================
FROM golang:1.22-alpine AS builder

# Install git and CA certificates — needed for fetching Go modules
# and for HTTPS calls at runtime.
RUN apk add --no-cache git ca-certificates

WORKDIR /src

# Copy dependency manifests first so Docker can cache the module
# download layer separately from source code changes.
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source and compile a static binary.
# CGO_ENABLED=0 ensures the binary has no C library dependencies.
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /devops-api ./cmd/server

# ============================================================
# Stage 2: Minimal runtime image with only the binary and certs.
# ============================================================
FROM alpine:3.19

# Install CA certificates so the binary can make outbound HTTPS
# requests (e.g. for future webhook integrations).
RUN apk add --no-cache ca-certificates

# Run as a non-root user for security — limits the blast radius
# if the container is ever compromised.
RUN adduser -D -u 1001 appuser
USER appuser

COPY --from=builder /devops-api /usr/local/bin/devops-api

EXPOSE 8080

ENTRYPOINT ["devops-api"]
