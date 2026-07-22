#!/usr/bin/env bash
# Mocked, non-root checks for P0 detection, COPR refusal, profiles, and reruns.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p0.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

cat > "$TMP/os-release" <<'EOF'
ID=fedora
VERSION_ID=44
PRETTY_NAME="Fedora Linux 44 (Mock)"
EOF

cat > "$TMP/dnf" <<'EOF'
#!/usr/bin/env bash
set -eu
root=${MOCK_DNF_ROOT:?}
args=" $* "
if [[ "$args" == *" repolist --enabled "* ]]; then
    printf 'repo id repo name\nfedora Fedora\nupdates Updates\n'
    [ ! -f "$root/copr-enabled" ] || printf 'copr:copr.fedorainfracloud.org:solopasha:hyprland COPR\n'
elif [[ "$args" == *" repoquery "* ]]; then
    package=${!#}
    case "$package" in
        official-package) printf 'copr:third:party\nupdates\n' ;;
        fallback-package)
            [ ! -f "$root/copr-enabled" ] || printf 'copr:copr.fedorainfracloud.org:solopasha:hyprland\n'
            ;;
        *) printf 'fedora\n' ;;
    esac
elif [[ "$args" == *" copr enable "* ]]; then
    touch "$root/copr-enabled"
    printf '%s\n' "$*" >> "$root/mutations"
elif [[ "$args" == *" install "* ]]; then
    printf '%s\n' "$*" >> "$root/mutations"
fi
EOF
chmod +x "$TMP/dnf"

export HOME="$TMP/home"
export HYPRVEIL_OS_RELEASE="$TMP/os-release"
export HYPRVEIL_DNF="$TMP/dnf"
export HYPRVEIL_STATE_HOME="$TMP/state"
export HYPRVEIL_CONFIG_HOME="$TMP/config"
export HYPRVEIL_NO_SUDO=1
export MOCK_DNF_ROOT="$TMP"
export PATH="$TMP/bin:$PATH"
mkdir -p "$HOME" "$HYPRVEIL_CONFIG_HOME" "$TMP/bin"

cat > "$TMP/bin/Hyprland" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = --verify-config ]; then
    exit 0
fi
exit 0
EOF
chmod +x "$TMP/bin/Hyprland"
for command in kitty polkit-mate-authentication-agent-1 xdg-desktop-portal-hyprland \
               rofi notify-send quickshell hyprlock hypridle hyprpaper wlogout \
               gio gtk-launch; do
    ln -s Hyprland "$TMP/bin/$command"
done

# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"
hv_load_fedora
[ "$HV_FEDORA_VERSION" = 44 ] || fail "Fedora version detection"
hv_check_supported_release
ok "Fedora 44 detection and support policy"

(
    # run_with_spinner can delegate executables to gum, but sourced Bash
    # functions must stay in the current shell context.
    ui_has_gum() { return 0; }
    ui_is_interactive() { return 0; }
    gum() {
        printf '%s\n' "$*" > "$TMP/gum-called"
        return 99
    }
    # shellcheck disable=SC2329
    spinner_function() {
        touch "$TMP/spinner-function-ran"
    }
    run_with_spinner "mock function spinner" spinner_function >/dev/null 2>&1
)
[ -f "$TMP/spinner-function-ran" ] || fail "spinner did not run shell function"
[ ! -f "$TMP/gum-called" ] || fail "spinner delegated a shell function to gum"
ok "spinner runs shell functions without delegating them to gum"

source=$(hv_package_source official-package)
[ "$source" = updates ] || fail "official repo was not preferred over third-party repo: $source"
ok "official package source preference"

printf 'n\n' | hv_enable_copr solopasha/hyprland "mock optional feature" && fail "COPR refusal returned success"
[ ! -e "$TMP/copr-enabled" ] || fail "COPR refusal changed repository state"
[ ! -e "$TMP/mutations" ] || fail "COPR refusal invoked a mutating dnf command"
ok "declining COPR leaves repository state unchanged"

