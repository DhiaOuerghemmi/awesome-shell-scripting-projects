#!/usr/bin/env bash
# scripts/apt_check.sh — apt cache & package health checks
set -euo pipefail
IFS=$'\n\t'

# apt_check: returns 0 if healthy, >0 if issues found
function apt_check() {
    local issues=0

    echo "🔍 Checking apt cache..."
    if ! sudo apt-get update -qq; then
        echo "❌ ERROR: 'apt-get update' failed"
        issues=$((issues + 1))
    fi

    echo "🔍 Checking for broken packages..."
    local broken
    broken=$(dpkg --audit || true)
    if [[ -n "$broken" ]]; then
        echo "❌ ERROR: Broken packages detected:"
        echo "$broken"
        issues=$((issues + 1))
    fi

    return "$issues"
}
