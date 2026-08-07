#!/usr/bin/env bash
# Typed, versioned, atomically-written shell settings — the "config
# versionada própria" the roadmap asks for: Panel/Preferences.qml edits THIS
# file through this script, never the generated QML/hyprland.conf directly.
#
# Same shape as dock-lib.sh/wallpaper.sh: flock + tmp + mv, jq for structure.
set -euo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
CONFIG_HOME="${HYPRVEIL_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
SETTINGS_DIR="$CONFIG_HOME/hyprveil"
SETTINGS_FILE="$SETTINGS_DIR/shell.json"
LEGACY_SETTINGS_FILE="$STATE_HOME/settings.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/data/settings-schema.json"
VALIDATOR="$SCRIPT_DIR/data/settings-validator.py"
LOCK_FILE="$STATE_HOME/settings.lock"
LOCK_DIR="$STATE_HOME/settings.lock.d"
LOCK_KIND=

# Bump this and add a case to `migrate` below whenever a stored key changes
# shape or meaning — never reinterpret an old value silently.
CURRENT_VERSION=2

message() { printf '%s\n' "$*" >&2; }

settings_lock() {
    mkdir -p "$STATE_HOME"
    if command -v flock >/dev/null 2>&1; then
        exec 200>"$LOCK_FILE"
        flock -x 200
        LOCK_KIND=flock
        return
    fi
    local attempts=0
    until mkdir "$LOCK_DIR" 2>/dev/null; do
        attempts=$((attempts + 1))
        [ "$attempts" -lt 200 ] || { message "timed out waiting for the settings lock"; return 1; }
        sleep 0.05
    done
    LOCK_KIND=directory
    trap settings_unlock EXIT INT TERM
}

settings_unlock() {
    case "$LOCK_KIND" in
        flock) flock -u 200 2>/dev/null || true; exec 200>&- ;;
        directory) rmdir "$LOCK_DIR" 2>/dev/null || true ;;
    esac
    LOCK_KIND=
    trap - EXIT INT TERM
}

defaults() {
    jq -c '.default' "$SCHEMA_FILE"
}