touch "$TMP/copr-enabled"
hv_enable_copr solopasha/hyprland "already approved mock" >/dev/null
[ ! -e "$TMP/mutations" ] || fail "rerun duplicated an already-enabled COPR"
rm -f "$TMP/copr-enabled"
ok "rerun does not duplicate an enabled COPR"

HYPRVEIL_ASSUME_YES=1 hv_install_group required "mock official feature" \
    solopasha/hyprland official-package >/dev/null
grep -q -- '--enable-repo=updates' "$TMP/mutations" || fail "official install was not pinned to official enabled repos"
grep -q -- '--enable-repo=copr' "$TMP/mutations" && fail "official install enabled a COPR source"
rm -f "$TMP/mutations"
ok "official package installation excludes third-party repositories"

cp -a "$REPO/config/hypr" "$HYPRVEIL_CONFIG_HOME/hypr"
"$REPO/scripts/06-select-profile.sh" --form-factor laptop --gpu amd >/dev/null
profile_before=$(sha256sum "$HYPRVEIL_STATE_HOME/hardware-profile.conf")
"$REPO/scripts/06-select-profile.sh" --ensure >/dev/null
profile_after=$(sha256sum "$HYPRVEIL_STATE_HOME/hardware-profile.conf")
[ "$profile_before" = "$profile_after" ] || fail "profile changed on ensure/rerun"
grep -q 'form-factor/laptop.conf' "$HYPRVEIL_CONFIG_HOME/hypr/profiles/active.conf" || fail "laptop include missing"
grep -q 'gpu/amd.conf' "$HYPRVEIL_CONFIG_HOME/hypr/profiles/active.conf" || fail "AMD include missing"
ok "hardware profile persists unchanged on rerun"

grep -q 'AudioSection' "$REPO/config/quickshell/Panel/QuickSettings.qml" \
    || fail "Quick Settings does not instantiate the audio section"
grep -q 'Quickshell.Services.Pipewire' "$REPO/config/quickshell/Panel/AudioSection.qml" \
    || fail "audio section is not driven by the PipeWire service"
grep -q 'AudioSection.qml' "$REPO/docs/QUICK-SETTINGS.md" \
    || fail "Quick Settings documentation omits the audio section"
ok "Quick Settings includes documented PipeWire audio controls"

grep -q 'visible: !Pipewire.ready' "$REPO/config/quickshell/Panel/AudioSection.qml" \
    || fail "audio section does not expose an unavailable PipeWire state"
grep -q 'visible: Pipewire.ready' "$REPO/config/quickshell/Panel/AudioSection.qml" \
    || fail "audio section does not hide controls until PipeWire is ready"
grep -q 'Audio service unavailable' "$REPO/config/quickshell/Panel/AudioSection.qml" \
    || fail "audio section does not explain unavailable PipeWire"

grep -q 'visible: root.device !== null' "$REPO/config/quickshell/Panel/WifiSection.qml" \
    || fail "Wi-Fi toggle is not hidden when no adapter exists"
grep -q 'No Wi-Fi adapter' "$REPO/config/quickshell/Panel/WifiSection.qml" \
    || fail "Wi-Fi section does not explain absent hardware"
grep -q 'No networks found' "$REPO/config/quickshell/Panel/WifiSection.qml" \
    || fail "Wi-Fi section does not expose an empty scan state"
grep -q 'command -v nmcli' "$REPO/config/quickshell/Panel/WifiSection.qml" \
    || fail "Wi-Fi secured-network fallback does not probe nmcli availability"
grep -q 'Wi-Fi connection unavailable' "$REPO/config/quickshell/Panel/WifiSection.qml" \
    || fail "Wi-Fi secured-network fallback does not fail visibly without nmcli"

grep -q 'blueman-manager' "$REPO/config/quickshell/Panel/BluetoothSection.qml" \
    || fail "Bluetooth section does not expose the Blueman pairing fallback"
grep -q 'Blueman' "$REPO/docs/QUICK-SETTINGS.md" \
    || fail "Quick Settings documentation omits the Bluetooth pairing fallback"
ok "Quick Settings exposes documented Bluetooth pairing fallback"

