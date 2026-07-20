#!/usr/bin/env bash
# Single entrypoint for the persisted Quickshell/SwayNC/Mako notification
# backend. Quickshell is a shell that also serves notifications; SwayNC and Mako
# are notification-only fallbacks. Only ever one daemon runs.
set -uo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
STATE_FILE="$STATE_HOME/notification-backend"

backend() {
    local selected=
    if [ -r "$STATE_FILE" ]; then
        IFS= read -r selected < "$STATE_FILE" || true
    fi
    case "$selected" in
        quickshell|swaync|mako) printf '%s\n' "$selected" ;;
        # A state file left over from the retired AGS backend lands here too,
        # which is the intended migration path: it reads as unset and gets the
        # default, rather than selecting a backend that no longer exists.
        *) printf 'quickshell\n' ;;
    esac
}

qs_running() {
    command -v quickshell >/dev/null 2>&1 || return 1
    pgrep -x quickshell >/dev/null 2>&1
}

# There is no toolchain gate here: Quickshell reads QML directly, so it has
# nothing to compile before it can start.
#
# No -c: the shell is deployed flat at ~/.config/quickshell/shell.qml, which is
# Quickshell's default config path, so both the launch and the IPC target the
# default instance.
qs_ipc() {
    command -v qs >/dev/null 2>&1 || return 1
    qs ipc call "$@" >/dev/null 2>&1
}

stop_daemons() {
    # A nested validation shell has an isolated D-Bus but shares the host process
    # namespace. Never let it kill notification daemons in the parent session.
    [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ] || return 0
    pkill -x quickshell 2>/dev/null || true
    pkill -x swaync 2>/dev/null || true
    pkill -x mako 2>/dev/null || true
}

start_daemon() {
    local selected
    selected=$(backend)
    if [ "$selected" = quickshell ]; then
        if [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ]; then
            pkill -x swaync 2>/dev/null || true
            pkill -x mako 2>/dev/null || true
            qs_running && return 0
        fi
        if command -v quickshell >/dev/null 2>&1; then
            # Every accent derivation rewrites Accent.qml, and every wallpaper
            # change derives an accent - so Quickshell's built-in reload toast
            # fired on each wallpaper click, announcing an internal mechanism as
            # if it were news. Suppressed for the session; `qs log` still has the
            # reload record, including failures.
            export QS_NO_RELOAD_POPUP=1
            if [ "${HYPRVEIL_NESTED_SESSION:-0}" = 1 ]; then
                exec quickshell
            fi
            exec quickshell --daemonize
        fi
        # Leaving the session with no notifications at all is the worst outcome,
        # so demote to the first fallback that is actually installed rather than
        # exiting.
        printf 'Quickshell is selected but quickshell is unavailable; falling back. Run scripts/02-install-fedora-shell.sh.\n' >&2
        selected=swaync
        command -v swaync >/dev/null 2>&1 || selected=mako
    fi

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
        case "$(backend)" in
            quickshell) qs_ipc quicksettings toggle ;;
            swaync) swaync-client -t -sw ;;
            *)
                command -v notify-send >/dev/null 2>&1 \
                    && notify-send "Mako fallback active" "Notification history is available with the Quickshell or SwayNC backend."
                ;;
        esac
        ;;
    dnd)
        case "$(backend)" in
            quickshell) qs_ipc notifications dnd ;;
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
