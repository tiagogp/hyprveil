#!/usr/bin/env bash
# CLI, schema migration/validation/recovery, and shell-profile contracts.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-shell-cli.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
STATE="$TMP/state"
CONFIG="$TMP/config"
DATA="$TMP/share"
BIN="$TMP/bin"
mkdir -p "$STATE" "$CONFIG"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }
mkdir -p "$BIN"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$*"' > "$BIN/qs"
chmod +x "$BIN/qs"
hv() { PATH="$BIN:$PATH" HYPRVEIL_STATE_HOME="$STATE" HYPRVEIL_CONFIG_HOME="$CONFIG" "$REPO/hyprveil" "$@"; }

[ "$(hv shell toggle launcher)" = "ipc call surface toggle launcher" ] \
    || fail "surface CLI bypassed the centralized IPC target"
[ "$(hv shell dnd on)" = "ipc call surface dnd on" ] \
    || fail "DND CLI bypassed the centralized IPC target"
[ "$(hv shell osd volume 42 false)" = "ipc call surface osd volume 42 false" ] \
    || fail "OSD CLI bypassed the centralized IPC target"
if hv shell osd volume invalid false >/dev/null 2>&1; then
    fail "OSD CLI accepted a non-numeric percentage"
fi
ok "surface, notification, and OSD commands share one public IPC route"

printf '%s\n' '{"version":1,"bar":{"workspacesMode":"fixed"},"dock":{"autohide":true},"accent":{"provider":"matugen"},"modules":{"calmMode":true,"launcherProviders":{"files":true,"calculator":false,"emoji":true}},"preferences":{"popupMonitor":"DP-1"},"monitors":{},"scenes":{"profiles":{},"previous":null}}' > "$STATE/settings.json"

settings=$(hv shell get settings)
jq -e '.version == 2 and .appearance.accentProvider == "matugen" and
    .dock.autohide and .providers.launcher.files and
    .surfaces.popupMonitor == "DP-1"' <<<"$settings" >/dev/null \
    || fail "schema v1 choices were not migrated to v2"
ok "settings schema v1 migrates to v2 without losing choices"
[ -f "$CONFIG/hyprveil/shell.json" ] && [ -f "$STATE/settings.json.migrated" ] \
    || fail "legacy settings did not move from state to XDG config"
ok "shell preferences live in XDG config and legacy state migrates once"

settings=$(hv shell set dock.autohide false)
jq -e '.dock.autohide == false and .appearance.accentProvider == "matugen"' \
    <<<"$settings" >/dev/null || fail "CLI setting update reset unrelated state"

if hv shell set dock.autohide invalid-json >/dev/null 2>&1; then
    fail "an invalid typed setting was accepted"
fi
ok "CLI settings are schema-validated before writing"

HYPRVEIL_STATE_HOME="$STATE" HYPRVEIL_CONFIG_HOME="$CONFIG" "$REPO/config/hypr/scripts/scenes.sh" save work >/dev/null 2>&1
hv shell set dock.autohide true >/dev/null
HYPRVEIL_STATE_HOME="$STATE" HYPRVEIL_CONFIG_HOME="$CONFIG" "$REPO/config/hypr/scripts/scenes.sh" apply work >/dev/null 2>&1
settings=$(hv shell get settings)
jq -e '.dock.autohide == false and .scenes.previous != null' <<<"$settings" >/dev/null \
    || fail "schema v2 scenes could not restore a saved profile"
ok "schema v2 scenes save and apply through the validated store"

printf '{broken\n' > "$CONFIG/hyprveil/shell.json"
settings=$(hv shell get settings 2>/dev/null)
jq -e '.version == 2 and .dock.autohide == false' <<<"$settings" >/dev/null \
    || fail "malformed settings did not recover to v2 defaults"
find "$CONFIG" -name 'shell.json.invalid-*' -type f | grep -q . \
    || fail "malformed settings were not preserved"
ok "malformed settings are preserved and recovered"

defaults=$(jq -c '.default' "$REPO/config/hypr/scripts/data/settings-schema.json")
reset=$(hv shell reset)
[ "$(jq -c . <<<"$reset")" = "$defaults" ] \
    || fail "runtime defaults drifted from the authoritative schema"
ok "CLI and QML share one authoritative settings default"

HYPRVEIL_STATE_HOME="$STATE" "$REPO/scripts/11-select-shell-profile.sh" --ensure >/dev/null
[ "$(HYPRVEIL_STATE_HOME="$STATE" "$REPO/config/hypr/scripts/notification-daemon.sh" profile)" = default ] \
    || fail "default shell profile was not selected"
HYPRVEIL_STATE_HOME="$STATE" "$REPO/scripts/11-select-shell-profile.sh" --profile recovery >/dev/null
[ "$(HYPRVEIL_STATE_HOME="$STATE" "$REPO/config/hypr/scripts/notification-daemon.sh" profile)" = recovery ] \
    || fail "recovery shell profile was not selected"
ok "default and recovery shell profiles persist independently"

HYPRVEIL_STATE_HOME="$STATE" HYPRVEIL_CONFIG_HOME="$CONFIG" \
    "$REPO/scripts/07-select-notification-backend.sh" --backend mako >/dev/null
[ "$(cat "$STATE/shell-profile")" = recovery ] \
    || fail "selecting a fallback backend did not select recovery"
HYPRVEIL_STATE_HOME="$STATE" HYPRVEIL_CONFIG_HOME="$CONFIG" \
    "$REPO/scripts/07-select-notification-backend.sh" --backend quickshell >/dev/null
[ "$(cat "$STATE/shell-profile")" = default ] \
    || fail "selecting Quickshell did not restore the default profile"
jq -e '.providers.notifications == "quickshell"' "$CONFIG/hyprveil/shell.json" >/dev/null \
    || fail "notification backend did not update the typed provider setting"
ok "notification backend compatibility maps to the explicit shell profiles"

HYPRVEIL_STATE_HOME="$STATE" HYPRVEIL_CONFIG_HOME="$CONFIG" \
HYPRVEIL_DATA_HOME="$DATA" HYPRVEIL_BIN_HOME="$BIN" \
    bash -c ". '$REPO/scripts/lib/install-common.sh'; hv_install_cli" >/dev/null
[ "$("$BIN/hyprveil" --version)" = "hyprveil 0.2.0" ] \
    || fail "installed CLI is not runnable independently of the checkout path"
[ -f "$DATA/bash-completion/completions/hyprveil" ] \
    || fail "CLI completion was not installed"
ok "versioned CLI runtime and shell completion install into user paths"

HYPRVEIL_STATE_HOME="$STATE" HYPRVEIL_CONFIG_HOME="$CONFIG" \
HYPRVEIL_DATA_HOME="$DATA" HYPRVEIL_BIN_HOME="$BIN" \
    bash -c ". '$REPO/scripts/lib/install-common.sh'; hv_remove_cli"
[ ! -e "$DATA/hyprveil" ] && [ ! -e "$BIN/hyprveil" ] \
    || fail "CLI uninstall left its managed runtime behind"
ok "CLI runtime uninstall is scoped and complete"