grep -q 'visible: root.adapter !== null' "$REPO/config/quickshell/Panel/BluetoothSection.qml" \
    || fail "Bluetooth toggle is not hidden when no adapter exists"
grep -q 'No Bluetooth adapter' "$REPO/config/quickshell/Panel/BluetoothSection.qml" \
    || fail "Bluetooth section does not explain absent hardware"
grep -q "Bluetooth pairing unavailable" "$REPO/config/quickshell/Panel/BluetoothSection.qml" \
    || fail "Bluetooth pairing fallback does not fail visibly when Blueman is absent"

grep -q 'PowerProfileSection' "$REPO/config/quickshell/Panel/QuickSettings.qml" \
    || fail "Quick Settings does not instantiate the power profile section"
grep -q 'powerprofilesctl' "$REPO/config/quickshell/Panel/PowerProfileSection.qml" \
    || fail "power profile section is not driven by powerprofilesctl"
grep -q 'power-profiles-daemon' "$REPO/scripts/data/dependencies.tsv" \
    || fail "dependency report omits the power profile helper"
grep -q 'PowerProfileSection.qml' "$REPO/docs/QUICK-SETTINGS.md" \
    || fail "Quick Settings documentation omits the power profile section"
ok "Quick Settings includes documented laptop power profile controls"

grep -q 'command -v powerprofilesctl' "$REPO/config/quickshell/Panel/PowerProfileSection.qml" \
    || fail "power profile section does not probe command availability"
grep -q 'Power profiles unavailable' "$REPO/config/quickshell/Panel/PowerProfileSection.qml" \
    || fail "power profile section does not explain unavailable service"
grep -q 'visible: root.available' "$REPO/config/quickshell/Panel/PowerProfileSection.qml" \
    || fail "power profile choices are not hidden when unavailable"

grep -q 'ClipboardSection' "$REPO/config/quickshell/Panel/QuickSettings.qml" \
    || fail "Quick Settings does not instantiate the clipboard section"
grep -q 'cliphist list' "$REPO/config/quickshell/Panel/ClipboardSection.qml" \
    || fail "clipboard section does not read cliphist history"
grep -q 'cliphist delete' "$REPO/config/quickshell/Panel/ClipboardSection.qml" \
    || fail "clipboard section does not expose clear-item behavior"
grep -q 'cliphist", "wipe' "$REPO/config/quickshell/Panel/ClipboardSection.qml" \
    || fail "clipboard section does not expose clear-all behavior"
grep -q 'ClipboardSection.qml' "$REPO/docs/QUICK-SETTINGS.md" \
    || fail "Quick Settings documentation omits the clipboard section"
ok "Quick Settings includes documented clipboard history controls"

grep -q 'command -v cliphist' "$REPO/config/quickshell/Panel/ClipboardSection.qml" \
    || fail "clipboard section does not probe cliphist availability"
grep -q 'command -v wl-copy' "$REPO/config/quickshell/Panel/ClipboardSection.qml" \
    || fail "clipboard section does not probe wl-copy availability"
grep -q 'Clipboard tools unavailable' "$REPO/config/quickshell/Panel/ClipboardSection.qml" \
    || fail "clipboard section does not explain unavailable tools"
grep -q 'visible: root.toolsAvailable' "$REPO/config/quickshell/Panel/ClipboardSection.qml" \
    || fail "clipboard controls are not hidden when tools are unavailable"

grep -q 'No notifications' "$REPO/config/quickshell/Panel/NotificationSection.qml" \
    || fail "notification section does not expose an empty history state"
grep -q 'notifications?' "$REPO/config/quickshell/Panel/NotificationSection.qml" \
    || fail "notification controls do not guard missing notification state"

for section in WifiSection BluetoothSection AudioSection PowerProfileSection ClipboardSection NotificationSection; do
    grep -q 'Section {' "$REPO/config/quickshell/Panel/$section.qml" \
        || fail "$section does not use the shared quick-settings surface"
    grep -q 'glyph:' "$REPO/config/quickshell/Panel/$section.qml" \
        || fail "$section does not use the shared icon slot"
    grep -q 'Tokens\.' "$REPO/config/quickshell/Panel/$section.qml" \
        || fail "$section does not use design tokens"
    ! grep -Eq '#[0-9A-Fa-f]{3,8}' "$REPO/config/quickshell/Panel/$section.qml" \
        || fail "$section hardcodes a hex color instead of the token/accent system"
