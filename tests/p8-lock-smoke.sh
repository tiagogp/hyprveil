#!/usr/bin/env bash
# Guards the lock fallback chain.
#
# A lock screen that fails to appear is not an inconvenience, it is an unlocked
# machine — so every branch that cannot positively confirm the shell locked must
# fall through to hyprlock, and the branch where nothing can lock must fail
# LOUDLY rather than exit 0 (which hypridle would read as success).
#
# Every case drives lock.sh through HYPRVEIL_QS_BIN / HYPRVEIL_HYPRLOCK_BIN. That
# seam exists because the obvious approach — dropping a mock qs from PATH to
# simulate "not installed" — finds the real qs one directory later and locks the
# developer's session for real.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p8.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

LOCK="$REPO/config/hypr/scripts/lock.sh"
[ -x "$LOCK" ] || fail "missing or non-executable config/hypr/scripts/lock.sh"

mkdir -p "$TMP/bin"
# pidof must report "no hyprlock running", or lock.sh short-circuits.
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/pidof"
chmod +x "$TMP/bin/pidof"
export PATH="$TMP/bin:$PATH"

mock_hyprlock() {
    printf '#!/usr/bin/env bash\nprintf HYPRLOCK_RAN\nexit 0\n' > "$TMP/hyprlock"
    chmod +x "$TMP/hyprlock"
}
mock_qs() {
    printf '#!/usr/bin/env bash\n%s\n' "$1" > "$TMP/qs"
    chmod +x "$TMP/qs"
}
run_lock() {
    HYPRVEIL_QS_BIN="$TMP/qs" HYPRVEIL_HYPRLOCK_BIN="$TMP/hyprlock" \
        bash "$LOCK" 2>"$TMP/err" || printf 'EXIT:%s' "$?"
}

mock_hyprlock

# --- the shell is not installed ---
rm -f "$TMP/qs"
out=$(run_lock)
[ "$out" = HYPRLOCK_RAN ] || fail "a missing shell did not fall back to hyprlock (got: $out)"
grep -q 'not installed' "$TMP/err" || fail "the missing-shell fallback was not explained"

# --- the shell is installed but does not answer ---
mock_qs 'exit 1'
out=$(run_lock)
[ "$out" = HYPRLOCK_RAN ] || fail "an unresponsive shell did not fall back (got: $out)"
grep -q 'did not answer' "$TMP/err" || fail "the unresponsive-shell fallback was not explained"

# --- the shell answers but does not confirm the lock ---
# The dangerous case: a shell that is alive enough to reply and broken enough not
# to lock. Exiting 0 here leaves the machine unlocked and hypridle satisfied.
mock_qs 'printf something-else'
out=$(run_lock)
[ "$out" = HYPRLOCK_RAN ] || fail "an unconfirmed lock did not fall back (got: $out)"
grep -q 'did not confirm' "$TMP/err" || fail "the unconfirmed-lock fallback was not explained"

# --- the shell hangs ---
mock_qs 'sleep 30'
start=$(date +%s)
out=$(run_lock)
elapsed=$(( $(date +%s) - start ))
[ "$out" = HYPRLOCK_RAN ] || fail "a hung shell did not fall back (got: $out)"
[ "$elapsed" -lt 15 ] || fail "a hung shell was not timed out promptly (${elapsed}s)"
ok "every unconfirmed lock path falls back to hyprlock, including a hang"

# --- the shell confirms ---
mock_qs 'printf locked'
out=$(run_lock)
[ -z "$out" ] || fail "a confirmed lock still ran the fallback (got: $out)"
ok "a confirmed lock does not stack a second locker on top"

# --- nothing can lock the session ---
rm -f "$TMP/qs" "$TMP/hyprlock"
out=$(run_lock)
[ "$out" = "EXIT:1" ] \
    || fail "with no locker available lock.sh must exit non-zero, not report success (got: $out)"
grep -q 'NOT locked' "$TMP/err" || fail "the unlockable session was not reported loudly"
ok "an unlockable session fails loudly instead of reporting success"

# --- hyprlock already running ---
printf '#!/usr/bin/env bash\nexit 0\n' > "$TMP/bin/pidof"
mock_hyprlock
mock_qs 'printf locked'
out=$(run_lock)
[ -z "$out" ] || fail "lock.sh stacked a locker on an already-locked session (got: $out)"
ok "an already-locked session is left alone"

# --- static contract ---
grep -q 'lock.sh' "$REPO/config/hypr/hypridle.conf" \
    || fail "hypridle does not route through lock.sh, so the fallback never runs"
grep -q 'hyprlock' "$REPO/scripts/data/dependencies.tsv" \
    || fail "hyprlock is the lock fallback but is not a declared dependency"
# The IPC is deliberately one-way: an unlock over IPC would make the lock
# bypassable by anything that can reach the socket.
grep -q 'function unlock' "$REPO/config/quickshell/Lock/Lock.qml" \
    && fail "Lock.qml exposes unlock over IPC, which makes the lock bypassable"
ok "hypridle routes through the fallback and the lock IPC is one-way"

printf 'P8 lock smoke tests passed.\n'
