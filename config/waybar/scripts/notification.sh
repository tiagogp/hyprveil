#!/usr/bin/env bash
# Waybar bridge for SwayNC's streaming JSON and the supported Mako fallback.
set -uo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
STATE_FILE="$STATE_HOME/notification-backend"
DAEMON_HELPER="${HYPRVEIL_NOTIFICATION_HELPER:-$HOME/.config/hypr/scripts/notification-daemon.sh}"
CLIENT_PID=

cleanup() {
    if [ -n "$CLIENT_PID" ]; then
        kill "$CLIENT_PID" 2>/dev/null || true
        wait "$CLIENT_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 0' INT TERM

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

mako_render() {
    local alt=none tooltip='Mako fallback — right-click toggles do-not-disturb'
    if command -v makoctl >/dev/null 2>&1 \
        && makoctl mode 2>/dev/null | grep -Fxq do-not-disturb; then
        alt=dnd-none
        tooltip='Mako fallback — do-not-disturb enabled'
    fi
    printf '{"text":"","alt":"%s","class":"%s","tooltip":"%s"}\n' "$alt" "$alt" "$tooltip"
}

listen() {
    local selected
    while :; do
        selected=$(backend)
        if [ "$selected" = swaync ]; then
            if command -v swaync-client >/dev/null 2>&1; then
                # Upstream's -swb stream supplies count plus empty, populated,
                # DND, and inhibitor alt states for Waybar's format-icons map.
                swaync-client -swb &
                CLIENT_PID=$!
                while kill -0 "$CLIENT_PID" 2>/dev/null \
                    && [ "$(backend)" = swaync ]; do
                    sleep 2
                done
                cleanup
                CLIENT_PID=
                sleep 1
            else
                printf '{"text":"","alt":"none","class":"unavailable","tooltip":"SwayNC unavailable"}\n'
                sleep 2
            fi
        else
            mako_render
            sleep 2
        fi
    done
}

case "${1:-listen}" in
    listen) listen ;;
    render)
        if [ "$(backend)" = swaync ] && command -v swaync-client >/dev/null 2>&1; then
            exec swaync-client -swb
        fi
        mako_render
        ;;
    toggle|dnd) exec "$DAEMON_HELPER" "$1" ;;
    *) printf 'Usage: %s listen|render|toggle|dnd\n' "$0" >&2; exit 2 ;;
esac