done
for section in WifiSection BluetoothSection AudioSection ClipboardSection NotificationSection; do
    grep -q 'Glyph {' "$REPO/config/quickshell/Panel/$section.qml" \
        || fail "$section custom rows do not use the shared Glyph icon component"
    grep -q 'Accent\.' "$REPO/config/quickshell/Panel/$section.qml" \
        || fail "$section custom rows do not use the accent system"
done
grep -q 'Segmented {' "$REPO/config/quickshell/Panel/PowerProfileSection.qml" \
    || fail "power profile section does not use the shared segmented control"
grep -q 'Surface {' "$REPO/config/quickshell/Osd/Osd.qml" \
    || fail "OSD does not use the shared surface system"
grep -q 'Glyph {' "$REPO/config/quickshell/Osd/Osd.qml" \
    || fail "OSD does not use the shared Glyph icon component"
grep -q 'Accent\.' "$REPO/config/quickshell/Osd/Osd.qml" \
    || fail "OSD does not use the accent system"
! grep -Eq '#[0-9A-Fa-f]{3,8}' "$REPO/config/quickshell/Osd/Osd.qml" \
    || fail "OSD hardcodes a hex color instead of the token/accent system"
ok "new desktop-polish controls use shared tokens, accent, surfaces, and icons"
ok "optional quick-settings controls hide or explain unavailable services and hardware"

cat > "$TMP/bin/mock-kitty" <<'EOF'
#!/usr/bin/env bash
printf 'kitty %s\n' "$*" >> "${MOCK_DNF_ROOT:?}/kitty-actions"
if [ "${1:-}" = @ ] && [ "${2:-}" = ls ]; then
    printf 'launch --cwd=current\n'
fi
EOF
chmod +x "$TMP/bin/mock-kitty"

rm -f "$TMP/kitty-actions"
HYPRVEIL_KITTY="$TMP/bin/mock-kitty" "$REPO/config/kitty/hyprveil-session.sh" save work >/dev/null
[ -f "$HYPRVEIL_STATE_HOME/kitty-sessions/work.conf" ] \
    || fail "Kitty session helper did not save a named session"
grep -q 'launch --cwd=current' "$HYPRVEIL_STATE_HOME/kitty-sessions/work.conf" \
    || fail "Kitty session helper did not write Kitty session output"
[ "$(stat -c '%a' "$HYPRVEIL_STATE_HOME/kitty-sessions")" = 700 ] \
    || fail "Kitty session directory is not private"
[ "$(stat -c '%a' "$HYPRVEIL_STATE_HOME/kitty-sessions/work.conf")" = 600 ] \
    || fail "Kitty session snapshot is not private"
HYPRVEIL_KITTY="$TMP/bin/mock-kitty" "$REPO/config/kitty/hyprveil-session.sh" new-tab >/dev/null
grep -q 'kitty @ launch --type=tab --cwd=current --add-to-session=.' "$TMP/kitty-actions" \
    || fail "Kitty session helper did not open tabs through Kitty remote control"
HYPRVEIL_KITTY="$TMP/bin/mock-kitty" "$REPO/config/kitty/hyprveil-session.sh" open work >/dev/null
grep -q "kitty --session $HYPRVEIL_STATE_HOME/kitty-sessions/work.conf --detach" "$TMP/kitty-actions" \
    || fail "Kitty session helper did not reopen saved sessions with Kitty"
HYPRVEIL_KITTY="$TMP/bin/mock-kitty" "$REPO/config/kitty/hyprveil-session.sh" delete work
[ ! -e "$HYPRVEIL_STATE_HOME/kitty-sessions/work.conf" ] \
    || fail "Kitty session helper did not delete a named session"
ok "Kitty tab/session helper saves, opens, and deletes optional sessions outside shell state"

