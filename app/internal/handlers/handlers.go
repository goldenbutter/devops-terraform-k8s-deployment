// Package handlers defines the HTTP endpoints for the devops-api.
// Each handler is a plain http.HandlerFunc so it works with the
// standard library mux — no framework dependencies required.
package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/goldenbutter/devops-terraform-k8s-deployment/internal/metrics"
	"github.com/goldenbutter/devops-terraform-k8s-deployment/internal/services"
)

// version is read from the APP_VERSION environment variable at startup.
// It falls back to "dev" so local runs without the configmap still work.
var version = getEnv("APP_VERSION", "dev")

// RegisterRoutes wires every endpoint to the provided mux and wraps each
// handler with Prometheus instrumentation so every request is counted and timed.
func RegisterRoutes(mux *http.ServeMux) {
	// Health check — used by Kubernetes liveness and readiness probes.
	mux.Handle("/", instrumentHandler("/", HealthHandler))

	// Returns system info (hostname, version, timestamp) as JSON.
	mux.Handle("/api/data", instrumentHandler("/api/data", DataHandler))

	// CPU-intensive prime calculation — used to trigger HPA autoscaling.
	mux.Handle("/api/calc", instrumentHandler("/api/calc", CalcHandler))

	// Prometheus metrics endpoint — scraped every 15 s by the monitoring stack.
	mux.Handle("/metrics", promhttp.Handler())
}

// instrumentHandler wraps an http.HandlerFunc with middleware that records
// request count, duration, and in-flight gauge in Prometheus.
func instrumentHandler(path string, next http.HandlerFunc) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		metrics.InFlightRequests.Inc()
		defer metrics.InFlightRequests.Dec()

		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, statusCode: http.StatusOK}
		next.ServeHTTP(rec, r)
		duration := time.Since(start).Seconds()

		metrics.RequestsTotal.WithLabelValues(path, r.Method, strconv.Itoa(rec.statusCode)).Inc()
		metrics.RequestDuration.WithLabelValues(path, r.Method).Observe(duration)
	})
}

// statusRecorder captures the HTTP status code written by downstream handlers
// so the instrumentation middleware can label the Prometheus counter accurately.
type statusRecorder struct {
	http.ResponseWriter
	statusCode int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.statusCode = code
	r.ResponseWriter.WriteHeader(code)
}

// HealthHandler responds with a simple JSON status. Kubernetes probes hit this
// endpoint to decide whether the pod is alive and ready to receive traffic.
func HealthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ok",
	})
}

// DataHandler returns runtime metadata: the current timestamp, the pod
// hostname (useful for verifying load balancing), and the app version.
func DataHandler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"timestamp": time.Now().UTC().Format(time.RFC3339),
		"hostname":  hostname,
		"version":   version,
		"message":   "DevOps Terraform K8s Deployment API",
	})
}

// CalcHandler triggers a CPU-intensive prime-number computation. The limit
// defaults to 100 000 but can be overridden via the ?limit= query parameter.
// The resulting CPU spike is what makes the HPA scale the deployment up.
func CalcHandler(w http.ResponseWriter, r *http.Request) {
	limit := 100000
	if q := r.URL.Query().Get("limit"); q != "" {
		if parsed, err := strconv.Atoi(q); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	result := services.CalculatePrimes(limit)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"primes_found":     result.Primes,
		"limit":            result.Limit,
		"computation_time": fmt.Sprintf("%v", result.Duration),
	})
}

// getEnv reads an environment variable with a fallback default,
// keeping the main code free of repetitive os.Getenv checks.
func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
