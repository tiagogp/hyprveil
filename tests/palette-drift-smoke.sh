#!/usr/bin/env bash
# Drift check for the neutral palette's manual mirrors. mako/config.in,
# swaync/style.css.in, waybar/style.css, and rofi/hyprveil.rasi.in each keep
# their own hand-written copy of the core neutrals (their own headers say so)
# because mako's format, waybar's plain CSS, and rofi's rasi cannot `source`
# neutrals.conf the way Hyprland/hyprlock do. This doesn't remove the mirror —
# it catches the day a neutral's value changes and one of the four is
# forgotten. Both forms actually in use are checked: bare hex (mako, waybar,
# rofi) and the "R, G, B" decimal triplet swaync's rgba() calls use.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
NEUTRALS="$REPO/config/hypr/neutrals.conf"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

[ -f "$NEUTRALS" ] || fail "missing config/hypr/neutrals.conf"

hex_of() {
    sed -nE "s/^\\\$$1[[:space:]]*=[[:space:]]*rgba\\(([0-9a-fA-F]{6})[0-9a-fA-F]{2}\\).*/\\1/p" \
        "$NEUTRALS" | tr '[:upper:]' '[:lower:]' | head -n1
}

decimal_of() {
    local hex=$1
    printf '%d, %d, %d' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

# Asserts $2 contains either the hex form or the "R, G, B" decimal form of
# neutral $1.
assert_mirrored() {
    local name=$1 file=$2 hex dec
    hex=$(hex_of "$name")
    [ -n "$hex" ] || fail "neutrals.conf has no \$$name"
    dec=$(decimal_of "$hex")
    grep -qi -- "$hex" "$file" || grep -qF -- "$dec" "$file" \
        || fail "$(basename "$file") is missing \$$name ($hex / $dec) — neutrals.conf drifted without its mirror"
}

MAKO="$REPO/config/mako/config.in"
SWAYNC="$REPO/config/swaync/style.css.in"
WAYBAR="$REPO/config/waybar/style.css"
ROFI="$REPO/config/rofi/hyprveil.rasi.in"
for f in "$MAKO" "$SWAYNC" "$WAYBAR" "$ROFI"; do
    [ -f "$f" ] || fail "missing $f"
done

for name in bg-surface text text-muted; do
    assert_mirrored "$name" "$MAKO"
    assert_mirrored "$name" "$SWAYNC"
    assert_mirrored "$name" "$WAYBAR"
done
ok "mako, swaync, and waybar mirror \$bg-surface/\$text/\$text-muted from neutrals.conf"

for name in text text-muted; do
    assert_mirrored "$name" "$ROFI"
done
ok "rofi's template mirrors \$text/\$text-muted from neutrals.conf"

printf 'Palette drift smoke test passed.\n'
