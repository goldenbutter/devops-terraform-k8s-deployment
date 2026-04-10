#!/bin/bash
# Simple load test using curl — no external tools required.
# Sends concurrent requests to /api/calc for 60 seconds to generate
# enough CPU load for the HPA to trigger a scale-up event.
#
# Usage: ./scripts/load-test.sh [base_url] [concurrency] [duration_seconds]
set -e

BASE_URL="${1:-http://localhost:8080}"
CONCURRENCY="${2:-50}"
DURATION="${3:-60}"
ENDPOINT="${BASE_URL}/api/calc"

echo "============================================"
echo "  Load Test — devops-api"
echo "============================================"
echo "  Target:      ${ENDPOINT}"
echo "  Concurrency: ${CONCURRENCY} workers"
echo "  Duration:    ${DURATION} seconds"
echo "============================================"
echo ""

# Counters for the summary report.
TOTAL=0
SUCCESS=0
FAIL=0
START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))

# worker sends requests in a tight loop until the time limit expires.
worker() {
  local ok=0
  local err=0
  while [ "$(date +%s)" -lt "$END_TIME" ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 "${ENDPOINT}" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
      ok=$((ok + 1))
    else
      err=$((err + 1))
    fi
  done
  echo "${ok} ${err}"
}

echo "Starting ${CONCURRENCY} workers..."

# Launch all workers in the background and collect PIDs.
PIDS=()
TMPDIR_RESULTS=$(mktemp -d)
for i in $(seq 1 "$CONCURRENCY"); do
  worker > "${TMPDIR_RESULTS}/worker_${i}.txt" &
  PIDS+=($!)
done

# Wait for every worker to finish.
for pid in "${PIDS[@]}"; do
  wait "$pid" 2>/dev/null || true
done

# Aggregate results from all workers.
for i in $(seq 1 "$CONCURRENCY"); do
  read -r ok err < "${TMPDIR_RESULTS}/worker_${i}.txt"
  SUCCESS=$((SUCCESS + ok))
  FAIL=$((FAIL + err))
done
rm -rf "$TMPDIR_RESULTS"

TOTAL=$((SUCCESS + FAIL))
ACTUAL_DURATION=$(( $(date +%s) - START_TIME ))
RPS=$( [ "$ACTUAL_DURATION" -gt 0 ] && echo $((TOTAL / ACTUAL_DURATION)) || echo 0 )

echo ""
echo "============================================"
echo "  Results"
echo "============================================"
echo "  Duration:   ${ACTUAL_DURATION}s"
echo "  Total:      ${TOTAL} requests"
echo "  Success:    ${SUCCESS} (HTTP 200)"
echo "  Failed:     ${FAIL}"
echo "  Throughput: ~${RPS} req/s"
echo "============================================"
echo ""
echo "Check HPA status: kubectl get hpa devops-api -w"
