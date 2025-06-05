#!/usr/bin/env bash
# ==============================================================================
# enforcer.sh
#
# Reads a JSON payload (from collector.sh) on stdin, iterates through each
# process, compares its pcpu/pmem against thresholds, and kills offenders.
# Logs actions via syslog and appends JSON “alerts” to /var/log/proc-dash/alerts.json.
#
# Usage (example):
#   collector.sh | enforcer.sh
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Locate this script’s directory so we can source config_loader.sh & utils.sh
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared helpers and configuration loader
# -------------------------------------------------------
# config_loader.sh: must export $THRESHOLD_CPU and $THRESHOLD_MEM, and define $CONFIG_PATH
# utils.sh: provides log_info(), log_warn(), log_error(), die(), json_wrap()
# -------------------------------------------------------
if [[ -r "${SCRIPT_DIR}/config_loader.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/config_loader.sh"
else
  echo "ERROR: Cannot find config_loader.sh in ${SCRIPT_DIR}" >&2
  exit 1
fi

if [[ -r "${SCRIPT_DIR}/utils.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/utils.sh"
else
  die "Cannot find utils.sh in ${SCRIPT_DIR}"
fi

# ------------------------------------------------------------------------------
# Ensure required commands exist
# ------------------------------------------------------------------------------
for cmd in jq yq kill; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Required command '$cmd' not found."
  fi
done

# ------------------------------------------------------------------------------
# Read whitelist patterns from config.yaml
#
# Expecting:
#   whitelist:
#     - "pattern1"
#     - "pattern2"
# ------------------------------------------------------------------------------
readarray -t WHITELIST_PATTERNS < <(
  yq eval '.whitelist[] // ""' "${CONFIG_PATH}" 2>/dev/null || true
)
# Filter out any empty strings
WHITELIST=()
for pattern in "${WHITELIST_PATTERNS[@]}"; do
  if [[ -n "$pattern" ]]; then
    WHITELIST+=("$pattern")
  fi
done

# ------------------------------------------------------------------------------
# Prepare alert log file
#
# We will append wrapped JSON alerts here:
# ------------------------------------------------------------------------------
ALERT_LOG="/var/log/proc-dash/alerts.json"
if [[ ! -d "$(dirname "$ALERT_LOG")" ]]; then
  mkdir -p "$(dirname "$ALERT_LOG")"
  chown proc_dash:proc_dash "$(dirname "$ALERT_LOG")"
  chmod 750 "$(dirname "$ALERT_LOG")"
fi
touch "$ALERT_LOG"
chmod 640 "$ALERT_LOG"
chown proc_dash:proc_dash "$ALERT_LOG"

# ------------------------------------------------------------------------------
# Read entire JSON payload from stdin into a variable
# Collector emits something like:
# {
#   "timestamp": "2025-06-05T12:34:56+00:00",
#   "hostname": "host1",
#   "processes": [
#     { "pid": 1234, "user": "alice", "pcpu": 45.3, "pmem": 12.1, "cmd": "/usr/bin/foo" },
#     ...
#   ]
# }
# ------------------------------------------------------------------------------
raw_payload="$(cat)"

# Validate it's valid JSON
if ! printf '%s\n' "$raw_payload" | jq . >/dev/null 2>&1; then
  log_error "enforcer.sh: received invalid JSON from collector."
  exit 1
fi

# Extract host (for alert payloads)
HOSTNAME_FROM_PAYLOAD="$(printf '%s\n' "$raw_payload" | jq -r '.hostname')"

# ------------------------------------------------------------------------------
# Iterate over each process object
# ------------------------------------------------------------------------------
printf '%s\n' "$raw_payload" \
  | jq -c '.processes[]' \
  | while read -r process_json; do

  # Extract fields from each process
  pid="$(printf '%s\n' "$process_json" | jq -r '.pid')"
  pcpu="$(printf '%s\n' "$process_json" | jq -r '.pcpu')"
  pmem="$(printf '%s\n' "$process_json" | jq -r '.pmem')"
  cmd="$(printf '%s\n' "$process_json" | jq -r '.cmd')"

  # ----------------------------------------------------------------------------
  # Check whitelist: if `cmd` matches any glob pattern in $WHITELIST, skip.
  # ----------------------------------------------------------------------------
  for pattern in "${WHITELIST[@]}"; do
    if [[ "$cmd" == $pattern ]]; then
      # Whitelisted → skip enforcement
      continue 2  # skip to next process_json
    fi
  done

  # ----------------------------------------------------------------------------
  # Determine if either threshold is exceeded
  # Using bc for floating‐point comparison
  # ----------------------------------------------------------------------------
  over_cpu=false
  over_mem=false

  # Compare pcpu > THRESHOLD_CPU
  if awk -v val="$pcpu" -v thr="$THRESHOLD_CPU" 'BEGIN { exit !(val > thr) }'; then
    over_cpu=true
  fi

  # Compare pmem > THRESHOLD_MEM
  if awk -v val="$pmem" -v thr="$THRESHOLD_MEM" 'BEGIN { exit !(val > thr) }'; then
    over_mem=true
  fi

  if [[ "$over_cpu" == true ]] || [[ "$over_mem" == true ]]; then
    # Build a reason string
    reason_parts=()
    if [[ "$over_cpu" == true ]]; then
      reason_parts+=("cpu_pct>$THRESHOLD_CPU")
    fi
    if [[ "$over_mem" == true ]]; then
      reason_parts+=("mem_pct>$THRESHOLD_MEM")
    fi
    reason="$(IFS=", "; echo "${reason_parts[*]}")"

    # ----------------------------------------------------------------------------
    # Attempt graceful kill (SIGTERM)
    # ----------------------------------------------------------------------------
    if kill -15 "$pid" >/dev/null 2>&1; then
      action="SIGTERM"
      log_warn "$(jq -n \
        --arg action "$action" \
        --arg pid "$pid" \
        --arg reason "$reason" \
        '{ action: $action, pid: ($pid|tonumber), reason: $reason }')"

      # Wait up to 10 seconds for process to exit
      for i in {1..10}; do
        if ! kill -0 "$pid" >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done
    else
      # Could not send SIGTERM (maybe no permission or process gone)
      action="SIGTERM_FAILED"
      log_warn "$(jq -n \
        --arg action "$action" \
        --arg pid "$pid" \
        --arg reason "$reason" \
        '{ action: $action, pid: ($pid|tonumber), reason: $reason }')"
    fi

    # ----------------------------------------------------------------------------
    # If process is still alive after waiting, escalate to SIGKILL
    # ----------------------------------------------------------------------------
    if kill -0 "$pid" >/dev/null 2>&1; then
      if kill -9 "$pid" >/dev/null 2>&1; then
        action="SIGKILL"
        log_warn "$(jq -n \
          --arg action "$action" \
          --arg pid "$pid" \
          --arg reason "$reason" \
          '{ action: $action, pid: ($pid|tonumber), reason: $reason }')"
      else
        action="SIGKILL_FAILED"
        log_warn "$(jq -n \
          --arg action "$action" \
          --arg pid "$pid" \
          --arg reason "$reason" \
          '{ action: $action, pid: ($pid|tonumber), reason: $reason }')"
      fi
    fi

    # ----------------------------------------------------------------------------
    # Build and append local alert JSON
    # ----------------------------------------------------------------------------
    alert_body="$(jq -n \
      --arg ts "$(date --iso-8601=seconds)" \
      --arg host "$HOSTNAME_FROM_PAYLOAD" \
      --arg action "$action" \
      --arg pid "$pid" \
      --arg reason "$reason" \
      '{ timestamp: $ts, host: $host, pid: ($pid|tonumber), action: $action, reason: $reason }')"

    # Wrap alert_body with top-level metadata (if desired, we already included timestamp & host)
    # You can simply append alert_body, or if you want the same structure as json_wrap:
    printf '%s\n' "$alert_body" >> "$ALERT_LOG"
  fi
done

# Exit successfully
exit 0
