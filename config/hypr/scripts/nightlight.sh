#!/usr/bin/env bash
# Night light: starts/stops the hyprsunset daemon. hyprsunset owns the color-
# temperature transition itself and reverts the display the moment it exits,
# so "off" here is simply "the daemon is not running" rather than a second
# command that has to restore neutral color.
set -euo pipefail

TEMPERATURE="${HYPRVEIL_NIGHTLIGHT_TEMP:-4000}"

is_running() { pgrep -x hyprsunset >/dev/null 2>&1; }

turn_on() {
    is_running && return 0
    command -v hyprsunset >/dev/null 2>&1 || {
        printf 'nightlight.sh: hyprsunset is not installed\n' >&2
        exit 1
    }
    hyprsunset -t "$TEMPERATURE" >/dev/null 2>&1 &
    disown
}

turn_off() {
    pkill -x hyprsunset >/dev/null 2>&1 || true
}

case "${1:-toggle}" in
    on)     turn_on ;;
    off)    turn_off ;;
    toggle)
        if is_running; then turn_off; else turn_on; fi
        ;;
    status)
        command -v hyprsunset >/dev/null 2>&1 || { printf 'missing\n'; exit 0; }
        is_running && printf 'on\n' || printf 'off\n'
        ;;
    *)
        printf 'Usage: %s on|off|toggle|status\n' "${0##*/}" >&2
        exit 2
        ;;
esac
