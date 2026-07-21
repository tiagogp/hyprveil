#!/usr/bin/env bash
# Optional Kitty tab/session helpers.
set -euo pipefail

KITTY_CMD=${HYPRVEIL_KITTY:-kitty}
STATE_ROOT=${HYPRVEIL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil}
SESSION_DIR=${HYPRVEIL_KITTY_SESSION_DIR:-$STATE_ROOT/kitty-sessions}

usage() {
    cat <<'EOF'
Usage: hyprveil-session.sh COMMAND [ARGS]

Commands:
  new-tab [CMD ...]     Open a Kitty tab in the current window's directory.
  rename-tab [TITLE]    Rename the current tab, or reset the title when empty.
  close-other-tabs      Close every other tab in the focused Kitty OS window.
  save NAME             Save the focused Kitty OS window as a session snapshot.
  open NAME             Open a saved session snapshot in a new Kitty window.
  list                  List saved session snapshot names.
  delete NAME           Delete a saved session snapshot.
EOF
}

die() {
    printf 'hyprveil-session: %s\n' "$*" >&2
    exit 1
}

valid_name() {
    [[ ${1:-} =~ ^[A-Za-z0-9._-]+$ ]]
}

session_path() {
    local name=${1:?}
    valid_name "$name" || die "session names may contain only letters, numbers, dot, underscore, and dash"
    printf '%s/%s.conf\n' "$SESSION_DIR" "$name"
}

kitty_rc() {
    "$KITTY_CMD" @ "$@"
}

ensure_dir() {
    mkdir -p "$SESSION_DIR"
    chmod 700 "$SESSION_DIR"
}

cmd=${1:-}
shift || true

case "$cmd" in
    new-tab)
        kitty_rc launch --type=tab --cwd=current --add-to-session=. --no-response "$@"
        ;;
    rename-tab)
        if [ "$#" -eq 0 ]; then
            kitty_rc set-tab-title
        else
            kitty_rc set-tab-title "$*"
        fi
        ;;
    close-other-tabs)
        kitty_rc close-tab --match "not state:focused and state:parent_focused" --ignore-no-match
        ;;
    save)
        [ "$#" -eq 1 ] || die "save needs exactly one session name"
        ensure_dir
        path=$(session_path "$1")
        tmp=$(mktemp "$SESSION_DIR/.${1}.XXXXXX")
        trap 'rm -f "$tmp"' EXIT
        umask 077
        kitty_rc ls --match-tab state:focused_os_window --output-format=session > "$tmp"
        chmod 600 "$tmp"
        mv "$tmp" "$path"
        trap - EXIT
        printf 'Saved Kitty session: %s\n' "$path"
        ;;
    open)
        [ "$#" -eq 1 ] || die "open needs exactly one session name"
        path=$(session_path "$1")
        [ -f "$path" ] || die "no saved Kitty session named '$1'"
        "$KITTY_CMD" --session "$path" --detach
        ;;
    list)
        [ -d "$SESSION_DIR" ] || exit 0
        find "$SESSION_DIR" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' \
            | sed 's/\.conf$//' \
            | sort
        ;;
    delete)
        [ "$#" -eq 1 ] || die "delete needs exactly one session name"
        path=$(session_path "$1")
        [ -f "$path" ] || die "no saved Kitty session named '$1'"
        rm -f "$path"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac
