#!/usr/bin/env bash
# Select the complete shell or the explicitly degraded recovery stack.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

PROFILE=
ENSURE=0
STATE_FILE="$HV_STATE_HOME/shell-profile"

usage() { printf 'Usage: %s [--ensure] [--profile default|recovery]\n' "${0##*/}"; }
valid() { [[ "$1" = default || "$1" = recovery ]]; }

while [ "$#" -gt 0 ]; do
    case "$1" in
        --ensure) ENSURE=1 ;;
        --profile) shift; PROFILE=${1:-} ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
    shift
done

saved=
if [ -r "$STATE_FILE" ]; then IFS= read -r saved < "$STATE_FILE" || true; fi
if [ -z "$PROFILE" ] && valid "$saved"; then PROFILE=$saved; fi
if [ -z "$PROFILE" ] && [ "$ENSURE" -eq 1 ]; then PROFILE=default; fi
if ! valid "$PROFILE"; then
    if [ ! -t 0 ]; then PROFILE=default
    else PROFILE=$(select_option "Choose shell profile" default recovery)
    fi
fi

mkdir -p "$HV_STATE_HOME"
tmp=$(mktemp "$HV_STATE_HOME/.shell-profile.XXXXXX")
printf '%s\n' "$PROFILE" > "$tmp"
chmod 600 "$tmp"
mv -f "$tmp" "$STATE_FILE"

printf 'Shell profile selected: %s\n' "$PROFILE"
if [ "$PROFILE" = recovery ]; then
    printf 'Recovery is degraded mode: Waybar plus Rofi/wlogout and SwayNC or Mako.\n'
fi

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}${WAYLAND_DISPLAY:-}" ] \
    && [ -x "$HV_CONFIG_HOME/hypr/scripts/notification-daemon.sh" ]; then
    HYPRVEIL_STATE_HOME="$HV_STATE_HOME" "$HV_CONFIG_HOME/hypr/scripts/notification-daemon.sh" restart
fi
