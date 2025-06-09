#!/usr/bin/env bash
# tests/test_yum.sh — ensure yum_check function is defined
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/yum_check.sh"

if ! declare -f yum_check &>/dev/null; then
    echo "❌ yum_check function not found"
    exit 1
fi

echo "✅ yum_check function exists"
