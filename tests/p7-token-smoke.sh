#!/usr/bin/env bash
# Guards the design token scale: the shape tokens.conf promises, the closed
# spacing set, unitless storage, and the rendered output actually landing on the
# scale. Also checks the committed outputs are in sync with their templates, so
# a template edit without a `theme.sh render` fails here instead of shipping.
#
# No Wayland session or ImageMagick needed; rendering happens in a scratch copy.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p7.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

TOKENS="$REPO/config/hypr/tokens.conf"
THEME="$REPO/config/hypr/scripts/theme.sh"
[ -f "$TOKENS" ] || fail "missing config/hypr/tokens.conf"
[ -x "$THEME" ] || fail "missing or non-executable config/hypr/scripts/theme.sh"

# The scales, restated here on purpose. This file is the second opinion — if it
# imported the values from tokens.conf it could only ever agree with itself.
RADIUS_SCALE=" 6 10 14 18 999 "
TEXT_SCALE=" 11 12 13 14 16 20 "
SPACING_SCALE=" 2 4 6 8 10 12 16 20 24 32 "
# Named one-offs, deliberately off the type scale. Adding to this list is a
# design decision; it should not be the reflex fix for a failing assertion.
TEXT_ONEOFFS=" 12.5 26 104 "

# --------------------------------------------------------------------------
# tokens.conf shape
# --------------------------------------------------------------------------
# Every meaningful line is `$name = value`. Both the renderer's regex and the
# checks below assume this, so it is asserted rather than hoped for.
while IFS= read -r line; do
    [ -n "${line// /}" ] || continue
    case "$line" in \#*) continue ;; esac
    [[ "$line" =~ ^\$[a-zA-Z0-9-]+[[:space:]]*=[[:space:]]*.+$ ]] \
        || fail "tokens.conf line is not \`\$name = value\`: $line"
done < "$TOKENS"
ok "every tokens.conf line is \$name = value"

