#!/usr/bin/env bash
# Capture the release stills and connected-flow demo from a live Hyprland shell.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/docs/images"
DELAY=${HYPRVEIL_CAPTURE_DELAY:-1}

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "required command is missing: $1"; }

[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || fail "run this inside the Hyprland session being documented"
need grim
need wf-recorder
need qs

mkdir -p "$OUT"

surface() {
    local name=$1 file=$2
    shift 2
    "$REPO/hyprveil" shell close >/dev/null 2>&1 || true
    "$REPO/hyprveil" "$@"
    sleep "$DELAY"
    grim "$OUT/$file"
    "$REPO/hyprveil" shell close >/dev/null 2>&1 || true
}

"$REPO/hyprveil" shell close >/dev/null 2>&1 || true
sleep "$DELAY"
grim "$OUT/desktop.png"

surface launcher launcher.png shell open launcher
surface wallpaper wallpaper-picker.png shell open wallpapers
surface cheatsheet cheatsheet.png shell open cheatsheet

# Record a short deterministic route through the connected surface families.
# wf-recorder is terminated with SIGINT so it writes the WebM trailer cleanly.
wf-recorder -f "$OUT/shell-demo.webm" >/dev/null 2>&1 &
recorder=$!
trap 'kill -INT "$recorder" 2>/dev/null || true' EXIT
sleep 1
for name in launcher quick-settings wallpapers cheatsheet session; do
    "$REPO/hyprveil" shell open "$name"
    sleep 2
    "$REPO/hyprveil" shell close
    sleep 1
done
kill -INT "$recorder"
wait "$recorder" || true
trap - EXIT

printf 'Captured release evidence in %s\n' "$OUT"
