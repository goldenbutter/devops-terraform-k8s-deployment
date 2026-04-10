// Package metrics registers and exposes Prometheus metrics for the devops-api.
// It tracks HTTP request counts, durations, and in-flight requests, plus
// standard Go runtime metrics via the default Prometheus collector.
package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// RequestsTotal counts every HTTP request, labelled by path, method, and
	// response status code. Use this to track traffic volume and error rates.
	RequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests processed, partitioned by path, method, and status code.",
		},
		[]string{"path", "method", "status"},
	)

	// RequestDuration records how long each request takes in seconds.
	// The histogram buckets are tuned for a typical API: most responses
	// finish in under 500 ms, but the /api/calc endpoint can take seconds.
	RequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Histogram of HTTP request latencies in seconds.",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"path", "method"},
	)

	// InFlightRequests tracks how many requests are currently being handled.
	// A sustained high value signals the server is under heavy load.
	InFlightRequests = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "http_in_flight_requests",
			Help: "Number of HTTP requests currently being served.",
		},
	)
)
