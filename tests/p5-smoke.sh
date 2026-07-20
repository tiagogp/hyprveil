#!/usr/bin/env bash
# Mocked, non-root checks for P5: the AGS quick-settings panel + notifications
# backend, its Waybar/daemon bridge, and Hyprland integration. No Wayland session
# or real AGS install is required; a mock `ags` stands in for the running shell.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p5.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

export HOME="$TMP/home"
export HYPRVEIL_STATE_HOME="$TMP/state"
export HYPRVEIL_CONFIG_HOME="$TMP/config"
export HYPRVEIL_NOTIFICATION_HELPER="$REPO/config/hypr/scripts/notification-daemon.sh"
export MOCK_ROOT="$TMP"
mkdir -p "$HOME" "$HYPRVEIL_STATE_HOME" "$HYPRVEIL_CONFIG_HOME" "$TMP/bin"
export PATH="$TMP/bin:$PATH"

# --- AGS project structure ---
AGS="$REPO/config/ags"
for f in app.ts style.scss tsconfig.json widget/QuickSettings.tsx \
         widget/Wifi.tsx widget/Bluetooth.tsx widget/Notifications.tsx \
         widget/NotificationPopups.tsx widget/Wallpapers.tsx; do
    [ -f "$AGS/$f" ] || fail "missing AGS source: config/ags/$f"
done
grep -q 'gi://AstalNetwork' "$AGS/widget/Wifi.tsx" || fail "Wifi widget does not use AstalNetwork"
grep -q 'gi://AstalBluetooth' "$AGS/widget/Bluetooth.tsx" || fail "Bluetooth widget does not use AstalBluetooth"
grep -q 'gi://AstalNotifd' "$AGS/widget/Notifications.tsx" || fail "Notifications widget does not use AstalNotifd"
for req in toggle-quicksettings notif-status notif-dnd notif-clear toggle-wallpapers; do
    grep -q "\"$req\"\|$req" "$AGS/app.ts" || fail "app.ts request handler missing: $req"
done
# The panel + popups declare the namespaces the Hyprland blur rules target.
grep -q 'hyprveil-quicksettings' "$AGS/widget/QuickSettings.tsx" || fail "quicksettings namespace missing"
grep -q 'hyprveil-notifications' "$AGS/widget/NotificationPopups.tsx" || fail "notifications namespace missing"
grep -q 'hyprveil-wallpapers' "$AGS/widget/Wallpapers.tsx" || fail "wallpapers namespace missing"
for ns in hyprveil-quicksettings hyprveil-notifications hyprveil-wallpapers; do
    grep -q "layerrule = blur, $ns" "$REPO/config/hypr/window-rules.conf" \
        || fail "missing blur layerrule for $ns"
done
# Derived from the QML rather than listed, so a surface added later is covered
# without anyone remembering to extend this. The glass is the compositor's: a
# namespace Hyprland has no rule for renders as a flat fill no matter what the
# QML asks for, and nothing about that failure points at the missing rule.
while IFS= read -r ns; do
    grep -q "layerrule = blur, $ns" "$REPO/config/hypr/window-rules.conf" \
        || fail "shell surface $ns has no blur layerrule"
    grep -Eq "layerrule = ignorealpha [0-9.]+, $ns" "$REPO/config/hypr/window-rules.conf" \
        || fail "shell surface $ns has no ignorealpha layerrule"
done < <(grep -rh 'WlrLayershell.namespace' "$REPO/config/quickshell" \
    | sed 's/.*"\(.*\)".*/\1/' | sort -u)
ok "every Quickshell layer-shell surface has its blur rules"

# A pragma Singleton with no qmldir entry resolves to the uninstantiated TYPE,
# so every property on it reads as undefined — which QML renders as 0 without
# raising anything. The shell loads and looks plausible with the singleton
# entirely unbound, so this cannot be left to review.
for dir in "$REPO/config/quickshell" "$REPO/config/quickshell/Services"; do
    while IFS= read -r file; do
        name=$(basename "$file" .qml)
        grep -q "^singleton $name " "$dir/qmldir" \
            || fail "$name is a pragma Singleton with no qmldir entry in ${dir#"$REPO/"}"
    done < <(grep -rl '^pragma Singleton' "$dir" --include='*.qml' -m1 \
        | while IFS= read -r f; do [ "$(dirname "$f")" = "$dir" ] && printf '%s\n' "$f"; done)
