#!/usr/bin/env bash
# Mocked P1 checks for Bluetooth, MPRIS selection, and desktop-entry dock pins.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p1.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

mkdir -p "$TMP/bin" "$TMP/apps" "$TMP/home" "$TMP/state/hyprveil"
export HOME="$TMP/home"
export XDG_STATE_HOME="$TMP/state"
export HYPRVEIL_APPLICATION_DIRS="$TMP/apps"
export MOCK_ROOT="$TMP"
export PATH="$TMP/bin:/usr/bin:/bin"

cat > "$TMP/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/notifications"
EOF

cat > "$TMP/bin/bluetoothctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    list)
        [ "${BT_MODE:-none}" = none ] || printf 'Controller 00:11:22:33:44:55 Mock [default]\n'
        ;;
    show)
        [ "${BT_MODE:-none}" = disabled ] && power=no || power=yes
        printf 'Controller %s\n\tPowered: %s\n' "$2" "$power"
        ;;
    devices)
        case "${BT_MODE:-none}" in
            one) printf 'Device AA:AA:AA:AA:AA:01 Headphones\n' ;;
            multiple) printf 'Device AA:AA:AA:AA:AA:01 Headphones\nDevice AA:AA:AA:AA:AA:02 Keyboard\n' ;;
        esac
        ;;
    info)
        case "$2" in
            *01) printf 'Device %s\n\tName: A&B <Headset>\n\tConnected: yes\n\tBattery Percentage: 0x55 (85)\n' "$2" ;;
            *02) printf 'Device %s\n\tAlias: Keyboard\n\tConnected: yes\n' "$2" ;;
        esac
        ;;
esac
EOF

cat > "$TMP/bin/playerctl" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = --list-all ]; then
    case "${MEDIA_MODE:-none}" in
        active|markup|long) printf 'paused.player\nstale.player\nplaying.player\n' ;;
        apps) printf 'spotify\nfirefox.instance\nvlc\n' ;;
        paused) printf 'paused.player\n' ;;
    esac
    exit 0
fi
player=${1#--player=}
action=${2:-}
if [ "$action" = status ]; then
    if [ "${MEDIA_MODE:-none}" = apps ]; then
        [ "$player" = "${PLAYING_APP:-spotify}" ] && printf 'Playing\n' || printf 'Paused\n'
        exit 0
    fi
    case "$player" in
        paused.player) printf 'Paused\n' ;;
        stale.player) exit 1 ;;
        playing.player) printf 'Playing\n' ;;
    esac
    exit 0
fi
if [ "$action" = metadata ]; then
    field=$3
    case "${MEDIA_MODE:-none}:$field" in
        apps:artist) printf '%s\n' "$player" ;;
        apps:title) printf 'Mock track\n' ;;
        markup:artist) printf 'A&B <Artist>\n' ;;
        markup:title) printf 'Title > "unsafe"\n' ;;
        long:artist) printf 'An extraordinarily verbose artist name\n' ;;
        long:title) printf 'A title that is much too long for a compact status bar\n' ;;
        *:artist) [ "$player" = playing.player ] && printf 'Playing Artist\n' || printf 'Paused Artist\n' ;;
        *:title) [ "$player" = playing.player ] && printf 'Playing Title\n' || printf 'Paused Title\n' ;;
    esac
    exit 0
fi
printf '%s %s\n' "$player" "$action" >> "$MOCK_ROOT/player-actions"
EOF

chmod +x "$TMP/bin/notify-send" "$TMP/bin/bluetoothctl" "$TMP/bin/playerctl"

bt=$(BT_MODE=none "$REPO/config/waybar/scripts/bluetooth.sh" render)
[ "$(jq -r '.text' <<<"$bt")" = "" ] || fail "Bluetooth did not hide without a controller"
jq -e '.class | index("unavailable")' <<<"$bt" >/dev/null || fail "missing Bluetooth unavailable state"
bt=$(BT_MODE=disabled "$REPO/config/waybar/scripts/bluetooth.sh" render)
jq -e '.class | index("disabled")' <<<"$bt" >/dev/null || fail "missing Bluetooth disabled state"
bt=$(BT_MODE=enabled "$REPO/config/waybar/scripts/bluetooth.sh" render)
jq -e '.class | index("enabled")' <<<"$bt" >/dev/null || fail "missing Bluetooth enabled state"
bt=$(BT_MODE=one "$REPO/config/waybar/scripts/bluetooth.sh" render)
grep -q 'A&amp;B &lt;Headset&gt; — 85%' <<<"$bt" || fail "Bluetooth tooltip omitted escaped device battery data"
bt=$(BT_MODE=multiple "$REPO/config/waybar/scripts/bluetooth.sh" render)
[ "$(grep -o 'Connected device' <<<"$bt" | wc -l)" -eq 1 ] || fail "multiple-device Bluetooth tooltip missing"
grep -q 'Keyboard' <<<"$bt" || fail "second Bluetooth device missing"
ok "Bluetooth handles unavailable, disabled, enabled, and connected states"

