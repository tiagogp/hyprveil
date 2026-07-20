#!/usr/bin/env bash
# Single entrypoint for the persisted Quickshell/AGS/SwayNC/Mako notification
# backend. Quickshell and AGS are shells that also serve notifications; SwayNC
# and Mako are notification-only fallbacks. Only ever one daemon runs.
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
        quickshell|ags|swaync|mako) printf '%s\n' "$selected" ;;
        *) printf 'ags\n' ;;
    esac
}

qs_running() {
    command -v quickshell >/dev/null 2>&1 || return 1
    pgrep -x quickshell >/dev/null 2>&1
}

# Unlike AGS there is no toolchain gate here: Quickshell reads QML directly, so
# the dart-sass half of ags_ready has no counterpart.
#
# No -c: the shell is deployed flat at ~/.config/quickshell/shell.qml, which is
# Quickshell's default config path, so both the launch and the IPC target the
# default instance.
qs_ipc() {
    command -v qs >/dev/null 2>&1 || return 1
    qs ipc call "$@" >/dev/null 2>&1
}

ags_running() {
    command -v ags >/dev/null 2>&1 || return 1
    ags list 2>/dev/null | grep -Fxq "$AGS_INSTANCE"
}

# AGS compiles style.scss with dart-sass on every start, so a missing sass aborts
# the whole shell — notifications included. Both have to be present to commit.
ags_ready() {
    command -v ags >/dev/null 2>&1 && command -v sass >/dev/null 2>&1
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
    pkill -x quickshell 2>/dev/null || true
    pkill -x swaync 2>/dev/null || true
    pkill -x mako 2>/dev/null || true
}

start_daemon() {
    local selected
    selected=$(backend)
    if [ "$selected" = quickshell ]; then
        if [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ]; then
            command -v ags >/dev/null 2>&1 && ags quit -i "$AGS_INSTANCE" 2>/dev/null || true
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
        # Same reasoning as the AGS arm below: a session with no notifications
        # at all is the worst outcome, so demote rather than exit.
        printf 'Quickshell is selected but quickshell is unavailable; falling back. Run scripts/02-install-fedora-shell.sh.\n' >&2
        selected=ags
    fi

    if [ "$selected" = ags ]; then
        if [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ]; then
            pkill -x swaync 2>/dev/null || true
            pkill -x mako 2>/dev/null || true
            ags_running && return 0
        fi
        if ags_ready; then
            exec ags run
        fi
        # Leaving the session with no notifications at all is the worst outcome,
        # so demote to the first fallback that is actually installed.
        if command -v ags >/dev/null 2>&1; then
            printf 'AGS is selected but dart-sass is unavailable; falling back. Run scripts/02-install-fedora-shell.sh.\n' >&2
        else
            printf 'AGS is selected but ags is unavailable; falling back. Run scripts/02-install-fedora-shell.sh.\n' >&2
        fi
        selected=swaync
        command -v swaync >/dev/null 2>&1 || selected=mako
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
            quickshell) qs_ipc quicksettings toggle ;;
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
            quickshell) qs_ipc notifications dnd ;;
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
