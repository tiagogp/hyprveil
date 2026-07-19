#!/usr/bin/env bash
# Derive the system accent from the current wallpaper and render it into every
# component that draws with it.
#
# The neutral palette in colors.conf is fixed by design; only the accent family
# moves. Each consumer either imports a generated fragment (Hyprland `source`,
# GTK CSS `@import`, Sass `@use`, rofi `@import`, kitty `include`) or is
# regenerated from a `.in` template when its format has no include mechanism
# (mako, qt5ct/qt6ct, the wlogout icon SVGs).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HV_LOG_PREFIX=Accent
# shellcheck source=lib/render-lib.sh
. "$SCRIPT_DIR/lib/render-lib.sh"

STATE_FILE="$STATE_HOME/accent.json"

# The palette's designed accent. Every template ships with this value baked in,
# so an unrendered checkout and a freshly deployed config look identical.
DEFAULT_ACCENT="#e14658"
DEFAULT_HOVER="#e86a79"

usage() {
    cat <<'EOF'
Usage:
  accent.sh from-wallpaper PATH   derive the accent from an image and apply it
  accent.sh set HEX               apply an explicit accent (#rrggbb)
  accent.sh reset                 return to the designed accent
  accent.sh extract PATH          print the accent an image would produce
  accent.sh render                re-render every consumer from saved state
  accent.sh current               print the saved accent state as JSON
  accent.sh auto [on|off]         follow wallpaper changes (default: on)

`render` is the repair path: it rewrites all generated fragments from
$XDG_STATE_HOME/hyprveil/accent.json. install.sh runs it after replacing a
managed config tree, which would otherwise leave the default-red fragments in
place; run it by hand after editing a .in template.
EOF
}

# --------------------------------------------------------------------------
# Extraction
# --------------------------------------------------------------------------

magick_cmd() {
    if command -v magick >/dev/null 2>&1; then
        printf 'magick\n'
    elif command -v convert >/dev/null 2>&1; then
        printf 'convert\n'
    else
        return 1
    fi
}

# Prints "count rrggbb" per line for the image's dominant colors.
#
# Scaling to 200px first keeps the quantizer's cost independent of the source
# resolution, and -colors collapses gradients into countable buckets. The
# histogram's own text format is parsed rather than -format %c on the pixels,
# because only the histogram carries the pixel counts we weight by.
histogram() {
    local image=$1 magick
    magick=$(magick_cmd) || return 1
    "$magick" "$image" -resize 200x200 -depth 8 -colors 24 \
        -define histogram:unique-colors=true -format %c histogram:info:- 2>/dev/null \
        | sed -n 's/^[[:space:]]*\([0-9]\+\):.*#\([0-9A-Fa-f]\{6\}\).*/\1 \2/p'
}

# Chooses the accent from a histogram on stdin.
#
# A wallpaper's *dominant* color is almost always a desaturated background that
# would vanish against the dark neutrals, so frequency alone is the wrong
# signal. Colors are scored on saturation and mid-range lightness first and
# pixel share only as a tie-breaker, then the winner is pushed into a band that
# is guaranteed to stay legible on #0f1115. A greyscale image therefore still
# yields a usable (if muted) accent rather than an invisible near-black.
score_histogram() {
    awk '
        function max3(a, b, c) { return (a > b ? (a > c ? a : c) : (b > c ? b : c)) }
        function min3(a, b, c) { return (a < b ? (a < c ? a : c) : (b < c ? b : c)) }

        function rgb2hsl(r, g, b,   mx, mn, d) {
            r /= 255; g /= 255; b /= 255
            mx = max3(r, g, b); mn = min3(r, g, b); d = mx - mn
            L = (mx + mn) / 2
            if (d == 0) { H = 0; S = 0; return }
            S = (L > 0.5) ? d / (2 - mx - mn) : d / (mx + mn)
            if (mx == r)      H = (g - b) / d + (g < b ? 6 : 0)
            else if (mx == g) H = (b - r) / d + 2
            else              H = (r - g) / d + 4
            H /= 6
        }

        function hue2rgb(p, q, t) {
            if (t < 0) t += 1
            if (t > 1) t -= 1
            if (t < 1/6) return p + (q - p) * 6 * t
            if (t < 1/2) return q
            if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
            return p
        }

        function hsl2hex(h, s, l,   q, p, r, g, b) {
            if (s == 0) { r = g = b = l }
            else {
                q = (l < 0.5) ? l * (1 + s) : l + s - l * s
                p = 2 * l - q
                r = hue2rgb(p, q, h + 1/3); g = hue2rgb(p, q, h); b = hue2rgb(p, q, h - 1/3)
            }
            return sprintf("%02x%02x%02x", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5)
        }

        {
            n++
            count[n] = $1 + 0
            hex = $2
            r = strtonum("0x" substr(hex, 1, 2))
            g = strtonum("0x" substr(hex, 3, 2))
            b = strtonum("0x" substr(hex, 5, 2))
            rgb2hsl(r, g, b)
            hh[n] = H; ss[n] = S; ll[n] = L
            # Chroma, not HSL saturation, is what "colorful" means here. HSL
            # saturation explodes near black and white — a near-white cream
            # scores 0.92 and a near-black scores 0.87 — so ranking by it hands
            # the accent to washed-out sky and shadow. Chroma stays honest.
            cc[n] = max3(r, g, b) / 255 - min3(r, g, b) / 255
            total += count[n]
        }

        END {
            if (total == 0 || n == 0) { exit 1 }

            for (i = 1; i <= n; i++) {
                # Lightness is scored as distance from 0.55: dark colors
                # disappear into the surfaces, near-white ones collide with
                # $text.
                light_fit = 1 - (ll[i] - 0.55 < 0 ? 0.55 - ll[i] : ll[i] - 0.55) / 0.55
                if (light_fit < 0) light_fit = 0

                # Chroma leads, but pixel share has to appear or a stray vivid
                # sliver outvotes the color the wallpaper actually reads as.
                # The fractional exponent damps share so a large flat wash
                # still loses to a genuinely vivid region of moderate size.
                share = count[i] / total
                score = (cc[i] ^ 2) * light_fit * (share ^ 0.35)

                if (score > best_score) {
                    best_score = score; best_h = hh[i]; best_s = ss[i]; best_l = ll[i]
                }
                # Tracked so a colorless image can be recognized as such below,
                # rather than silently amplified into an invented hue.
                if (cc[i] > top_chroma) {
                    top_chroma = cc[i]; top_h = hh[i]; top_s = ss[i]; top_l = ll[i]
                }
            }

            # A greyscale or near-greyscale wallpaper carries no hue worth
            # trusting — what little it has is compression noise. Amplifying
            # that to meet the saturation floor would pick a color at random
            # and change it on re-encode, so the designed accent is kept.
            if (top_chroma < 0.10) { exit 2 }

            h = best_score > 0 ? best_h : top_h
            s = best_score > 0 ? best_s : top_s
            l = best_score > 0 ? best_l : top_l

            # Legibility band on the dark neutrals: a muted wallpaper still has
            # to produce an accent that reads against #0f1115 without competing
            # with $text.
            if (s < 0.45) s = 0.45
            if (s > 0.85) s = 0.85
            if (l < 0.52) l = 0.52
            if (l > 0.68) l = 0.68

            printf "#%s\n", hsl2hex(h, s, l)
        }
    '
}

extract_accent() {
    local image=$1 hex status
    [ -f "$image" ] || die "file does not exist: $image"
    magick_cmd >/dev/null || die "ImageMagick is required to derive an accent (install ImageMagick)"
    hex=$(histogram "$image" | score_histogram)
    status=$?
    case "$status" in
        0) ;;
        2) warn "$(basename "$image") is effectively greyscale; keeping the designed accent" ;;
        *) warn "could not read colors from $image; keeping the designed accent" ;;
    esac
    if [ "$status" -ne 0 ] || [ -z "$hex" ]; then
        printf '%s\n' "$DEFAULT_ACCENT"
        return 0
    fi
    printf '%s\n' "$hex"
}