rm -f "$TMP/notifications"
rm -f "$TMP/bin/blueman-manager"
HYPRVEIL_BLUEMAN_MANAGER="$TMP/bin/blueman-manager" \
    "$REPO/config/waybar/scripts/bluetooth.sh" open 2>/dev/null
grep -q 'Bluetooth manager unavailable' "$TMP/notifications" || fail "missing Blueman failure was not visible"
cat > "$TMP/bin/blueman-manager" <<'EOF'
#!/usr/bin/env bash
printf 'opened\n' >> "$MOCK_ROOT/blueman-opened"
EOF
chmod +x "$TMP/bin/blueman-manager"
HYPRVEIL_BLUEMAN_MANAGER="$TMP/bin/blueman-manager" \
    "$REPO/config/waybar/scripts/bluetooth.sh" open
for _ in 1 2 3 4 5; do
    [ -s "$TMP/blueman-opened" ] && break
    sleep 0.05
done
[ -s "$TMP/blueman-opened" ] || fail "installed Blueman was not opened"
ok "Blueman opens when installed and fails visibly when missing"

media=$(MEDIA_MODE=active "$REPO/config/waybar/scripts/media.sh" render label)
grep -q 'Playing Artist — Playing Title' <<<"$media" || fail "playing player did not beat paused player"
media=$(MEDIA_MODE=paused "$REPO/config/waybar/scripts/media.sh" render label)
grep -q 'Paused Artist — Paused Title' <<<"$media" || fail "paused fallback was not selected"
media=$(MEDIA_MODE=none "$REPO/config/waybar/scripts/media.sh" render label)
[ "$(jq -r '.text' <<<"$media")" = "" ] || fail "no-player media state was not empty"
media=$(MEDIA_MODE=markup "$REPO/config/waybar/scripts/media.sh" render label)
grep -q 'A&amp;B &lt;Artist&gt;' <<<"$media" || fail "MPRIS markup was not escaped"
media=$(MEDIA_MODE=long HYPRVEIL_MEDIA_MAX_LENGTH=24 "$REPO/config/waybar/scripts/media.sh" render label)
[ "$(jq -r '.text' <<<"$media" | sed 's/&[^;]*;//g' | wc -m)" -le 25 ] || fail "MPRIS label was not truncated"
MEDIA_MODE=active "$REPO/config/waybar/scripts/media.sh" next
grep -q 'playing.player next' "$TMP/player-actions" || fail "media command targeted the wrong player"
for app in spotify firefox.instance vlc; do
    media=$(MEDIA_MODE=apps PLAYING_APP="$app" "$REPO/config/waybar/scripts/media.sh" render label)
    grep -q "$app — Mock track" <<<"$media" || fail "$app could not provide MPRIS metadata"
done
ok "Spotify, browser, and VLC MPRIS names work with selection, escaping, truncation, and controls"

make_desktop() {
    local id=$1 name=$2 wm=${3:-}
    {
        printf '[Desktop Entry]\nType=Application\nName=%s\nExec=flatpak run %s %%U\n' "$name" "$id"
        [ -z "$wm" ] || printf 'StartupWMClass=%s\n' "$wm"
    } > "$TMP/apps/$id.desktop"
}

make_desktop firefox 'Firefox' firefox
make_desktop org.example.Electron 'Electron Flatpak' electron-class
for number in 3 4 5 6 7 8 9 10 11; do
    make_desktop "example.app$number" "Example $number"
done

cat > "$TMP/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = clients ]; then
    cat "$MOCK_ROOT/clients.json"
elif [ "$1" = activewindow ]; then
    cat "$MOCK_ROOT/active.json"
elif [ "$1" = dispatch ]; then
    printf '%s\n' "$*" >> "$MOCK_ROOT/hypr-actions"
fi
EOF
cat > "$TMP/bin/gtk-launch" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$MOCK_ROOT/launches"
EOF
chmod +x "$TMP/bin/hyprctl" "$TMP/bin/gtk-launch"
printf '[]\n' > "$TMP/clients.json"
printf '{"address":""}\n' > "$TMP/active.json"

manager="$REPO/config/hypr/scripts/dock-manager.sh"
dock="$REPO/config/waybar/scripts/dock.sh"
# dock.sh reaches into hypr/scripts for dock-lib.sh now; keep the test on the
# repo copy rather than whatever is deployed to this developer's HOME.
export HYPRVEIL_DOCK_LIB="$REPO/config/hypr/scripts/dock-lib.sh"
"$manager" add firefox.desktop
"$manager" add org.example.Electron.desktop
"$manager" move org.example.Electron.desktop first
state=$("$manager" list)
[ "$(jq -r '.[0].desktop_id' <<<"$state")" = org.example.Electron.desktop ] || fail "dock pin move did not preserve requested order"
HYPRVEIL_NO_DETACH=1 "$dock" click 0 left
grep -q '^org.example.Electron.desktop$' "$TMP/launches" || fail "dock did not launch through the desktop entry"

