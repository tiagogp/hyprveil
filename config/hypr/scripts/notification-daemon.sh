#!/usr/bin/env bash
# Single entrypoint for the persisted Quickshell/SwayNC/Mako notification
# backend. Quickshell is a shell that also serves notifications; SwayNC and Mako
# are notification-only fallbacks. Only ever one daemon runs.
set -uo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
STATE_FILE="$STATE_HOME/notification-backend"
PROFILE_FILE="$STATE_HOME/shell-profile"

shell_profile() {
    local profile=default
    if [ -r "$PROFILE_FILE" ]; then IFS= read -r profile < "$PROFILE_FILE" || true; fi
    case "$profile" in default|recovery) printf '%s\n' "$profile" ;; *) printf 'default\n' ;; esac
}

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

# Quickshell ships TWO names for the same binary — `quickshell` and the short
# `qs` — and an instance started as one is invisible to a check for the other.
# Matching only `quickshell` meant `restart` left a `qs` instance alive, and
# start_daemon then launched a second shell on top of it: two bars, two docks,
# two notification servers racing for the bus name.
QS_NAMES=(quickshell qs)

qs_running() {
    local name
    command -v quickshell >/dev/null 2>&1 || command -v qs >/dev/null 2>&1 || return 1
    for name in "${QS_NAMES[@]}"; do
        pgrep -x "$name" >/dev/null 2>&1 && return 0
    done
    return 1
}

# There is no toolchain gate here: Quickshell reads QML directly, so it has
# nothing to compile before it can start.
#
# No -c: the shell is deployed flat at ~/.config/quickshell/shell.qml, which is
# Quickshell's default config path, so both the launch and the IPC target the
# default instance.
shell_cli() {
    command -v hyprveil >/dev/null 2>&1 || return 1
    hyprveil shell "$@" >/dev/null 2>&1
}

stop_daemons() {
    # A nested validation shell has an isolated D-Bus but shares the host process
    # namespace. Never let it kill notification daemons in the parent session.
    [ "${HYPRVEIL_NESTED_SESSION:-0}" != 1 ] || return 0
    local name
    # Both names, or restart orphans the instance it failed to match. See
    # QS_NAMES.
    for name in "${QS_NAMES[@]}"; do
        pkill -x "$name" 2>/dev/null || true
    done
    pkill -x swaync 2>/dev/null || true
    pkill -x mako 2>/dev/null || true
    pkill -x waybar 2>/dev/null || true
}

start_recovery_bar() {
    command -v waybar >/dev/null 2>&1 || {
        printf 'Recovery profile: Waybar is unavailable.\n' >&2
        return 1
    }
    if ! pgrep -x waybar >/dev/null 2>&1; then
        waybar >/dev/null 2>&1 &
    fi
}

start_daemon() {
    local selected
    selected=$(backend)
    if [ "$(shell_profile)" = default ]; then
        selected=quickshell
        pkill -x waybar 2>/dev/null || true
    else
        for name in "${QS_NAMES[@]}"; do pkill -x "$name" 2>/dev/null || true; done
        start_recovery_bar || true
        [ "$selected" != quickshell ] || {
            selected=swaync
            command -v swaync >/dev/null 2>&1 || selected=mako
        }
    fi
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
        if [ "$(shell_profile)" = default ]; then shell_cli toggle quick-settings; exit $?; fi
        case "$(backend)" in
            quickshell) shell_cli toggle quick-settings ;;
            swaync) swaync-client -t -sw ;;
            *)
                command -v notify-send >/dev/null 2>&1 \
                    && notify-send "Mako fallback active" "Notification history is available with the Quickshell or SwayNC backend."
                ;;
        esac
        ;;
    dnd)
        if [ "$(shell_profile)" = default ]; then shell_cli dnd toggle; exit $?; fi
        case "$(backend)" in
            quickshell) shell_cli dnd toggle ;;
            swaync) swaync-client -d -sw ;;
            *) makoctl mode -t do-not-disturb ;;
        esac
        ;;
    backend) backend ;;
    profile) shell_profile ;;
    *)
        printf 'Usage: %s start|stop|restart|toggle|dnd|backend|profile\n' "$0" >&2
        exit 2
        ;;
esac