# --------------------------------------------------------------------------
# State
# --------------------------------------------------------------------------

default_state() {
    jq -n --arg accent "$DEFAULT_ACCENT" \
        '{version: 1, accent: $accent, source: "default", auto: true}'
}

valid_state() {
    jq -e '
        type == "object" and
        .version == 1 and
        (.accent | type == "string") and
        (.accent | test("^#[0-9a-fA-F]{6}$")) and
        (.source | type == "string") and
        (.auto | type == "boolean")
    ' "$STATE_FILE" >/dev/null 2>&1
}

write_json() {
    local input=$1 tmp
    mkdir -p "$STATE_HOME"
    tmp=$(mktemp "$STATE_HOME/.accent.XXXXXX") || return 1
    if ! jq -c . "$input" > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    chmod 600 "$tmp"
    mv -f "$tmp" "$STATE_FILE"
}

write_default_state() {
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/hyprveil-accent.XXXXXX") || return 1
    default_state > "$tmp"
    write_json "$tmp"
    rm -f "$tmp"
}

ensure_state() {
    mkdir -p "$STATE_HOME"
    if [ ! -e "$STATE_FILE" ]; then
        write_default_state
    elif ! valid_state; then
        warn "malformed accent state replaced with defaults"
        write_default_state
    fi
}

