# Monitoring Dashboards Guide

How to access Grafana, import dashboards, and interpret the key metrics from the devops-api.

## Accessing Grafana

### Local (kind cluster)

Grafana is exposed as a NodePort service on port 30300:

```bash
# Direct access if port mapping is configured
open http://localhost:30300

# Alternative: use port-forward
kubectl port-forward svc/grafana 3000:3000
open http://localhost:3000
```

### AWS (EC2 instance)

```bash
# Get the EC2 public IP from Terraform output
cd infra/terraform
EC2_IP=$(terraform output -raw ec2_public_ip)
open "http://${EC2_IP}:30300"
```

### Login Credentials

- **Username:** admin
- **Password:** admin
- You will be prompted to change the password on first login.

## Prometheus Datasource

Prometheus is auto-provisioned as the default datasource via the `grafana-datasource` ConfigMap. No manual configuration needed.

To verify:

1. Go to **Configuration → Data Sources**
2. "Prometheus" should be listed with a green checkmark
3. URL: `http://prometheus.default.svc.cluster.local:9090`

## Accessing Prometheus Directly

```bash
# Port-forward to access the Prometheus UI
kubectl port-forward svc/prometheus 9090:9090
open http://localhost:9090
```

Useful Prometheus queries to try in the web UI:

```promql
# Total requests per endpoint
sum by (path) (rate(http_requests_total[5m]))

# Average request duration
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Currently in-flight requests
http_in_flight_requests

# Go memory usage
go_memstats_alloc_bytes
```

## Importing Dashboards

### Option 1: Community Dashboard (Recommended)

1. Go to **Dashboards → Import**
2. Enter dashboard ID and click **Load**:
   - `1860` — Node Exporter Full (if node-exporter is installed)
   - `6671` — Go Processes
3. Select "Prometheus" as the data source
4. Click **Import**

### Option 2: Custom Dashboard

1. Go to **Dashboards → New Dashboard → Add Visualization**
2. Select "Prometheus" as the data source
3. Add panels for the devops-api metrics (see below)

## Key Metrics to Monitor

### Request Rate

Shows how many requests per second each endpoint is handling.

```promql
sum by (path) (rate(http_requests_total[5m]))
```

**Panel type:** Time series
**What to watch:** Spikes on `/api/calc` during load tests.

### Error Rate

Percentage of non-200 responses — should stay near zero.

```promql
sum(rate(http_requests_total{status!="200"}[5m])) / sum(rate(http_requests_total[5m])) * 100
```

**Panel type:** Stat or Gauge
**Alert threshold:** > 1% warrants investigation.

### Request Duration (p95)

95th percentile response time — shows worst-case user experience.

```promql
histogram_quantile(0.95, sum by (le, path) (rate(http_request_duration_seconds_bucket[5m])))
```

**Panel type:** Time series
**What to watch:** `/api/calc` will be slow by design; `/` and `/api/data` should stay under 10 ms.

### In-Flight Requests

How many requests are being processed right now.

```promql
http_in_flight_requests
```

**Panel type:** Gauge
**What to watch:** Sustained high values mean the server is saturated.

### Go Runtime

```promql
# Memory allocated by Go
go_memstats_alloc_bytes

# Number of goroutines
go_goroutines

# GC pause duration
go_gc_duration_seconds
```

## Recommended Dashboard Layout

| Row | Panel 1 | Panel 2 | Panel 3 |
|-----|---------|---------|---------|
| 1   | Request Rate (time series) | Error Rate (stat) | In-Flight (gauge) |
| 2   | Duration p50/p95 (time series) | Total Requests (stat) | Pods Running (stat) |
| 3   | Go Memory (time series) | Goroutines (time series) | GC Pause (time series) |
