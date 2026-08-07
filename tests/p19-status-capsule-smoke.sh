#!/usr/bin/env bash
# Runs tests/manual/status-capsule/probe.qml through the real `quickshell`
# binary and checks that toggling DND (Popups.dontDisturb) and Calm Mode
# (CalmMode.toggleManual) both actually open the status capsule with the
# right text — the cross-scope wiring in shell.qml/Popups.qml is exactly
# the kind of thing that looks right in a diff and does nothing at runtime.
# See p13-qml-load-smoke.sh for why no live Wayland session is required.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p19.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

if ! command -v quickshell >/dev/null 2>&1; then
    printf 'WARN: quickshell is unavailable; skipping the status capsule probe\n' >&2
    exit 0
fi

mkdir -p "$TMP/home/.config" "$TMP/home/.local/state"
ln -s "$REPO/config/hypr" "$TMP/home/.config/hypr"
OUT="$TMP/results.txt"
: > "$OUT"

QSLOG="$TMP/quickshell.log"
HOME="$TMP/home" XDG_STATE_HOME="$TMP/home/.local/state" HYPRVEIL_PROBE_OUT="$OUT" \
    timeout 8 quickshell -p "$REPO/tests/manual/status-capsule/probe.qml" >"$QSLOG" 2>&1 &
QS_PID=$!

for _ in $(seq 1 40); do
    grep -q '^DONE:' "$OUT" 2>/dev/null && break
    sleep 0.2
done
kill "$QS_PID" 2>/dev/null || true
wait "$QS_PID" 2>/dev/null || true

grep -q 'ERROR' "$QSLOG" && { cat "$QSLOG" >&2; fail "the probe logged a QML error"; }
grep -q '^DONE:' "$OUT" || { cat "$QSLOG" >&2; cat "$OUT" >&2; fail "the probe never finished — see quickshell log above"; }

get_line() { grep "^$1:" "$OUT" | tail -n1 | cut -d: -f2-; }

[ "$(get_line BEFORE)" = "closed" ] || fail "the capsule must start closed: $(get_line BEFORE)"
[ "$(get_line DND_ON)" = "true:Do Not Disturb on" ] || fail "DND on did not open the capsule with the right text: $(get_line DND_ON)"
[ "$(get_line DND_OFF)" = "true:Do Not Disturb off" ] || fail "DND off did not re-open the capsule with the right text: $(get_line DND_OFF)"
ok "toggling Popups.dontDisturb opens the status capsule with the right text both ways"

[ "$(get_line CALM_ON)" = "true:Calm Mode on" ] || fail "enabling Calm Mode did not open the capsule with the right text: $(get_line CALM_ON)"
[ "$(get_line CALM_OFF)" = "true:Calm Mode off" ] || fail "disabling Calm Mode did not open the capsule with the right text: $(get_line CALM_OFF)"
ok "toggling CalmMode.toggleManual() opens the status capsule with the right text both ways"

ok "status capsule probe passed"
