#!/usr/bin/env bash
# tests/test_dnf.sh — ensure dnf_check function is defined
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/dnf_check.sh"

if ! declare -f dnf_check &>/dev/null; then
    echo "❌ dnf_check function not found"
    exit 1
fi

echo "✅ dnf_check function exists"
