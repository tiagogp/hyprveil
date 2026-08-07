#!/usr/bin/env bash
# Optional Matugen accent provider — the roadmap's "Matugen opcional".
#
# Hyprveil's own extraction algorithm (accent.sh from-wallpaper) stays the
# default and needs nothing installed. This is an ALTERNATIVE source for the
# one thing accent.sh actually consumes — a single #rrggbb — for anyone who
# wants Matugen's Material You extraction instead. It does not replace
# accent.sh's rendering pipeline: matugen-adapter.sh only asks Matugen for a
# primary color and hands it to `accent.sh set`, so every consumer accent.sh
# already renders into (Hyprland, GTK, rofi, kitty, mako, qt5ct/qt6ct,
# wlogout) stays correct without a second render path to maintain.
#
# Selected by `accent.provider` in settings.json ("hyprveil" default,
# "matugen" to opt in — see Settings.qml/Panel/Preferences.qml). Missing
# matugen is neutral, not an error: this prints a message and exits 0,
# leaving the accent exactly as it was, the same contract doctor.sh already
# reports for this dependency.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCENT_SH="$SCRIPT_DIR/accent.sh"

message() { printf '%s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: matugen-adapter.sh from-wallpaper PATH

Runs `matugen image PATH --json hex` and hands its primary color to
`accent.sh set`. Missing matugen or unparsable output leaves the accent
untouched and exits 0 with a message on stderr — this is an OPTIONAL
provider, never a hard dependency.
EOF
}

# Matugen's --json output nests each role under a mode. The exact shape has
# moved between Matugen releases, so this tries every layout that has been
# observed in the wild, in order, rather than committing to one — a provider
# that only works against one exact version is not "opcional", it is
# "usually broken".
extract_primary() {
    local json=$1
    jq -r '
        (.colors.primary.dark // .colors.primary.light // .colors.primary)
        // (.primary.dark // .primary.light // .primary)
        // .colors.source_color.hex
        // empty
    ' <<<"$json" 2>/dev/null | head -n1
}

from_wallpaper_command() {
    local path=${1:-} json hex
    [ -n "$path" ] || { message "matugen-adapter.sh: from-wallpaper requires an image path"; exit 2; }
    [ -f "$path" ] || { message "matugen-adapter.sh: no such file: $path"; exit 1; }

    if ! command -v matugen >/dev/null 2>&1; then
        message "Matugen is not installed; the accent is unchanged (Hyprveil's own algorithm remains active). See: cargo install matugen"
        exit 0
    fi

    json=$(matugen image "$path" --json hex --mode dark 2>/dev/null) || json=""
    if [ -z "$json" ]; then
        message "Matugen produced no output for $path; the accent is unchanged"
        exit 0
    fi

    hex=$(extract_primary "$json")
    if [ -z "$hex" ] || [ "$hex" = null ]; then
        message "Could not find a primary color in Matugen's output; the accent is unchanged"
        exit 0
    fi
    case "$hex" in
        '#'*) : ;;
        *) hex="#$hex" ;;
    esac

    "$ACCENT_SH" set "$hex"
}

case "${1:-}" in
    from-wallpaper) shift; from_wallpaper_command "$@" ;;
    -h|--help) usage ;;
    *) usage >&2; exit 2 ;;
esac