grep -q 'valid_name' "$REPO/config/kitty/hyprveil-session.sh" \
    || fail "Kitty session helper does not schema-check snapshot names"
grep -Fq "mktemp \"\$SESSION_DIR" "$REPO/config/kitty/hyprveil-session.sh" \
    || fail "Kitty session helper does not write snapshots through a temporary file"
grep -Fq "mv \"\$tmp\" \"\$path\"" "$REPO/config/kitty/hyprveil-session.sh" \
    || fail "Kitty session helper does not atomically replace snapshots"
grep -q 'kitty-sessions' "$REPO/docs/CONFIGURATION.md" \
    || fail "configuration inventory omits Kitty session state"
ok "new persistent Kitty state is schema-checked, private, atomic, and inventoried"

for control in Button Toggle Segmented LinkRow; do
    grep -q 'activeFocusOnTab: true' "$REPO/config/quickshell/Panel/$control.qml" \
        || fail "$control does not accept keyboard focus"
    grep -q 'Keys.on.*Pressed' "$REPO/config/quickshell/Panel/$control.qml" \
        || fail "$control does not expose keyboard activation"
    grep -q 'Accessible.name' "$REPO/config/quickshell/Panel/$control.qml" \
        || fail "$control does not expose an accessible name"
done
for section in WifiSection BluetoothSection AudioSection ClipboardSection NotificationSection; do
    grep -q 'activeFocusOnTab: true' "$REPO/config/quickshell/Panel/$section.qml" \
        || fail "$section does not expose keyboard-focusable custom controls"
    grep -q 'Accessible.name' "$REPO/config/quickshell/Panel/$section.qml" \
        || fail "$section does not name custom controls for assistive tech"
done
grep -q 'accessible names' "$REPO/docs/QUICK-SETTINGS.md" \
    || fail "Quick Settings documentation omits shared accessibility behavior"
for modal in QuickSettings Wallpapers Cheatsheet; do
    grep -q 'Close .*"' "$REPO/config/quickshell/Panel/$modal.qml" \
        || fail "$modal close button does not expose an accessible name"
done
grep -q 'Select wallpaper' "$REPO/config/quickshell/Panel/Wallpapers.qml" \
    || fail "wallpaper picker thumbnails are not named for assistive tech"
grep -q 'Pin ") + modelData.name' "$REPO/config/quickshell/Dock/PinPicker.qml" \
    || fail "dock pin picker rows are not named for assistive tech"
grep -q 'Qt.Key_MediaTogglePlayPause' "$REPO/config/quickshell/Lock/Lock.qml" \
    || fail "lock screen does not handle media keys without a pointer"
grep -q 'hardware media keys' "$REPO/docs/QUICK-SETTINGS.md" \
    || fail "Quick Settings documentation omits lock-screen pointer-free media behavior"
grep -q 'activeFocus' "$REPO/config/sddm/hyprveil/Components/SessionPicker.qml" \
    || fail "SDDM session picker focus does not light the control"
grep -q 'Accessible.name' "$REPO/config/sddm/hyprveil/Components/PasswordField.qml" \
    || fail "SDDM password field does not expose an accessible name"
grep -q 'typeof primaryScreen === "undefined" ? true : primaryScreen' "$REPO/config/sddm/hyprveil/Main.qml" \
    || fail "SDDM greeter hides controls when primaryScreen is unavailable"
grep -q 'sourceSize.width: root.width' "$REPO/config/sddm/hyprveil/Main.qml" \
    || fail "SDDM backdrop is not decoded at the greeter surface size"
python3 - <<'PY' || fail "focus accent does not meet the 3:1 UI contrast floor"
def linear(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def luminance(hex_color):
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)

def contrast(a, b):
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)

accent = "#e14658"
surfaces = ["#0d0e11", "#15171b", "#1c1f26", "#23262e"]
assert min(contrast(accent, surface) for surface in surfaces) >= 3.0
PY
ok "Quick Settings, modal, dock-picker, and lock controls expose keyboard/accessibility wiring"

