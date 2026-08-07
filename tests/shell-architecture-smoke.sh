#!/usr/bin/env bash
# Source-level contracts that remain meaningful without a Wayland session.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
COMPONENTS="$REPO/config/quickshell/Design/Components"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

for name in HvButton HvIconButton HvToggle HvListRow HvActionRow HvTextField \
    HvSearchField HvSlider HvPanel HvDialog HvPopover HvSection HvHeader \
    HvEmptyState HvFocusRing HvTooltip HvContextMenu HvChrome; do
    [ -f "$COMPONENTS/$name.qml" ] || fail "missing shared component: $name"
    grep -q "^$name 1.0 $name.qml$" "$COMPONENTS/qmldir" \
        || fail "$name is not exported by the component module"
done
ok "the complete shared component library is exported"

for file in Session/Session.qml Launcher/Launcher.qml \
    Panel/Integrations.qml Panel/Preferences.qml; do
    path="$REPO/config/quickshell/$file"
    grep -q 'Design/Components' "$path" || fail "$file does not import shared controls"
    grep -q 'MouseArea {' "$path" && fail "$file still creates an ad-hoc MouseArea control"
done
ok "Session, Launcher, Integrations, and Preferences use shared interaction controls"

APP="$REPO/config/quickshell/App"
for name in SurfaceCoordinator SurfaceHost AnchoredHost ModalHost FullscreenHost PassiveHost Shell; do
    [ -f "$APP/$name.qml" ] || fail "missing App component: $name"
done
grep -q 'App.Shell' "$REPO/config/quickshell/shell.qml" \
    || fail "shell.qml is not a thin App/Shell entry point"
for surface in quick-settings calendar launcher session preferences wallpapers \
    integrations overview cheatsheet; do
    grep -q "registerSurface(\"$surface\"" "$APP/Shell.qml" \
        || fail "$surface is not registered with SurfaceCoordinator"
    grep -q "reportState(\"$surface\"" "$APP/Shell.qml" \
        || fail "$surface state is not synchronized with SurfaceCoordinator"
done
grep -q 'setControllerOpen(previous, false)' "$APP/SurfaceCoordinator.qml" \
    || fail "opening a surface does not close the previous controller"
grep -q 'restore.forceActiveFocus' "$APP/SurfaceCoordinator.qml" \
    || fail "the coordinator does not restore focus to the opener"
ok "surface coordinator registration, exclusivity, and focus restoration are wired"

for file in Panel/QuickSettings.qml Panel/Calendar.qml; do
    grep -q 'SurfaceCoordinator.originRect' "$REPO/config/quickshell/$file" \
        || fail "$file does not derive its entrance from the opening origin"
    grep -q 'HvPopover {' "$REPO/config/quickshell/$file" \
        || fail "$file does not use the shared popover transition"
done
grep -q 'Behavior on opacity' "$COMPONENTS/HvPanel.qml" \
    || fail "shared panels have no entry/exit transition"
for file in Session/Session.qml Launcher/Launcher.qml Panel/QuickSettings.qml \
    Panel/Integrations.qml Panel/Preferences.qml Panel/Wallpapers.qml \
    Panel/Cheatsheet.qml Panel/Calendar.qml; do
    grep -q 'HvHeader {' "$REPO/config/quickshell/$file" \
        || fail "$file does not use the unified header"
done
for file in Launcher/Launcher.qml Panel/Wallpapers.qml Overview/Overview.qml; do
    grep -q 'HvEmptyState {' "$REPO/config/quickshell/$file" \
        || fail "$file does not use the unified empty-state component"
done
for file in Bar/Bar.qml Dock/Dock.qml; do
    grep -q 'HvChrome {' "$REPO/config/quickshell/$file" \
        || fail "$file is not rendered as shared shell chrome"
done
ok "origin transitions, headers, state presentation, and shell chrome are unified"

for name in Audio Network Bluetooth Settings WallpaperService ShellActions State; do
    file="$REPO/config/quickshell/Services/$name.qml"
    [ -f "$file" ] || fail "missing centralized service: $name"
    for contract in available state busy error lastUpdated refresh; do
        grep -q "$contract" "$file" || fail "$name does not expose service contract field $contract"
    done
done
for name in Hyprland SystemActions Wallpaper; do
    [ -f "$REPO/config/quickshell/Adapters/$name.qml" ] || fail "missing external adapter: $name"
done
rg -q 'systemctl' "$REPO/config/quickshell/Session" "$REPO/config/quickshell/Launcher" \
    && fail "session or launcher still invokes systemctl directly"
settings_readers=$(rg -l '/settings.json' "$REPO/config/quickshell" -g '*.qml' || true)
[ "$settings_readers" = "$REPO/config/quickshell/Services/Settings.qml" ] \
    || fail "a feature reads settings.json directly"
for command in 'shell toggle' 'shell get' 'shell set' 'shell doctor' 'wallpaper set'; do
    grep -q "$command" "$REPO/hyprveil" || fail "public CLI is missing: hyprveil $command"
done
ok "service contracts, adapters, state discovery, and public CLI are present"

python3 - "$REPO/config/quickshell" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for path in root.rglob("*.qml"):
    text = path.read_text()
    depth = 0
    quote = None
    escaped = False
    line_comment = False
    block_comment = False
    i = 0
    while i < len(text):
        char = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if line_comment:
            if char == "\n":
                line_comment = False
        elif block_comment:
            if char == "*" and nxt == "/":
                block_comment = False
                i += 1
        elif quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "\"'`":
            quote = char
        elif char == "/" and nxt == "/":
            line_comment = True
            i += 1
        elif char == "/" and nxt == "*":
            block_comment = True
            i += 1
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth < 0:
                raise SystemExit(f"{path}: unmatched closing brace")
        i += 1
    if quote or block_comment or depth:
        raise SystemExit(f"{path}: unbalanced source (depth={depth}, quote={quote})")
PY
ok "all QML files have balanced source structure"
