#!/usr/bin/env bash
# Loads the real Quickshell config with the real `quickshell` binary against
# an isolated HOME.
#
# Every other test in this suite verifies QML by grepping source text — real,
# but blind to two failure modes that only show up when the QML engine
# actually parses and instantiates the tree: a qmldir entry pointing at a
# file that does not exist (a missing singleton breaks every consumer's
# import, not just its own), and a binding error in a file nothing else
# happens to `grep` for. Both are silent until something runs the shell.
#
# This is intentionally optional: it only runs when `quickshell` can start in
# the current graphical/runtime environment. Headless CI and restricted
# sandboxes skip it rather than failing on display setup.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-qml-load.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

if ! command -v quickshell >/dev/null 2>&1; then
    printf 'WARN: quickshell is unavailable; skipping the real QML load smoke test\n' >&2
    exit 0
fi

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    printf 'WARN: no Wayland display is available; skipping the real QML load smoke test\n' >&2
    exit 0
fi

mkdir -p "$TMP/home/.config" "$TMP/home/.local/state" "$TMP/runtime"
chmod 700 "$TMP/runtime"
ln -s "$REPO/config/quickshell" "$TMP/home/.config/quickshell"
ln -s "$REPO/config/hypr" "$TMP/home/.config/hypr"

LOG="$TMP/log.txt"
status=0
HOME="$TMP/home" XDG_STATE_HOME="$TMP/home/.local/state" XDG_RUNTIME_DIR="$TMP/runtime" \
    timeout 5 quickshell -p "$TMP/home/.config/quickshell" >"$LOG" 2>&1 || status=$?

# 124 is timeout(1) killing a process that was still alive at the deadline —
# the expected outcome for a shell that loaded cleanly and sat there. Any
# other exit means Quickshell gave up on its own, which only happens on a
# load failure.
if [ "$status" -ne 124 ]; then
    if grep -Eq 'Failed to create wl_display|could not connect to display|no Qt platform plugin could be initialized' "$LOG"; then
        printf 'WARN: quickshell could not start in this graphical environment; skipping the real QML load smoke test\n' >&2
        exit 0
    fi
    cat "$LOG" >&2
    fail "quickshell exited $status before the timeout instead of staying up"
fi

grep -q 'Configuration Loaded' "$LOG" \
    || { cat "$LOG" >&2; fail "log never reported Configuration Loaded"; }
grep -q 'ERROR' "$LOG" && { cat "$LOG" >&2; fail "quickshell logged an ERROR while loading"; }

# The scripts every new singleton shells out to (doctor.sh, settings-store.sh,
# notification-store.sh) must actually be found and runnable, not merely
# referenced — a typo'd path fails silently as an empty Process result with
# nothing else in this suite able to notice.
grep -q 'could not be found' "$LOG" && { cat "$LOG" >&2; fail "a Process command referenced a script that does not exist or is not executable"; }

ok "the real Quickshell config loads every QML file, singleton, and script path with no errors"
