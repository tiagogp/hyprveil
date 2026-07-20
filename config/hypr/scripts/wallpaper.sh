#!/usr/bin/env bash
# Pick, apply, and restore persistent per-monitor Hyprpaper wallpapers.
set -uo pipefail

STATE_HOME="${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}"
STATE_FILE="$STATE_HOME/wallpapers.json"
LOCK_FILE="$STATE_HOME/wallpapers.lock"
WALLPAPER_DIR="${HYPRVEIL_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_WALLPAPER="${HYPRVEIL_DEFAULT_WALLPAPER:-$SCRIPT_DIR/../wallpaper-default.jpg}"
ACCENT_HELPER="${HYPRVEIL_ACCENT_HELPER:-$SCRIPT_DIR/accent.sh}"

usage() {
    cat <<'EOF'
Usage:
  wallpaper.sh pick
  wallpaper.sh apply PATH [MONITOR] [cover|contain]
  wallpaper.sh apply PATH [cover|contain]
  wallpaper.sh list
  wallpaper.sh restore

An omitted monitor updates the fallback and applies it to every connected monitor.
`pick` opens the AGS grid when the shell is running and falls back to Rofi.
`list` prints the catalog the AGS picker renders, as JSON.
Selections are saved in $XDG_STATE_HOME/hyprveil/wallpapers.json.
EOF
}

die() { printf 'Wallpaper: %s\n' "$*" >&2; exit 2; }
warn() { printf 'Wallpaper: %s\n' "$*" >&2; }
valid_fit() { [[ "$1" = cover || "$1" = contain ]]; }

default_state() {
    jq -n --arg path "$DEFAULT_WALLPAPER" \
        '{version: 1, fallback: {path: $path, fit: "cover"}, monitors: {}}'
}

valid_state() {
    jq -e '
        type == "object" and
        .version == 1 and
        (.fallback | type == "object") and
        (.fallback.path | type == "string") and
        (.fallback.fit == "cover" or .fallback.fit == "contain") and
        (.monitors | type == "object") and
        all(.monitors[];
            type == "object" and
            (.path | type == "string") and
            (.fit == "cover" or .fit == "contain"))
    ' "$STATE_FILE" >/dev/null 2>&1
}

write_json() {
    local input=$1 tmp
    mkdir -p "$STATE_HOME"
    tmp=$(mktemp "$STATE_HOME/.wallpapers.XXXXXX") || return 1
    if ! jq -c . "$input" > "$tmp"; then
        rm -f "$tmp"
        return 1
    fi
    chmod 600 "$tmp"
    mv -f "$tmp" "$STATE_FILE"
}

write_default_state() {
    local tmp
    tmp=$(mktemp "${TMPDIR:-/tmp}/hyprveil-wallpapers.XXXXXX") || return 1
    default_state > "$tmp"
    write_json "$tmp"
    rm -f "$tmp"
}

backup_invalid_state() {
    local stamp backup suffix=0
    stamp=$(date +%Y%m%d-%H%M%S)
    backup="$STATE_FILE.invalid-$stamp"
    while [ -e "$backup" ]; do
        suffix=$((suffix + 1))
        backup="$STATE_FILE.invalid-$stamp-$suffix"
    done
    cp -a "$STATE_FILE" "$backup"
    warn "malformed state preserved at $backup; using safe defaults"
}

ensure_state() {
    mkdir -p "$STATE_HOME"
    if [ ! -e "$STATE_FILE" ]; then
        write_default_state
    elif ! valid_state; then
        backup_invalid_state
        write_default_state
    fi
}

