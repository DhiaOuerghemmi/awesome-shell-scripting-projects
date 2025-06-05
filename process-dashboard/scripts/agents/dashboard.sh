#!/usr/bin/env bash
# ==============================================================================
# dashboard.sh
#
# Displays a ncurses-based, two-pane dashboard for on-box troubleshooting:
#  - Left pane: Top 10 CPU-consuming processes, with load average & zombie count.
#  - Right pane: Top 10 memory-consuming processes.
#
# Updates every 5 seconds. Exit gracefully via Ctrl-C or Esc.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Constants & Temp Files
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="/tmp/proc_dash_dashboard.$$"
TMP_CPU="$TMP_DIR/top_cpu.txt"
TMP_MEM="$TMP_DIR/top_mem.txt"

# Ensure cleanup on exit
cleanup() {
  # Kill background updater if running
  [[ -n "${UPDATER_PID:-}" ]] && kill "$UPDATER_PID" 2>/dev/null || true
  rm -rf "$TMP_DIR"
  clear
  exit 0
}
trap cleanup SIGINT SIGTERM

# ------------------------------------------------------------------------------
# Check for required commands
# ------------------------------------------------------------------------------
for cmd in dialog ps awk; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

# ------------------------------------------------------------------------------
# Prepare temp directory and files
# ------------------------------------------------------------------------------
mkdir -p "$TMP_DIR"
chmod 700 "$TMP_DIR"
touch "$TMP_CPU" "$TMP_MEM"

# ------------------------------------------------------------------------------
# Function: update_files
#    - Generates CPU pane:
#         * Line 1: "Load Avg: X.YZ   Zombies: N"
#         * Blank line
#         * Header: "PID   CPU%   CMD"
#         * Top 10 CPU processes via `ps -eo pid,pcpu,cmd --sort=-pcpu`
#    - Generates MEM pane:
#         * Header: "PID   MEM%   CMD"
#         * Top 10 memory processes via `ps -eo pid,pmem,cmd --sort=-pmem`
# ------------------------------------------------------------------------------
update_files() {
  # 1) Load average (1-minute) from /proc/loadavg
  load_avg="$(awk '{print $1}' /proc/loadavg)"
  # 2) Count zombie processes
  zombie_count="$(ps -eo stat | awk '$1 ~ /^Z/ { count++ } END { print count+0 }')"

  # Build CPU pane content
  {
    printf "Load Avg: %s   Zombies: %s\n\n" "$load_avg" "$zombie_count"
    printf "PID     CPU%%    CMD\n"
    ps -eo pid=,pcpu=,cmd= --sort=-pcpu | head -n 10 | awk '{ printf "%-7s %-6s %s\n", $1, $2, substr($0, index($0,$3)) }'
  } > "$TMP_CPU"

  # Build MEM pane content
  {
    printf "PID     MEM%%    CMD\n"
    ps -eo pid=,pmem=,cmd= --sort=-pmem | head -n 10 | awk '{ printf "%-7s %-6s %s\n", $1, $2, substr($0, index($0,$3)) }'
  } > "$TMP_MEM"
}

# ------------------------------------------------------------------------------
# Background updater: refresh CPU/MEM files every 5 seconds
# ------------------------------------------------------------------------------
update_loop() {
  while true; do
    update_files
    sleep 5
  done
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
# Initial update
update_files

# Start updater in background
update_loop &
UPDATER_PID=$!

# Launch dialog with two side-by-side tailboxbg widgets
#   - Left pane (starting at row 0, col 0): width 60, height 15
#   - Right pane (starting at row 0, col 62): width 60, height 15
#
# Pressing Esc or Ctrl-C will trigger cleanup() and exit.
dialog \
  --title "Top CPU Processes" \
  --begin 0 0 --tailboxbg "$TMP_CPU" 15 60 \
  --and-widget \
  --title "Top MEM Processes" \
  --begin 0 62 --tailboxbg "$TMP_MEM" 15 60

# If the user presses Esc (or dialog terminates for any reason), clean up
cleanup
