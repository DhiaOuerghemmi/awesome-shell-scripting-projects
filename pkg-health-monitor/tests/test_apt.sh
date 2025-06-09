#!/usr/bin/env bash
# tests/test_apt.sh — ensure apt_check function is defined
set -euo pipefail
IFS=$'\n\t'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT}/scripts/apt_check.sh"

if ! declare -f apt_check &>/dev/null; then
    echo "❌ apt_check function not found"
    exit 1
fi

echo "✅ apt_check function exists"
