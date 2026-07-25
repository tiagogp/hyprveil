#!/usr/bin/env bash
# Mocked smoke test for the anti-flashbang brightness save/restore used by
# hypridle's before_sleep_cmd/after_sleep_cmd. No real backlight is required;
# a mock brightnessctl stands in for it.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p12.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

mkdir -p "$TMP/sys/class/backlight/intel_backlight" "$TMP/state" "$TMP/bin"
export PATH="$TMP/bin:$PATH"

# Real `brightnessctl -m` field order is device,class,current,percent%,max
# (e.g. "input2::kana,leds,0,0%,1") — matches what osd-action.sh already reads
# from field 4.
cat > "$TMP/bin/brightnessctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${MOCK_LOG:?}"
if [ "${1:-}" = -m ]; then
    printf 'mock,intel_backlight,62,62%%,100\n'
fi
EOF
chmod +x "$TMP/bin/brightnessctl"
export MOCK_LOG="$TMP/calls.log"
: > "$MOCK_LOG"

HW="$REPO/config/hypr/scripts/hardware-action.sh"

HYPRVEIL_SYSFS_ROOT="$TMP/sys" HYPRVEIL_STATE_HOME="$TMP/state" "$HW" brightness-save
[ "$(cat "$TMP/state/brightness")" = 62 ] || fail "brightness-save did not record 62"
[ "$(stat -c %a "$TMP/state/brightness")" = 600 ] || fail "brightness state permissions are not private"
ok "brightness-save reads the current level and persists it privately"

: > "$MOCK_LOG"
HYPRVEIL_SYSFS_ROOT="$TMP/sys" HYPRVEIL_STATE_HOME="$TMP/state" "$HW" brightness-restore
mapfile -t calls < <(grep '^set ' "$MOCK_LOG")
[ "${#calls[@]}" -eq 5 ] || fail "expected 5 ramp steps, got ${#calls[@]}: ${calls[*]:-<none>}"
[ "${calls[0]}" = "set 2%" ] || fail "ramp did not start at the low floor: ${calls[0]}"
[ "${calls[-1]}" = "set 62%" ] || fail "ramp did not end exactly at the saved level: ${calls[-1]}"
ok "brightness-restore forces the register and ramps from a low floor to the saved level"

# A target below the floor must not overshoot: the floor collapses to the
# target itself rather than starting the ramp above it.
printf '1\n' > "$TMP/state/brightness"
: > "$MOCK_LOG"
HYPRVEIL_SYSFS_ROOT="$TMP/sys" HYPRVEIL_STATE_HOME="$TMP/state" "$HW" brightness-restore
mapfile -t low_calls < <(grep '^set ' "$MOCK_LOG")
for call in "${low_calls[@]}"; do
    [ "$call" = "set 1%" ] || fail "ramp overshot a target below the floor: $call"
done
ok "a saved target below the floor never overshoots"

# restore is a no-op with nothing saved.
rm -f "$TMP/state/brightness"
: > "$MOCK_LOG"
HYPRVEIL_SYSFS_ROOT="$TMP/sys" HYPRVEIL_STATE_HOME="$TMP/state" "$HW" brightness-restore
[ ! -s "$MOCK_LOG" ] || fail "restore touched brightnessctl with nothing saved"
ok "restore is a no-op when nothing has been saved"

printf 'P12 brightness ramp smoke tests passed.\n'
