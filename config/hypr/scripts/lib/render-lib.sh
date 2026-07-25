#!/usr/bin/env bash
# Shared rendering primitives for the two theme renderers.
#
# accent.sh derives the accent family from the wallpaper; theme.sh renders the
# design tokens. They write disjoint sets of files — no output is produced by
# both — but they share the same three mechanics: write only on change, expand
# `.in` templates for formats with no include mechanism, and fan a reload out to
# whatever is running. Those live here so the two stay in step.
#
# Sourced, never executed. The caller sets HV_LOG_PREFIX before sourcing to
# label its diagnostics.

HV_LOG_PREFIX="${HV_LOG_PREFIX:-Theme}"

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
CONFIG_HOME="${HYPRVEIL_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
# One lock for both renderers: their outputs are disjoint, but a reload fired
# mid-render by the other would push a half-written stylesheet.
LOCK_FILE="$STATE_HOME/accent.lock"

die() { printf '%s: %s\n' "$HV_LOG_PREFIX" "$*" >&2; exit 2; }
warn() { printf '%s: %s\n' "$HV_LOG_PREFIX" "$*" >&2; }

# --------------------------------------------------------------------------
# Color math
# --------------------------------------------------------------------------

# Shared OKLCH conversion primitives (Björn Ottosson's OKLab, standard M1/M2
# matrices). Used everywhere hue/chroma/lightness need to move independently
# without HSL's perceptual unevenness — HSL lightening shifts perceived hue
# and chroma unevenly across the color wheel, which shows up as the same
# numeric delta looking like a bigger jump on some hues than others. OKLCH's
# axes are perceptually uniform, so one delta means the same thing everywhere.
#
# Spliced into a caller's own awk script (accent.sh's score_histogram does
# this too), the same way accent.sh's CHROME_AWK_LIB is shared.
OKLCH_AWK_LIB='
    function srgb_lin(c) {
        c /= 255
        return (c <= 0.04045) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4
    }
    function lin_srgb(c) {
        c = (c <= 0.0031308) ? c * 12.92 : 1.055 * (c ^ (1/2.4)) - 0.055
        if (c < 0) c = 0
        if (c > 1) c = 1
        return c * 255
    }
    # Guards the fractional exponent below zero: LMS values can round to a
    # hair under 0 for near-black or edge-of-gamut colors, and x^(1/3) on a
    # negative base is undefined in awk (real domain only).
    function cbrt(x) { return (x < 0) ? -((-x) ^ (1/3)) : x ^ (1/3) }

    # Sets globals OKL, OKC, OKH (radians) from 8-bit sRGB channels.
    function rgb2oklch(r, g, b,   R, G, B, l, m, s, l_, m_, s_, La, aa, bb) {
        R = srgb_lin(r); G = srgb_lin(g); B = srgb_lin(b)
        l = 0.4122214708*R + 0.5363325363*G + 0.0514459929*B
        m = 0.2119034982*R + 0.6806995451*G + 0.1073969566*B
        s = 0.0883024619*R + 0.2817188376*G + 0.6299787005*B
        l_ = cbrt(l); m_ = cbrt(m); s_ = cbrt(s)
        La = 0.2104542553*l_ + 0.7936177850*m_ - 0.0040720468*s_
        aa = 1.9779984951*l_ - 2.4285922050*m_ + 0.4505937099*s_
        bb = 0.0259040371*l_ + 0.7827717662*m_ - 0.8086757660*s_
        OKL = La; OKC = sqrt(aa*aa + bb*bb); OKH = atan2(bb, aa)
    }

    # Sets globals RL, GL, BL: unclamped LINEAR sRGB for an OKLCH triple.
    # Split out so the gamut check and oklch2hex share one transform.
    function oklch2rgb_lin(L, C, H,   aa, bb, l_, m_, s_, l, m, s) {
        aa = C * cos(H); bb = C * sin(H)
        l_ = L + 0.3963377774*aa + 0.2158037573*bb
        m_ = L - 0.1055613458*aa - 0.0638541728*bb
        s_ = L - 0.0894841775*aa - 1.2914855480*bb
        l = l_*l_*l_; m = m_*m_*m_; s = s_*s_*s_
        RL = 4.0767416621*l - 3.3077115913*m + 0.2309699292*s
        GL = -1.2684380046*l + 2.6097574011*m - 0.3413193965*s
        BL = -0.0041960863*l - 0.7034186147*m + 1.7076147010*s
    }
    function ok_in_gamut(   eps) {
        eps = 1e-4
        return (RL >= -eps && RL <= 1+eps && GL >= -eps && GL <= 1+eps && BL >= -eps && BL <= 1+eps)
    }

    # Prints "rrggbb" for an OKLCH triple. If it falls outside sRGB,
    # binary-searches (12 iterations, 2^-12 precision) the largest in-gamut
    # chroma at the SAME L and H, so an over-lightened saturated color
    # desaturates gracefully at the gamut edge instead of the hue shift a
    # naive per-channel clamp would cause.
    function oklch2hex(L, C, H,   lo, hi, mid, i) {
        oklch2rgb_lin(L, C, H)
        if (!ok_in_gamut()) {
            lo = 0; hi = C
            for (i = 0; i < 12; i++) {
                mid = (lo + hi) / 2
                oklch2rgb_lin(L, mid, H)
                if (ok_in_gamut()) lo = mid; else hi = mid
            }
            oklch2rgb_lin(L, lo, H)
        }
        return sprintf("%02x%02x%02x", lin_srgb(RL)+0.5, lin_srgb(GL)+0.5, lin_srgb(BL)+0.5)
    }
