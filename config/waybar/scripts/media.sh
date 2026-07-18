#!/usr/bin/env bash
# Select one active MPRIS player and expose Waybar rendering and controls.
set -uo pipefail

MAX_LABEL_LENGTH=${HYPRVEIL_MEDIA_MAX_LENGTH:-48}

select_player() {
    local player status first_paused=""
    command -v playerctl >/dev/null 2>&1 || return 1
    while IFS= read -r player; do
        [ -n "$player" ] || continue
        status=$(playerctl --player="$player" status 2>/dev/null) || continue
        case "$status" in
            Playing) printf '%s\t%s\n' "$player" "$status"; return 0 ;;
            Paused) [ -n "$first_paused" ] || first_paused="$player" ;;
        esac
    done < <(playerctl --list-all 2>/dev/null || true)
    [ -n "$first_paused" ] || return 1
    printf '%s\tPaused\n' "$first_paused"
}

escape_markup() {
    jq -nr --arg value "$1" \
        '$value | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;") | gsub("\"";"&quot;") | gsub("'"'"'";"&apos;")'
}

empty() {
    jq -nc '{text:"", tooltip:"", class:["media","unavailable"]}'
}

render() {
    local part=${1:-label} selected player status artist title label short icon tooltip
    command -v jq >/dev/null 2>&1 || { printf '{"text":"","tooltip":""}\n'; return; }
    selected=$(select_player) || { empty; return; }
    player=${selected%%$'\t'*}
    status=${selected#*$'\t'}

    case "$part" in
        previous) icon="󰒮"; tooltip="Previous" ;;
        toggle)
            [ "$status" = Playing ] && icon="󰏤" || icon="󰐊"
            tooltip="$([ "$status" = Playing ] && printf Pause || printf Play)"
            ;;
        next) icon="󰒭"; tooltip="Next" ;;
        label)
            artist=$(playerctl --player="$player" metadata artist 2>/dev/null || true)
            title=$(playerctl --player="$player" metadata title 2>/dev/null || true)
            if [ -n "$artist" ] && [ -n "$title" ]; then
                label="$artist — $title"
            else
                label=${title:-${artist:-$player}}
            fi
            short=$(jq -nr --arg value "$label" --argjson max "$MAX_LABEL_LENGTH" \
                '$value | if length > $max then .[0:($max - 1)] + "…" else . end')
            short=$(escape_markup "$short")
            tooltip=$(escape_markup "$label")
            jq -nc --arg text "$short" --arg tooltip "$tooltip" --arg status "${status,,}" \
                '{text:$text, tooltip:$tooltip, class:["media",$status]}'
            return
            ;;
        *) printf 'unknown media render part: %s\n' "$part" >&2; exit 2 ;;
    esac
    jq -nc --arg text "$icon" --arg tooltip "$tooltip" --arg status "${status,,}" \
        '{text:$text, tooltip:$tooltip, class:["media","control",$status]}'
}

control() {
    local action=$1 selected player
    selected=$(select_player) || return 0
    player=${selected%%$'\t'*}
    playerctl --player="$player" "$action" >/dev/null 2>&1 || true
}

case "${1:-render}" in
    render) render "${2:-label}" ;;
    previous) control previous ;;
    toggle) control play-pause ;;
    next) control next ;;
    *) printf 'usage: %s render [label|previous|toggle|next] | previous | toggle | next\n' "$0" >&2; exit 2 ;;
esac