# Reduced motion is a Hyprland source line, and Hyprland does not animate the
# Quickshell surfaces — they draw their own transitions in QML. So the shell has
# to honor the same motion-profile state file itself, or "reduced motion" leaves
# the panel, OSD, and sliders moving exactly as before.
grep -q 'motion-profile' "$REPO/config/quickshell/Services/Motion.qml" \
    || fail "Motion service does not read the motion-profile state file"
grep -q 'reduced ? 0' "$REPO/config/quickshell/Services/Motion.qml" \
    || fail "Motion.duration does not collapse to zero under reduced motion"
grep -q 'HYPRVEIL_STATE_HOME' "$REPO/config/quickshell/Services/Motion.qml" \
    || fail "Motion service ignores the HYPRVEIL_STATE_HOME test override"
# Every animated surface added for the desktop-polish work routes its durations
# through the service; a raw Tokens.durN in a Behavior would ignore the profile.
for surface in Osd/Osd Panel/AudioSlider Overview/Overview Overview/WindowTile Bar/TrayItem; do
    grep -q 'Motion.duration(' "$REPO/config/quickshell/$surface.qml" \
        || fail "$surface animates without honoring the reduced-motion profile"
done
# Icon-only and grouped controls name themselves for assistive tech.
grep -q 'Accessible.role: showHeader ? Accessible.Grouping' "$REPO/config/quickshell/Panel/Section.qml" \
    || fail "quick-settings sections are not exposed as named groups"
grep -q 'Accessible.role: Accessible.StaticText' "$REPO/config/quickshell/Panel/BindRow.qml" \
    || fail "cheatsheet rows are not named for assistive tech"
ok "reduced-motion profile and section/cheatsheet accessible names reach the QML shell"

# Desktop-feature parity work (calendar, system tray, system monitors, window
# overview). Each is wired end to end — a component that exists but is never
# instantiated, or a keybind/IPC target with no handler, is a silent no-op — so
# the checks pair the component with the thing that reaches it.

# Calendar: the clock opens it, shell.qml instantiates the single scope, and it
# reads the shared Time singleton rather than a clock of its own.
grep -q 'today' "$REPO/config/quickshell/Time.qml" \
    || fail "Time singleton does not expose today for the calendar"
grep -q 'Time.today' "$REPO/config/quickshell/Panel/Calendar.qml" \
    || fail "Calendar does not read today from the shared Time singleton"
grep -q 'Calendar {' "$REPO/config/quickshell/shell.qml" \
    || fail "shell.qml never instantiates the Calendar scope"
grep -q 'calendar.open = !bar.calendar.open' "$REPO/config/quickshell/Bar/Bar.qml" \
    || fail "the bar clock does not toggle the calendar"

# System tray: a StatusNotifier host in the bar, hidden when empty, with the
# three-button contract and a menu anchor.
grep -q 'Quickshell.Services.SystemTray' "$REPO/config/quickshell/Bar/Tray.qml" \
    || fail "Tray does not use the SystemTray service"
grep -q 'SystemTray.items.values.length > 0' "$REPO/config/quickshell/Bar/Tray.qml" \
    || fail "Tray does not hide itself when nothing is registered"
grep -q 'QsMenuAnchor' "$REPO/config/quickshell/Bar/TrayItem.qml" \
    || fail "tray items have no context-menu anchor"
grep -q 'Tray {' "$REPO/config/quickshell/Bar/Bar.qml" \
    || fail "the bar never places the system tray"

# System monitors: a single procfs-reading singleton, registered, feeding a bar
# widget that gates polling on being on screen.
grep -q '/proc/stat' "$REPO/config/quickshell/Services/SysInfo.qml" \
    || fail "SysInfo does not read CPU from /proc/stat"
grep -q '/proc/meminfo' "$REPO/config/quickshell/Services/SysInfo.qml" \
    || fail "SysInfo does not read memory from /proc/meminfo"
grep -q '^singleton SysInfo ' "$REPO/config/quickshell/Services/qmldir" \
    || fail "SysInfo singleton is not registered in the Services qmldir"