'

# Shifts lightness by a signed amount in OKLCH, holding hue and chroma. Used
# for the hover shade and the lock screen's dim fill.
shade() {
    local hex=$1 delta=$2
    printf '%s %s\n' "${hex#\#}" "$delta" | awk "$OKLCH_AWK_LIB"'
        {
            hex = $1; delta = $2 + 0
            r = strtonum("0x" substr(hex, 1, 2))
            g = strtonum("0x" substr(hex, 3, 2))
            b = strtonum("0x" substr(hex, 5, 2))
            rgb2oklch(r, g, b)
            L = OKL + delta
            if (L < 0) L = 0
            if (L > 1) L = 1
            printf "#%s\n", oklch2hex(L, OKC, OKH)
        }
    '
}

rgb_triplet() {
    local hex=${1#\#}
    printf '%d,%d,%d\n' "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

valid_hex() { [[ "$1" =~ ^#[0-9A-Fa-f]{6}$ ]]; }

normalize_hex() {
    local hex=$1
    [[ "$hex" = \#* ]] || hex="#$hex"
    valid_hex "$hex" || return 1
    printf '#%s\n' "$(printf '%s' "${hex#\#}" | tr '[:upper:]' '[:lower:]')"
}

# --------------------------------------------------------------------------
# Writing
# --------------------------------------------------------------------------

# Writes $2.. as the content of $1, but only when it differs. Skipping identical
# writes keeps the reload step from restarting components that would render the
# same pixels, which matters because a wallpaper cycle can fire on every login.
write_if_changed() {
    local target=$1 content=$2 dir
    dir=$(dirname "$target")
    [ -d "$dir" ] || return 0
    if [ -f "$target" ] && [ "$(cat "$target")" = "$content" ]; then
        return 1
    fi
    printf '%s\n' "$content" > "$target" || die "could not write $target"
    return 0
}

# Placeholder table consumed by render_template. Callers populate it before
# rendering; keys are placeholder names without the surrounding @.
declare -A HV_TOKENS=()

TOKENS_FILE="${HYPRVEIL_TOKENS_FILE:-$CONFIG_HOME/hypr/tokens.conf}"

# Adds every design token to HV_TOKENS. Additive on purpose: a template that
# carries both @radius-md-px@ and @accent@ has to be rendered by ONE writer, or
# each pass would leave the other's placeholders in the file. accent.sh owns
# those mixed templates and calls this first; theme.sh owns the token-only ones.
#
# tokens.conf guarantees every meaningful line is `$name = value` and nothing
# else, which is what lets this be a regex rather than a parser — and what
# tests/p7-token-smoke.sh enforces so it stays that way.
#
# Numeric tokens also get `-px` and `-ms` variants. They are generated
# unconditionally rather than from a list of which token needs which unit,
# because that list is a second table that drifts from this one; an unused
# placeholder costs one sed clause and is never written anywhere.
load_design_tokens() {
    local line name value key points
    [ -f "$TOKENS_FILE" ] || { warn "tokens file not found: $TOKENS_FILE"; return 1; }

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^\$([a-zA-Z0-9-]+)[[:space:]]*=[[:space:]]*(.*)$ ]] || continue
        name="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        # Trim trailing whitespace; tokens.conf aligns its `=` with spaces.
        value="${value%"${value##*[![:space:]]}"}"
        HV_TOKENS["$name"]="$value"
        if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            HV_TOKENS["$name-px"]="${value}px"
            HV_TOKENS["$name-ms"]="${value}ms"
        fi
    done < "$TOKENS_FILE"

    # Second pass, over a snapshot of the keys: bash gives no ordering guarantee
    # for an associative array and inserting during iteration is undefined.
    #
    # `$ease-out-points = 0.16, 1, 0.3, 1` is stored bare because Hyprland's
    # `bezier =` line wants it that way. CSS and QML want the same numbers
    # wrapped, so @ease-out@ is derived rather than written twice.
    for key in "${!HV_TOKENS[@]}"; do
        [[ "$key" = *-points ]] || continue
        points="${HV_TOKENS[$key]}"
        HV_TOKENS["${key%-points}"]="cubic-bezier($points)"
    done
}

# The neutral palette, the counterpart to the accent family. neutrals.conf holds
# every non-accent color as `$name = rgba(RRGGBBAA)`; this adds, per name, the
# forms the consumers need — `@name@` as `#rrggbb` (starship) and `@name-bare@`
# as `rrggbb` (for composing a translucent shade, `#26@accent-bare@` style).
# Additive on HV_TOKENS, exactly like load_design_tokens: the templates that
# carry both an accent and a neutral placeholder are rendered by ONE writer
# (accent.sh), which calls this after loading the tokens and the accent.
#
# The alpha byte in each rgba() is dropped: neutrals are the opaque design
# colors, and every consumer that needs a translucent shade of one composes it
# from the bare hex with its own alpha, the way the accent washes already do.
PALETTE_FILE="${HYPRVEIL_PALETTE_FILE:-$CONFIG_HOME/hypr/neutrals.conf}"

load_palette() {
    local line name hex
    [ -f "$PALETTE_FILE" ] || { warn "palette file not found: $PALETTE_FILE"; return 1; }

    while IFS= read -r line || [ -n "$line" ]; do
        [[ "$line" =~ ^\$([a-zA-Z0-9-]+)[[:space:]]*=[[:space:]]*rgba\(([0-9a-fA-F]{6})[0-9a-fA-F]{2}\) ]] || continue
        name="${BASH_REMATCH[1]}"
        hex="$(printf '%s' "${BASH_REMATCH[2]}" | tr '[:upper:]' '[:lower:]')"
        HV_TOKENS["$name"]="#$hex"
        HV_TOKENS["$name-bare"]="$hex"
    done < "$PALETTE_FILE"
}

# Escapes a value for use as a sed replacement. Today every token is numeric or
# a hex color so none of these characters occur — which is exactly why the
# escaping would be forgotten the first time a token holds a font name or a path.
hv_sed_escape() {
    printf '%s' "$1" | sed -e 's/[\\&/]/\\&/g'
}

# Formats with no include mechanism — mako, the Qt color schemes, the wlogout
# icon SVGs, and the token-bearing stylesheets — are regenerated from a `.in`
# template carrying @name@ placeholders. The templates ship alongside the
# outputs, which is what makes rendering idempotent instead of a repeated
# search-and-replace over a file whose current value we would have to guess.
render_template() {
    local template=$1 target=$2 content key
    [ -f "$template" ] || return 1
    local -a args=()
    for key in "${!HV_TOKENS[@]}"; do
        args+=(-e "s/@$key@/$(hv_sed_escape "${HV_TOKENS[$key]}")/g")
    done
    content=$(sed "${args[@]}" "$template")
    write_if_changed "$target" "$content"
}

# --------------------------------------------------------------------------
# Locking
# --------------------------------------------------------------------------

# Serializes the two renderers against each other. Opens fd 9 on the lock; the
# caller releases with hv_unlock.
hv_lock() {
    mkdir -p "$STATE_HOME"
    exec 9>"$LOCK_FILE"
    flock 9
}

hv_unlock() { flock -u 9; }

# --------------------------------------------------------------------------
# Live reload
# --------------------------------------------------------------------------

reload_waybar() {
    pgrep -x waybar >/dev/null 2>&1 || return 0
    pkill -SIGUSR2 -x waybar >/dev/null 2>&1 || warn "could not signal Waybar to reload"
}

reload_swaync() {
    pgrep -x swaync >/dev/null 2>&1 || return 0
    command -v swaync-client >/dev/null 2>&1 || return 0
    swaync-client --reload-css >/dev/null 2>&1 || warn "could not reload the SwayNC stylesheet"
}

reload_mako() {
    pgrep -x mako >/dev/null 2>&1 || return 0
    command -v makoctl >/dev/null 2>&1 || return 0
    makoctl reload >/dev/null 2>&1 || warn "could not reload Mako"
}

# Quickshell's Quickshell.watchFiles defaults to true, so writing Accent.qml or
# Tokens.qml already IS the reload — verified by watching the instance's load
# count increment on an accent change. There is deliberately nothing to send.
#
# A named no-op rather than an omission from reload_all, so the next person
# looking for "where does the shell get told" finds the answer instead of
# concluding it was forgotten.
#
# The reload is a full config reload, which is why NotificationServer sets
# keepOnReload: true — without it, changing the wallpaper would silently discard
# the session's notification history.
#
# Caveat worth knowing: the watcher tracks the paths it started with. Replacing
# ~/.config/quickshell wholesale — a symlink swapped for a directory, or
# hv_deploy_configs moving a staged tree into place — leaves the running
# instance watching paths that no longer exist, and it will stop reacting until
# it is restarted.
reload_quickshell() { :; }

reload_hyprland() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    pgrep -x Hyprland >/dev/null 2>&1 || return 0
    hyprctl reload >/dev/null 2>&1 || warn "could not reload Hyprland"
}

reload_all() {
    reload_hyprland
    reload_waybar
    reload_swaync
    reload_mako
    reload_quickshell
}
