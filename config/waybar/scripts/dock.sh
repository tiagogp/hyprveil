#!/usr/bin/env bash
# Render, focus, launch, close, and right-click-toggle Waybar dock slots.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
ICONS_FILE="$SCRIPT_DIR/dock-icons.json"
# shellcheck source=config/hypr/scripts/dock-lib.sh
# dock-lib.sh moved to hypr/scripts/ when Waybar was retired as the bar: the pin
# state it owns is still live, and it no longer belongs in a directory named
# after a shell that does not run.
. "${HYPRVEIL_DOCK_LIB:-$HOME/.config/hypr/scripts/dock-lib.sh}"

icon_for() {
    jq -r --arg id "$1" '(.[$id] // ._default)' "$ICONS_FILE"
}

has_image_icon() {
    case "$1" in
        spotify|code|brave-browser|discord|org.gnome.nautilus|kitty) return 0 ;;
        *) return 1 ;;
    esac
}

build_list() {
    local pins clients active_addr curr_ws
    pins=$(dock_read_state)
    clients=$(hyprctl clients -j 2>/dev/null || printf '[]')
    active_addr=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' || true)
    # Which workspace is on screen right now, so the unpinned "running" icons
    # only reflect apps on the current tab instead of every workspace at once.
    # Pinned icons still resolve their window across every workspace (click
    # needs that address to focus-and-switch to it from anywhere) but carry
    # an extra "onscreen" flag so the lit/dimmed look only reflects windows
    # actually on the current tab, not ones running elsewhere off-screen.
    curr_ws=$(hyprctl monitors -j 2>/dev/null | jq -r '(map(select(.focused)) | first.activeWorkspace.id) // empty' || true)
    jq -n --argjson pins "$pins" --argjson clients "$clients" --arg active "$active_addr" \
        --argjson curr_ws "${curr_ws:-null}" '
      ($pins | map(.app_id)) as $pinned_ids
      | ($clients | map(select((.class // "") != ""))) as $wins
      | ($pins | map(
          . as $p
          | ($wins | map(select((.class|ascii_downcase) == $p.app_id)) | .[0]) as $w
          | {kind:"pinned", app_id:$p.app_id, desktop_id:$p.desktop_id,
             title:($w.title // $p.app_id), address:($w.address // null),
             running:($w != null),
             onscreen:($w != null and ($curr_ws == null or $w.workspace.id == $curr_ws)),
             active:(($w.address // "") == $active)}
        )) as $pinned_items
      | ($wins
          | map(select((.class|ascii_downcase) as $c | ($pinned_ids | index($c)) | not))
          | (if $curr_ws != null then map(select(.workspace.id == $curr_ws)) else . end)
          | unique_by(.class | ascii_downcase)
          | map({kind:"running", app_id:(.class|ascii_downcase), desktop_id:"",
                 title:.title, address:.address, running:true, onscreen:true, active:(.address == $active)})) as $running_items
      | $pinned_items + $running_items
    '
}

cmd_render() {
    local slot=$1 item app_id title kind running onscreen active glyph classes
    item=$(build_list | jq ".[$slot]")
    if [ "$item" = null ]; then
        jq -nc '{text:"",tooltip:""}'
        return
    fi
    app_id=$(jq -r '.app_id' <<<"$item")
    title=$(jq -r '.title' <<<"$item")
    kind=$(jq -r '.kind' <<<"$item")
    running=$(jq -r '.running' <<<"$item")
    onscreen=$(jq -r '.onscreen' <<<"$item")
    active=$(jq -r '.active' <<<"$item")
    glyph=$(icon_for "$app_id")
    classes='["dock-btn"'
    [ "$kind" = pinned ] && classes+=',"pinned"'
    [ "$running" = true ] && [ "$onscreen" = true ] && classes+=',"running"'
    [ "$active" = true ] && classes+=',"active"'
    if has_image_icon "$app_id"; then
        classes+=',"app-'"$(printf '%s' "$app_id" | tr -c 'a-zA-Z0-9_-' '-')"'"'
        glyph=" "
    fi
    classes+=']'
    jq -nc --arg text "$glyph" --arg tooltip "$title" --argjson class "$classes" \
        '{text:$text, tooltip:$tooltip, class:$class}'
}

launch_desktop() {
    local desktop_id=$1 record file
    [ -n "$desktop_id" ] || { dock_message "This preserved pin has no matching desktop entry; remove it or add the application again."; return; }
    record=$(dock_desktop_record "$desktop_id") || { dock_message "Desktop entry '$desktop_id' is no longer installed."; return; }
    file=$(cut -f4 <<<"$record")
    if command -v gtk-launch >/dev/null 2>&1; then
        if [ "${HYPRVEIL_NO_DETACH:-0}" = 1 ]; then gtk-launch "$desktop_id"; else setsid -f gtk-launch "$desktop_id" >/dev/null 2>&1; fi
    elif command -v gio >/dev/null 2>&1; then
        if [ "${HYPRVEIL_NO_DETACH:-0}" = 1 ]; then gio launch "$file"; else setsid -f gio launch "$file" >/dev/null 2>&1; fi
    else
        dock_message "Cannot launch '$desktop_id': install GTK (gtk-launch) or GLib (gio)."
    fi
}

cmd_click() {
    local slot=$1 button=$2 item kind app_id desktop_id address running resolved
    item=$(build_list | jq ".[$slot]")
    [ "$item" != null ] || return 0
    kind=$(jq -r '.kind' <<<"$item")
    app_id=$(jq -r '.app_id' <<<"$item")
    desktop_id=$(jq -r '.desktop_id' <<<"$item")
    address=$(jq -r '.address // empty' <<<"$item")
    running=$(jq -r '.running' <<<"$item")
    case "$button" in
        left)
            if [ "$running" = true ] && [ -n "$address" ]; then
                hyprctl dispatch focuswindow "address:$address" >/dev/null
            elif [ "$kind" = pinned ]; then
                launch_desktop "$desktop_id"
            fi
            ;;
        middle) [ -z "$address" ] || hyprctl dispatch closewindow "address:$address" >/dev/null ;;
        right)
            if [ "$kind" = pinned ]; then
                "$HOME/.config/hypr/scripts/dock-manager.sh" remove "${desktop_id:-$app_id}"
            else
                resolved=$(dock_resolve_class "$app_id" || true)
                if [ -n "$resolved" ]; then
                    "$HOME/.config/hypr/scripts/dock-manager.sh" add "$resolved"
                else
                    dock_message "No installed desktop entry matches window class '$app_id'; use the dock manager to choose it."
                fi
            fi
            ;;
        *) printf 'unknown dock button: %s\n' "$button" >&2; exit 2 ;;
    esac
}

case "${1:-}" in
    render) cmd_render "$2" ;;
    click) cmd_click "$2" "$3" ;;
    *) printf 'usage: %s render <slot> | click <slot> <left|middle|right>\n' "$0" >&2; exit 2 ;;
esac
