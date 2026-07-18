#!/usr/bin/env bash
# Signals Waybar the instant Hyprland's focused/opened/closed window changes,
# so the dock's "active" highlight updates immediately instead of waiting on
# its polling interval (see custom/dock-N "signal" in config.jsonc). Runs for
# the whole session via hypr/autostart.conf; reconnects if the event socket
# drops (e.g. a Hyprland reload).
set -uo pipefail

command -v socat >/dev/null 2>&1 || { printf 'dock-watch: socat not found; dock falls back to its polling interval\n' >&2; exit 1; }

SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:?}/.socket2.sock"

while true; do
    socat -U - "UNIX-CONNECT:$SOCK" 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            activewindow\>\>*|activewindowv2\>\>*|openwindow\>\>*|closewindow\>\>*)
                pkill -RTMIN+8 waybar 2>/dev/null || true
                ;;
        esac
    done
    sleep 1
done
