#!/usr/bin/env bash
# Hardware-aware key actions. Missing laptop hardware is a supported no-op.
set -euo pipefail

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
    *)
        printf 'Usage: %s brightness-up|brightness-down\n' "${0##*/}" >&2
        exit 2
        ;;
esac
