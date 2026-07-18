#!/usr/bin/env bash
# Single entrypoint for the persisted SwayNC/Mako notification backend.
set -uo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
STATE_FILE="$STATE_HOME/notification-backend"

backend() {
    local selected=
    if [ -r "$STATE_FILE" ]; then
        IFS= read -r selected < "$STATE_FILE" || true
    fi
    case "$selected" in
        swaync|mako) printf '%s\n' "$selected" ;;
        *) printf 'swaync\n' ;;
    esac
}

stop_daemons() {
    # A nested validation shell has an isolated D-Bus but shares the host process
    # namespace. Never let it kill notification daemons in the parent session.
    [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ] || return 0
    pkill -x swaync 2>/dev/null || true
    pkill -x mako 2>/dev/null || true
}

start_daemon() {
    local selected
    selected=$(backend)
    if [ "$selected" = swaync ]; then
        if [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ]; then
            pkill -x mako 2>/dev/null || true
            pgrep -x swaync >/dev/null 2>&1 && return 0
        fi
        if command -v swaync >/dev/null 2>&1; then
            exec swaync
        fi
        printf 'SwayNC is selected but swaync is unavailable; run scripts/02-install-fedora-shell.sh.\n' >&2
        return 1
    fi

    if [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ]; then
        pkill -x swaync 2>/dev/null || true
        pgrep -x mako >/dev/null 2>&1 && return 0
    fi
    if command -v mako >/dev/null 2>&1; then
        exec mako
    fi
    printf 'Mako fallback is selected but mako is unavailable; run scripts/02-install-fedora-shell.sh.\n' >&2
    return 1
}

case "${1:-start}" in
    start) start_daemon ;;
    stop) stop_daemons ;;
    restart)
        stop_daemons
        if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}${WAYLAND_DISPLAY:-}" ]; then
            "$0" start >/dev/null 2>&1 &
        fi
        ;;
    toggle)
        if [ "$(backend)" = swaync ]; then
            swaync-client -t -sw
        else
            command -v notify-send >/dev/null 2>&1 \
                && notify-send "Mako fallback active" "Notification history is available with the SwayNC backend."
        fi
        ;;
    dnd)
        if [ "$(backend)" = swaync ]; then
            swaync-client -d -sw
        else
            makoctl mode -t do-not-disturb
        fi
        ;;
    backend) backend ;;
    *)
        printf 'Usage: %s start|stop|restart|toggle|dnd|backend\n' "$0" >&2
        exit 2
        ;;
esac
