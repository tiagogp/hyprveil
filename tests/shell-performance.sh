#!/usr/bin/env bash
# Measure end-to-end CLI-to-coordinator surface opening latency.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
RUNS=${HYPRVEIL_PERF_RUNS:-10}

[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || {
    printf 'SKIP: opening latency needs a running Hyprland session\n'
    exit 0
}
command -v qs >/dev/null 2>&1 || {
    printf 'SKIP: qs is unavailable\n'
    exit 0
}

measure() {
    local surface=$1 start end elapsed total=0
    for ((i = 0; i < RUNS; i++)); do
        "$REPO/hyprveil" shell close >/dev/null 2>&1 || true
        start=$(date +%s%N)
        "$REPO/hyprveil" shell open "$surface" >/dev/null
        while [ "$("$REPO/hyprveil" shell get active 2>/dev/null || true)" != "$surface" ]; do
            sleep 0.005
        done
        end=$(date +%s%N)
        elapsed=$(( (end - start) / 1000000 ))
        total=$((total + elapsed))
    done
    printf '{"surface":"%s","runs":%d,"mean_ms":%d}\n' "$surface" "$RUNS" "$((total / RUNS))"
}

measure launcher
measure quick-settings
tests/bench.sh
