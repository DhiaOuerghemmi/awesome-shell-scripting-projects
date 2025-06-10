#!/usr/bin/env bash
#
# Minimal Prometheus exporter for package-health metrics
set -euo pipefail
IFS=$'\n\t'

# Port to listen on
PORT="${EXPORTER_PORT:-9100}"

# List of package managers & their cache dirs
declare -A CACHE_DIR=(
    [apt]="/var/cache/apt"
    [yum]="/var/cache/yum"
    [dnf]="/var/cache/dnf"
)

echo "🚀 Starting exporter on port ${PORT}..."
while true; do
    # Serve a single HTTP request
    {
        # Read and discard request headers
        while read -r line && [[ -n "$line" ]]; do :; done

        # HTTP response header
        echo -e "HTTP/1.1 200 OK\r"
        echo -e "Content-Type: text/plain; version=0.0.4\r\n"

        # Metrics
        for pm in "${!CACHE_DIR[@]}"; do
            dir="${CACHE_DIR[$pm]}"
            if [[ -d "$dir" ]]; then
                size=$(du -sb "$dir" | cut -f1)
            else
                size=0
            fi

            # Expose cache size in bytes
            echo "pkg_cache_size_bytes{pm=\"${pm}\"} ${size}"

            # Expose total cleanups (stubbed to zero for now)
            echo "pkg_cleanup_total{pm=\"${pm}\"} 0"
        done
    } | nc -l -p "${PORT}" -q 1
done
