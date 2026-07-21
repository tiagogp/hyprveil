#!/usr/bin/env bash
# Lock the session.
#
# Prefers the Quickshell lock, falls back to hyprlock. The fallback is the whole
# point of this script: a lock screen that fails to appear is not an
# inconvenience, it is an unlocked machine, so anything short of positive
# confirmation that the shell locked has to fall through.
#
# The reverse failure matters too. ext-session-lock keeps the session locked if
# the lock client dies without unlocking — deliberately, so a crashed locker
# cannot expose the desktop. That also means a bug in Lock.qml locks the user
# out, which is why hyprlock stays installed and why this script never assumes
# the shell is healthy.
set -uo pipefail

# Injectable so the branch tests can never reach a real shell or a real locker.
# This is not premature generality: testing the "Quickshell is missing" branch by
# removing a mock from PATH finds the REAL qs one directory later and locks the
# developer's session. That happened.
QS_BIN="${HYPRVEIL_QS_BIN:-qs}"
HYPRLOCK_BIN="${HYPRVEIL_HYPRLOCK_BIN:-hyprlock}"

log() { printf 'Lock: %s\n' "$*" >&2; }

fallback() {
    if command -v "$HYPRLOCK_BIN" >/dev/null 2>&1; then
        log "$1; falling back to hyprlock"
        exec "$HYPRLOCK_BIN"
    fi
    # Nothing can lock the session. Say so loudly rather than exiting 0, which
    # hypridle would read as success and never retry.
    log "$1, and hyprlock is not installed — the session is NOT locked"
    exit 1
}

# Already locked by hyprlock: do not stack a second locker on top.
pidof hyprlock >/dev/null 2>&1 && exit 0

command -v "$QS_BIN" >/dev/null 2>&1 || fallback "Quickshell is not installed"

# `qs ipc call` fails if no instance is running, if the target is missing, or if
# the shell is wedged. All three mean the same thing here.
state=$(timeout 5 "$QS_BIN" ipc call lock lock 2>/dev/null) || fallback "the shell did not answer"
[ "$state" = locked ] || fallback "the shell did not confirm the lock"

exit 0
