#!/usr/bin/env bash
# Render the design tokens into every component that cannot read a Hyprland
# variable.
#
# Hyprland and hyprlock `source` tokens.conf directly and need nothing from this
# script. Everything else — Quickshell's QML, the GTK stylesheets, mako — gets
# its sizes baked in from a `.in` template, because GTK CSS has @define-color but
# no length variables and QML cannot read Hyprland's config syntax.
#
# Values in tokens.conf are stored unitless, so the unit is appended here, per
# target: the same 10 reaches Hyprland as `10`, CSS as `10px`, and QML as `10`.
# See docs/CONFIGURATION.md.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HV_LOG_PREFIX=Theme
# shellcheck source=config/hypr/scripts/lib/render-lib.sh
. "$SCRIPT_DIR/lib/render-lib.sh"

usage() {
    cat <<'EOF'
Usage:
  theme.sh render     re-render every token consumer from tokens.conf
  theme.sh list       print the resolved placeholder table
  theme.sh check      verify every consumer is up to date (renders nothing)

`render` is the repair path, the counterpart to `accent.sh render`: install.sh
runs it after replacing a managed config tree, and it is what you run by hand
after editing tokens.conf or any .in template.
EOF
}

# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

# Every token-ONLY consumer, as `template:target` relative to CONFIG_HOME.
#
# Deliberately absent:
#   - mako/config, the Qt color schemes, and the wlogout SVGs carry the accent
#     as well, so accent.sh owns them outright. Rendering a mixed template from
#     both scripts would leave each pass's placeholders unexpanded by the other;
#     render_command hands off below instead.
#   - gtk-3.0/gtk.css and gtk-4.0/gtk.css carry only named colors and not one
#     length, so templating them would add a generated file that never changes.
token_consumers() {
    cat <<'EOF'
quickshell/Tokens.qml.in:quickshell/Tokens.qml
wlogout/style.css.in:wlogout/style.css
swaync/style.css.in:swaync/style.css
rofi/hyprveil.rasi.in:rofi/hyprveil.rasi
EOF
}

# Renders every consumer. Returns 0 if anything changed, 1 if all were current,
# matching write_if_changed's convention so callers can skip a reload.
render_all() {
    local template target changed=1
    while IFS=: read -r template target; do
        [ -n "$template" ] || continue
        if render_template "$CONFIG_HOME/$template" "$CONFIG_HOME/$target"; then
            changed=0
        fi
    done < <(token_consumers)
    return "$changed"
}

# --------------------------------------------------------------------------
# Commands
# --------------------------------------------------------------------------

render_command() {
    load_design_tokens || die "could not read the design tokens"
    hv_lock
    render_all
    hv_unlock

    # Hand off the accent-bearing templates. They have to be rendered by their
    # single owner, but a token change still has to reach them, and accent.sh
    # loads the tokens too. write_if_changed makes this a no-op when nothing
    # moved, so the extra pass costs one process, not a reload.
    #
    # Deliberately outside the lock: accent.sh takes the same one.
    "$SCRIPT_DIR/accent.sh" render >/dev/null \
        || warn "could not re-render the accent-bearing templates"

    reload_all
    printf 'Theme: rendered %d placeholders into %d consumers\n' \
        "${#HV_TOKENS[@]}" "$(token_consumers | grep -c .)"
}

list_command() {
    local key
    load_design_tokens || die "could not read the design tokens"
    for key in $(printf '%s\n' "${!HV_TOKENS[@]}" | sort); do
        printf '@%s@\t%s\n' "$key" "${HV_TOKENS[$key]}"
    done
}

# Renders into a scratch copy and diffs, so the check never touches the live
# config. Used by tests/p7-token-smoke.sh and worth running before a commit that
# edits a template.
check_command() {
    local template target scratch stale=0
    load_design_tokens || die "could not read the design tokens"
    scratch=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-theme.XXXXXX") || die "could not create a scratch directory"
    # shellcheck disable=SC2064  # expand scratch now, not at trap time
    trap "rm -rf '$scratch'" EXIT

    while IFS=: read -r template target; do
        [ -n "$template" ] || continue
        [ -f "$CONFIG_HOME/$template" ] || continue
        mkdir -p "$scratch/$(dirname "$target")"
        render_template "$CONFIG_HOME/$template" "$scratch/$target"
        if ! cmp -s "$scratch/$target" "$CONFIG_HOME/$target"; then
            warn "out of date: $target"
            stale=1
        fi
    done < <(token_consumers)

    [ "$stale" -eq 0 ] || die "run theme.sh render"
    printf 'Theme: every consumer is current\n'
}

command=${1:-}
shift 2>/dev/null || true
case "$command" in
    render) render_command ;;
    list) list_command ;;
    check) check_command ;;
    -h|--help) usage ;;
    *) usage >&2; exit 2 ;;
esac
