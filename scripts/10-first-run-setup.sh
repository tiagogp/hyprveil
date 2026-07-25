#!/usr/bin/env bash
# First-run setup: detect the machine, collect a few choices, preview the
# generated configuration, and deploy it. Safe to re-run at any time — nothing
# here blocks on a completion marker, and cancelling touches nothing.
#
# Every interactive choice has a command-line flag so the whole flow can run
# unattended (or be scripted in CI). Monitor, keyboard, and app choices are
# regenerated from saved state after every deploy via `--ensure`, so they
# survive `hyprveil update`.
#
# No -e: interactive/report steps below need to collect and surface failures
# rather than abort the whole flow at the first one, so -e is deliberately
# left off here too.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

SETUP_STATE="$HV_STATE_HOME/setup.conf"
MONITOR_STATE="$HV_STATE_HOME/monitors.tsv"
HYPR_DIR="$HV_CONFIG_HOME/hypr"

ENSURE=0
PREVIEW=0
# Empty means "not passed on the command line"; the value is then taken from
# saved state, detection, or an interactive prompt in that order.
OPT_KB_LAYOUT=''
OPT_KB_VARIANT='__unset__'
OPT_TERMINAL=''
OPT_BROWSER=''
OPT_FILES=''
OPT_EDITOR=''
OPT_IDLE_LOCK=''
OPT_IDLE_DPMS=''
OPT_IDLE_SUSPEND=''
OPT_WALLPAPER=''
OPT_ACCENT=''
OPT_MOTION=''
OPT_FORM_FACTOR=''
OPT_GPU=''
OPT_BACKEND=''
declare -a OPT_MONITORS=()

usage() {
    cat <<'EOF'
Usage: 10-first-run-setup.sh [options]

Run with no options for the interactive first-run flow. Every choice also has a
flag, so the flow can run unattended. Re-running is always safe.

  --ensure                 Regenerate the setup-owned files (local.conf,
                           apps.conf, hypridle.conf) from saved state and exit.
                           Used by `hyprveil update` after a deploy. No prompts.
  --preview                Show the configuration that would be written and exit
                           without changing anything.
  --yes, -y                Assume yes for confirmations.

  --monitor SPEC           Configure a monitor. Repeatable. SPEC is
                           NAME:MODE:POSITION:SCALE[:TRANSFORM][:primary], e.g.
                           'DP-1:2560x1440@144:0x0:1:primary'. Omit --monitor to
                           auto-detect connected monitors.
  --kb-layout LAYOUT       Keyboard layout (e.g. us, de, fr). Default: us.
  --kb-variant VARIANT     Keyboard variant (e.g. intl, nodeadkeys). May be empty.

  --terminal CMD           Terminal, browser, file manager, and editor launched
  --browser CMD            by the keybindings. Each defaults to the first
  --file-manager CMD       installed candidate (kitty/firefox/nautilus/code).
  --editor CMD

  --idle-lock SECONDS      Idle timers. 0 disables that listener. Keep
  --idle-dpms SECONDS      lock < dpms < suspend. Defaults: 600 / 900 / 1800,
  --idle-suspend SECONDS   or 300 / 480 / 900 when a battery is detected.

  --wallpaper PATH         Set the fallback wallpaper for every monitor.
  --accent auto|#RRGGBB    Follow the wallpaper (auto) or pin an explicit accent.
  --motion standard|reduced  Motion profile.

  --form-factor desktop|laptop   Confirm the hardware profile (see 06-select-profile.sh).
  --gpu intel|amd|nvidia
  --backend quickshell|swaync|mako  Notification backend (see 07-select-notification-backend.sh).

  -h, --help               Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --ensure) ENSURE=1 ;;
        --preview) PREVIEW=1 ;;
        --yes|-y) export HYPRVEIL_ASSUME_YES=1 ;;
        --monitor) shift; OPT_MONITORS+=("${1:-}") ;;
        --kb-layout) shift; OPT_KB_LAYOUT=${1:-} ;;
        --kb-variant) shift; OPT_KB_VARIANT=${1:-} ;;
        --terminal) shift; OPT_TERMINAL=${1:-} ;;
        --browser) shift; OPT_BROWSER=${1:-} ;;
        --file-manager) shift; OPT_FILES=${1:-} ;;
        --editor) shift; OPT_EDITOR=${1:-} ;;
        --idle-lock) shift; OPT_IDLE_LOCK=${1:-} ;;
        --idle-dpms) shift; OPT_IDLE_DPMS=${1:-} ;;
        --idle-suspend) shift; OPT_IDLE_SUSPEND=${1:-} ;;
        --wallpaper) shift; OPT_WALLPAPER=${1:-} ;;
        --accent) shift; OPT_ACCENT=${1:-} ;;
        --motion) shift; OPT_MOTION=${1:-} ;;
        --form-factor) shift; OPT_FORM_FACTOR=${1:-} ;;
        --gpu) shift; OPT_GPU=${1:-} ;;
        --backend) shift; OPT_BACKEND=${1:-} ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