printf '[{"class":"electron-class","title":"Electron","address":"0xabc"}]\n' > "$TMP/clients.json"
printf '{"address":"0xabc"}\n' > "$TMP/active.json"
HYPRVEIL_NO_DETACH=1 "$dock" click 0 left
grep -q 'focuswindow address:0xabc' "$TMP/hypr-actions" || fail "running pin was not focused"
"$dock" click 0 middle
grep -q 'closewindow address:0xabc' "$TMP/hypr-actions" || fail "running pin was not closed"
ok "dock pins reorder, match StartupWMClass, launch desktop entries, focus, and close"

entries=$("$manager" entries)
[ "$(jq -r '.limit' <<<"$entries")" -eq 10 ] || fail "entries did not report the pin limit the picker enforces"
jq -e '.entries | any(.desktop_id == "org.example.Electron.desktop" and .app_id == "electron-class")' \
    <<<"$entries" >/dev/null || fail "entries did not resolve StartupWMClass into app_id"
jq -e '.entries | all(.name != "")' <<<"$entries" >/dev/null || fail "entries emitted a nameless application"

# The picker stages a whole list and commits it once, so `set` has to apply
# add, remove, and reorder together.
"$manager" set example.app3.desktop firefox.desktop
state=$("$manager" list)
[ "$(jq -r '[.[].desktop_id] | join(",")' <<<"$state")" = 'example.app3.desktop,firefox.desktop' ] \
    || fail "set did not replace the pin list in the requested order"
"$manager" set firefox.desktop example.app3.desktop firefox.desktop
[ "$("$manager" list | jq -r '[.[].desktop_id] | join(",")')" = 'firefox.desktop,example.app3.desktop' ] \
    || fail "set did not reorder and de-duplicate in one write"

# A typo must leave the existing pins alone rather than truncate them at the
# entry that failed, which is why ids are resolved before the lock is taken.
if "$manager" set firefox.desktop no-such-app.desktop 2>"$TMP/set-error"; then
    fail "set accepted an unknown desktop entry"
fi
[ "$("$manager" list | jq -r '[.[].desktop_id] | join(",")')" = 'firefox.desktop,example.app3.desktop' ] \
    || fail "a rejected set damaged the existing pin list"
if "$manager" set example.app3.desktop example.app4.desktop example.app5.desktop \
    example.app6.desktop example.app7.desktop example.app8.desktop example.app9.desktop \
    example.app10.desktop example.app11.desktop firefox.desktop org.example.Electron.desktop \
    2>"$TMP/set-limit"; then
    fail "set accepted more than ten pins"
fi
grep -q 'at most 10' "$TMP/set-limit" || fail "set limit message was unclear"
"$manager" set
[ "$("$manager" list | jq length)" -eq 0 ] || fail "set with no arguments did not clear the dock"
ok "dock set replaces, reorders, de-duplicates, and rejects bad input atomically"

"$manager" add firefox.desktop
"$manager" add org.example.Electron.desktop
"$manager" move org.example.Electron.desktop first
for number in 3 4 5 6 7 8 9 10; do "$manager" add "example.app$number.desktop"; done
if "$manager" add example.app11.desktop 2>"$TMP/limit-error"; then
    fail "dock accepted more than ten pins"
fi
grep -q 'maximum: 10' "$TMP/limit-error" || fail "ten-pin limit message was unclear"
[ "$(jq length "$TMP/state/hyprveil/dock-pins.json")" -eq 10 ] || fail "dock limit damaged pin state"
ok "dock enforces its ten-pin limit"

printf '[{"app_id":"firefox","exec":"firefox"},{"app_id":"electron-class","exec":"flatpak run org.example.Electron"}]\n' \
    > "$TMP/state/hyprveil/dock-pins.json"
state=$("$manager" list)
[ "$(jq -r '.[0].desktop_id' <<<"$state")" = firefox.desktop ] || fail "legacy first pin was not migrated in place"
[ "$(jq -r '.[1].desktop_id' <<<"$state")" = org.example.Electron.desktop ] || fail "legacy second pin order was not preserved"
ok "legacy executable pins migrate to desktop entries without reordering"

printf 'keep me\n' > "$TMP/state/hyprveil/unrelated-state"
printf '{broken json\n' > "$TMP/state/hyprveil/dock-pins.json"
"$manager" list >/dev/null 2>"$TMP/recovery-message"
jq -e 'type == "array" and length == 0' "$TMP/state/hyprveil/dock-pins.json" >/dev/null || fail "malformed state did not recover"
find "$TMP/state/hyprveil" -name 'dock-pins.json.invalid-*' -print -quit | grep -q . || fail "malformed state was not backed up"
grep -q 'keep me' "$TMP/state/hyprveil/unrelated-state" || fail "dock recovery damaged unrelated state"
ok "malformed dock state is backed up and recovered in isolation"

printf 'P1 smoke tests passed.\n'
