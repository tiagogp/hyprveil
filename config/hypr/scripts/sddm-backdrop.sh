#!/usr/bin/env bash
# Render the current wallpaper into the SDDM greeter as a pre-blurred backdrop.
#
# The greeter runs as the `sddm` system user, and $HOME is 0700 on Fedora, so
# SDDM cannot read ~/Pictures/Wallpapers no matter what path it is pointed at.
# Symlinking or relaxing the home directory's mode to work around that would
# expose the whole home directory to a system account, which is a much worse
# trade than keeping one derived copy. So the wallpaper is copied — blurred and
# dimmed on the way — into the theme directory, which is world-readable already.
#
# Blurring here rather than in QML is deliberate. Qt's MultiEffect could blur at
# runtime, but the greeter would then decode a full-size image and run a blur
# pass on every boot, on the one surface where a slow first frame is most
# visible. Baking it once costs a 200KB file and makes greeter startup a plain
# image load.
#
# The blur/dim parameters mirror hyprlock.conf's `background` block so the
# greeter and the lock screen read as the same surface. Change them together.
set -uo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
STATE_FILE="$STATE_HOME/wallpapers.json"
THEME_DST="${HYPRVEIL_SDDM_THEME_DIR:-/usr/share/sddm/themes/hyprveil}"
BACKDROP_REL="backgrounds/backdrop.jpg"

# hyprlock.conf: blur_passes = 3, blur_size = 8, brightness = 0.45,
# contrast = 0.9, vibrancy = 0.15, noise = 0.02.
# Lighter blur than hyprlock's 3x8. The lock screen blurs a SCREENSHOT, which
# is mostly flat desktop chrome and stays coherent under a heavy blur; this
# blurs a photograph, which at sigma 20 dissolves into unrecognisable coloured
# blobs. Sigma 14 keeps the wallpaper's large shapes legible as the wallpaper.
BLUR_SIGMA="${HYPRVEIL_BACKDROP_BLUR:-14}"
# Darker and less saturated than the lock screen for the same reason: a
# saturated wallpaper competes with the accent the whole greeter is built
# around. Muting the source keeps the accent the only saturated thing on screen.
BRIGHTNESS="${HYPRVEIL_BACKDROP_BRIGHTNESS:-38}"
SATURATION="${HYPRVEIL_BACKDROP_SATURATION:-82}"
CONTRAST="${HYPRVEIL_BACKDROP_CONTRAST:--12}"
NOISE="${HYPRVEIL_BACKDROP_NOISE:-0.05}"
# Downscaled before blurring: a 5120x2880 wallpaper blurred at full size takes
# seconds and produces a file the greeter has to decode for no visible gain —
# the image is about to be blurred into mush anyway.
WIDTH="${HYPRVEIL_BACKDROP_WIDTH:-2560}"

usage() {
    cat <<'EOF'
Usage:
  sddm-backdrop.sh render [PATH]   blur PATH (default: current wallpaper) into the greeter
  sddm-backdrop.sh clear           remove the backdrop; the greeter returns to flat dark
  sddm-backdrop.sh status          show what the greeter is currently using

The system theme directory is root-owned, so `render` and `clear` call sudo for
the install step only — the blur itself always runs unprivileged.
EOF
}

die() { printf 'Backdrop: %s\n' "$*" >&2; exit 2; }
warn() { printf 'Backdrop: %s\n' "$*" >&2; }
info() { printf 'Backdrop: %s\n' "$*"; }

# Escalate only when the theme directory actually needs it. The real target is
# root-owned, but HYPRVEIL_SDDM_THEME_DIR points the tests (and a preview of an
# uninstalled theme) at a writable copy, and prompting for a password to write
# into a directory the caller already owns trains the wrong reflex.
as_owner() {
    if [ -w "$THEME_DST" ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Same magick/convert straddle the rest of the repo uses: ImageMagick 7 renamed
# the binary, and Fedora still ships both depending on the package set.
magick_bin() {
    if command -v magick >/dev/null 2>&1; then printf 'magick'
    elif command -v convert >/dev/null 2>&1; then printf 'convert'
    else return 1
    fi
}

current_wallpaper() {
    [ -r "$STATE_FILE" ] || return 1
    command -v jq >/dev/null 2>&1 || return 1
    jq -re '.fallback.path' "$STATE_FILE" 2>/dev/null
}

render_command() {
    local src=${1:-}
    if [ -z "$src" ]; then
        src=$(current_wallpaper) \
            || die "no wallpaper recorded in $STATE_FILE — pass an image path explicitly"
    fi
    [ -r "$src" ] || die "cannot read $src"

    local mb
    mb=$(magick_bin) || die "ImageMagick is not installed (need 'magick' or 'convert')"

    local tmp
    tmp=$(mktemp --suffix=.jpg) || die "could not create a temp file"
    # Expanded when the trap is SET, not when it fires: `tmp` is function-local,
    # so a single-quoted trap body would dereference an unset name at shell exit
    # and trip `set -u` after the render had already succeeded.
    # shellcheck disable=SC2064
    trap "rm -f '$tmp'" EXIT

    info "rendering $src"
    if ! "$mb" "$src" \
        -auto-orient \
        -resize "${WIDTH}x>" \
        -blur "0x${BLUR_SIGMA}" \
        -modulate "${BRIGHTNESS},${SATURATION},100" \
        -brightness-contrast "0,${CONTRAST}" \
        -attenuate "$NOISE" +noise Gaussian \
        -quality 88 \
        "$tmp"; then
        die "ImageMagick failed on $src"
    fi

    [ -d "$THEME_DST" ] || die "$THEME_DST does not exist — run scripts/05-install-fedora-sddm.sh first"

    # 0644 on purpose: the greeter reads this as the unprivileged `sddm` user.
    info "installing to $THEME_DST/$BACKDROP_REL"
    as_owner install -D -m 0644 "$tmp" "$THEME_DST/$BACKDROP_REL" \
        || die "could not install the backdrop"

    info "done — visible at the next login"
}

clear_command() {
    [ -e "$THEME_DST/$BACKDROP_REL" ] || { info "no backdrop installed"; return 0; }
    as_owner rm -f "$THEME_DST/$BACKDROP_REL" || die "could not remove the backdrop"
    info "removed — the greeter will fall back to flat dark"
}

status_command() {
    local wp
    wp=$(current_wallpaper) || wp="(none recorded)"
    printf 'Source wallpaper : %s\n' "$wp"
    if [ -e "$THEME_DST/$BACKDROP_REL" ]; then
        printf 'Greeter backdrop : %s\n' "$THEME_DST/$BACKDROP_REL"
        ls -l "$THEME_DST/$BACKDROP_REL"
    else
        printf 'Greeter backdrop : none (flat dark)\n'
    fi
}

case "${1:-}" in
    render) shift; render_command "${1:-}" ;;
    clear)  clear_command ;;
    status) status_command ;;
    -h|--help|help|"") usage ;;
    *) usage; exit 2 ;;
esac
