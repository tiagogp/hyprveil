#!/usr/bin/env bash
# scenes.sh: save, list, apply, one-step revert, remove, and the "no scene
# applied yet" / "no such scene" error paths.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p17.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

STORE="$REPO/config/hypr/scripts/settings-store.sh"
SCENES="$REPO/config/hypr/scripts/scenes.sh"
export HYPRVEIL_STATE_HOME="$TMP/state"

"$STORE" set '{"dock":{"autohide":true},"accent":{"provider":"matugen"},"modules":{"calmMode":true}}' >/dev/null
"$SCENES" save work >/dev/null 2>&1

"$SCENES" list | jq -e '. == ["work"]' >/dev/null \
    || fail "list did not report the saved scene"
ok "save records a named scene and list reports it"

"$STORE" set '{"dock":{"autohide":false},"accent":{"provider":"hyprveil"},"modules":{"calmMode":false}}' >/dev/null

"$SCENES" apply work >/dev/null 2>&1
out=$("$STORE" get)
echo "$out" | jq -e '.dock.autohide == true and .accent.provider == "matugen" and .modules.calmMode == true' >/dev/null \
    || fail "apply did not restore the saved scene's fields: $out"
ok "apply restores every field the scene snapshotted, atomically"

"$SCENES" revert >/dev/null 2>&1
out=$("$STORE" get)
echo "$out" | jq -e '.dock.autohide == false and .accent.provider == "hyprveil" and .modules.calmMode == false' >/dev/null \
    || fail "revert did not restore the pre-apply state: $out"
ok "revert undoes exactly the last apply"

"$SCENES" revert >/dev/null 2>&1 && fail "a second revert with nothing to undo should fail"
ok "revert refuses when nothing has been applied this session"

"$SCENES" apply does-not-exist >/dev/null 2>&1 && fail "applying an unknown scene should fail"
ok "applying an unknown scene name fails instead of silently doing nothing"

"$SCENES" remove work >/dev/null 2>&1
"$SCENES" list | jq -e '. == []' >/dev/null || fail "remove did not delete the scene"
ok "remove deletes a saved scene"

# A scene never touches wallpaper — only settings-store.sh's own fields.
"$SCENES" save empty >/dev/null 2>&1
profile=$("$STORE" get | jq -c '.scenes.profiles.empty')
echo "$profile" | jq -e 'has("wallpaper") | not' >/dev/null \
    || fail "a scene snapshot reached into wallpaper state, which it must never own"
ok "a scene snapshot never includes wallpaper state"

ok "scenes.sh smoke tests passed"