interactive() { [ -t 0 ] && [ "${HYPRVEIL_ASSUME_YES:-0}" != 1 ]; }

# ---------------------------------------------------------------------------
# Saved state
# ---------------------------------------------------------------------------
SAVED_KB_LAYOUT='us'
SAVED_KB_VARIANT=''
SAVED_TERMINAL=''
SAVED_BROWSER=''
SAVED_FILES=''
SAVED_EDITOR=''

# Same battery-presence signal 06-select-profile.sh uses to auto-detect a
# laptop. Duplicated rather than shared because it is a one-line check and the
# two scripts pick unrelated things — profile selection is explicit and
# persistent, this only seeds the idle-timer starting point below, and any
# saved or flag-passed value always overrides it regardless of hardware.
detect_has_battery() {
    shopt -s nullglob
    local batteries=("${HYPRVEIL_SYSFS_ROOT:-/sys}"/class/power_supply/BAT*)
    shopt -u nullglob
    [ "${#batteries[@]}" -gt 0 ]
}

# An idle laptop is usually running on battery, so the never-configured
# starting point is shorter than a desktop's; a prior `hyprveil setup` run
# (loaded by load_saved below) or an explicit --idle-* flag always wins over
# this default.
if detect_has_battery; then
    SAVED_IDLE_LOCK='300'
    SAVED_IDLE_DPMS='480'
    SAVED_IDLE_SUSPEND='900'
else
    SAVED_IDLE_LOCK='600'
    SAVED_IDLE_DPMS='900'
    SAVED_IDLE_SUSPEND='1800'
fi

load_saved() {
    [ -r "$SETUP_STATE" ] || return 0
    local key value
    while IFS='=' read -r key value; do
        case "$key" in
            kb_layout) SAVED_KB_LAYOUT=$value ;;
            kb_variant) SAVED_KB_VARIANT=$value ;;
            terminal) SAVED_TERMINAL=$value ;;
            browser) SAVED_BROWSER=$value ;;
            file_manager) SAVED_FILES=$value ;;
            editor) SAVED_EDITOR=$value ;;
            idle_lock) SAVED_IDLE_LOCK=$value ;;
            idle_dpms) SAVED_IDLE_DPMS=$value ;;
            idle_suspend) SAVED_IDLE_SUSPEND=$value ;;
        esac
    done < "$SETUP_STATE"
}
load_saved

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------
# A hyprctl monitor dump, either from a live session or from the mock file the
# tests point HYPRVEIL_MONITORS_JSON at.
monitors_json() {
    if [ -n "${HYPRVEIL_MONITORS_JSON:-}" ] && [ -r "${HYPRVEIL_MONITORS_JSON}" ]; then
        cat "${HYPRVEIL_MONITORS_JSON}"
        return 0
    fi
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl monitors -j 2>/dev/null
        return 0
    fi
    return 1
}