absolute_path() {
    local path=$1 dir base
    if [[ "$path" != /* ]]; then
        path="$PWD/$path"
    fi
    dir=$(dirname "$path")
    base=$(basename "$path")
    if [ -d "$dir" ]; then
        printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
    else
        printf '%s\n' "$path"
    fi
}

connected_monitors() {
    local json
    json=$(hyprctl -j monitors 2>/dev/null) || return 1
    jq -er '. | if type == "array" then .[]?.name else error("not an array") end' \
        <<<"$json" 2>/dev/null
}

monitor_connected() {
    local wanted=$1 monitor
    while IFS= read -r monitor; do
        [ "$monitor" = "$wanted" ] && return 0
    done < <(connected_monitors || true)
    return 1
}

# Prints Hyprpaper's request list, or fails when its IPC is not usable.
# Current Hyprpaper prints usage on stdout but exits non-zero, and hyprctl prints
# a connection error when the daemon is down, so readiness is decided by whether
# the output actually advertises a wallpaper request — never by the exit status.
hyprpaper_help() {
    local help
    help=$(hyprctl hyprpaper --help 2>&1) || true
    grep -Eq '(^|[[:space:]])(preload|wallpaper|reload)([[:space:]]|$)' <<<"$help" || return 1
    printf '%s\n' "$help"
}

apply_ipc() {
    local monitor=$1 path=$2 fit=$3 help legacy_path
    [ -f "$path" ] || return 1
    help=$(hyprpaper_help) || return 1

    # Fit travels as a `contain:` path prefix; only the oldest IPC took it as a
    # separate field.
    legacy_path=$path
    [ "$fit" = cover ] || legacy_path="contain:$path"

    if grep -Eq '(^|[[:space:]])reload([[:space:]]|$)' <<<"$help"; then
        hyprctl hyprpaper reload "$monitor,$legacy_path" >/dev/null
    elif grep -Eq '(^|[[:space:]])preload([[:space:]]|$)' <<<"$help"; then
        # Current Hyprpaper: an image must be preloaded before it can be shown,
        # and `wallpaper` takes `monitor,[contain:]path` — appending a third
        # field makes it read "path,fit" as one filename and fail.
        hyprctl hyprpaper preload "$path" >/dev/null \
            && hyprctl hyprpaper wallpaper "$monitor,$legacy_path" >/dev/null
    elif grep -Eq '(^|[[:space:]])wallpaper([[:space:]]|$)' <<<"$help"; then
        hyprctl hyprpaper wallpaper "$monitor,$path,$fit" >/dev/null
    else
        warn "the running Hyprpaper exposes no supported wallpaper IPC request"
        return 1
    fi
}

runtime_path() {
    local selected=$1
    if [ -f "$selected" ]; then
        printf '%s\n' "$selected"
    elif [ -f "$DEFAULT_WALLPAPER" ]; then
        warn "saved file is missing: $selected; using bundled default"
        printf '%s\n' "$DEFAULT_WALLPAPER"
    else
        warn "saved file and bundled default are missing; leaving the current background unchanged"
        return 1
    fi
}

apply_all_connected() {
    local path=$1 fit=$2 monitor found=0 failed=0
    while IFS= read -r monitor; do
        [ -n "$monitor" ] || continue
        found=1
        apply_ipc "$monitor" "$path" "$fit" || failed=1
    done < <(connected_monitors || true)
    if [ "$found" -eq 0 ]; then
        apply_ipc "" "$path" "$fit" || failed=1
    fi
    return "$failed"
}

save_selection() {
    local path=$1 monitor=$2 fit=$3 tmp
    ensure_state || return 1
    tmp=$(mktemp "${TMPDIR:-/tmp}/hyprveil-wallpapers.XXXXXX") || return 1
    if [ -n "$monitor" ]; then
        jq --arg monitor "$monitor" --arg path "$path" --arg fit "$fit" \
            '.monitors[$monitor] = {path: $path, fit: $fit}' "$STATE_FILE" > "$tmp"
    else
        jq --arg path "$path" --arg fit "$fit" \
            '.fallback = {path: $path, fit: $fit} | .monitors = {}' \
            "$STATE_FILE" > "$tmp"
    fi
    write_json "$tmp"
    local status=$?
    rm -f "$tmp"
    return "$status"
}

# Re-render the accent family from an image. Always warn-only: neither picking a
# wallpaper nor logging in may be blocked by a failed extraction, and `is-auto`
# failing is the documented opt-out rather than an error.
derive_accent() {
    local image=$1
    [ -n "$image" ] || return 0
    [ -x "$ACCENT_HELPER" ] || return 0
    "$ACCENT_HELPER" is-auto >/dev/null 2>&1 || return 0
    "$ACCENT_HELPER" from-wallpaper "$image" >/dev/null \
        || warn "the accent could not be derived from $image"
}

apply_command() {
    local path=${1:-} monitor=${2:-} fit=${3:-cover} runtime
    [ -n "$path" ] || die "apply requires a wallpaper path"
    if valid_fit "$monitor" && [ "$#" -eq 2 ]; then
        fit=$monitor
        monitor=
    fi
    valid_fit "$fit" || die "fit mode must be cover or contain"
    path=$(absolute_path "$path")
    [ -f "$path" ] || die "file does not exist: $path"

    mkdir -p "$STATE_HOME"
    exec 9>"$LOCK_FILE"
    flock 9
    save_selection "$path" "$monitor" "$fit" || die "could not save wallpaper state"
    flock -u 9

    # Hyprpaper first, the accent last. Deriving the accent rewrites Accent.qml,
    # which IS a full Quickshell config reload (see render-lib's
    # reload_quickshell) - a system-wide side effect, and the last thing this
    # command should set off. It once ran first, and any caller that waited on
    # this script as a child was killed by that reload before reaching apply_ipc:
    # the click recolored the desktop and left the wallpaper untouched. The
    # Quickshell picker no longer waits, but the ordering is what makes that
    # safe for every other caller, so keep the visible effect ahead of it.
    if runtime=$(runtime_path "$path"); then
        if [ -n "$monitor" ]; then
            if monitor_connected "$monitor"; then
                apply_ipc "$monitor" "$runtime" "$fit" \
                    || warn "selection was saved but Hyprpaper is not ready"
            else
                warn "$monitor is disconnected; selection was retained for reconnection"
            fi
        else
            apply_all_connected "$runtime" "$fit" \
                || warn "selection was saved but Hyprpaper is not ready"
        fi
    fi

    derive_accent "$path"
}

restore_command() {
    local attempts=${HYPRVEIL_RESTORE_ATTEMPTS:-40} delay=${HYPRVEIL_RESTORE_DELAY:-0.1}
    local help fallback_path fallback_fit runtime monitor path fit i
    ensure_state || { warn "could not initialize wallpaper state"; return 0; }

    help=
    for ((i=0; i<attempts; i++)); do
        if help=$(hyprpaper_help); then
            break
        fi
        sleep "$delay"
    done
    if [ -z "$help" ]; then
        warn "Hyprpaper IPC did not become ready; login will continue"
        return 0
    fi

    fallback_path=$(jq -r '.fallback.path' "$STATE_FILE")
    fallback_fit=$(jq -r '.fallback.fit' "$STATE_FILE")
    if runtime=$(runtime_path "$fallback_path"); then
        apply_all_connected "$runtime" "$fallback_fit" \
            || warn "could not restore the fallback wallpaper"
    fi

    while IFS=$'\t' read -r monitor path fit; do
        [ -n "$monitor" ] || continue
        monitor_connected "$monitor" || continue
        runtime=$(runtime_path "$path") || continue
        apply_ipc "$monitor" "$runtime" "$fit" \
            || warn "could not restore wallpaper for $monitor"
    done < <(jq -r '.monitors | to_entries[] | [.key, .value.path, .value.fit] | @tsv' "$STATE_FILE")

    # Keep the accent in step with the wallpaper across logins: a reinstall
    # replaces the rendered fragments with the default-red copies, and a
    # hand-edited state file can drift too. The fallback is the system-wide
    # selection, so it stays the source even when a monitor overrides its own
    # wallpaper - deriving per monitor would take the accent lock, rewrite every
    # fragment and reload five daemons once per screen at every login.
    derive_accent "$fallback_path"
}

rofi_menu() {
    local prompt=$1
    rofi -dmenu -i -p "$prompt"
}

# NUL-separated, sorted list of supported images below $WALLPAPER_DIR.
find_images() {
    [ -d "$WALLPAPER_DIR" ] || return 0
    find "$WALLPAPER_DIR" -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
        -iname '*.webp' -o -iname '*.jxl' -o -iname '*.bmp' \) -print0 | sort -z
}

json_array() {
    if [ "$#" -eq 0 ]; then
        printf '[]\n'
    else
        printf '%s\0' "$@" | jq -Rs 'split("\u0000")[:-1]'
    fi
}

# The catalog the AGS grid renders: available images, connected outputs, and the
# saved selection it highlights as active.
list_command() {
    local -a images=() outputs=()
    local path monitor images_json outputs_json
    while IFS= read -r -d '' path; do
        images+=("$path")
    done < <(find_images)
    while IFS= read -r monitor; do
        [ -n "$monitor" ] && outputs+=("$monitor")
    done < <(connected_monitors || true)

    ensure_state || die "could not initialize wallpaper state"
    images_json=$(json_array "${images[@]}")
    outputs_json=$(json_array "${outputs[@]}")
    jq -n \
        --arg dir "$WALLPAPER_DIR" \
        --argjson images "$images_json" \
        --argjson outputs "$outputs_json" \
        --slurpfile state "$STATE_FILE" \
        '{dir: $dir, images: $images, outputs: $outputs,
          fallback: $state[0].fallback, monitors: $state[0].monitors}'
}

# The AGS shell owns the graphical picker whenever it is running; Rofi is the
# fallback for the SwayNC/Mako backends and for a session without the panel.
# The Quickshell picker, when that shell is running. Same shape as ags_picker:
# return non-zero and pick_command falls through to the Rofi flow, so a missing or
# wedged shell degrades to a working picker rather than to nothing.
qs_picker() {
    command -v qs >/dev/null 2>&1 || return 1
    timeout 5 qs ipc call wallpapers open >/dev/null 2>&1
}

ags_picker() {
    local instance="${HYPRVEIL_AGS_INSTANCE:-hyprveil}"
    command -v ags >/dev/null 2>&1 || return 1
    ags list 2>/dev/null | grep -Fxq "$instance" || return 1
    ags request -i "$instance" toggle-wallpapers >/dev/null 2>&1
}

pick_command() {
    local -a paths=() labels=() monitors=()
    local path choice index target fit monitor
    # Both shells show a thumbnail grid that stays open across selections; Rofi
    # keeps the picker usable when neither is running.
    qs_picker && return 0
    ags_picker && return 0
    if [ ! -d "$WALLPAPER_DIR" ]; then
        rofi -e "No wallpaper directory: $WALLPAPER_DIR" 2>/dev/null || true
        warn "create $WALLPAPER_DIR and add an image"
        return 0
    fi
    while IFS= read -r -d '' path; do
        paths+=("$path")
        printf -v index '%03d' "${#paths[@]}"
        labels+=("$index  $(basename "$path")")
    done < <(find_images)
    if [ "${#paths[@]}" -eq 0 ]; then
        rofi -e "No supported images in $WALLPAPER_DIR" 2>/dev/null || true
        warn "no supported images found in $WALLPAPER_DIR"
        return 0
    fi

    choice=$(printf '%s\n' "${labels[@]}" | rofi_menu wallpaper) || return 0
    index=${choice%% *}
    [[ "$index" =~ ^[0-9]+$ ]] || return 0
    index=$((10#$index - 1))
    [ "$index" -ge 0 ] && [ "$index" -lt "${#paths[@]}" ] || return 0
    path=${paths[$index]}

    monitors=("All monitors")
    while IFS= read -r monitor; do
        [ -n "$monitor" ] && monitors+=("$monitor")
    done < <(connected_monitors || true)
    target=$(printf '%s\n' "${monitors[@]}" | rofi_menu target) || return 0
    if [ "$target" = "All monitors" ]; then
        target=
    elif ! printf '%s\n' "${monitors[@]:1}" | grep -Fxq "$target"; then
        return 0
    fi
    fit=$(printf 'cover\ncontain\n' | rofi_menu fit) || return 0
    valid_fit "$fit" || return 0
    apply_command "$path" "$target" "$fit"
}

command=${1:-}
shift 2>/dev/null || true
case "$command" in
    pick) pick_command "$@" ;;
    apply) apply_command "$@" ;;
    list) list_command "$@" ;;
    restore) restore_command "$@" ;;
    -h|--help) usage ;;
    *) usage >&2; exit 2 ;;
esac
