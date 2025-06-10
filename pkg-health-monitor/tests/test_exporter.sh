#!/usr/bin/env bash
#
# tests/test_exporter.sh — verify /metrics endpoint
set -euo pipefail
IFS=$'\n\t'

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exporter="${SCRIPT_ROOT}/exporter/exporter.sh"
TEST_PORT=9999

# Ensure the exporter is executable
chmod +x "${exporter}"

# Start exporter in background
EXPORTER_PORT="${TEST_PORT}" "${exporter}" >/dev/null 2>&1 &
pid=$!
trap "kill ${pid}" EXIT

# Give it a moment to bind
sleep 1

# Fetch metrics
METRICS=$(curl -s "http://127.0.0.1:${TEST_PORT}/metrics")

# Basic validation: check for both metric names
if ! grep -q '^pkg_cache_size_bytes' <<<"${METRICS}"; then
    echo "❌ Missing pkg_cache_size_bytes in metrics"
    exit 1
fi
if ! grep -q '^pkg_cleanup_total' <<<"${METRICS}"; then
    echo "❌ Missing pkg_cleanup_total in metrics"
    exit 1
fi

echo "✅ Exporter metrics endpoint is serving correctly."
