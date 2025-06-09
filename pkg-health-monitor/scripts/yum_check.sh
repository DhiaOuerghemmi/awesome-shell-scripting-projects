#!/usr/bin/env bash
# scripts/yum_check.sh — yum cache & package health checks
set -euo pipefail
IFS=$'\n\t'

# yum_check: returns 0 if healthy, >0 if issues found
function yum_check() {
    local issues=0

    echo "🔍 Checking yum cache..."
    if ! sudo yum clean all --quiet; then
        echo "❌ ERROR: 'yum clean all' failed"
        issues=$((issues + 1))
    fi

    echo "🔍 Checking for available updates..."
    if ! sudo yum check-update --quiet; then
        # note: yum check-update exits 100 when updates are available
        echo "⚠️  yum has updates or failed to check"
        issues=$((issues + 1))
    fi

    return "$issues"
}