# Emit one TSV row per connected monitor: name, mode, position, scale,
# transform, primary. The focused monitor is primary; if none is focused the
# caller marks the first row.
detect_monitors() {
    command -v jq >/dev/null 2>&1 || return 1
    local json
    json=$(monitors_json) || return 1
    [ -n "$json" ] || return 1
    printf '%s' "$json" | jq -r '
        .[] | [
            .name,
            ((.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate // 60)|round|tostring)),
            ((.x|tostring) + "x" + (.y|tostring)),
            ((.scale // 1)|tostring),
            ((.transform // 0)|tostring),
            (if .focused then "primary" else "" end)
        ] | @tsv' 2>/dev/null
}

# First installed command from a candidate list, or the first candidate as the
# documented default when none are installed yet.
detect_app() {
    local candidate
    for candidate in "$@"; do
        # Native binary on PATH.
        command -v "$candidate" >/dev/null 2>&1 && { printf '%s\n' "$candidate"; return 0; }
        # Flatpak application id (contains a dot, e.g. com.brave.Browser); emit a
        # ready-to-exec launch command so the keybinding works without a wrapper.
        case "$candidate" in
            *.*)
                if command -v flatpak >/dev/null 2>&1 && flatpak info "$candidate" >/dev/null 2>&1; then
                    printf 'flatpak run %s\n' "$candidate"
                    return 0
                fi
                ;;
        esac
    done
    printf '%s\n' "$1"
}

# ---------------------------------------------------------------------------
# Resolve the chosen values (flag > saved > detected/default > prompt)
# ---------------------------------------------------------------------------
KB_LAYOUT='' KB_VARIANT='' TERMINAL='' BROWSER='' FILES='' EDITOR=''
IDLE_LOCK='' IDLE_DPMS='' IDLE_SUSPEND=''
declare -a MONITORS=()

is_seconds() { [[ "$1" =~ ^[0-9]+$ ]]; }

# NAME:MODE:POSITION:SCALE[:TRANSFORM][:primary] -> validated TSV row.
parse_monitor_spec() {
    local spec=$1 name mode pos scale transform='0' primary='' field
    IFS=':' read -r name mode pos scale transform primary <<<"$spec"
    if [ -z "$name" ] || [ -z "$mode" ] || [ -z "$pos" ] || [ -z "$scale" ]; then
        printf 'Invalid --monitor spec (need NAME:MODE:POSITION:SCALE): %s\n' "$spec" >&2
        return 1
    fi
    # TRANSFORM is optional and numeric; the token may instead be "primary".
    if [ "$transform" = primary ]; then
        primary=primary
        transform=0
    fi
    [ -n "$transform" ] || transform=0
    if ! [[ "$transform" =~ ^[0-7]$ ]]; then
        printf 'Invalid --monitor transform (expect 0-7): %s\n' "$spec" >&2
        return 1
    fi
    [ "$primary" = primary ] && field=primary || field=''
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$mode" "$pos" "$scale" "$transform" "$field"
}

load_saved_monitors() {
    local row
    [ -r "$MONITOR_STATE" ] || return 0
    while IFS= read -r row; do [ -n "$row" ] && MONITORS+=("$row"); done < "$MONITOR_STATE"
}

resolve_monitors() {
    local row spec
    # Explicit --monitor flags always win.
    if [ "${#OPT_MONITORS[@]}" -gt 0 ]; then
        for spec in "${OPT_MONITORS[@]}"; do
            row=$(parse_monitor_spec "$spec") || exit 2
            MONITORS+=("$row")
        done
        return 0
    fi
    # --ensure only ever replays saved monitors; it must never re-detect, since
    # it runs unattended after every deploy.
    if [ "$ENSURE" -eq 1 ]; then
        load_saved_monitors
        return 0
    fi

    local -a detected=()
    while IFS= read -r row; do [ -n "$row" ] && detected+=("$row"); done < <(detect_monitors || true)

    if [ "${#detected[@]}" -eq 0 ]; then
        printf 'No monitors detected (not in a Hyprland session, or hyprctl/jq missing); keeping saved/default layout.\n'
        load_saved_monitors
        return 0
    fi

    printf 'Detected %d monitor(s):\n' "${#detected[@]}"
    for row in "${detected[@]}"; do
        printf '  %s\n' "$(printf '%s' "$row" | awk -F'\t' '{printf "%s  %s  @%s  scale %s%s", $1, $2, $3, $4, ($6=="primary"?"  (primary)":"")}')"
    done

    if interactive; then
        if hv_confirm "Use these detected monitors?"; then
            MONITORS=("${detected[@]}")
        else
            printf 'Leaving monitors as they are; use --monitor flags for exact control.\n'
            load_saved_monitors
        fi
    elif [ "${#MONITORS[@]}" -eq 0 ] && [ ! -r "$MONITOR_STATE" ]; then
        # Unattended first run: adopt the detected layout so a fresh install
        # reaches a usable multi-monitor desktop with no manual edits.
        printf 'Adopting detected monitors (unattended run).\n'
        MONITORS=("${detected[@]}")
    else
        load_saved_monitors
    fi
}

# Ensure exactly one primary when monitors are set: honor an explicit primary,
# otherwise the first monitor.
normalize_primary() {
    [ "${#MONITORS[@]}" -gt 0 ] || return 0
    local i has_primary=0 name mode pos scale transform primary
    for i in "${!MONITORS[@]}"; do
        IFS=$'\t' read -r name mode pos scale transform primary <<<"${MONITORS[$i]}"
        [ "$primary" = primary ] && has_primary=1
    done
    if [ "$has_primary" -eq 0 ]; then
        IFS=$'\t' read -r name mode pos scale transform primary <<<"${MONITORS[0]}"
        MONITORS[0]=$(printf '%s\t%s\t%s\t%s\t%s\tprimary' "$name" "$mode" "$pos" "$scale" "$transform")
    fi
}

prompt_value() {
    local label=$1 default=$2 answer
    read -r -p "$label [$default]: " answer
    printf '%s\n' "${answer:-$default}"
}

resolve_scalars() {
    # Keyboard
    if [ -n "$OPT_KB_LAYOUT" ]; then KB_LAYOUT=$OPT_KB_LAYOUT
    elif [ "$ENSURE" -eq 1 ] || ! interactive; then KB_LAYOUT=$SAVED_KB_LAYOUT
    else KB_LAYOUT=$(prompt_value "Keyboard layout" "$SAVED_KB_LAYOUT"); fi
    if [ "$OPT_KB_VARIANT" != '__unset__' ]; then KB_VARIANT=$OPT_KB_VARIANT
    elif [ "$ENSURE" -eq 1 ] || ! interactive; then KB_VARIANT=$SAVED_KB_VARIANT
    else KB_VARIANT=$(prompt_value "Keyboard variant (blank for none)" "$SAVED_KB_VARIANT"); fi

    # Apps
    local d_term d_browser d_files d_editor
    d_term=${SAVED_TERMINAL:-$(detect_app kitty alacritty foot wezterm)}
    d_browser=${SAVED_BROWSER:-$(detect_app firefox chromium google-chrome brave-browser \
        org.mozilla.firefox com.brave.Browser com.google.Chrome io.gitlab.librewolf-community)}
    d_files=${SAVED_FILES:-$(detect_app nautilus thunar dolphin nemo pcmanfm)}
    d_editor=${SAVED_EDITOR:-$(detect_app code nvim vim nano)}
    if [ -n "$OPT_TERMINAL" ]; then TERMINAL=$OPT_TERMINAL
    elif [ "$ENSURE" -eq 1 ] || ! interactive; then TERMINAL=$d_term
    else TERMINAL=$(prompt_value "Terminal" "$d_term"); fi
    if [ -n "$OPT_BROWSER" ]; then BROWSER=$OPT_BROWSER
    elif [ "$ENSURE" -eq 1 ] || ! interactive; then BROWSER=$d_browser
    else BROWSER=$(prompt_value "Browser" "$d_browser"); fi
    if [ -n "$OPT_FILES" ]; then FILES=$OPT_FILES
    elif [ "$ENSURE" -eq 1 ] || ! interactive; then FILES=$d_files
    else FILES=$(prompt_value "File manager" "$d_files"); fi
    if [ -n "$OPT_EDITOR" ]; then EDITOR=$OPT_EDITOR
    elif [ "$ENSURE" -eq 1 ] || ! interactive; then EDITOR=$d_editor
    else EDITOR=$(prompt_value "Editor" "$d_editor"); fi

    # Idle timers
    IDLE_LOCK=${OPT_IDLE_LOCK:-$SAVED_IDLE_LOCK}
    IDLE_DPMS=${OPT_IDLE_DPMS:-$SAVED_IDLE_DPMS}
    IDLE_SUSPEND=${OPT_IDLE_SUSPEND:-$SAVED_IDLE_SUSPEND}
    for value in "$IDLE_LOCK" "$IDLE_DPMS" "$IDLE_SUSPEND"; do
        is_seconds "$value" || { printf 'Idle timers must be whole seconds: %s\n' "$value" >&2; exit 2; }
    done
}

# ---------------------------------------------------------------------------
# Generators (write to stdout; callers redirect atomically)
# ---------------------------------------------------------------------------
emit_local_conf() {
    cat <<EOF
# Machine-local overrides, sourced last so they win over the managed defaults.
# GENERATED by hyprveil setup from saved state. Edit through \`hyprveil setup\`;
# manual edits here are replaced on the next deploy or \`setup --ensure\`.

input {
    kb_layout = $KB_LAYOUT
EOF
    if [ -n "$KB_VARIANT" ]; then
        printf '    kb_variant = %s\n' "$KB_VARIANT"
    else
        printf '    kb_variant =\n'
    fi
    printf '}\n'
    local name mode pos scale transform primary row
    if [ "${#MONITORS[@]}" -gt 0 ]; then
        printf '\n'
        for row in "${MONITORS[@]}"; do
            IFS=$'\t' read -r name mode pos scale transform primary <<<"$row"
            [ "$primary" = primary ] && printf '# primary display\n'
            if [ "$transform" != 0 ]; then
                printf 'monitor = %s, %s, %s, %s, transform, %s\n' "$name" "$mode" "$pos" "$scale" "$transform"
            else
                printf 'monitor = %s, %s, %s, %s\n' "$name" "$mode" "$pos" "$scale"
            fi
        done
    fi
}

emit_apps_conf() {
    cat <<EOF
# Preferred applications used by the keybindings.
# GENERATED by hyprveil setup from saved state. Edit through \`hyprveil setup\`;
# manual edits here are replaced on the next deploy or \`setup --ensure\`.

\$terminal = $TERMINAL
\$fileManager = $FILES
\$browser = $BROWSER
\$editor = $EDITOR
EOF
}

emit_hypridle_conf() {
    cat <<'EOF'
# Idle daemon. GENERATED by hyprveil setup from saved state.
# Edit timers through `hyprveil setup --idle-lock/--idle-dpms/--idle-suspend`;
# manual edits here are replaced on the next deploy or `setup --ensure`.

general {
    lock_cmd = pidof hyprlock || ~/.config/hypr/scripts/lock.sh
    before_sleep_cmd = ~/.config/hypr/scripts/lock.sh; ~/.config/hypr/scripts/hardware-action.sh brightness-save
    after_sleep_cmd = ~/.config/hypr/scripts/hardware-action.sh brightness-restore; hyprctl dispatch dpms on
}
EOF
    if [ "$IDLE_LOCK" -gt 0 ]; then
        printf '\nlistener {\n    timeout = %s\n    on-timeout = ~/.config/hypr/scripts/lock.sh\n}\n' "$IDLE_LOCK"
    fi
    if [ "$IDLE_DPMS" -gt 0 ]; then
        printf '\nlistener {\n    timeout = %s\n    on-timeout = hyprctl dispatch dpms off\n    on-resume = hyprctl dispatch dpms on\n}\n' "$IDLE_DPMS"
    fi
    if [ "$IDLE_SUSPEND" -gt 0 ]; then
        printf '\nlistener {\n    timeout = %s\n    on-timeout = systemctl suspend\n}\n' "$IDLE_SUSPEND"
    fi
}

# ---------------------------------------------------------------------------
# Write generated files atomically into the deployed tree
# ---------------------------------------------------------------------------
write_file() {
    local target=$1 tmp
    if [ ! -d "$HYPR_DIR" ]; then
        printf 'Hyprveil config is not deployed at %s; run ./install.sh first.\n' "$HYPR_DIR" >&2
        return 1
    fi
    tmp=$(mktemp "$HYPR_DIR/.setup.XXXXXX")
    cat > "$tmp"
    mv -f "$tmp" "$target"
}

regenerate_files() {
    emit_local_conf | write_file "$HYPR_DIR/local.conf" || return 1
    emit_apps_conf | write_file "$HYPR_DIR/apps.conf" || return 1
    emit_hypridle_conf | write_file "$HYPR_DIR/hypridle.conf" || return 1
}

persist_state() {
    mkdir -p "$HV_STATE_HOME"
    local tmp
    tmp=$(mktemp "$HV_STATE_HOME/.setup.XXXXXX")
    {
        printf 'kb_layout=%s\n' "$KB_LAYOUT"
        printf 'kb_variant=%s\n' "$KB_VARIANT"
        printf 'terminal=%s\n' "$TERMINAL"
        printf 'browser=%s\n' "$BROWSER"
        printf 'file_manager=%s\n' "$FILES"
        printf 'editor=%s\n' "$EDITOR"
        printf 'idle_lock=%s\n' "$IDLE_LOCK"
        printf 'idle_dpms=%s\n' "$IDLE_DPMS"
        printf 'idle_suspend=%s\n' "$IDLE_SUSPEND"
        printf 'completed_at=%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)"
    } > "$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$SETUP_STATE"

    tmp=$(mktemp "$HV_STATE_HOME/.monitors.XXXXXX")
    local row
    for row in "${MONITORS[@]}"; do printf '%s\n' "$row"; done > "$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$MONITOR_STATE"
}

# ---------------------------------------------------------------------------
# Delegated selections (profile, backend, wallpaper, accent, motion)
# ---------------------------------------------------------------------------
run_delegates() {
    local -a args
    args=()
    [ -n "$OPT_FORM_FACTOR" ] && args+=(--form-factor "$OPT_FORM_FACTOR")
    [ -n "$OPT_GPU" ] && args+=(--gpu "$OPT_GPU")
    if [ "${#args[@]}" -gt 0 ] || ! [ -r "$HV_STATE_HOME/hardware-profile.conf" ]; then
        "$REPO/scripts/06-select-profile.sh" "${args[@]}" || hv_warn "hardware profile selection did not complete"
    else
        "$REPO/scripts/06-select-profile.sh" --ensure || true
    fi

    if [ -n "$OPT_BACKEND" ]; then
        "$REPO/scripts/07-select-notification-backend.sh" --backend "$OPT_BACKEND" || hv_warn "notification backend selection did not complete"
    elif ! [ -r "$HV_NOTIFICATION_STATE" ]; then
        "$REPO/scripts/07-select-notification-backend.sh" || hv_warn "notification backend selection did not complete"
    fi

    if [ -n "$OPT_WALLPAPER" ] && [ -x "$HYPR_DIR/scripts/wallpaper.sh" ]; then
        "$HYPR_DIR/scripts/wallpaper.sh" apply "$OPT_WALLPAPER" cover || hv_warn "could not set wallpaper $OPT_WALLPAPER"
    fi
    if [ -n "$OPT_ACCENT" ] && [ -x "$HYPR_DIR/scripts/accent.sh" ]; then
        if [ "$OPT_ACCENT" = auto ]; then
            "$HYPR_DIR/scripts/accent.sh" auto on || hv_warn "could not enable auto accent"
        else
            "$HYPR_DIR/scripts/accent.sh" set "$OPT_ACCENT" || hv_warn "could not set accent $OPT_ACCENT"
        fi
    fi
    if [ -n "$OPT_MOTION" ] && [ -x "$HYPR_DIR/scripts/motion-profile.sh" ]; then
        "$HYPR_DIR/scripts/motion-profile.sh" "$OPT_MOTION" || hv_warn "could not set motion profile $OPT_MOTION"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
resolve_monitors
normalize_primary
resolve_scalars

# --ensure: regenerate the setup-owned files from saved state and stop. This is
# the post-deploy hook `hyprveil update` calls; it must not prompt or run
# delegates, and it does nothing gracefully when setup has never been run.
if [ "$ENSURE" -eq 1 ]; then
    if [ ! -r "$SETUP_STATE" ]; then
        exit 0
    fi
    regenerate_files || exit 1
    printf 'Regenerated setup-owned config from saved state.\n'
    exit 0
fi

printf '\n== Configuration to be written ==\n'
printf -- '--- ~/.config/hypr/local.conf ---\n'
emit_local_conf
printf -- '\n--- ~/.config/hypr/apps.conf ---\n'
emit_apps_conf
printf -- '\n--- ~/.config/hypr/hypridle.conf ---\n'
emit_hypridle_conf
printf '\n'

if [ "$PREVIEW" -eq 1 ]; then
    printf 'Preview only; no changes were made. Re-run without --preview to apply.\n'
    exit 0
fi

if ! hv_confirm "Write this configuration and apply the selected options?"; then
    printf 'Setup cancelled; no changes were made.\n'
    exit 0
fi

persist_state
if ! regenerate_files; then
    hv_bad "could not write generated config; saved choices are stored and will apply on the next deploy."
    exit 1
fi
run_delegates

if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || hv_warn "could not reload the live Hyprland session"
    printf 'Applied to the live session.\n'
else
    printf 'Setup saved. Log into Hyprland to see the changes.\n'
fi
printf 'First-run setup complete. Re-run ./hyprveil setup any time to change these.\n'
