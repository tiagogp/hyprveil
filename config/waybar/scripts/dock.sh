#!/usr/bin/env bash
# Drives the waybar "dock" bar's custom/dock-<N> module pool (see config.jsonc).
# Each slot polls `render <N>` for its icon; pinned apps (persisted below) are
# listed first, followed by one entry per running window not already pinned.
# Right-clicking a slot toggles that app's pinned state.
#
# Usage: dock.sh render <slot> | dock.sh click <slot> <left|middle|right>
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ICONS_FILE="$SCRIPT_DIR/dock-icons.json"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil"
PINS_FILE="$STATE_DIR/dock-pins.json"
LOCK_FILE="$STATE_DIR/dock-pins.lock"

mkdir -p "$STATE_DIR"
[ -f "$PINS_FILE" ] || echo "[]" > "$PINS_FILE"

icon_for() {
    jq -r --arg id "$1" '(.[$id] // ._default)' "$ICONS_FILE"
}

# Apps with a real (colored) icon file wired up in style.css — see the
# ".dock-btn.app-<slug>" rules there. Render sends a blank space instead of
# the Nerd Font glyph for these so the background-image shows through
# instead of a monochrome symbol; anything not listed here still falls back
# to the glyph from dock-icons.json.
has_image_icon() {
    case "$1" in
        spotify|code|brave-browser|discord|org.gnome.nautilus|kitty) return 0 ;;
        *) return 1 ;;
    esac
}

# Pinned apps (state order) first, then one entry per running window whose
# class isn't already pinned (hyprctl's own order).
build_list() {
    local pins clients active_addr
    pins=$(cat "$PINS_FILE")
    clients=$(hyprctl clients -j)
    active_addr=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')

    jq -n --argjson pins "$pins" --argjson clients "$clients" --arg active "$active_addr" '
      ($pins | map(.app_id)) as $pinned_ids
      | ($clients | map(select(.class != ""))) as $wins
      | ($pins | map(
          . as $p
          | ($wins | map(select((.class|ascii_downcase) == $p.app_id)) | .[0]) as $w
          | {
              kind: "pinned",
              app_id: $p.app_id,
              exec: $p.exec,
              title: ($w.title // $p.app_id),
              address: ($w.address // null),
              running: ($w != null),
              active: (($w.address // "") == $active)
            }
        )) as $pinned_items
      | ($wins
          | map(select((.class|ascii_downcase) as $c | ($pinned_ids | index($c)) | not))
          | map({
              kind: "running",
              app_id: (.class|ascii_downcase),
              exec: null,
              title: .title,
              address: .address,
              running: true,
              active: (.address == $active)
            })
        ) as $running_items
      | $pinned_items + $running_items
    '
}

cmd_render() {
    local slot="$1" item app_id title kind running active glyph classes
    item=$(build_list | jq ".[$slot]")
    if [ "$item" = "null" ]; then
        echo '{"text":"","tooltip":""}'
        return
    fi

    app_id=$(jq -r '.app_id' <<<"$item")
    title=$(jq -r '.title' <<<"$item")
    kind=$(jq -r '.kind' <<<"$item")
    running=$(jq -r '.running' <<<"$item")
    active=$(jq -r '.active' <<<"$item")
    glyph=$(icon_for "$app_id")

    classes='["dock-btn"'
    [ "$kind" = "pinned" ] && classes="$classes,\"pinned\""
    [ "$running" = "true" ] && classes="$classes,\"running\""
    [ "$active" = "true" ] && classes="$classes,\"active\""
    if has_image_icon "$app_id"; then
        classes="$classes,\"app-$(printf '%s' "$app_id" | tr -c 'a-zA-Z0-9_-' '-')\""
        glyph=" "
    fi
    classes="$classes]"

    jq -nc --arg text "$glyph" --arg tooltip "$title" --argjson class "$classes" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

cmd_click() {
    local slot="$1" button="$2" item
    item=$(build_list | jq ".[$slot]")
    [ "$item" = "null" ] && return 0

    local kind app_id address running exec_cmd
    kind=$(jq -r '.kind' <<<"$item")
    app_id=$(jq -r '.app_id' <<<"$item")
    address=$(jq -r '.address // empty' <<<"$item")
    running=$(jq -r '.running' <<<"$item")
    exec_cmd=$(jq -r '.exec // empty' <<<"$item")

    case "$button" in
        left)
            if [ "$running" = "true" ] && [ -n "$address" ]; then
                hyprctl dispatch focuswindow "address:$address" >/dev/null
            elif [ "$kind" = "pinned" ]; then
                setsid -f bash -c "${exec_cmd:-$app_id}" >/dev/null 2>&1 &
            fi
            ;;
        middle)
            [ -n "$address" ] && hyprctl dispatch closewindow "address:$address" >/dev/null
            ;;
        right)
            (
                flock -x 200
                if [ "$kind" = "pinned" ]; then
                    jq --arg id "$app_id" 'map(select(.app_id != $id))' "$PINS_FILE" > "$PINS_FILE.tmp"
                else
                    # Best-effort launch command: the window class itself. Fix
                    # up "exec" by hand in the state file for apps where that
                    # guess is wrong (e.g. Flatpaks, Electron apps).
                    jq --arg id "$app_id" '. + [{app_id: $id, exec: $id}]' "$PINS_FILE" > "$PINS_FILE.tmp"
                fi
                mv "$PINS_FILE.tmp" "$PINS_FILE"
            ) 200>"$LOCK_FILE"
            ;;
    esac
}

case "${1:-}" in
    render) cmd_render "$2" ;;
    click) cmd_click "$2" "$3" ;;
    *) echo "usage: $0 render <slot> | click <slot> <left|middle|right>" >&2; exit 1 ;;
esac
