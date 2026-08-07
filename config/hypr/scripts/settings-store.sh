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
    jq -nc --argjson v "$CURRENT_VERSION" '{
        version: $v,
        appearance: { accentProvider: "hyprveil", density: "comfortable" },
        modules: {
            enabled: { bar: true, dock: true, notifications: true, osd: true },
            calmMode: false
        },
        bar: { workspacesMode: "dynamic", position: "top" },
        dock: { autohide: false },
        surfaces: { popupMonitor: "focused", rememberLastPage: false },
        animation: { profile: "system", reducedMotion: false },
        accessibility: { highContrast: false, largeTargets: false },
        providers: {
            launcher: { files: false, calculator: true, emoji: false },
            notifications: "quickshell",
            wallpaper: "hyprpaper"
        },
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
            monitors: ($s.monitors // {}),
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
    mkdir -p "$STATE_HOME"
    tmp=$(mktemp "$STATE_HOME/.settings.XXXXXX")
    printf '%s\n' "$json" > "$tmp"
    mv -f "$tmp" "$SETTINGS_FILE"
}

settings_valid() {
    jq -e '
        type == "object" and
        if .version == 1 then true
        elif .version == 2 then
            ((keys_unsorted - ["version","appearance","modules","bar","dock","surfaces","animation","accessibility","providers","monitors","scenes"]) | length == 0) and
            (.appearance | type == "object" and .accentProvider as $a | ($a == "hyprveil" or $a == "matugen") and (.density == "compact" or .density == "comfortable")) and
            (.modules.enabled | type == "object" and all(.[]; type == "boolean")) and (.modules.calmMode | type == "boolean") and
            (.bar.workspacesMode == "dynamic" or .bar.workspacesMode == "fixed") and (.bar.position == "top" or .bar.position == "bottom") and
            (.dock.autohide | type == "boolean") and
            (.surfaces.popupMonitor | type == "string") and (.surfaces.rememberLastPage | type == "boolean") and
            (.animation.profile == "system" or .animation.profile == "standard" or .animation.profile == "reduced") and (.animation.reducedMotion | type == "boolean") and
            (.accessibility.highContrast | type == "boolean") and (.accessibility.largeTargets | type == "boolean") and
            (.providers.launcher | all(.[]; type == "boolean")) and
            (.providers.notifications == "quickshell" or .providers.notifications == "swaync" or .providers.notifications == "mako") and
            (.providers.wallpaper | type == "string") and
            (.monitors | type == "object") and all(.monitors[]; type == "object" and ((keys_unsorted - ["dockAutohide","barWorkspacesMode","surfaceScale"]) | length == 0)) and
            (.scenes | type == "object") and (.scenes.profiles | type == "object")
        else false end
    ' "$1" >/dev/null 2>&1
}

cmd_get() {
    mkdir -p "$STATE_HOME"
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
    mkdir -p "$STATE_HOME"
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
        if ! jq -e '
            .version == 2 and
            ((keys_unsorted - ["version","appearance","modules","bar","dock","surfaces","animation","accessibility","providers","monitors","scenes"]) | length == 0) and
            (.appearance.accentProvider == "hyprveil" or .appearance.accentProvider == "matugen") and
            (.appearance.density == "compact" or .appearance.density == "comfortable") and
            (.modules.enabled | all(.[]; type == "boolean")) and (.modules.calmMode | type == "boolean") and
            (.bar.workspacesMode == "dynamic" or .bar.workspacesMode == "fixed") and
            (.dock.autohide | type == "boolean") and (.surfaces.popupMonitor | type == "string") and
            (.animation.reducedMotion | type == "boolean") and
            (.accessibility.highContrast | type == "boolean") and
            (.providers.launcher | all(.[]; type == "boolean")) and (.monitors | type == "object")
        ' >/dev/null 2>&1 <<<"$merged"; then
            message "settings-store.sh set: patch violates schema v2"
            settings_unlock
            exit 1
        fi
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
