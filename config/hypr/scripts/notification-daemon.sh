#!/usr/bin/env bash
# Single entrypoint for the persisted AGS/SwayNC/Mako notification backend.
# AGS (the quick-settings panel) is the default and also serves notifications;
# SwayNC and Mako remain selectable fallbacks. Only ever one daemon runs.
set -uo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
STATE_FILE="$STATE_HOME/notification-backend"
AGS_INSTANCE="${HYPRVEIL_AGS_INSTANCE:-hyprveil}"

backend() {
    local selected=
    if [ -r "$STATE_FILE" ]; then
        IFS= read -r selected < "$STATE_FILE" || true
    fi
    case "$selected" in
        ags|swaync|mako) printf '%s\n' "$selected" ;;
        *) printf 'ags\n' ;;
    esac
}

ags_running() {
    command -v ags >/dev/null 2>&1 || return 1
    ags list 2>/dev/null | grep -Fxq "$AGS_INSTANCE"
}

ags_request() {
    command -v ags >/dev/null 2>&1 || return 1
    ags request -i "$AGS_INSTANCE" "$@" >/dev/null 2>&1
}

stop_daemons() {
    # A nested validation shell has an isolated D-Bus but shares the host process
    # namespace. Never let it kill notification daemons in the parent session.
    [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ] || return 0
    command -v ags >/dev/null 2>&1 && ags quit -i "$AGS_INSTANCE" 2>/dev/null || true
    pkill -x swaync 2>/dev/null || true
    pkill -x mako 2>/dev/null || true
}

start_daemon() {
    local selected
    selected=$(backend)
    if [ "$selected" = ags ]; then
        if [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ]; then
            pkill -x swaync 2>/dev/null || true
            pkill -x mako 2>/dev/null || true
            ags_running && return 0
        fi
        if command -v ags >/dev/null 2>&1; then
            exec ags run
        fi
        printf 'AGS is selected but ags is unavailable; run scripts/02-install-fedora-shell.sh.\n' >&2
        return 1
    fi

    if [ "$selected" = swaync ]; then
        if [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ]; then
            command -v ags >/dev/null 2>&1 && ags quit -i "$AGS_INSTANCE" 2>/dev/null || true
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
        command -v ags >/dev/null 2>&1 && ags quit -i "$AGS_INSTANCE" 2>/dev/null || true
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
        case "$(backend)" in
            ags) ags_request toggle-quicksettings ;;
            swaync) swaync-client -t -sw ;;
            *)
                command -v notify-send >/dev/null 2>&1 \
                    && notify-send "Mako fallback active" "Notification history is available with the AGS or SwayNC backend."
                ;;
        esac
        ;;
    dnd)
        case "$(backend)" in
            ags) ags_request notif-dnd ;;
            swaync) swaync-client -d -sw ;;
            *) makoctl mode -t do-not-disturb ;;
        esac
        ;;
    backend) backend ;;
    *)
        printf 'Usage: %s start|stop|restart|toggle|dnd|backend\n' "$0" >&2
        exit 2
        ;;
esac
