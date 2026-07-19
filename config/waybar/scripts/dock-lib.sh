#!/usr/bin/env bash
# Shared desktop-entry discovery and atomic dock pin state helpers.

DOCK_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil"
DOCK_PINS_FILE="$DOCK_STATE_DIR/dock-pins.json"
DOCK_LOCK_FILE="$DOCK_STATE_DIR/dock-pins.lock"
DOCK_LIMIT=10

dock_message() {
    printf '%s\n' "$*" >&2
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Hyprveil dock" "$*" || true
    fi
}

dock_desktop_dirs() {
    local raw dir
    if [ -n "${HYPRVEIL_APPLICATION_DIRS:-}" ]; then
        raw=$HYPRVEIL_APPLICATION_DIRS
    else
        raw="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
        while IFS= read -r dir; do
            raw+=":$dir/applications"
        done < <(tr ':' '\n' <<<"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}")
        raw+=":$HOME/.local/share/flatpak/exports/share/applications:/var/lib/flatpak/exports/share/applications"
    fi
    while IFS= read -r dir; do
        [ -d "$dir" ] && printf '%s\n' "$dir"
    done < <(tr ':' '\n' <<<"$raw" | awk 'NF && !seen[$0]++')
}

# desktop_id<TAB>display name<TAB>StartupWMClass<TAB>absolute file
dock_desktop_entries() {
    local dir file id record
    local -A seen=()
    while IFS= read -r dir; do
        while IFS= read -r file; do
            id=${file#"$dir"/}
            id=${id//\//-}
            [ -z "${seen[$id]+x}" ] || continue
            record=$(awk -F= '
                BEGIN { section=0; type=""; name=""; wm=""; hidden=0 }
                /^\[Desktop Entry\][[:space:]]*$/ { section=1; next }
                /^\[/ { if (section) exit; next }
                !section { next }
                $1 == "Type" { type=substr($0, index($0,"=")+1) }
                $1 == "Name" && name == "" { name=substr($0, index($0,"=")+1) }
                $1 == "StartupWMClass" { wm=substr($0, index($0,"=")+1) }
                ($1 == "Hidden" || $1 == "NoDisplay") && tolower(substr($0,index($0,"=")+1)) == "true" { hidden=1 }
                END { if (type == "Application" && !hidden && name != "") printf "%s\t%s", name, (wm == "" ? "-" : wm) }
            ' "$file")
            [ -n "$record" ] || continue
            seen[$id]=1
            printf '%s\t%s\t%s\n' "$id" "$record" "$file"
        done < <(find -L "$dir" -type f -name '*.desktop' -print 2>/dev/null | LC_ALL=C sort)
    done < <(dock_desktop_dirs)
}

dock_desktop_record() {
    local wanted=${1,,} id name wm file
    while IFS=$'\t' read -r id name wm file; do
        [ "${id,,}" = "$wanted" ] || continue
        printf '%s\t%s\t%s\t%s\n' "$id" "$name" "$wm" "$file"
        return 0
    done < <(dock_desktop_entries)
    return 1
}

dock_resolve_class() {
    local wanted=${1,,} id name wm file base
    while IFS=$'\t' read -r id name wm file; do
        base=${id%.desktop}
        if [ "${base,,}" = "$wanted" ] || { [ "$wm" != - ] && [ "${wm,,}" = "$wanted" ]; }; then
            printf '%s\n' "$id"
            return 0
        fi
    done < <(dock_desktop_entries)
    return 1
}

dock_backup_invalid_locked() {
    local stamp backup suffix=0
    stamp=$(date +%Y%m%d-%H%M%S)
    backup="$DOCK_PINS_FILE.invalid-$stamp"
    while [ -e "$backup" ]; do
        suffix=$((suffix + 1))
        backup="$DOCK_PINS_FILE.invalid-$stamp-$suffix"
    done
    cp -a "$DOCK_PINS_FILE" "$backup"
    dock_message "Malformed pin state was backed up to $backup; an empty dock was restored."
}

dock_write_locked() {
    local json=$1 tmp
    tmp=$(mktemp "$DOCK_STATE_DIR/.dock-pins.XXXXXX")
    printf '%s\n' "$json" > "$tmp"
    mv -f "$tmp" "$DOCK_PINS_FILE"
    # Pin changes don't emit a Hyprland window event for dock-watch.sh to
    # catch, so nudge Waybar directly instead of waiting on the fallback poll.
    pkill -RTMIN+8 waybar 2>/dev/null || true
}

dock_state_valid() {
    jq -e --argjson limit "$DOCK_LIMIT" '
        type == "array" and length <= $limit and
        all(.[]; type == "object" and (.app_id | type == "string" and length > 0) and
            ((.desktop_id == null) or (.desktop_id | type == "string")))
    ' "$1" >/dev/null 2>&1
}

dock_state_current() {
    jq -e --argjson limit "$DOCK_LIMIT" '
        type == "array" and length <= $limit and
        all(.[]; type == "object" and (.app_id | type == "string" and length > 0) and
            (.desktop_id | type == "string" and length > 0))
    ' "$1" >/dev/null 2>&1
}

dock_ensure_state_locked() {
    local source normalized='[]' row app_id desktop_id resolved
    if [ ! -e "$DOCK_PINS_FILE" ]; then
        dock_write_locked '[]'
        return
    fi
    if ! dock_state_valid "$DOCK_PINS_FILE"; then
        dock_backup_invalid_locked
        dock_write_locked '[]'
        return
    fi

    source=$(jq -c '.[] | {app_id, desktop_id:(.desktop_id // "")}' "$DOCK_PINS_FILE")
    while IFS= read -r row; do
        [ -n "$row" ] || continue
        app_id=$(jq -r '.app_id' <<<"$row")
        desktop_id=$(jq -r '.desktop_id' <<<"$row")
        if [ -z "$desktop_id" ]; then
            resolved=$(dock_resolve_class "$app_id" 2>/dev/null || true)
            desktop_id=$resolved
        fi
        normalized=$(jq -nc --argjson state "$normalized" --arg app "$app_id" --arg desktop "$desktop_id" \
            '$state + [{app_id:$app, desktop_id:$desktop}]')
    done <<<"$source"
    if ! cmp -s <(jq -c . "$DOCK_PINS_FILE") <(jq -c . <<<"$normalized"); then
        dock_write_locked "$normalized"
    fi
}

dock_init() {
    mkdir -p "$DOCK_STATE_DIR"
    (
        flock -x 200
        dock_ensure_state_locked
    ) 200>"$DOCK_LOCK_FILE"
}

dock_read_state() {
    # dock.sh calls this on every render (10 slots x every poll interval), so
    # the common case must skip dock_init's exclusive flock entirely -- that
    # lock made every one of those renders queue up behind each other and
    # turned a ~4ms read into several seconds. dock_write_locked's tmp+mv is
    # already atomic, so an unlocked read of an already-valid file is safe;
    # only fall back to the locked init/repair path when the file is missing
    # or malformed.
    if [ -e "$DOCK_PINS_FILE" ] && dock_state_current "$DOCK_PINS_FILE"; then
        cat "$DOCK_PINS_FILE"
        return
    fi
    dock_init
    cat "$DOCK_PINS_FILE"
}
