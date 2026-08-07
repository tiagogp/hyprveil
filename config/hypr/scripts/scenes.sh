#!/usr/bin/env bash
# Named scenes — the roadmap's "Cenas por monitor" (in practice, per-desktop:
# see the header note below on why this snapshots the whole settings surface
# rather than one screen).
#
# A scene is a snapshot of exactly the fields Settings/settings-store.sh
# already owns — dock autohide, appearance, Calm Mode, and providers — applied
# atomically through the same `settings-store.sh set` every other write in
# this shell goes through. Wallpaper and the measured accent COLOR stay out
# of a scene on purpose: those are wallpaper.sh/accent.sh's own state, with
# their own atomic writers, and a scene reaching into both at once is exactly
# the two-writers-for-one-file risk settings-store.sh exists to avoid.
#
# "Por monitor" in the roadmap's title reads as an aspiration this MVP does
# not fully deliver: Settings.monitors already carries a per-connector
# dockAutohide override (see settings-store.sh), and a scene COULD extend
# that per monitor, but doing so honestly needs a monitor picker in the UI
# this pass did not build. A scene here is a whole-desktop profile — still
# useful for the "trabalho vs. apresentação" switch the roadmap describes,
# just not scoped to a single screen yet.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE="$SCRIPT_DIR/settings-store.sh"

message() { printf '%s\n' "$*" >&2; }

# The fields a scene snapshots — kept in one place so save/apply/revert
# cannot drift out of sync with each other about what a "scene" contains.
scene_fields() {
    jq -c '{dock: .dock, appearance: .appearance, modules: .modules, providers: .providers}' <<<"$1"
}

cmd_list() {
    "$STORE" get | jq -c '.scenes.profiles | keys'
}

cmd_save() {
    local name=${1:?usage: scenes.sh save <name>} current snapshot updated
    current=$("$STORE" get)
    snapshot=$(scene_fields "$current")
    updated=$(jq -c --arg name "$name" --argjson snap "$snapshot" \
        '.scenes.profiles[$name] = $snap' <<<"$current")
    "$STORE" set "$(jq -c '{scenes: .scenes}' <<<"$updated")"
    message "Saved the current dock/accent/Calm Mode settings as scene \"$name\"."
}

cmd_apply() {
    local name=${1:?usage: scenes.sh apply <name>} current profile previous patch
    current=$("$STORE" get)
    profile=$(jq -c --arg name "$name" '.scenes.profiles[$name] // empty' <<<"$current")
    [ -n "$profile" ] || { message "No such scene: $name"; exit 1; }

    # The pre-apply state becomes the one-step undo. Only ever one previous
    # snapshot is kept — applying a second scene overwrites the ability to
    # undo the first, which matches how a single Ctrl+Z slot behaves
    # elsewhere, rather than growing an unbounded history nothing surfaces.
    # $profile is already {dock,appearance,modules,providers}; scenes.previous is merged in
    # alongside it, at the top level, not inside it.
    previous=$(scene_fields "$current")
    patch=$(jq -nc --argjson snap "$profile" --argjson prev "$previous" \
        '$snap + {scenes: {previous: $prev}}')
    "$STORE" set "$patch"
    message "Applied scene \"$name\". Use \"scenes.sh revert\" to undo."
}

cmd_revert() {
    local current previous
    current=$("$STORE" get)
    previous=$(jq -c '.scenes.previous // empty' <<<"$current")
    [ -n "$previous" ] || { message "Nothing to revert — no scene has been applied this session."; exit 1; }
    "$STORE" set "$(jq -nc --argjson prev "$previous" '$prev + {scenes: {previous: null}}')"
    message "Reverted to the settings from before the last scene was applied."
}

cmd_remove() {
    local name=${1:?usage: scenes.sh remove <name>}
    # A merge-based `set` can only add/overwrite a key, never delete one —
    # see settings-store.sh's `unset-scene` for why removal is its own
    # command there.
    "$STORE" unset-scene "$name"
}

case "${1:-}" in
    list)   cmd_list ;;
    save)   shift; cmd_save "$@" ;;
    apply)  shift; cmd_apply "$@" ;;
    revert) cmd_revert ;;
    remove) shift; cmd_remove "$@" ;;
    *)
        printf 'Usage: %s list|save <name>|apply <name>|revert|remove <name>\n' "${0##*/}" >&2
        exit 2
        ;;
esac
