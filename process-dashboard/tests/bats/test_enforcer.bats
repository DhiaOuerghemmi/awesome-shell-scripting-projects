#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  # Create a temporary alerts file
  TMP_ALERTS="$(mktemp)"
  export ALERT_LOG="$TMP_ALERTS"
  # Ensure config.yaml points to a temp config
  TMP_CONFIG="$(mktemp)"
  export CONFIG_PATH="$TMP_CONFIG"

  # Minimal config with thresholds and whitelist
  cat <<EOF > "$CONFIG_PATH"
thresholds:
  process:
    cpu_pct: 0.1
    mem_pct: 0.1

whitelist:
  - "critical_service_test"
EOF

  # Source the enforcer (with our overridden paths)
  cp "$SCRIPT_DIR"/enforcer.sh /tmp/enforcer.sh
  chmod +x /tmp/enforcer.sh
}

teardown() {
  pkill -f "sleep 300" || true
  rm -f "$TMP_ALERTS" "$TMP_CONFIG" /tmp/enforcer.sh
}

@test "whitelisted process is NOT killed" {
  # Start a dummy process whose cmd contains "critical_service_test"
  bash -c 'critical_service_test() { sleep 300; }; critical_service_test &' 

  pid_whitelisted="$!"

  # Build a minimal collector payload
  payload="$(jq -n \
    --arg ts "$(date --iso-8601=seconds)" \
    --arg host "$(hostname)" \
    --arg pid "$pid_whitelisted" \
    --arg pcpu "50.0" \
    --arg pmem "50.0" \
    --arg cmd "critical_service_test" \
    '{ timestamp: $ts, hostname: $host, processes: [ { pid: ($pid|tonumber), user: "test", pcpu: ($pcpu|tonumber), pmem: ($pmem|tonumber), cmd: $cmd } ] }')"

  printf '%s' "$payload" | /tmp/enforcer.sh

  # Give a moment for enforcer to (not) kill
  sleep 1

  # Process should still be running
  if kill -0 "$pid_whitelisted" >/dev/null 2>&1; then
    assert_success
  else
    fail "Whitelisted process was killed unexpectedly."
  fi
}

@test "non-whitelisted process is killed" {
  # Start a dummy process named "evil_process"
  bash -c 'evil_process() { sleep 300; }; evil_process &' 
  pid_evil="$!"

  payload="$(jq -n \
    --arg ts "$(date --iso-8601=seconds)" \
    --arg host "$(hostname)" \
    --arg pid "$pid_evil" \
    --arg pcpu "50.0" \
    --arg pmem "50.0" \
    --arg cmd "evil_process" \
    '{ timestamp: $ts, hostname: $host, processes: [ { pid: ($pid|tonumber), user: "test", pcpu: ($pcpu|tonumber), pmem: ($pmem|tonumber), cmd: $cmd } ] }')"

  printf '%s' "$payload" | /tmp/enforcer.sh

  # Give a moment for enforcer to kill
  sleep 1

  # Process should be gone
  if kill -0 "$pid_evil" >/dev/null 2>&1; then
    fail "Non-whitelisted process was not killed."
  else
    assert_success
  fi
}
