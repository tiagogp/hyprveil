#!/usr/bin/env bash
# Hardware-aware key actions. Missing laptop hardware is a supported no-op.
set -euo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
BRIGHTNESS_STATE_FILE="$STATE_HOME/brightness"

have_backlight() {
    command -v brightnessctl >/dev/null 2>&1 || return 1
    shopt -s nullglob
    local backlights=("${HYPRVEIL_SYSFS_ROOT:-/sys}"/class/backlight/*)
    [ "${#backlights[@]}" -gt 0 ]
}

# Persists the current brightness percent before sleep. Many laptops reset the
# panel's backlight to a firmware default (often near-max) across a
# suspend/resume cycle, independent of what the OS last set — writing the
# value back afterward (restore_brightness, below) is what actually corrects
# the hardware register, not a cosmetic match of the old percentage.
save_brightness() {
    have_backlight || exit 0
    local percent
    # Same field (4) osd-action.sh already reads from `brightnessctl -m`:
    # device,class,current,percent%,max.
    percent=$(brightnessctl -m 2>/dev/null | awk -F, '{ gsub(/%/, "", $4); print $4; exit }')
    [[ "$percent" =~ ^[0-9]+$ ]] || exit 0
    mkdir -p "$STATE_HOME"
    local tmp
    tmp=$(mktemp "$STATE_HOME/.brightness.XXXXXX") || exit 0
    printf '%s\n' "$percent" > "$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$BRIGHTNESS_STATE_FILE"
}

# Restores the saved brightness after resume, ramping up from a low floor
# rather than snapping straight to the target so waking in the dark isn't a
# jarring flash. The floor write is what forces the backlight register back to
# a sane value; the ramp on top of it is the secondary nicety.
restore_brightness() {
    have_backlight || exit 0
    [ -r "$BRIGHTNESS_STATE_FILE" ] || exit 0
    local target
    IFS= read -r target < "$BRIGHTNESS_STATE_FILE" || exit 0
    [[ "$target" =~ ^[0-9]+$ ]] || exit 0
    [ "$target" -le 100 ] || target=100

    local floor=2 steps=4 i level
    if [ "$target" -lt "$floor" ]; then floor=$target; fi
    brightnessctl set "${floor}%" >/dev/null 2>&1 || true
    sleep 0.05
    for i in 1 2 3 4; do
        level=$(( floor + (target - floor) * i / steps ))
        brightnessctl set "${level}%" >/dev/null 2>&1 || true
        if [ "$i" -lt "$steps" ]; then sleep 0.05; fi
    done
    return 0
}

case "${1:-}" in
    brightness-up|brightness-down)
        if ! command -v brightnessctl >/dev/null 2>&1; then
            exit 0
        fi
        shopt -s nullglob
        backlights=("${HYPRVEIL_SYSFS_ROOT:-/sys}"/class/backlight/*)
        [ "${#backlights[@]}" -gt 0 ] || exit 0
        if [ "$1" = brightness-up ]; then
            exec brightnessctl set 5%+
        else
            exec brightnessctl set 5%-
        fi
        ;;
    brightness-save) save_brightness ;;
    brightness-restore) restore_brightness ;;
    *)
        printf 'Usage: %s brightness-up|brightness-down|brightness-save|brightness-restore\n' "${0##*/}" >&2
        exit 2
        ;;
esac
