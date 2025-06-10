#!/usr/bin/env bash
# scripts/cleanup.sh — auto-cleanup & retry helpers
set -euo pipefail
IFS=$'\n\t'

# apt_cleanup: autoclean + autoremove
function apt_cleanup() {
  echo "🧹 Cleaning apt cache..."
  sudo apt-get autoclean -qq
  sudo apt-get autoremove -qq
}

# yum_cleanup: clean all
function yum_cleanup() {
  echo "🧹 Cleaning yum cache..."
  sudo yum clean all -q
}

# dnf_cleanup: clean all
function dnf_cleanup() {
  echo "🧹 Cleaning dnf cache..."
  sudo dnf clean all -q
}

# retry_check <check_func> <cleanup_func>
# Runs <check_func>; on failure runs <cleanup_func> then retries <check_func>
# Returns 0 if second check passes, else non-zero.
function retry_check() {
  local check_fn="$1"
  local clean_fn="$2"

  if ! $check_fn; then
    echo "🔄 Attempting cleanup before retry..."
    $clean_fn
    echo "🔄 Retrying check..."
    $check_fn
  else
    return 0
  fi
}
