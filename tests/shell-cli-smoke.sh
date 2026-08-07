#!/usr/bin/env bash
# CLI, schema migration/validation/recovery, and shell-profile contracts.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-shell-cli.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
STATE="$TMP/state"
mkdir -p "$STATE"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

printf '%s\n' '{"version":1,"bar":{"workspacesMode":"fixed"},"dock":{"autohide":true},"accent":{"provider":"matugen"},"modules":{"calmMode":true,"launcherProviders":{"files":true,"calculator":false,"emoji":true}},"preferences":{"popupMonitor":"DP-1"},"monitors":{},"scenes":{"profiles":{},"previous":null}}' > "$STATE/settings.json"

settings=$(HYPRVEIL_STATE_HOME="$STATE" "$REPO/hyprveil" shell get settings)
jq -e '.version == 2 and .appearance.accentProvider == "matugen" and
    .dock.autohide and .providers.launcher.files and
    .surfaces.popupMonitor == "DP-1"' <<<"$settings" >/dev/null \
    || fail "schema v1 choices were not migrated to v2"
ok "settings schema v1 migrates to v2 without losing choices"

settings=$(HYPRVEIL_STATE_HOME="$STATE" "$REPO/hyprveil" shell set dock.autohide false)
jq -e '.dock.autohide == false and .appearance.accentProvider == "matugen"' \
    <<<"$settings" >/dev/null || fail "CLI setting update reset unrelated state"

if HYPRVEIL_STATE_HOME="$STATE" "$REPO/hyprveil" shell set dock.autohide invalid-json >/dev/null 2>&1; then
    fail "an invalid typed setting was accepted"
fi
ok "CLI settings are schema-validated before writing"

HYPRVEIL_STATE_HOME="$STATE" "$REPO/config/hypr/scripts/scenes.sh" save work >/dev/null 2>&1
HYPRVEIL_STATE_HOME="$STATE" "$REPO/hyprveil" shell set dock.autohide true >/dev/null
HYPRVEIL_STATE_HOME="$STATE" "$REPO/config/hypr/scripts/scenes.sh" apply work >/dev/null 2>&1
settings=$(HYPRVEIL_STATE_HOME="$STATE" "$REPO/hyprveil" shell get settings)
jq -e '.dock.autohide == false and .scenes.previous != null' <<<"$settings" >/dev/null \
    || fail "schema v2 scenes could not restore a saved profile"
ok "schema v2 scenes save and apply through the validated store"

printf '{broken\n' > "$STATE/settings.json"
settings=$(HYPRVEIL_STATE_HOME="$STATE" "$REPO/hyprveil" shell get settings 2>/dev/null)
jq -e '.version == 2 and .dock.autohide == false' <<<"$settings" >/dev/null \
    || fail "malformed settings did not recover to v2 defaults"
find "$STATE" -name 'settings.json.invalid-*' -type f | grep -q . \
    || fail "malformed settings were not preserved"
ok "malformed settings are preserved and recovered"

HYPRVEIL_STATE_HOME="$STATE" "$REPO/scripts/11-select-shell-profile.sh" --ensure >/dev/null
[ "$(HYPRVEIL_STATE_HOME="$STATE" "$REPO/config/hypr/scripts/notification-daemon.sh" profile)" = default ] \
    || fail "default shell profile was not selected"
HYPRVEIL_STATE_HOME="$STATE" "$REPO/scripts/11-select-shell-profile.sh" --profile recovery >/dev/null
[ "$(HYPRVEIL_STATE_HOME="$STATE" "$REPO/config/hypr/scripts/notification-daemon.sh" profile)" = recovery ] \
    || fail "recovery shell profile was not selected"
ok "default and recovery shell profiles persist independently"

HYPRVEIL_STATE_HOME="$STATE" "$REPO/scripts/07-select-notification-backend.sh" --backend mako >/dev/null
[ "$(cat "$STATE/shell-profile")" = recovery ] \
    || fail "selecting a fallback backend did not select recovery"
HYPRVEIL_STATE_HOME="$STATE" "$REPO/scripts/07-select-notification-backend.sh" --backend quickshell >/dev/null
[ "$(cat "$STATE/shell-profile")" = default ] \
    || fail "selecting Quickshell did not restore the default profile"
ok "notification backend compatibility maps to the explicit shell profiles"