done
ok "every shell singleton is registered in its qmldir"
grep -q 'displayTitle(title: string)' "$REPO/config/quickshell/Services/Compositor.qml" \
    || fail "Compositor does not normalize focused window titles"
grep -q ' - hyprveil - Visual Studio Code' "$REPO/config/quickshell/Services/Compositor.qml" \
    || fail "VS Code workspace segment is not stripped from the bar title"
grep -q 'Visual Studio Code - ' "$REPO/config/quickshell/Services/Compositor.qml" \
    || fail "Quickshell title does not put VS Code before the file name"
grep -q '"^(.*) - hyprveil - Visual Studio Code$"' "$REPO/config/waybar/config.jsonc" \
    || fail "Waybar window title does not strip the VS Code workspace segment"
grep -q '"Visual Studio Code - \$1"' "$REPO/config/waybar/config.jsonc" \
    || fail "Waybar title does not put VS Code before the file name"
ok "bar title removes the hyprveil workspace segment and puts VS Code first"
# Glass palette imports the generated accent fragment rendered from colors.conf.
grep -q '#e14658' "$AGS/_accent.scss" || fail "accent color not mirrored in _accent.scss"
grep -q '@use "accent" as \*' "$AGS/style.scss" || fail "style.scss does not import the generated accent fragment"
# Sass owns alpha() with one argument; the two-argument GTK form fails to compile
# and would take the whole shell down, so keep the stylesheet on rgba().
! grep -qE '[^-a-z]alpha\(\$[a-z-]+,' "$AGS/style.scss" \
    || fail "style.scss uses two-argument alpha(); use rgba() so dart-sass can compile it"
# GTK CSS has no max-height/max-width, and one unknown property discards the
# entire stylesheet, leaving an unstyled shell.
! grep -qE '^\s*max-(height|width):' "$AGS/style.scss" \
    || fail "style.scss uses max-height/max-width; GTK rejects them - use heightRequest"
# Font weights must be whole hundreds, or GTK discards the stylesheet.
! grep -qE 'font-weight:\s*[0-9]*[1-9][0-9]\s*;' "$AGS/style.scss" \
    || fail "style.scss uses a font-weight that is not a multiple of 100"
# A non-ASCII byte in a preserved /* */ comment makes dart-sass emit @charset,
# which GTK rejects as an unknown at-rule - again discarding the stylesheet.
! grep -qP '^\s*(/\*|\s\*).*[^\x00-\x7F]' "$AGS/style.scss" \
    || fail "style.scss has a non-ASCII preserved comment; dart-sass will emit @charset"