# Recursive merge: stored keys win over defaults, but a key the defaults
# schema no longer has is dropped, and a key defaults gained is filled in.
# This is what lets an older settings.json load cleanly after an upgrade
# instead of a component reading `undefined` for a field it now expects.
merge_defaults() {
    jq -c --slurpfile d <(defaults) '
        . as $s | $d[0] as $d | {
            version: 2,
            appearance: ($d.appearance * ($s.appearance // {}) |
                {accentProvider, density}),
            modules: {
                enabled: ($d.modules.enabled * ($s.modules.enabled // {}) |
                    {bar, dock, notifications, osd}),
                calmMode: ($s.modules.calmMode // $d.modules.calmMode)
            },
            bar: ($d.bar * ($s.bar // {}) | {workspacesMode, position}),
            dock: ($d.dock * ($s.dock // {}) | {autohide}),
            surfaces: ($d.surfaces * ($s.surfaces // {}) |
                {popupMonitor, rememberLastPage}),
            animation: ($d.animation * ($s.animation // {}) |
                {profile, reducedMotion}),
            accessibility: ($d.accessibility * ($s.accessibility // {}) |
                {highContrast, largeTargets}),
            providers: {
                launcher: ($d.providers.launcher * ($s.providers.launcher // {}) |
                    {files, calculator, emoji}),
                notifications: ($s.providers.notifications // $d.providers.notifications),
                wallpaper: ($s.providers.wallpaper // $d.providers.wallpaper)
            },
            monitors: (($s.monitors // {}) | with_entries(.value |=
                ({dockAutohide: .dockAutohide, barWorkspacesMode: .barWorkspacesMode}
                | with_entries(select(.value != null))))),
            scenes: ($d.scenes * ($s.scenes // {}))
        }
    ' <<<"$1" 2>/dev/null
}

migrate() {
    local json=$1
    local version
    version=$(jq -r '.version // 1' <<<"$json")
    if [ "$version" -lt 2 ]; then
        json=$(jq -c '{
            version: 2,
            appearance: {accentProvider: (.accent.provider // "hyprveil"), density: "comfortable"},
            modules: {
                enabled: {bar: true, dock: true, notifications: true, osd: true},
                calmMode: (.modules.calmMode // false)
            },
            bar: {workspacesMode: (.bar.workspacesMode // "dynamic"), position: "top"},
            dock: {autohide: (.dock.autohide // false)},
            surfaces: {popupMonitor: (.preferences.popupMonitor // "focused"), rememberLastPage: false},
            animation: {profile: "system", reducedMotion: false},
            accessibility: {highContrast: false, largeTargets: false},
            providers: {
                launcher: (.modules.launcherProviders // {files:false, calculator:true, emoji:false}),
                notifications: "quickshell", wallpaper: "hyprpaper"
            },
            monitors: (.monitors // {}),
            scenes: (.scenes // {profiles:{}, previous:null})
        }' <<<"$json")
    fi
    printf '%s' "$json"
}

settings_write_locked() {
    local json=$1 tmp
    mkdir -p "$SETTINGS_DIR"
    tmp=$(mktemp "$SETTINGS_DIR/.shell.XXXXXX")
    printf '%s\n' "$json" > "$tmp"
    mv -f "$tmp" "$SETTINGS_FILE"
}

settings_valid() {
    python3 "$VALIDATOR" --allow-v1 "$SCHEMA_FILE" "$1" >/dev/null 2>&1
}

cmd_get() {
    mkdir -p "$STATE_HOME"
    if [ ! -e "$SETTINGS_FILE" ] && [ -e "$LEGACY_SETTINGS_FILE" ]; then
        settings_lock
        if [ ! -e "$SETTINGS_FILE" ] && [ -e "$LEGACY_SETTINGS_FILE" ]; then
            mkdir -p "$SETTINGS_DIR"
            cp -a "$LEGACY_SETTINGS_FILE" "$SETTINGS_FILE"
            mv "$LEGACY_SETTINGS_FILE" "$LEGACY_SETTINGS_FILE.migrated"
            message "Legacy settings were migrated to $SETTINGS_FILE."
        fi
        settings_unlock
    fi
    if [ ! -e "$SETTINGS_FILE" ] || ! settings_valid "$SETTINGS_FILE"; then
        settings_lock
            if [ ! -e "$SETTINGS_FILE" ] || ! settings_valid "$SETTINGS_FILE"; then
                if [ -e "$SETTINGS_FILE" ]; then
                    local backup
                    backup="$SETTINGS_FILE.invalid-$(date +%Y%m%d-%H%M%S)"
                    cp -a "$SETTINGS_FILE" "$backup" 2>/dev/null || true
                    message "Malformed settings were backed up to $backup; defaults were restored."
                fi
                settings_write_locked "$(defaults)"
            fi
        settings_unlock
    fi
    local raw migrated merged
    raw=$(cat "$SETTINGS_FILE")
    migrated=$(migrate "$raw")
    merged=$(merge_defaults "$migrated")
    [ -n "$merged" ] || merged=$(defaults)
    if [ "$merged" != "$raw" ]; then
        settings_lock
        settings_write_locked "$merged"
        settings_unlock
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
    mkdir -p "$STATE_HOME" "$SETTINGS_DIR"
    settings_lock
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
        local validation_file
        validation_file=$(mktemp "$STATE_HOME/.settings-validation.XXXXXX")
        printf '%s\n' "$merged" > "$validation_file"
        if ! python3 "$VALIDATOR" "$SCHEMA_FILE" "$validation_file" >/dev/null 2>&1; then
            rm -f "$validation_file"
            message "settings-store.sh set: patch violates schema v2"
            settings_unlock
            exit 1
        fi
        rm -f "$validation_file"
        settings_write_locked "$merged"
    settings_unlock
}

cmd_reset() {
    mkdir -p "$STATE_HOME"
    settings_lock
    settings_write_locked "$(defaults)"
    settings_unlock
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
    settings_lock
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
    settings_unlock
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
