#!/usr/bin/env bash
#
# Basic test: ensure `monitor --dry-run` reads config and prints variables

set -euo pipefail
IFS=$'\n\t'

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MONITOR="${SCRIPT_ROOT}/bin/monitor"
CONF_OVERRIDE="${SCRIPT_ROOT}/configs/monitor.conf"

# Run dry-run
OUTPUT="$("${MONITOR}" --config "${CONF_OVERRIDE}" --dry-run)"

# Check for expected variable names
for var in CHECK_INTERVAL EMAIL_RECIPIENT SLACK_WEBHOOK_URL PACKAGES_TO_CHECK; do
    echo "$OUTPUT" | grep -q "${var}=" ||
        {
            echo "❌ Expected ${var} in output"
            exit 1
        }
done

echo "✅ monitor --dry-run loaded all config variables successfully."