save_state() {
    local accent=$1 source=$2 tmp status
    ensure_state || return 1
    tmp=$(mktemp "${TMPDIR:-/tmp}/hyprveil-accent.XXXXXX") || return 1
    jq --arg accent "$accent" --arg source "$source" \
        '.accent = $accent | .source = $source' "$STATE_FILE" > "$tmp"
    write_json "$tmp"
    status=$?
    rm -f "$tmp"
    return "$status"
}

state_accent() {
    ensure_state || { printf '%s\n' "$DEFAULT_ACCENT"; return 0; }
    jq -r '.accent' "$STATE_FILE"
}

auto_enabled() {
    ensure_state || return 0
    [ "$(jq -r '.auto' "$STATE_FILE")" = true ]
}

# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

render_hypr() {
    local accent=$1 hover=$2
    local content
    content="# Generated by hypr/scripts/accent.sh — edit the wallpaper, not this file.
# colors.conf and hyprlock.conf source it; \`accent.sh reset\` restores the design.

\$accent        = rgba(${accent#\#}ff)
\$accent-hover  = rgba(${hover#\#}ff)
\$accent-soft   = rgba(${accent#\#}26)
\$border-active = rgba(${accent#\#}ff)"
    write_if_changed "$CONFIG_HOME/hypr/accent.conf" "$content"
}

# waybar, swaync, wlogout, and both GTK versions all read GTK CSS, so one
# fragment shape serves all five. gtk-3.0/gtk-4.0 additionally need libadwaita's
# accent_* role names to recolor stock widgets.
render_gtk_css() {
    local accent=$1 hover=$2 rgb=$3 changed=0 name content
    content="/* Generated by hypr/scripts/accent.sh — do not edit. */
@define-color accent $accent;
@define-color accent-hover $hover;
@define-color accent-soft rgba($rgb, 0.18);
@define-color border-active $accent;
@define-color accent_color $hover;
@define-color accent_bg_color $accent;
@define-color accent_fg_color #f5f5f7;"
    for name in waybar swaync wlogout gtk-3.0 gtk-4.0; do
        write_if_changed "$CONFIG_HOME/$name/accent.css" "$content" && changed=1
    done
    return "$((1 - changed))"
}

render_ags() {
    local accent=$1 hover=$2 rgb=$3 content
    content="// Generated by hypr/scripts/accent.sh — do not edit.
\$accent: $accent;
\$accent-hover: $hover;
\$accent-soft: rgba($rgb, 0.18);"
    write_if_changed "$CONFIG_HOME/ags/_accent.scss" "$content"
}

render_rofi() {
    local accent=$1 rgb=$2 content
    content="/* Generated by hypr/scripts/accent.sh — do not edit. */
* {
    accent:     $accent;
    accent-dim: rgba($rgb, 14%);
}"
    write_if_changed "$CONFIG_HOME/rofi/accent.rasi" "$content"
}

render_kitty() {
    local accent=$1 content
    content="# Generated by hypr/scripts/accent.sh — do not edit.
cursor                  $accent
url_color               $accent
color9                  $accent
active_tab_background   $accent
active_border_color     $accent"
    write_if_changed "$CONFIG_HOME/kitty/accent.conf" "$content"
}

# Loads the placeholders render_template expands: the design tokens first, then
# the accent family on top.
#
# The templates below (mako, the Qt schemes, the wlogout SVGs) carry BOTH kinds
# of placeholder, and render-lib's invariant is that no output has two writers —
# a second pass from theme.sh would rewrite the file from the template and drop
# whatever this one substituted. So this script owns them and needs both tables.
# theme.sh owns the token-only consumers and calls back here to keep them fresh.
load_accent_tokens() {
    local accent=$1 hover=$2 rgb=$3
    HV_TOKENS=()
    load_design_tokens || warn "rendering without design tokens"
    HV_TOKENS+=(
        [accent]="$accent"
        [accent-upper]="$(printf '%s' "$accent" | tr '[:lower:]' '[:upper:]')"
        [accent-bare]="${accent#\#}"
        [accent-hover]="$hover"
        [accent-hover-bare]="${hover#\#}"
        [accent-rgb]="$rgb"
    )
}

render_templated_consumers() {
    local changed=0 dir name
    render_template "$CONFIG_HOME/mako/config.in" "$CONFIG_HOME/mako/config" && changed=1
    # QML has no include mechanism for values, so the accent arrives as a
    # generated singleton. Quickshell watches its config directory, which makes
    # writing this file the reload as well — see reload_quickshell.
    render_template "$CONFIG_HOME/quickshell/Accent.qml.in" \
        "$CONFIG_HOME/quickshell/Accent.qml" && changed=1
    for dir in qt5ct qt6ct; do
        render_template "$CONFIG_HOME/$dir/colors/hyprveil.conf.in" \
            "$CONFIG_HOME/$dir/colors/hyprveil.conf" && changed=1
    done
    # wlogout bakes the ring and glyph of each button into one SVG per state, so
    # the accent variants are recolored rather than styled.
    for name in lock logout reboot shutdown suspend; do
        render_template "$CONFIG_HOME/wlogout/assets/src/$name-accent.svg" \
            "$CONFIG_HOME/wlogout/assets/$name-accent.svg" && changed=1
    done
    return "$((1 - changed))"
}

# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

apply_accent() {
    local accent=$1 source=$2 hover rgb
    if [ "$accent" = "$DEFAULT_ACCENT" ]; then
        hover="$DEFAULT_HOVER"
    else
        hover=$(shade "$accent" 0.08)
    fi
    rgb=$(rgb_triplet "$accent")
    load_accent_tokens "$accent" "$hover" "$rgb"

    hv_lock
    save_state "$accent" "$source" || { hv_unlock; die "could not save accent state"; }

    render_hypr "$accent" "$hover"
    render_gtk_css "$accent" "$hover" "$rgb"
    render_ags "$accent" "$hover" "$rgb"
    render_rofi "$accent" "$rgb"
    render_kitty "$accent"
    render_templated_consumers
    hv_unlock

    reload_all
    printf 'Accent: %s (from %s)\n' "$accent" "$source"
}

from_wallpaper_command() {
    local image=${1:-} accent
    [ -n "$image" ] || die "from-wallpaper requires an image path"
    accent=$(extract_accent "$image") || return 1
    apply_accent "$accent" "$image"
}

set_command() {
    local hex=${1:-} accent
    [ -n "$hex" ] || die "set requires a color as #rrggbb"
    accent=$(normalize_hex "$hex") || die "not a valid #rrggbb color: $hex"
    apply_accent "$accent" manual
}

auto_command() {
    local mode=${1:-} tmp
    ensure_state || die "could not initialize accent state"
    if [ -z "$mode" ]; then
        auto_enabled && printf 'on\n' || printf 'off\n'
        return 0
    fi
    case "$mode" in
        on|off) ;;
        *) die "auto takes on or off" ;;
    esac
    tmp=$(mktemp "${TMPDIR:-/tmp}/hyprveil-accent.XXXXXX") || die "could not write state"
    jq --argjson auto "$([ "$mode" = on ] && printf 'true' || printf 'false')" \
        '.auto = $auto' "$STATE_FILE" > "$tmp"
    write_json "$tmp"
    rm -f "$tmp"
    printf 'Accent: wallpaper tracking %s\n' "$mode"
}

command=${1:-}
shift 2>/dev/null || true
case "$command" in
    from-wallpaper) from_wallpaper_command "$@" ;;
    set) set_command "$@" ;;
    reset) apply_accent "$DEFAULT_ACCENT" default ;;
    extract) [ -n "${1:-}" ] || die "extract requires an image path"; extract_accent "$1" ;;
    render) apply_accent "$(state_accent)" "$(ensure_state; jq -r '.source' "$STATE_FILE")" ;;
    current) ensure_state && jq . "$STATE_FILE" ;;
    auto) auto_command "$@" ;;
    is-auto) auto_enabled ;;
    -h|--help) usage ;;
    *) usage >&2; exit 2 ;;
esac
