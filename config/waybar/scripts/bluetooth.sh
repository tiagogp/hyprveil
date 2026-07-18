#!/usr/bin/env bash
# Render a resilient Bluetooth status module and open Blueman on demand.
set -uo pipefail

empty() {
    jq -nc --arg state "${1:-unavailable}" \
        '{text:"", tooltip:"", class:["bluetooth", $state]}'
}

pango_escape() {
    jq -nr --arg value "$1" \
        '$value | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;") | gsub("\"";"&quot;") | gsub("'"'"'";"&apos;")'
}

render() {
    local controller controller_info powered line mac info name battery tooltip="" count=0
    local -a details=()

    command -v jq >/dev/null 2>&1 || { printf '{"text":"","tooltip":""}\n'; return; }
    command -v bluetoothctl >/dev/null 2>&1 || { empty unavailable; return; }

    controller=$(bluetoothctl list 2>/dev/null | head -n 1) || true
    [ -n "$controller" ] || { empty unavailable; return; }
    controller=$(awk '{print $2}' <<<"$controller")
    controller_info=$(bluetoothctl show "$controller" 2>/dev/null) || { empty unavailable; return; }
    powered=$(awk -F: '/^[[:space:]]*Powered:/ {gsub(/^[[:space:]]+/, "", $2); print tolower($2); exit}' <<<"$controller_info")
    if [ "$powered" = no ]; then
        jq -nc '{text:"󰂲", tooltip:"Bluetooth disabled", class:["bluetooth","disabled"]}'
        return
    fi
    [ "$powered" = yes ] || { empty unavailable; return; }

    while IFS= read -r line; do
        [[ "$line" == Device\ * ]] || continue
        mac=${line#Device }
        mac=${mac%% *}
        info=$(bluetoothctl info "$mac" 2>/dev/null) || continue
        grep -qi '^[[:space:]]*Connected:[[:space:]]*yes' <<<"$info" || continue
        name=$(awk -F: '/^[[:space:]]*(Name|Alias):/ {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' <<<"$info")
        [ -n "$name" ] || name="$mac"
        battery=$(sed -n 's/.*Battery Percentage:.*(\([0-9][0-9]*\)).*/\1/p' <<<"$info" | head -n 1)
        if [ -n "$battery" ]; then
            details+=("$(pango_escape "$name") — ${battery}%")
        else
            details+=("$(pango_escape "$name")")
        fi
        count=$((count + 1))
    done < <(bluetoothctl devices 2>/dev/null || true)

    if [ "$count" -eq 0 ]; then
        jq -nc '{text:"󰂯", tooltip:"Bluetooth enabled — no connected devices", class:["bluetooth","enabled"]}'
        return
    fi

    printf -v tooltip 'Connected device%s' "$([ "$count" -eq 1 ] || printf s)"
    for line in "${details[@]}"; do
        tooltip+=$'\n'"$line"
    done
    jq -nc --arg tooltip "$tooltip" --arg count "$count" \
        '{text:"󰂱", tooltip:$tooltip, class:["bluetooth","connected"], percentage:($count|tonumber)}'
}

open_manager() {
    if command -v blueman-manager >/dev/null 2>&1; then
        setsid -f blueman-manager >/dev/null 2>&1
        return
    fi
    printf 'Bluetooth manager is unavailable: install blueman.\n' >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal "Bluetooth manager unavailable" "Install Blueman to manage Bluetooth devices."
    fi
}

case "${1:-render}" in
    render) render ;;
    open) open_manager ;;
    *) printf 'usage: %s [render|open]\n' "$0" >&2; exit 2 ;;
esac
