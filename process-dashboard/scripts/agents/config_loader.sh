#!/usr/bin/env bash
# config_loader.sh: Load and validate /etc/proc-dash/config.yaml (or $CONFIG_PATH)
# Exports THRESHOLD_CPU and THRESHOLD_MEM for use by collector/enforcer.

set -euo pipefail

#------------------------------------------------------------------------------
# Default CONFIG_PATH if not set via environment
#------------------------------------------------------------------------------
: "${CONFIG_PATH:=/etc/proc-dash/config.yaml}"

# Source utils for logging and die()
# If utils.sh is not found or not readable, exit immediately.
if [[ -r "$(dirname "${BASH_SOURCE[0]}")/utils.sh" ]]; then
    # shellcheck source=/dev/null
    source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
else
    echo "ERROR: utils.sh not found or not readable in scripts/agents/" >&2
    exit 1
fi

#------------------------------------------------------------------------------
# Check that CONFIG_PATH exists and is readable
#------------------------------------------------------------------------------
if [[ ! -f "${CONFIG_PATH}" ]]; then
    die "Configuration file not found: ${CONFIG_PATH}"
fi

if [[ ! -r "${CONFIG_PATH}" ]]; then
    die "Configuration file is not readable: ${CONFIG_PATH}"
fi

#------------------------------------------------------------------------------
# Ensure yq is installed (for YAML parsing). If not, fail.
#------------------------------------------------------------------------------
if ! command -v yq >/dev/null 2>&1; then
    die "yq is required to parse YAML, but it was not found."
fi

#------------------------------------------------------------------------------
# Validate YAML syntax
#------------------------------------------------------------------------------
# yq eval '.' returns non-zero on invalid YAML.
if ! yq eval '.' "${CONFIG_PATH}" >/dev/null 2>&1; then
    log_error "Invalid YAML syntax in ${CONFIG_PATH}"
    exit 1
fi

#------------------------------------------------------------------------------
# Extract thresholds from YAML and export as environment variables
# Expected YAML structure:
# thresholds:
#   process:
#     cpu_pct: 80
#     mem_pct: 70
#------------------------------------------------------------------------------

# Read CPU threshold
if ! THRESHOLD_CPU="$(yq eval '.thresholds.process.cpu_pct // empty' "${CONFIG_PATH}")"; then
    die "Failed to read 'thresholds.process.cpu_pct' from ${CONFIG_PATH}"
fi

# Read MEM threshold
if ! THRESHOLD_MEM="$(yq eval '.thresholds.process.mem_pct // empty' "${CONFIG_PATH}")"; then
    die "Failed to read 'thresholds.process.mem_pct' from ${CONFIG_PATH}"
fi

# Validate that thresholds are non-empty and numeric
if [[ -z "${THRESHOLD_CPU}" ]]; then
    die "Missing 'thresholds.process.cpu_pct' in ${CONFIG_PATH}"
fi
if [[ -z "${THRESHOLD_MEM}" ]]; then
    die "Missing 'thresholds.process.mem_pct' in ${CONFIG_PATH}"
fi

# Ensure values are integers (or numeric)
if ! [[ "${THRESHOLD_CPU}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    die "'thresholds.process.cpu_pct' must be a number, got '${THRESHOLD_CPU}'"
fi
if ! [[ "${THRESHOLD_MEM}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    die "'thresholds.process.mem_pct' must be a number, got '${THRESHOLD_MEM}'"
fi

export THRESHOLD_CPU
export THRESHOLD_MEM

log_info "Loaded thresholds: CPU=${THRESHOLD_CPU}%  MEM=${THRESHOLD_MEM}%"

#------------------------------------------------------------------------------
# (Optional) Load additional config keys as needed, e.g., email, whitelist, etc.
# Example:
#   SMTP_HOST="$(yq eval '.smtp.host // empty' "${CONFIG_PATH}")"
#   export SMTP_HOST
#   ...
#------------------------------------------------------------------------------

# End of config_loader.sh
