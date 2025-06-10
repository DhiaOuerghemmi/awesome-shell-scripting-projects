#!/usr/bin/env bash
#
# tests/test_cleanup.sh — verify cleanup & retry logic
set -euo pipefail
IFS=$'\n\t'

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLEANUP="${SCRIPT_ROOT}/scripts/cleanup.sh"

# Create dummy commands to stub apt-get, yum, dnf
TMPDIR="$(mktemp -d)"
trap "rm -rf ${TMPDIR}" EXIT

for cmd in apt-get yum dnf; do
    cat <<'EOF' >"${TMPDIR}/${cmd}"
#!/usr/bin/env bash
echo "stub ${cmd} $*"
exit 0
EOF
    chmod +x "${TMPDIR}/${cmd}"
done
export PATH="${TMPDIR}:$PATH"

# Source cleanup functions
# shellcheck source=/dev/null
source "${CLEANUP}"

# Test each cleanup function exits 0
for fn in apt_cleanup yum_cleanup dnf_cleanup; do
    echo "Testing ${fn}..."
    if ! ${fn}; then
        echo "❌ ${fn} failed"
        exit 1
    fi
done

# Test retry_check:
calls=0
function fake_check() {
    calls=$((calls + 1))
    if [[ $calls -eq 1 ]]; then
        return 1
    else
        return 0
    fi
}
# stub cleanup function
function fake_cleanup() { echo "fake_cleanup ran"; }

echo "Testing retry_check..."
if ! retry_check fake_check fake_cleanup; then
    echo "❌ retry_check did not succeed on second attempt"
    exit 1
fi

echo "✅ Cleanup & retry tests passed."
