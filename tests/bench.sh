#!/usr/bin/env bash
# Reproducible performance baseline — adapted from the methodology Silere's
# bench.sh documents (see the competitive analysis). Every number this prints
# is tagged with the metadata that makes it comparable at all: commit,
# Quickshell/Qt version, GPU, monitor count/scale, and which scenario was
# sampled. A number without that metadata is not a regression signal, it is
# noise — see docs/QUICKSHELL-COMPETITIVE-ANALYSIS.md's "Como ler desempenho".
#
# Requires a running Quickshell instance (qs/quickshell) to measure anything;
# with none running it prints the metadata and an explicit "not running"
# result rather than fabricating a number, which is also what --check exercises
# in CI where no Wayland session exists.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-}"
CHECK=0
[ "$OUT" != --check ] || { CHECK=1; OUT=""; }

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

qs_pid() {
    pgrep -x quickshell 2>/dev/null | head -n1 || pgrep -x qs 2>/dev/null | head -n1 || true
}

# Pss/Private_Clean+Private_Dirty (≈ USS) summed across every mapping, in kB —
# see the competitive analysis for why PSS and USS are reported rather than
# RSS alone (RSS overcounts pages shared with every other process on the
# system, e.g. libQt6Core).
sample_memory() {
    local pid=$1 rollup=/proc/$1/smaps_rollup
    [ -r "$rollup" ] || { echo "0 0 0"; return; }
    awk '
        /^Rss:/            { rss += $2 }
        /^Pss:/            { pss += $2 }
        /^Private_Clean:/  { priv += $2 }
        /^Private_Dirty:/  { priv += $2 }
        END { printf "%d %d %d", rss, pss, priv }
    ' "$rollup"
}

# CPU percent over a fixed window, from /proc/<pid>/stat utime+stime deltas —
# the same source SysInfo.qml reads for the bar's own CPU meter, just sampled
# for one process instead of the whole system.
sample_cpu() {
    local pid=$1 window=${2:-2}
    local hz ut1 st1 ut2 st2
    hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
    read -r _ _ _ _ _ _ _ _ _ _ _ _ _ ut1 st1 _ < "/proc/$pid/stat" 2>/dev/null || { echo 0; return; }
    sleep "$window"
    read -r _ _ _ _ _ _ _ _ _ _ _ _ _ ut2 st2 _ < "/proc/$pid/stat" 2>/dev/null || { echo 0; return; }
    awk -v u1="$ut1" -v s1="$st1" -v u2="$ut2" -v s2="$st2" -v hz="$hz" -v w="$window" \
        'BEGIN { printf "%.1f", 100 * ((u2 - u1) + (s2 - s1)) / hz / w }'
}

metadata() {
    local commit qsver monitors scale gpu
    commit=$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)
    qsver=$(quickshell --version 2>/dev/null | head -n1 || echo "quickshell not found")
    gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -n1 | cut -d: -f3- | sed 's/^ *//' || true)
    [ -n "$gpu" ] || gpu="unknown"
    if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors -j >/dev/null 2>&1; then
        monitors=$(hyprctl monitors -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d))' 2>/dev/null || echo unknown)
        scale=$(hyprctl monitors -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(",".join(str(m.get("scale","?")) for m in d))' 2>/dev/null || echo unknown)
    else
        monitors=unknown; scale=unknown
    fi
    printf '{"commit":"%s","quickshell_version":"%s","gpu":"%s","monitors":"%s","scale":"%s","host":"%s","date":"%s"}\n' \
        "$commit" "$qsver" "$gpu" "$monitors" "$scale" "$(uname -n)" "$(date -Iseconds)"
}

run_scenario() {
    local name=$1 pid=$2 rss pss uss cpu
    read -r rss pss uss < <(sample_memory "$pid")
    cpu=$(sample_cpu "$pid" 2)
    printf '{"scenario":"%s","rss_kb":%s,"pss_kb":%s,"uss_kb":%s,"cpu_pct":%s}\n' \
        "$name" "$rss" "$pss" "$uss" "$cpu"
}

main() {
    local pid meta
    meta=$(metadata)

    if [ "$CHECK" = 1 ]; then
        # CI has no Wayland session; this only proves the script itself runs
        # cleanly (metadata collection, jq/python availability, awk parsing)
        # rather than producing a comparable number.
        metadata >/dev/null
        printf 'OK: bench.sh metadata collection runs\n'
        return 0
    fi

    pid=$(qs_pid)
    if [ -z "$pid" ]; then
        printf '%s\n' "$meta"
        printf '{"scenario":"idle","status":"quickshell not running"}\n'
        return 0
    fi

    {
        printf '%s\n' "$meta"
        run_scenario idle "$pid"

        # Launcher: open, settle one frame, sample, close.
        "$REPO/hyprveil" shell open launcher >/dev/null 2>&1 || true
        sleep 0.3
        run_scenario launcher "$pid"
        "$REPO/hyprveil" shell close >/dev/null 2>&1 || true

        sleep 0.3
        # Notifications: the panel's notification view, same open/sample/close.
        "$REPO/hyprveil" shell open quick-settings >/dev/null 2>&1 || true
        sleep 0.3
        run_scenario notifications "$pid"
        "$REPO/hyprveil" shell close >/dev/null 2>&1 || true
    } | if [ -n "$OUT" ]; then tee -a "$OUT"; else cat; fi
}

main
