# scripts/agents/collector.sh
#!/usr/bin/env bash
set -euo pipefail

# Ensure jq is installed
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: 'jq' is required but not installed." >&2
  exit 1
fi

timestamp="$(date --iso-8601=seconds)"
hostname="$(hostname)"

# Sample top 50 processes by CPU usage, emit one JSON object per line,
# then wrap all objects into a top-level JSON with timestamp, hostname, and processes array.
ps -eo pid=,user=,pcpu=,pmem=,args= --sort=-pcpu | head -n 50 \
  | awk '{
      pid=$1; user=$2; pcpu=$3; pmem=$4;
      # Remove first four columns to get the full command line
      $1=""; $2=""; $3=""; $4="";
      sub(/^ +/, "");
      cmd=$0;
      # Escape existing double quotes in cmd
      gsub(/"/, "\\\"", cmd);
      printf "{\"pid\": %s, \"user\": \"%s\", \"pcpu\": %s, \"pmem\": %s, \"cmd\": \"%s\"}\n", pid, user, pcpu, pmem, cmd
    }' \
  | jq -s --arg timestamp "$timestamp" --arg hostname "$hostname" \
      '{ timestamp: $timestamp,
         hostname: $hostname,
         processes: . }'