grep -q 'SysInfo.watch()' "$REPO/config/quickshell/Bar/SysMonitor.qml" \
    || fail "SysMonitor does not gate polling on being visible"
grep -q 'SysMonitor {' "$REPO/config/quickshell/Bar/Bar.qml" \
    || fail "the bar never places the system monitor"

# Window overview: live previews via ScreencopyView, reachable over IPC, bound
# to a keybind, with the blur/scrim rules a full-screen modal needs.
grep -q 'ScreencopyView' "$REPO/config/quickshell/Overview/WindowTile.qml" \
    || fail "overview tiles do not use a live ScreencopyView preview"
grep -q 'captureSource: root.toplevel?.wayland' "$REPO/config/quickshell/Overview/WindowTile.qml" \
    || fail "overview preview is not bound to the toplevel wayland handle"
grep -q 'target: "overview"' "$REPO/config/quickshell/Overview/Overview.qml" \
    || fail "overview has no IPC target for the keybind to reach"
grep -q 'qs ipc call overview toggle' "$REPO/config/hypr/keybindings.conf" \
    || fail "no keybind toggles the window overview"
grep -q 'Overview {' "$REPO/config/quickshell/shell.qml" \
    || fail "shell.qml never instantiates the Overview scope"
ok "calendar, system tray, system monitors, and window overview are wired end to end"


printf 'old wallpaper\n' > "$HYPRVEIL_CONFIG_HOME/hypr/wallpaper.jpg"
printf 'stale\n' > "$HYPRVEIL_CONFIG_HOME/hypr/stale-managed.conf"
mkdir -p "$HYPRVEIL_STATE_HOME"
printf '{"pins":[]}\n' > "$HYPRVEIL_STATE_HOME/dock-pins.json"
hv_deploy_configs >/dev/null
[ ! -e "$HYPRVEIL_CONFIG_HOME/hypr/stale-managed.conf" ] || fail "stale managed file survived replacement"
grep -q 'old wallpaper' "$HYPRVEIL_CONFIG_HOME/hypr/wallpaper.jpg" || fail "wallpaper was not preserved"
grep -q 'pins' "$HYPRVEIL_STATE_HOME/dock-pins.json" || fail "persistent state was overwritten"
find "$HYPRVEIL_STATE_HOME/backups" -path '*/config/hypr/stale-managed.conf' -print -quit | grep -q . \
    || fail "existing config was not timestamp-backed-up"
ok "rerun removes stale files while preserving backup, wallpaper, and state"

"$REPO/scripts/06-select-profile.sh" --ensure >/dev/null
grep -q 'form-factor/laptop.conf' "$HYPRVEIL_CONFIG_HOME/hypr/profiles/active.conf" || fail "profile not restored after deploy"
ok "saved profile restored after clean config replacement"

mkdir -p "$TMP/empty-sys/class/backlight" "$TMP/empty-sys/class/power_supply"
HYPRVEIL_SYSFS_ROOT="$TMP/empty-sys" "$REPO/config/hypr/scripts/hardware-action.sh" brightness-up
battery_output=$(HYPRVEIL_SYSFS_ROOT="$TMP/empty-sys" "$REPO/config/waybar/scripts/battery.sh")
printf '%s' "$battery_output" | grep -q '"text":""' || fail "battery module did not hide without a battery"
ok "absent brightness and battery hardware is handled safely"

cat > "$TMP/bin/wpctl" <<'EOF'
#!/usr/bin/env bash
printf 'wpctl %s\n' "$*" >> "${MOCK_DNF_ROOT:?}/osd-actions"
if [ "${1:-}" = get-volume ]; then
    printf 'Volume: 0.42\n'
fi
EOF
cat > "$TMP/bin/brightnessctl" <<'EOF'
#!/usr/bin/env bash
printf 'brightnessctl %s\n' "$*" >> "${MOCK_DNF_ROOT:?}/osd-actions"
if [ "${1:-}" = -m ]; then
    printf 'mock,intel_backlight,42,100,42%%\n'
