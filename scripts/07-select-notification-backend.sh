#!/usr/bin/env bash
# Persist the notification daemon used by startup, keybindings, and Waybar.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

BACKEND=
ENSURE=0
STATE_INVALID=0

usage() {
    cat <<'EOF'
Usage: 07-select-notification-backend.sh [--ensure] [--backend swaync|mako]

SwayNC is the default full notification center. Mako is the supported fallback
for systems where the SwayNC COPR was declined or is unavailable. With --ensure,
an existing valid choice is retained without prompting or changing it.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --ensure) ENSURE=1 ;;
        --backend) shift; BACKEND=${1:-} ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

valid_backend() { [[ "$1" = swaync || "$1" = mako ]]; }

saved=
if [ -f "$HV_NOTIFICATION_STATE" ]; then
    IFS= read -r saved < "$HV_NOTIFICATION_STATE" || true
    valid_backend "$saved" || STATE_INVALID=1
fi

if [ -z "$BACKEND" ] && valid_backend "$saved"; then
    BACKEND=$saved
fi

if [ "$ENSURE" -eq 1 ] && valid_backend "$BACKEND"; then
    printf 'Keeping saved notification backend: %s\n' "$BACKEND"
fi

if ! valid_backend "$BACKEND"; then
    if [ ! -t 0 ]; then
        printf 'No saved notification backend; pass --backend swaync|mako.\n' >&2
        exit 2
    fi
    read -r -p 'Notification backend (swaync/mako) [swaync]: ' BACKEND
    BACKEND=${BACKEND:-swaync}
fi
valid_backend "$BACKEND" || { printf 'Invalid notification backend: %s\n' "$BACKEND" >&2; exit 2; }

mkdir -p "$HV_STATE_HOME"
if [ "$STATE_INVALID" -eq 1 ]; then
    invalid_backup="$HV_NOTIFICATION_STATE.invalid-$(date +%Y%m%d-%H%M%S)"
    cp -a "$HV_NOTIFICATION_STATE" "$invalid_backup"
    printf 'Malformed prior notification backend preserved at %s\n' "$invalid_backup" >&2
fi
state_tmp=$(mktemp "$HV_STATE_HOME/.notification-backend.XXXXXX")
printf '%s\n' "$BACKEND" > "$state_tmp"
chmod 600 "$state_tmp"
mv -f "$state_tmp" "$HV_NOTIFICATION_STATE"

printf 'Notification backend selected: %s\n' "$BACKEND"
if [ "$BACKEND" = mako ]; then
    printf 'Mako fallback selected: popup notifications and DND remain available; history requires SwayNC.\n'
fi

# An explicit live switch should not require logout. The Waybar bridge observes
# this state file, and the installed launcher safely replaces the running daemon.
if [ "$saved" != "$BACKEND" ] \
    && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}${WAYLAND_DISPLAY:-}" ] \
    && [ -x "$HV_CONFIG_HOME/hypr/scripts/notification-daemon.sh" ]; then
    if command -v "$BACKEND" >/dev/null 2>&1; then
        HYPRVEIL_STATE_HOME="$HV_STATE_HOME" \
            "$HV_CONFIG_HOME/hypr/scripts/notification-daemon.sh" restart
        printf 'Restarted the live notification backend; Waybar will follow the new state.\n'
    else
        printf 'Backend saved; install %s before switching the live session.\n' "$BACKEND" >&2
    fi
fi
