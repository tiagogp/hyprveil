#!/usr/bin/env bash
# Typed, versioned, atomically-written shell settings — the "config
# versionada própria" the roadmap asks for: Panel/Preferences.qml edits THIS
# file through this script, never the generated QML/hyprland.conf directly.
#
# Same shape as dock-lib.sh/wallpaper.sh: flock + tmp + mv, jq for structure.
set -euo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
SETTINGS_FILE="$STATE_HOME/settings.json"
LOCK_FILE="$STATE_HOME/settings.lock"

# Bump this and add a case to `migrate` below whenever a stored key changes
# shape or meaning — never reinterpret an old value silently.
CURRENT_VERSION=1

message() { printf '%s\n' "$*" >&2; }

defaults() {
    jq -nc --argjson v "$CURRENT_VERSION" '{
        version: $v,
        bar: { workspacesMode: "dynamic" },
        dock: { autohide: false },
        accent: { provider: "hyprveil" },
        modules: {
            calmMode: false,
            launcherProviders: { files: false, calculator: true, emoji: false }
        },
        # "focused" always follows Hyprland.focusedMonitor; a connector name
        # (e.g. "eDP-1") pins every single-instance popup (launcher, quick
        # settings, calendar, integrations) to that screen regardless of
        # focus.
        preferences: { popupMonitor: "focused" },
        # Per-connector-name overrides, e.g. {"DP-2": {"dockAutohide": true}}.
        # A monitor with no entry here inherits every global default above —
        # this object only ever holds the DIFFERENCE from the default.
        monitors: {},
        # Named snapshots of the settings above (never wallpaper/accent
        # colors, which stay owned by wallpaper.sh/accent.sh) plus the one
        # snapshot needed to undo the last apply — see scenes.sh.
        scenes: { profiles: {}, previous: null }
    }'
}

# Recursive merge: stored keys win over defaults, but a key the defaults
# schema no longer has is dropped, and a key defaults gained is filled in.
# This is what lets an older settings.json load cleanly after an upgrade
# instead of a component reading `undefined` for a field it now expects.
merge_defaults() {
    jq -c --slurpfile d <(defaults) '. as $stored | $d[0] * $stored' <<<"$1" 2>/dev/null
}

migrate() {
    local json=$1
    # No migrations exist yet (schema started at v1); this is the hook future
    # versions add a case to, e.g.:
    #   local version; version=$(jq -r '.version // 0' <<<"$json")
    #   if [ "$version" -lt 2 ]; then json=$(jq '...' <<<"$json"); fi
    printf '%s' "$json"
}

settings_write_locked() {
    local json=$1 tmp
    mkdir -p "$STATE_HOME"
    tmp=$(mktemp "$STATE_HOME/.settings.XXXXXX")
    printf '%s\n' "$json" > "$tmp"
    mv -f "$tmp" "$SETTINGS_FILE"
}

settings_valid() {
    jq -e 'type == "object" and (.version | type == "number")' "$1" >/dev/null 2>&1
}

cmd_get() {
    mkdir -p "$STATE_HOME"
    if [ ! -e "$SETTINGS_FILE" ] || ! settings_valid "$SETTINGS_FILE"; then
        (
            flock -x 200
            if [ ! -e "$SETTINGS_FILE" ] || ! settings_valid "$SETTINGS_FILE"; then
                if [ -e "$SETTINGS_FILE" ]; then
                    local backup
                    backup="$SETTINGS_FILE.invalid-$(date +%Y%m%d-%H%M%S)"
                    cp -a "$SETTINGS_FILE" "$backup" 2>/dev/null || true
                    message "Malformed settings were backed up to $backup; defaults were restored."
                fi
                settings_write_locked "$(defaults)"
            fi
        ) 200>"$LOCK_FILE"
    fi
    local raw migrated merged
    raw=$(cat "$SETTINGS_FILE")
    migrated=$(migrate "$raw")
    merged=$(merge_defaults "$migrated")
    [ -n "$merged" ] || merged=$(defaults)
    if [ "$merged" != "$raw" ]; then
        (flock -x 200; settings_write_locked "$merged") 200>"$LOCK_FILE"
    fi
    printf '%s\n' "$merged"
}

cmd_set() {
    local json=${1:?usage: settings-store.sh set '<json object>'}
    jq -e 'type == "object"' <<<"$json" >/dev/null 2>&1 \
        || { message "settings-store.sh set: not a JSON object"; exit 1; }
    # mkdir BEFORE the subshell: `(...) 200>"$LOCK_FILE"` opens that redirect
    # in the CURRENT shell before the subshell body ever runs, so on a
    # brand-new install (nothing has called `get` yet) the open failed with
    # "No such file or directory" if the directory did not already exist.
    mkdir -p "$STATE_HOME"
    (
        flock -x 200
        # Merged onto the CURRENT stored (already defaulted/migrated)
        # settings, not onto raw defaults — merge_defaults's `$d[0] * $stored`
        # is "defaults, with $stored's keys winning", which is right for
        # normalizing a full file (cmd_get) but wrong for a partial PATCH: a
        # `set` that only touches `dock` must not silently reset `accent`,
        # `modules`, and everything else back to its default value.
        local raw current merged
        if [ -e "$SETTINGS_FILE" ] && settings_valid "$SETTINGS_FILE"; then
            raw=$(cat "$SETTINGS_FILE")
        else
            raw=$(defaults)
        fi
        current=$(merge_defaults "$(migrate "$raw")")
        [ -n "$current" ] || current=$(defaults)
        merged=$(jq -c --argjson patch "$json" '. * $patch' <<<"$current")
        settings_write_locked "$merged"
    ) 200>"$LOCK_FILE"
}

cmd_reset() {
    mkdir -p "$STATE_HOME"
    (flock -x 200; settings_write_locked "$(defaults)") 200>"$LOCK_FILE"
}

# `set`'s patch is a deep MERGE (jq's `*`): it can add or overwrite a key,
# but a key present on disk and absent from the patch survives, because a
# merge has no way to say "and this one is gone now". Deleting a scene by
# name needs an actual delete, so this is its own narrow command rather than
# a generic jq-path argument — one exact, safe operation instead of handing
# an arbitrary jq filter to a script other tools shell out to.
cmd_unset_scene() {
    local name=${1:?usage: settings-store.sh unset-scene <name>}
    mkdir -p "$STATE_HOME"
    (
        flock -x 200
        local raw current updated
        if [ -e "$SETTINGS_FILE" ] && settings_valid "$SETTINGS_FILE"; then
            raw=$(cat "$SETTINGS_FILE")
        else
            raw=$(defaults)
        fi
        current=$(merge_defaults "$(migrate "$raw")")
        [ -n "$current" ] || current=$(defaults)
        updated=$(jq -c --arg name "$name" 'del(.scenes.profiles[$name])' <<<"$current")
        settings_write_locked "$updated"
    ) 200>"$LOCK_FILE"
}

case "${1:-}" in
    get)         cmd_get ;;
    set)         shift; cmd_set "$@" ;;
    reset)       cmd_reset ;;
    unset-scene) shift; cmd_unset_scene "$@" ;;
    *)
        printf 'Usage: %s get|set <json>|reset|unset-scene <name>\n' "${0##*/}" >&2
        exit 2
        ;;
esac