fi
EOF
cat > "$TMP/bin/qs" <<'EOF'
#!/usr/bin/env bash
printf 'qs %s\n' "$*" >> "${MOCK_DNF_ROOT:?}/osd-actions"
EOF
chmod +x "$TMP/bin/wpctl" "$TMP/bin/brightnessctl" "$TMP/bin/qs"

rm -f "$TMP/osd-actions"
"$REPO/config/hypr/scripts/osd-action.sh" volume-up
grep -q 'wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 2%+' "$TMP/osd-actions" \
    || fail "OSD volume helper did not change sink volume"
grep -q 'qs ipc call osd show volume 42 false' "$TMP/osd-actions" \
    || fail "OSD volume helper did not show the coalesced overlay"

rm -f "$TMP/osd-actions"
HYPRVEIL_SYSFS_ROOT="$TMP/empty-sys" "$REPO/config/hypr/scripts/osd-action.sh" brightness-up
[ ! -e "$TMP/osd-actions" ] || fail "OSD brightness helper touched tools without backlight hardware"
ok "OSD media-key helper reports audio and preserves absent-brightness no-op"

report=$("$REPO/scripts/09-dependency-report.sh")
printf '%s' "$report" | grep -q 'Fedora: Fedora Linux 44 (Mock)' || fail "dependency report omitted Fedora version"
printf '%s' "$report" | grep -q 'Chosen package sources:' || fail "dependency report omitted package sources"
ok "dependency report includes Fedora version and package sources"

printf 'quickshell\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
printf 'standard\n' > "$HYPRVEIL_STATE_HOME/motion-profile"
printf '[]\n' > "$HYPRVEIL_STATE_HOME/dock-pins.json"
cat > "$HYPRVEIL_STATE_HOME/wallpapers.json" <<EOF
{"version":1,"fallback":{"path":"$HYPRVEIL_CONFIG_HOME/hypr/wallpaper-default.jpg","fit":"cover"},"monitors":{}}
EOF
cat > "$HYPRVEIL_STATE_HOME/accent.json" <<'EOF'
{"version":1,"accent":"#e14658","source":"default","auto":true,"chromeAlpha":"0.87"}
EOF
doctor=$("$REPO/hyprveil" doctor)
printf '%s' "$doctor" | grep -q 'Fedora Linux 44 (Mock) is supported' || fail "doctor omitted Fedora support"
printf '%s' "$doctor" | grep -q 'notification backend: quickshell' || fail "doctor omitted notification backend"
printf '%s' "$doctor" | grep -q 'Doctor found no failures' || fail "doctor did not complete a clean mocked report"
ok "doctor reports Fedora, dependencies, shell, and state in a mocked install"

printf '{broken json\n' > "$HYPRVEIL_STATE_HOME/wallpapers.json"
wallpaper_before=$(sha256sum "$HYPRVEIL_STATE_HOME/wallpapers.json")
doctor_status=0
doctor_bad=$("$REPO/hyprveil" doctor 2>&1) || doctor_status=$?
[ "$doctor_status" -ne 0 ] || fail "doctor succeeded with malformed wallpaper state"
printf '%s' "$doctor_bad" | grep -q 'wallpaper state is malformed' || fail "doctor did not explain malformed wallpaper state"
printf '%s' "$doctor_bad" | grep -q 'wallpaper.sh restore' || fail "doctor did not print wallpaper recovery command"
wallpaper_after=$(sha256sum "$HYPRVEIL_STATE_HOME/wallpapers.json")
[ "$wallpaper_before" = "$wallpaper_after" ] || fail "doctor modified malformed wallpaper state"
ok "doctor detects malformed state without modifying it"

printf 'not-a-profile\n' > "$HYPRVEIL_STATE_HOME/hardware-profile.conf"
"$REPO/scripts/06-select-profile.sh" --form-factor desktop --gpu intel >/dev/null 2>&1
find "$HYPRVEIL_STATE_HOME" -name 'hardware-profile.conf.invalid-*' -print -quit | grep -q . \
    || fail "malformed profile was not preserved"
ok "malformed profile state is preserved before recovery"

printf 'P0 smoke tests passed.\n'