# Nerd Font glyphs live in the Private Use Area and have been silently dropped
# by editors before now, leaving blank buttons. Icons must use \u{...} escapes.
if grep -n 'label=""' "$AGS"/widget/*.tsx; then
    fail "an icon label is empty; write Nerd Font glyphs as \\u{...} escapes"
fi
grep -q 'label={"\\u{' "$AGS/widget/QuickSettings.tsx" \
    || fail "QuickSettings icons are not written as \\u{...} escapes"
ok "AGS project has Wi-Fi/Bluetooth/notification/wallpaper widgets, request handlers, and glass styling"

# --- Wallpaper picker delegates to the shared helper ---
grep -q 'wallpaper.sh' "$AGS/widget/Wallpapers.tsx" \
    || fail "Wallpapers widget does not call the wallpaper helper"
for cmd in '"list"' '"apply"'; do
    grep -q "$cmd" "$AGS/widget/Wallpapers.tsx" \
        || fail "Wallpapers widget does not use wallpaper.sh $cmd"
done
ok "AGS wallpaper grid reuses the wallpaper.sh state and IPC helper"

# --- Mock ags standing in for the running shell ---
cat > "$TMP/bin/ags" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/ags"
case "${1:-}" in
    list) [ "${MOCK_AGS_RUNNING:-0}" = 1 ] && printf '%s\n' "${HYPRVEIL_AGS_INSTANCE:-hyprveil}" ;;
    run) : ;;  # exec target; just records the invocation
    request)
        req=${!#}
        [ "$req" = notif-status ] && \
            printf '{"text":"2","alt":"notification","class":"notification","tooltip":"2 notifications"}\n'
        ;;
esac
exit 0
EOF
cat > "$TMP/bin/quickshell" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/quickshell"
EOF
cat > "$TMP/bin/pkill" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/killed"
EOF
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/pgrep"
# AGS shells out to dart-sass at startup, so the daemon requires it before it
# commits to AGS. Mock it too, or these checks depend on the host's install.
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/sass"
cat > "$TMP/bin/swaync" <<'EOF'
#!/usr/bin/env bash
printf 'started\n' >> "$MOCK_ROOT/swaync"
EOF
chmod +x "$TMP/bin/ags" "$TMP/bin/quickshell" "$TMP/bin/pkill" "$TMP/bin/pgrep" "$TMP/bin/sass" "$TMP/bin/swaync"

# --- Backend selection accepts ags and defaults to it ---
rm -f "$HYPRVEIL_STATE_HOME/notification-backend"
"$REPO/scripts/07-select-notification-backend.sh" --backend ags >/dev/null
[ "$(cat "$HYPRVEIL_STATE_HOME/notification-backend")" = ags ] || fail "AGS backend was not saved"
rm -f "$HYPRVEIL_STATE_HOME/notification-backend"
[ "$("$REPO/config/hypr/scripts/notification-daemon.sh" backend)" = ags ] \
    || fail "daemon default backend is not ags"
ok "backend selection accepts ags and defaults to it"

# --- Daemon exclusivity: ags start stops swaync + mako and launches the shell ---
printf 'ags\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
rm -f "$TMP/killed" "$TMP/ags"
"$REPO/config/hypr/scripts/notification-daemon.sh" start
grep -qx -- '-x swaync' "$TMP/killed" || fail "ags startup did not stop SwayNC"
grep -qx -- '-x mako' "$TMP/killed" || fail "ags startup did not stop Mako"
grep -qx run "$TMP/ags" || fail "ags run was not launched"
ok "selecting ags stops the other daemons and launches the AGS shell"

# --- Missing dart-sass degrades to a fallback instead of no notifications ---
# `ags run` compiles style.scss on every start; without sass it exits and would
# take notifications down with it, so the daemon must hand off to swaync/mako.
rm -f "$TMP/ags" "$TMP/swaync"
# /usr/bin supplies env(1); sass is mocked in $TMP/bin only, so dropping it here
# makes it genuinely absent regardless of what the host has installed.
mv "$TMP/bin/sass" "$TMP/sass.hidden"
PATH="$TMP/bin:/usr/bin" "$REPO/config/hypr/scripts/notification-daemon.sh" start 2>/dev/null
mv "$TMP/sass.hidden" "$TMP/bin/sass"
[ -s "$TMP/swaync" ] || fail "missing dart-sass did not fall back to a working daemon"
! grep -qx run "$TMP/ags" 2>/dev/null || fail "ags run was launched without dart-sass"
ok "a missing dart-sass falls back instead of leaving the session without notifications"

# --- Quickshell daemonizes in a real session and stays foregrounded in nested tests ---
printf 'quickshell\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
rm -f "$TMP/quickshell" "$TMP/killed"
"$REPO/config/hypr/scripts/notification-daemon.sh" start
grep -qx -- '--daemonize' "$TMP/quickshell" || fail "quickshell backend was not daemonized for a normal session"
grep -qx -- '-x swaync' "$TMP/killed" || fail "quickshell startup did not stop SwayNC"
grep -qx -- '-x mako' "$TMP/killed" || fail "quickshell startup did not stop Mako"
rm -f "$TMP/quickshell"
HYPRVEIL_NESTED_SESSION=1 "$REPO/config/hypr/scripts/notification-daemon.sh" start
[ -s "$TMP/quickshell" ] || fail "nested quickshell backend did not start"
! grep -qx -- '--daemonize' "$TMP/quickshell" || fail "nested quickshell backend daemonized instead of staying attached"
ok "quickshell backend daemonizes only for the real session"

# --- Daemon toggle/dnd route to the AGS panel ---
printf 'ags\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
rm -f "$TMP/ags"
MOCK_AGS_RUNNING=1 "$REPO/config/hypr/scripts/notification-daemon.sh" toggle
MOCK_AGS_RUNNING=1 "$REPO/config/hypr/scripts/notification-daemon.sh" dnd
grep -q 'toggle-quicksettings' "$TMP/ags" || fail "SUPER+N/center toggle did not reach the AGS panel"
grep -q 'notif-dnd' "$TMP/ags" || fail "DND did not reach the AGS panel"
ok "daemon toggle and DND route through the AGS request bridge"

# --- Waybar bridge renders the AGS status ---
rm -f "$TMP/ags"
render=$(MOCK_AGS_RUNNING=1 "$REPO/config/waybar/scripts/notification.sh" render)
printf '%s' "$render" | grep -q '"alt":"notification"' || fail "AGS Waybar status not forwarded"
grep -q 'notif-status' "$TMP/ags" || fail "Waybar bridge did not query notif-status"
ok "Waybar notification module reflects the AGS status"

# --- Hyprland + Waybar integration wiring ---
grep -q 'toggle-quicksettings' "$REPO/config/waybar/config.jsonc" \
    || fail "Waybar does not toggle the AGS panel"
for ns in hyprveil-quicksettings hyprveil-notifications; do
    grep -q "blur, $ns" "$REPO/config/hypr/window-rules.conf" \
        || fail "missing blur layer rule for $ns"
done
grep -q 'notification-daemon.sh start' "$REPO/config/hypr/autostart.conf" \
    || fail "autostart does not launch the backend-aware daemon"
ok "Waybar toggle, layer blur rules, and autostart are wired for AGS"

# --- Deployment installs only the ags backend tree ---
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"
printf 'ags\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
mkdir -p "$HYPRVEIL_CONFIG_HOME/swaync" "$HYPRVEIL_CONFIG_HOME/mako"
printf 'stale\n' > "$HYPRVEIL_CONFIG_HOME/swaync/config.json"
printf 'stale\n' > "$HYPRVEIL_CONFIG_HOME/mako/config"
hv_deploy_configs >/dev/null
[ -f "$HYPRVEIL_CONFIG_HOME/ags/app.ts" ] || fail "AGS config was not deployed"
[ ! -e "$HYPRVEIL_CONFIG_HOME/swaync" ] || fail "inactive SwayNC tree survived AGS deployment"
[ ! -e "$HYPRVEIL_CONFIG_HOME/mako" ] || fail "inactive Mako tree survived AGS deployment"
ok "deployment installs only the AGS backend and backs up the inactive trees"

# --- A misresolved HV_REPO must not destroy the installed configuration ---
# Each target tree is removed immediately before its replacement is moved in, so
# a source that does not exist used to empty the target and install nothing:
# cp printed an error and the loop continued to the rm. Sourcing this library
# from a shell without BASH_SOURCE (zsh) is one way to land there.
deploy_guard_marker="$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf"
[ -f "$deploy_guard_marker" ] || fail "fixture precondition: hypr was not deployed"
(
    HV_REPO="$TMP/definitely-not-the-repo"
    hv_deploy_configs >/dev/null 2>&1
) && fail "hv_deploy_configs succeeded against a missing source tree"
[ -f "$deploy_guard_marker" ] \
    || fail "a missing source tree destroyed the installed configuration"
[ -s "$deploy_guard_marker" ] \
    || fail "a missing source tree emptied the installed configuration"
ok "deployment refuses a missing source tree instead of emptying the target"

printf 'P5 smoke tests passed.\n'
