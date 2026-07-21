#!/usr/bin/env bash
# Rofi and command-line manager for the ordered ten-item Hyprveil dock.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/dock-lib.sh"
mkdir -p "$DOCK_STATE_DIR"

choose_entry() {
    local prompt=$1 rows choice
    rows=$(dock_desktop_entries | awk -F '\t' '{print $2 "\t" $1}')
    [ -n "$rows" ] || { dock_message "No installed applications were found."; return 1; }
    choice=$(printf '%s\n' "$rows" | rofi -dmenu -i -p "$prompt") || return 1
    printf '%s\n' "${choice#*$'\t'}"
}

choose_pin() {
    local prompt=$1 rows choice state id app name
    state=$(dock_read_state)
    rows=""
    while IFS=$'\t' read -r id app; do
        [ -n "$id" ] || id="$app"
        name=$(dock_desktop_record "$id" 2>/dev/null | cut -f2 || true)
        rows+="${name:-$app}"$'\t'"$id"$'\n'
    done < <(jq -r '.[] | [.desktop_id, .app_id] | @tsv' <<<"$state")
    [ -n "$rows" ] || { dock_message "The dock has no pinned applications."; return 1; }
    choice=$(printf '%s' "$rows" | rofi -dmenu -i -p "$prompt") || return 1
    printf '%s\n' "${choice#*$'\t'}"
}

cmd_list() {
    dock_read_state | jq .
}

cmd_show_list() {
    local state rows id app name position=0
    state=$(dock_read_state)
    rows=""
    while IFS=$'\t' read -r id app; do
        position=$((position + 1))
        [ -n "$id" ] || id="$app"
        name=$(dock_desktop_record "$id" 2>/dev/null | cut -f2 || true)
        rows+="$position. ${name:-$app}"$'\n'
    done < <(jq -r '.[] | [.desktop_id, .app_id] | @tsv' <<<"$state")
    [ -n "$rows" ] || rows="No pinned applications"
    printf '%s' "$rows" | rofi -dmenu -p "Pinned applications" >/dev/null || true
}

cmd_add() {
    local requested=${1:-} record desktop_id name wm _file app_id current updated
    if [ -z "$requested" ]; then
        requested=$(choose_entry "Pin application") || return 0
    fi
    record=$(dock_desktop_record "$requested") || { dock_message "No installed desktop entry matches '$requested'."; return 1; }
    IFS=$'\t' read -r desktop_id name wm _file <<<"$record"
    [ "$wm" != - ] || wm=""
    app_id=${wm:-${desktop_id%.desktop}}
    app_id=${app_id,,}

    (
        flock -x 200
        dock_ensure_state_locked
        current=$(cat "$DOCK_PINS_FILE")
        if jq -e --arg desktop "${desktop_id,,}" --arg app "$app_id" \
            'any(.[]; (.desktop_id|ascii_downcase) == $desktop or .app_id == $app)' <<<"$current" >/dev/null; then
            dock_message "$name is already pinned."
            exit 0
        fi
        if [ "$(jq length <<<"$current")" -ge "$DOCK_LIMIT" ]; then
            dock_message "The dock is full. Remove a pin before adding another (maximum: $DOCK_LIMIT)."
            exit 3
        fi
        updated=$(jq -nc --argjson state "$current" --arg desktop "$desktop_id" --arg app "$app_id" \
            '$state + [{desktop_id:$desktop, app_id:$app}]')
        dock_write_locked "$updated"
    ) 200>"$DOCK_LOCK_FILE"
}

cmd_remove() {
    local requested=${1:-} current updated
    if [ -z "$requested" ]; then
        requested=$(choose_pin "Remove pin") || return 0
    fi
    (
        flock -x 200
        dock_ensure_state_locked
        current=$(cat "$DOCK_PINS_FILE")
        updated=$(jq --arg id "${requested,,}" \
            'map(select(((.desktop_id|ascii_downcase) != $id) and (.app_id != $id)))' <<<"$current")
        dock_write_locked "$updated"
    ) 200>"$DOCK_LOCK_FILE"
}

