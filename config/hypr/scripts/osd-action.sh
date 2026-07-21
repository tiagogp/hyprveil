#!/usr/bin/env bash
# Media-key actions with a coalesced Quickshell on-screen display.
set -euo pipefail

show_osd() {
    command -v qs >/dev/null 2>&1 || return 0
    qs ipc call osd show "$@" >/dev/null 2>&1 || true
}

audio_state() {
    local node=$1 label=$2 output volume muted=false

    command -v wpctl >/dev/null 2>&1 || return 0
    output=$(wpctl get-volume "$node" 2>/dev/null || true)
    [ -n "$output" ] || return 0

    volume=$(printf '%s\n' "$output" | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+(\.[0-9]+)?$/) {
                    printf "%.0f", $i * 100
                    exit
                }
            }
        }
    ')
    [ -n "$volume" ] || return 0
    [[ "$output" != *"[MUTED]"* ]] || muted=true

    show_osd "$label" "$volume" "$muted"
}

has_backlight() {
    shopt -s nullglob
    local backlights=("${HYPRVEIL_SYSFS_ROOT:-/sys}"/class/backlight/*)
    [ "${#backlights[@]}" -gt 0 ]
}

brightness_state() {
    local percent

    command -v brightnessctl >/dev/null 2>&1 || return 0
    has_backlight || return 0
    percent=$(brightnessctl -m 2>/dev/null | awk -F, '{ gsub(/%/, "", $4); print $4; exit }')
    [ -n "$percent" ] || return 0

    show_osd brightness "$percent" false
}

case "${1:-}" in
    volume-up)
        command -v wpctl >/dev/null 2>&1 || exit 0
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 2%+
        audio_state @DEFAULT_AUDIO_SINK@ volume
        ;;
    volume-down)
        command -v wpctl >/dev/null 2>&1 || exit 0
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-
        audio_state @DEFAULT_AUDIO_SINK@ volume
        ;;
    volume-mute)
        command -v wpctl >/dev/null 2>&1 || exit 0
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        audio_state @DEFAULT_AUDIO_SINK@ volume
        ;;
    microphone-mute)
        command -v wpctl >/dev/null 2>&1 || exit 0
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        audio_state @DEFAULT_AUDIO_SOURCE@ microphone
        ;;
    brightness-up)
        command -v brightnessctl >/dev/null 2>&1 || exit 0
        has_backlight || exit 0
        brightnessctl set 5%+
        brightness_state
        ;;
    brightness-down)
        command -v brightnessctl >/dev/null 2>&1 || exit 0
        has_backlight || exit 0
        brightnessctl set 5%-
        brightness_state
        ;;
    *)
        printf 'Usage: %s volume-up|volume-down|volume-mute|microphone-mute|brightness-up|brightness-down\n' "${0##*/}" >&2
        exit 2
        ;;
esac
