#!/usr/bin/env bash
# Required live-session gate for a self-hosted Hyprland/Wayland runner.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT=${1:-"$REPO/runtime-benchmark.jsonl"}

HYPRVEIL_REQUIRE_RUNTIME=1 "$REPO/tests/qml-load-smoke.sh"
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || {
    printf 'FAIL: runtime-shell.sh requires a running Hyprland session\n' >&2
    exit 1
}
command -v qs >/dev/null 2>&1 || {
    printf 'FAIL: runtime-shell.sh requires the qs IPC client\n' >&2
    exit 1
}

"$REPO/tests/shell-performance.sh"
"$REPO/tests/bench.sh" "$OUT"
jq -e 'select(.scenario == "idle") | .rss_kb > 0 and .pss_kb > 0' "$OUT" >/dev/null
printf 'OK: live QML load, IPC latency, CPU, and memory measurements completed\n'
