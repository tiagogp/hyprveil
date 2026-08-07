#!/usr/bin/env bash
# Runs tests/manual/providers/probe.qml through the real `quickshell` binary
# and checks the results it writes — the calculator's hand-rolled arithmetic
# parser and the emoji provider's default-off/enabled behavior are exactly
# the kind of logic a source-text grep cannot exercise. See p13-qml-load-
# smoke.sh for why no live Wayland session is required.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p18.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

if ! command -v quickshell >/dev/null 2>&1; then
    printf 'WARN: quickshell is unavailable; skipping the launcher providers probe\n' >&2
    exit 0
fi

mkdir -p "$TMP/home/.config" "$TMP/home/.local/state"
ln -s "$REPO/config/hypr" "$TMP/home/.config/hypr"
OUT="$TMP/results.txt"
: > "$OUT"

QSLOG="$TMP/quickshell.log"
HOME="$TMP/home" XDG_STATE_HOME="$TMP/home/.local/state" HYPRVEIL_PROBE_OUT="$OUT" \
    timeout 8 quickshell -p "$REPO/tests/manual/providers/probe.qml" >"$QSLOG" 2>&1 &
QS_PID=$!

# Poll for the DONE marker instead of a fixed sleep — quicker on a fast
# machine, still bounded by the `timeout 8` above on a slow one.
for _ in $(seq 1 40); do
    grep -q '^DONE:' "$OUT" 2>/dev/null && break
    sleep 0.2
done
kill "$QS_PID" 2>/dev/null || true
wait "$QS_PID" 2>/dev/null || true

grep -q 'ERROR' "$QSLOG" && { cat "$QSLOG" >&2; fail "the probe logged a QML error"; }
grep -q '^DONE:' "$OUT" || { cat "$QSLOG" >&2; cat "$OUT" >&2; fail "the probe never finished — see quickshell log above"; }

get_line() { grep "^$1:" "$OUT" | tail -n1 | cut -d: -f2-; }

[ "$(get_line CALC_ADD)" = '"2 + 2 = 4"' ] || fail "calculator got 2 + 2 wrong: $(get_line CALC_ADD)"
[ "$(get_line CALC_PRECEDENCE)" = '"2 + 3 * 4 = 14"' ] || fail "calculator does not respect * before +: $(get_line CALC_PRECEDENCE)"
[ "$(get_line CALC_PAREN)" = '"(2 + 3) * 4 = 20"' ] || fail "calculator does not respect parentheses: $(get_line CALC_PAREN)"
[ "$(get_line CALC_DIV)" = '"9 / 2 = 4.5"' ] || fail "calculator got division wrong: $(get_line CALC_DIV)"
[ "$(get_line CALC_DIVZERO)" = 'null' ] || fail "division by zero should yield no result, not a value or a crash: $(get_line CALC_DIVZERO)"
[ "$(get_line CALC_NEGATIVE)" = '"-5 + 2 = -3"' ] || fail "calculator got a leading negative number wrong: $(get_line CALC_NEGATIVE)"
[ "$(get_line CALC_NONMATH)" = 'null' ] || fail "a plain app-name query must not be treated as arithmetic: $(get_line CALC_NONMATH)"
[ "$(get_line CALC_GARBLED)" = 'null' ] || fail "malformed arithmetic should yield no result, not a crash: $(get_line CALC_GARBLED)"
[ "$(get_line CALC_EMPTY)" = 'null' ] || fail "an empty query should yield no calculator result: $(get_line CALC_EMPTY)"
ok "the calculator provider parses precedence, parentheses, division, and negatives, and rejects non-math/malformed/empty queries"

[ "$(get_line EMOJI_DISABLED)" = '[]' ] || fail "emoji must be off by default: $(get_line EMOJI_DISABLED)"
ok "the emoji provider is off by default"

[ "$(get_line EMOJI_ENABLED_FIRE)" = '["🔥  fire"]' ] || fail "emoji did not match \"fire\" once enabled: $(get_line EMOJI_ENABLED_FIRE)"
[ "$(get_line EMOJI_ENABLED_NOMATCH)" = '[]' ] || fail "a non-matching emoji query should return nothing: $(get_line EMOJI_ENABLED_NOMATCH)"
[ "$(get_line EMOJI_ENABLED_EMPTY)" = '[]' ] || fail "an empty query should return no emoji: $(get_line EMOJI_ENABLED_EMPTY)"
ok "once enabled through Settings, the emoji provider matches by name and stays empty for an empty or non-matching query"

ok "launcher providers probe passed"