cmd_move() {
    local requested=${1:-} direction=${2:-} current length from to updated
    if [ -z "$requested" ]; then
        requested=$(choose_pin "Move pin") || return 0
    fi
    if [ -z "$direction" ]; then
        direction=$(printf 'up\ndown\nfirst\nlast\n' | rofi -dmenu -p "Move") || return 0
    fi
    (
        flock -x 200
        dock_ensure_state_locked
        current=$(cat "$DOCK_PINS_FILE")
        length=$(jq length <<<"$current")
        from=$(jq --arg id "${requested,,}" \
            'map((.desktop_id|ascii_downcase) == $id or .app_id == $id) | index(true) // -1' <<<"$current")
        [ "$from" -ge 0 ] || { dock_message "Pin '$requested' was not found."; exit 1; }
        case "$direction" in
            up) to=$((from - 1)) ;;
            down) to=$((from + 1)) ;;
            first) to=0 ;;
            last) to=$((length - 1)) ;;
            *[!0-9]*|'') dock_message "Move must be up, down, first, last, or a position from 1 to $length."; exit 2 ;;
            *) to=$((direction - 1)) ;;
        esac
        [ "$to" -ge 0 ] || to=0
        [ "$to" -lt "$length" ] || to=$((length - 1))
        updated=$(jq --argjson from "$from" --argjson to "$to" \
            '.[ $from ] as $item | del(.[ $from ]) | .[0:$to] + [$item] + .[$to:]' <<<"$current")
        dock_write_locked "$updated"
    ) 200>"$DOCK_LOCK_FILE"
}

# The installed-application catalogue the in-shell pin picker renders. It ships
# the limit alongside the entries so the picker enforces the same ceiling this
# script does, rather than hardcoding a second copy of the number that then
# drifts.
cmd_entries() {
    dock_desktop_entries | jq -R -s --argjson limit "$DOCK_LIMIT" '
        [ split("\n")[]
          | select(length > 0)
          | split("\t")
          | { desktop_id: .[0],
              name: .[1],
              app_id: (if .[2] == "-" then (.[0] | sub("\\.desktop$"; "")) else .[2] end
                       | ascii_downcase) } ]
        | { limit: $limit, entries: . }'
}

# Replace the whole pin list in one write. The picker stages its choices and
# commits once, so add/remove/reorder arrive together; applying them as a
# sequence of cmd_add and cmd_remove calls would take the lock N times and leave
# the dock rendering each intermediate state.
#
# Every id is resolved BEFORE the lock is taken: a typo should leave the
# existing pins alone rather than truncate them at the entry that failed.
cmd_set() {
    local id record desktop_id name wm _file app_id updated='[]'
    if [ "$#" -gt "$DOCK_LIMIT" ]; then
        dock_message "The dock holds at most $DOCK_LIMIT pins; $# were requested."
        return 3
    fi
    for id in "$@"; do
        record=$(dock_desktop_record "$id") || {
            dock_message "No installed desktop entry matches '$id'."
            return 1
        }
        IFS=$'\t' read -r desktop_id name wm _file <<<"$record"
        [ "$wm" != - ] || wm=""
        app_id=${wm:-${desktop_id%.desktop}}
        app_id=${app_id,,}
        # Two desktop entries can declare the same StartupWMClass, which would
        # otherwise put two tiles on one window.
        if jq -e --arg desktop "${desktop_id,,}" --arg app "$app_id" \
            'any(.[]; (.desktop_id|ascii_downcase) == $desktop or .app_id == $app)' \
            <<<"$updated" >/dev/null; then
            continue
        fi
        updated=$(jq -nc --argjson state "$updated" --arg desktop "$desktop_id" --arg app "$app_id" \
            '$state + [{desktop_id:$desktop, app_id:$app}]')
    done
    (
        flock -x 200
        dock_ensure_state_locked
        dock_write_locked "$updated"
    ) 200>"$DOCK_LOCK_FILE"
}

cmd_manage() {
    local action
    command -v rofi >/dev/null 2>&1 || { dock_message "Rofi is required for the dock manager."; return 1; }
    action=$(printf 'List pins\nAdd pin\nRemove pin\nMove pin\n' | rofi -dmenu -p "Dock manager") || return 0
    case "$action" in
        "List pins") cmd_show_list ;;
        "Add pin") cmd_add ;;
        "Remove pin") cmd_remove ;;
        "Move pin") cmd_move ;;
    esac
}

case "${1:-manage}" in
    list) cmd_list ;;
    entries) cmd_entries ;;
    add) cmd_add "${2:-}" ;;
    remove) cmd_remove "${2:-}" ;;
    move) cmd_move "${2:-}" "${3:-}" ;;
    set) shift; cmd_set "$@" ;;
    manage) cmd_manage ;;
    *) printf 'usage: %s [manage|list|entries|add [desktop-id]|remove [desktop-id]|move [desktop-id] [up|down|first|last|position]|set [desktop-id ...]]\n' "$0" >&2; exit 2 ;;
esac
