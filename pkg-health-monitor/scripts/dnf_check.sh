#!/usr/bin/env bash
# scripts/dnf_check.sh — dnf cache & package health checks
set -euo pipefail
IFS=$'\n\t'

# dnf_check: returns 0 if healthy, >0 if issues found
function dnf_check() {
    local issues=0

    echo "🔍 Checking dnf cache..."
    if ! sudo dnf clean all --quiet; then
        echo "❌ ERROR: 'dnf clean all' failed"
        issues=$((issues + 1))
    fi

    echo "🔍 Checking for available updates..."
    if ! sudo dnf check-update --quiet; then
        # dnf exits 100 when there are updates
        echo "⚠️  dnf has updates or failed to check"
        issues=$((issues + 1))
    fi

    return "$issues"
}
