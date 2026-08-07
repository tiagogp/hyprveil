#!/usr/bin/env bash
# settings-store.sh: defaults, atomic partial writes, migration passthrough,
# and recovery from a malformed file. Also a regression test for two bugs
# found while wiring Panel/Preferences.qml to this store:
#   1. `set` on a brand-new state directory (nobody has called `get` yet)
#      failed with "No such file or directory" opening the lock file.
#   2. `set` merged its patch onto DEFAULTS instead of onto the current
#      stored settings, so any `set` silently reset every field it did not
#      mention back to default — the second `set` in a session wiped the
#      first one's effect.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p16.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

STORE="$REPO/config/hypr/scripts/settings-store.sh"

# --- get on a fresh directory creates valid, versioned defaults ------------
STATE1="$TMP/state1"
out=$(HYPRVEIL_STATE_HOME="$STATE1" "$STORE" get)
echo "$out" | jq -e '.version == 1 and .dock.autohide == false and .accent.provider == "hyprveil"' >/dev/null \
    || fail "get on a fresh directory did not produce versioned defaults: $out"
[ -f "$STATE1/settings.json" ] || fail "get did not persist the defaults to disk"
ok "get on a fresh state directory writes versioned, schema-complete defaults"

# --- REGRESSION: set works with no prior get and no existing directory -----
STATE2="$TMP/state2"
HYPRVEIL_STATE_HOME="$STATE2" "$STORE" set '{"dock":{"autohide":true}}' \
    || fail "set failed on a brand-new state directory (missing mkdir before the lock redirect)"
HYPRVEIL_STATE_HOME="$STATE2" "$STORE" get | jq -e '.dock.autohide == true' >/dev/null \
    || fail "set on a fresh directory did not persist"
ok "set works on a completely fresh state directory with no prior get"

# --- REGRESSION: an unrelated second `set` must not reset earlier fields ---
STATE3="$TMP/state3"
HYPRVEIL_STATE_HOME="$STATE3" "$STORE" set '{"dock":{"autohide":true}}' >/dev/null
HYPRVEIL_STATE_HOME="$STATE3" "$STORE" set '{"accent":{"provider":"matugen"}}' >/dev/null
out=$(HYPRVEIL_STATE_HOME="$STATE3" "$STORE" get)
echo "$out" | jq -e '.dock.autohide == true' >/dev/null \
    || fail "an unrelated set() reset dock.autohide back to default: $out"
echo "$out" | jq -e '.accent.provider == "matugen"' >/dev/null \
    || fail "set did not apply its own patch: $out"
echo "$out" | jq -e '.modules.launcherProviders.calculator == true' >/dev/null \
    || fail "an untouched nested default was reset by an unrelated set(): $out"
ok "set merges its patch onto the current stored settings, not onto raw defaults"

# --- a deep patch only touches the keys it names ----------------------------
STATE4="$TMP/state4"
HYPRVEIL_STATE_HOME="$STATE4" "$STORE" set '{"modules":{"calmMode":true}}' >/dev/null
out=$(HYPRVEIL_STATE_HOME="$STATE4" "$STORE" get)
echo "$out" | jq -e '.modules.calmMode == true and .modules.launcherProviders.calculator == true' >/dev/null \
    || fail "a patch to one nested key clobbered its object siblings: $out"
ok "a nested patch leaves sibling keys in the same object untouched"

# --- malformed settings.json is backed up and reset, not left broken -------
STATE5="$TMP/state5"
mkdir -p "$STATE5"
printf 'not json' > "$STATE5/settings.json"
out=$(HYPRVEIL_STATE_HOME="$STATE5" "$STORE" get)
echo "$out" | jq -e '.version == 1' >/dev/null || fail "malformed settings.json was not recovered: $out"
compgen -G "$STATE5/settings.json.invalid-*" >/dev/null \
    || fail "malformed settings.json was not backed up before recovery"
ok "malformed settings.json is backed up and replaced with valid defaults"

# --- reset returns to defaults ----------------------------------------------
STATE6="$TMP/state6"
HYPRVEIL_STATE_HOME="$STATE6" "$STORE" set '{"dock":{"autohide":true}}' >/dev/null
HYPRVEIL_STATE_HOME="$STATE6" "$STORE" reset
HYPRVEIL_STATE_HOME="$STATE6" "$STORE" get | jq -e '.dock.autohide == false' >/dev/null \
    || fail "reset did not restore defaults"
ok "reset restores every field to its default"

ok "settings-store.sh smoke tests passed"
