#!/usr/bin/env bash
# Launch Hyprveil nested with every user-writable XDG path isolated in a temp tree.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND=quickshell
KEEP=0

usage() {
    cat <<'EOF'
Usage: 08-test-nested-session.sh [--backend quickshell|swaync|mako] [--keep-stage]

Launches Hyprland with a staged copy of this repository. HOME, XDG_CONFIG_HOME,
XDG_STATE_HOME, XDG_CACHE_HOME, XDG_DATA_HOME, and XDG_RUNTIME_DIR all point into
the stage, so the nested shell cannot modify the real user's config or state.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --backend)
            shift
            BACKEND=${1:-}
            ;;
        --keep-stage) KEEP=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

case "$BACKEND" in
    quickshell|swaync|mako) ;;
    *) printf 'Backend must be quickshell, swaync, or mako.\n' >&2; exit 2 ;;
esac

for command in Hyprland dbus-run-session jq; do
    command -v "$command" >/dev/null 2>&1 || {
        printf '%s is required for the nested-session check.\n' "$command" >&2
        exit 1
    }
done
[ -n "${WAYLAND_DISPLAY:-}" ] || {
    printf 'Run this check from an existing Wayland session.\n' >&2
    exit 1
}

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-nested.XXXXXX")
cleanup() {
    if [ "$KEEP" -eq 1 ]; then
        printf 'Nested stage retained at %s\n' "$STAGE"
    else
        rm -rf "$STAGE"
    fi
}
trap cleanup EXIT

STAGE_HOME="$STAGE/home"
STAGE_CONFIG="$STAGE/config"
STAGE_STATE="$STAGE/state"
STAGE_CACHE="$STAGE/cache"
STAGE_DATA="$STAGE/data"
STAGE_RUNTIME="$STAGE/runtime"
mkdir -p "$STAGE_HOME" "$STAGE_CONFIG" "$STAGE_STATE/hyprveil" \
    "$STAGE_CACHE" "$STAGE_DATA" "$STAGE_RUNTIME"
chmod 700 "$STAGE_RUNTIME"
ln -s "$STAGE_CONFIG" "$STAGE_HOME/.config"
cp -a "$REPO/config/." "$STAGE_CONFIG/"
cp -a "$REPO/config/hypr/wallpaper-default.jpg" \
    "$STAGE_CONFIG/hypr/wallpaper-default.jpg"
chmod +x "$STAGE_CONFIG/hypr/scripts/"*.sh "$STAGE_CONFIG/waybar/scripts/"*.sh

printf '%s\n' "$BACKEND" > "$STAGE_STATE/hyprveil/notification-backend"
printf '[]\n' > "$STAGE_STATE/hyprveil/dock-pins.json"
jq -nc --arg path "$STAGE_CONFIG/hypr/wallpaper-default.jpg" \
    '{version:1, fallback:{path:$path, fit:"cover"}, monitors:{}}' \
    > "$STAGE_STATE/hyprveil/wallpapers.json"
chmod 600 "$STAGE_STATE/hyprveil/notification-backend" \
    "$STAGE_STATE/hyprveil/dock-pins.json" "$STAGE_STATE/hyprveil/wallpapers.json"

# Exercise generation of both profiles before restoring the nested default.
for profile in standard reduced standard; do
    env -u HYPRLAND_INSTANCE_SIGNATURE \
        HOME="$STAGE_HOME" XDG_CONFIG_HOME="$STAGE_CONFIG" XDG_STATE_HOME="$STAGE_STATE" \
        HYPRVEIL_CONFIG_HOME="$STAGE_CONFIG" HYPRVEIL_STATE_HOME="$STAGE_STATE/hyprveil" \
        "$STAGE_CONFIG/hypr/scripts/motion-profile.sh" "$profile" >/dev/null
done

# The distributed config uses the conventional ~/.config path. Point every source
# in the staged copy at the isolated tree, including generated active profiles.
while IFS= read -r file; do
    sed -i "s|~/.config/hypr|$STAGE_CONFIG/hypr|g" "$file"
done < <(find "$STAGE_CONFIG/hypr" -type f -name '*.conf')

printf 'Nested isolation root: %s\n' "$STAGE"
printf 'Backend: %s; motion profiles: standard and reduced preflighted.\n' "$BACKEND"
printf 'Exit the nested session with SUPER+SHIFT+Q.\n'

XDG_RUNTIME_DIR="$STAGE_RUNTIME" dbus-run-session -- env -u HYPRLAND_INSTANCE_SIGNATURE \
    HOME="$STAGE_HOME" \
    XDG_CONFIG_HOME="$STAGE_CONFIG" \
    XDG_STATE_HOME="$STAGE_STATE" \
    XDG_CACHE_HOME="$STAGE_CACHE" \
    XDG_DATA_HOME="$STAGE_DATA" \
    XDG_RUNTIME_DIR="$STAGE_RUNTIME" \
    HYPRVEIL_CONFIG_HOME="$STAGE_CONFIG" \
    HYPRVEIL_STATE_HOME="$STAGE_STATE/hyprveil" \
    HYPRVEIL_NESTED_STAGE="$STAGE" \
    HYPRVEIL_NESTED_SESSION=1 \
    Hyprland -c "$STAGE_CONFIG/hypr/hyprland.conf"
