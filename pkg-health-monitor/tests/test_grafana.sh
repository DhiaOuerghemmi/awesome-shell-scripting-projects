#!/usr/bin/env bash
#
# tests/test_grafana.sh — validate Grafana provisioning files
set -euo pipefail
IFS=$'\n\t'

JSON_FILE="grafana/dashboards/package-health.json"

# 1) JSON validity
if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  PY=""
fi

if [[ -n "$PY" ]]; then
  if ! $PY - <<PYCODE
import json, sys
try:
    json.load(open("$JSON_FILE"))
except Exception:
    sys.exit(1)
else:
    sys.exit(0)
PYCODE
  then
    echo "❌ $JSON_FILE is not valid JSON"
    exit 1
  fi
else
  # Fallback sanity check: must start with '{'
  first=$(head -c1 "$JSON_FILE")
  if [[ "$first" != '{' ]]; then
    echo "❌ $JSON_FILE does not appear to be JSON (missing '{' at start)"
    exit 1
  fi
  echo "⚠️  Skipped full JSON validation (no Python); basic check passed"
fi

# 2) Check for expected panel title and metric
grep -q '"title": "Package Cache Size"' "$JSON_FILE" || {
  echo "❌ Dashboard missing 'Package Cache Size' panel"
  exit 1
}
grep -q '"expr": "pkg_cache_size_bytes"' "$JSON_FILE" || {
  echo "❌ Metric expr 'pkg_cache_size_bytes' not found"
  exit 1
}

# 3) Validate provisioning YAML files have apiVersion
for file in grafana/provisioning/dashboards.yml grafana/provisioning/datasources.yml; do
  grep -q "apiVersion: 1" "$file" || {
    echo "❌ $file missing apiVersion"
    exit 1
  }
done

echo "✅ Grafana provisioning files look valid."