# Values are stored unitless because the same 10 has to reach Hyprland as 10,
# CSS as 10px, and QML as 10. A unit here would be baked into all three.
while IFS= read -r line; do
    [[ "$line" =~ ^\$([a-zA-Z0-9-]+)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
    name="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    [[ "$value" =~ [0-9](px|pt|em|rem|ms|s|%)([[:space:],]|$) ]] \
        && fail "\$$name carries a unit: $value (units belong to the renderer)"
done < "$TOKENS"
ok "no token carries a unit"

# --------------------------------------------------------------------------
# The closed sets
# --------------------------------------------------------------------------
# The spacing set being CLOSED is what actually kills drift — a half-step is
# fine, a fourteenth distinct value is not.
while IFS= read -r line; do
    [[ "$line" =~ ^\$(space-[a-z0-9]+)[[:space:]]*=[[:space:]]*([0-9.]+) ]] || continue
    [[ "$SPACING_SCALE" = *" ${BASH_REMATCH[2]} "* ]] \
        || fail "\$${BASH_REMATCH[1]} = ${BASH_REMATCH[2]} is not in the closed spacing set"
done < "$TOKENS"

# shellcheck disable=SC2016
count=$(grep -cE '^\$space-[a-z0-9]+[[:space:]]*=' "$TOKENS")
expected=$(printf '%s' "$SPACING_SCALE" | wc -w)
[ "$count" -eq "$expected" ] \
    || fail "the spacing set has $count members but the scale has $expected; it is supposed to be closed"
ok "the spacing set is closed at $expected members"

while IFS= read -r line; do
    [[ "$line" =~ ^\$(radius-[a-z]+)[[:space:]]*=[[:space:]]*([0-9]+) ]] || continue
    [[ "$RADIUS_SCALE" = *" ${BASH_REMATCH[2]} "* ]] \
        || fail "\$${BASH_REMATCH[1]} = ${BASH_REMATCH[2]} is not on the radius ramp"
done < "$TOKENS"

# GTK discards an ENTIRE stylesheet on a non-hundred weight, which is why this
# is a hard failure and not a lint.
while IFS= read -r line; do
    [[ "$line" =~ ^\$(weight-[a-z]+)[[:space:]]*=[[:space:]]*([0-9]+) ]] || continue
    [ $((BASH_REMATCH[2] % 100)) -eq 0 ] \
        || fail "\$${BASH_REMATCH[1]} = ${BASH_REMATCH[2]} is not a whole hundred; GTK will discard the stylesheet"
done < "$TOKENS"
ok "radii are on the ramp and font weights are whole hundreds"

# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------
export HYPRVEIL_CONFIG_HOME="$TMP/config"
export HYPRVEIL_STATE_HOME="$TMP/state"
mkdir -p "$HYPRVEIL_CONFIG_HOME" "$HYPRVEIL_STATE_HOME"
for name in hypr quickshell wlogout swaync mako; do
    [ -d "$REPO/config/$name" ] || fail "missing managed config tree: config/$name"
    mkdir -p "$HYPRVEIL_CONFIG_HOME/$name"
    cp -a "$REPO/config/$name/." "$HYPRVEIL_CONFIG_HOME/$name/"
done

# The reload fan-out probes for live daemons; stub the lot so rendering is the
# only thing under test.
mkdir -p "$TMP/bin"
for tool in pgrep pkill hyprctl swaync-client makoctl; do
    printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/$tool"
done
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH"

"$THEME" render >/dev/null 2>&1 || fail "theme.sh render failed"

RENDERED=(
    "$HYPRVEIL_CONFIG_HOME/quickshell/Tokens.qml"
    "$HYPRVEIL_CONFIG_HOME/wlogout/style.css"
    "$HYPRVEIL_CONFIG_HOME/swaync/style.css"
    "$HYPRVEIL_CONFIG_HOME/mako/config"
)
for file in "${RENDERED[@]}"; do
    [ -f "$file" ] || fail "renderer did not produce $file"
done

# An unconsumed placeholder is the failure mode that ships a literal @radius-md@
# into a stylesheet, where GTK drops the rule and the UI silently loses a corner.
for file in "${RENDERED[@]}"; do
    if leftover=$(grep -oE '@[a-zA-Z0-9-]+@' "$file" | sort -u); then
        fail "unsubstituted placeholders in $(basename "$file"): $(printf '%s' "$leftover" | tr '\n' ' ')"
    fi
done
ok "every placeholder is consumed across all $(printf '%s' "${#RENDERED[@]}") consumers"

# accent.sh owns the mixed templates; a token reaching mako proves the handoff
# in theme.sh render actually happened rather than silently no-oping.
grep -q '^padding=16$' "$HYPRVEIL_CONFIG_HOME/mako/config" \
    || fail "the accent-owned templates did not receive the design tokens"
ok "the accent-owned templates receive tokens via the render handoff"

# --------------------------------------------------------------------------
# The rendered values land on the scale
# --------------------------------------------------------------------------
# Comments are prose, not declarations: wlogout's header explains why a
# `border-radius: 50%` ring would turn into an ellipse, and swaync keeps a
# commented-out scrollbar block. Scanning those would report values that are not
# in effect, so they come out first.
strip_css_comments() { sed -Ez 's#/\*([^*]|\*+[^*/])*\*+/##g' "$1"; }

for file in "$HYPRVEIL_CONFIG_HOME/wlogout/style.css" "$HYPRVEIL_CONFIG_HOME/swaync/style.css"; do
    strip_css_comments "$file" > "$TMP/live.css"
    while IFS= read -r value; do
        [ "$value" = 0 ] && continue
        [[ "$RADIUS_SCALE" = *" $value "* ]] \
            || fail "$(basename "$(dirname "$file")")/style.css has an off-scale radius: ${value}px"
    done < <(grep -oE 'border-radius:[[:space:]]*[0-9]+' "$TMP/live.css" | grep -oE '[0-9]+$')

    while IFS= read -r value; do
        [[ "$TEXT_SCALE" = *" $value "* || "$TEXT_ONEOFFS" = *" $value "* ]] \
            || fail "$(basename "$(dirname "$file")")/style.css has an off-scale font size: ${value}px"
    done < <(grep -oE 'font-size:[[:space:]]*[0-9.]+px' "$TMP/live.css" | grep -oE '[0-9.]+')

    while IFS= read -r value; do
        [ $((value % 100)) -eq 0 ] \
            || fail "$(basename "$(dirname "$file")")/style.css has a non-hundred font weight: $value"
    done < <(grep -oE 'font-weight:[[:space:]]*[0-9]+' "$TMP/live.css" | grep -oE '[0-9]+$')
done
ok "rendered stylesheets carry only on-scale radii, type, and weights"

# --------------------------------------------------------------------------
# The committed outputs match their templates
# --------------------------------------------------------------------------
# Generated files ship committed so an unrendered checkout looks like a deployed
# one. That only holds if template edits are rendered before they land.
HYPRVEIL_CONFIG_HOME="$REPO/config" HYPRVEIL_STATE_HOME="$TMP/state-check" \
    "$THEME" check >/dev/null 2>&1 \
    || fail "committed outputs are stale; run: theme.sh render"
ok "committed outputs are in sync with their templates"

# --------------------------------------------------------------------------
# Static contract
# --------------------------------------------------------------------------
grep -q 'source = ~/.config/hypr/tokens.conf' "$REPO/config/hypr/hyprlock.conf" \
    || fail "hyprlock.conf does not source tokens.conf"
grep -q 'tokens.conf' "$REPO/config/hypr/hyprland.conf" \
    || fail "hyprland.conf does not source tokens.conf"
[ -f "$REPO/docs/TOKENS.md" ] || fail "docs/TOKENS.md is referenced from tokens.conf but missing"
ok "tokens.conf is sourced by Hyprland and hyprlock, and documented"

printf 'P7 token smoke tests passed.\n'
