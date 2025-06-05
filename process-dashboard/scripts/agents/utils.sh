#!/usr/bin/env bash
# utils.sh: Common helper functions for proc-dash agent scripts.
# Provides structured logging (via 'logger'), JSON wrapping, and error handling.

set -euo pipefail

#------------------------------------------------------------------------------
# Logging Helpers
#------------------------------------------------------------------------------
# Usage:
#   log_info "Some informational message"
#   log_warn "A warning occurred"
#   log_error "An error occurred"
# These wrap `logger -t proc-dash-agent` to send messages to syslog.
#------------------------------------------------------------------------------

log_info() {
    local msg="$*"
    # priority "info"
    logger -t proc-dash-agent "[INFO] ${msg}"
}

log_warn() {
    local msg="$*"
    # priority "warning"
    logger -t proc-dash-agent "[WARN] ${msg}"
}

log_error() {
    local msg="$*"
    # priority "err"
    logger -t proc-dash-agent "[ERROR] ${msg}"
}

#------------------------------------------------------------------------------
# die()
#------------------------------------------------------------------------------
# Log an error message and exit with status 1.
# Usage:
#   die "Something went horribly wrong"
#------------------------------------------------------------------------------

die() {
    local msg="$*"
    log_error "${msg}"
    exit 1
}

#------------------------------------------------------------------------------
# json_wrap()
#------------------------------------------------------------------------------
# Wraps a raw JSON payload (string or piped-in) into a top-level object:
#   {
#     "timestamp":   "2025-06-05T12:34:56+00:00",
#     "host":        "hostname.example.com",
#     "metrics":     <raw-json-payload>
#   }
#
# Expects valid JSON on stdin or as first argument; emits wrapped JSON to stdout.
#
# Requires `jq` to be available. If `jq` is missing, calls die().
#------------------------------------------------------------------------------

json_wrap() {
    local raw_json

    # Ensure jq is installed
    if ! command -v jq >/dev/null 2>&1; then
        die "jq is required for json_wrap(), but it was not found."
    fi

    # Capture raw JSON: either from argument or from stdin
    if [[ "${#}" -gt 0 ]]; then
        # Provided as argument (string)
        raw_json="$1"
        shift
    else
        # Read from stdin
        raw_json="$(cat)"
    fi

    # Validate that raw_json is valid JSON
    if ! printf '%s\n' "${raw_json}" | jq . >/dev/null 2>&1; then
        die "json_wrap(): invalid JSON payload."
    fi

    local timestamp
    local hostname

    timestamp="$(date --iso-8601=seconds)"
    hostname="$(hostname)"

    # Build wrapped JSON
    jq -n \
        --arg ts "${timestamp}" \
        --arg host "${hostname}" \
        --argjson metrics "${raw_json}" \
        '{ timestamp: $ts, host: $host, metrics: $metrics }'
}
