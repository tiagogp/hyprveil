#!/usr/bin/env bash
# Minimal prompt-driven CLI helpers for Hyprveil shell scripts.
# Source this file from Bash entrypoints; do not execute it directly.

if [ -z "${BASH_VERSION:-}" ]; then
    printf 'This CLI helper requires Bash.\n' >&2
    if ! return 2 2>/dev/null; then
        # shellcheck disable=SC2317
        exit 2
    fi
fi

CLI_UI_TEMP_FILES=()
CLI_UI_TEMP_DIRS=()
CLI_UI_COLOR=0
CLI_UI_INTERACTIVE=0
CLI_UI_HAS_GUM=0
CLI_UI_INITIALIZED=0
CLI_UI_CURSOR_HIDDEN=0

detect_terminal() {
    CLI_UI_COLOR=0
    CLI_UI_INTERACTIVE=0
    CLI_UI_HAS_GUM=0

    if [ -z "${NO_COLOR:-}" ]; then
        case "${HYPRVEIL_COLOR:-auto}" in
            always) CLI_UI_COLOR=1 ;;
            never) CLI_UI_COLOR=0 ;;
            *) [ -t 1 ] && [ "${TERM:-}" != dumb ] && CLI_UI_COLOR=1 ;;
        esac
    fi

    [ -t 0 ] && [ -t 2 ] && [ "${TERM:-}" != dumb ] && CLI_UI_INTERACTIVE=1
    command -v gum >/dev/null 2>&1 && CLI_UI_HAS_GUM=1
}

ui_supports_color() {
    [ "$CLI_UI_INITIALIZED" -eq 1 ] || init_cli_ui
    [ "$CLI_UI_COLOR" -eq 1 ]
}

ui_is_interactive() {
    [ "$CLI_UI_INITIALIZED" -eq 1 ] || init_cli_ui
    [ "$CLI_UI_INTERACTIVE" -eq 1 ] && [ "${HYPRVEIL_ASSUME_YES:-0}" != 1 ]
}

ui_has_gum() {
    [ "$CLI_UI_INITIALIZED" -eq 1 ] || init_cli_ui
    [ "$CLI_UI_HAS_GUM" -eq 1 ]
}

ui_style() {
    local code=$1 text=$2
    if ui_supports_color; then
        printf '\033[%sm%s\033[0m' "$code" "$text"
    else
        printf '%s' "$text"
    fi
}

ui_muted() { ui_style '2' "$*"; }
ui_bold() { ui_style '1' "$*"; }
ui_blue() { ui_style '1;34' "$*"; }
ui_cyan() { ui_style '1;36' "$*"; }
ui_green() { ui_style '1;32' "$*"; }
ui_yellow() { ui_style '1;33' "$*"; }
ui_red() { ui_style '1;31' "$*"; }

ui_symbol() {
    local plain=$1 fancy=$2
    if [ "${HYPRVEIL_ASCII:-0}" = 1 ] || ! ui_supports_color; then
        printf '%s' "$plain"
    else
        printf '%s' "$fancy"
    fi
}

register_temp_file() {
    local path=$1
    CLI_UI_TEMP_FILES+=("$path")
}

register_temp_dir() {
    local path=$1
    CLI_UI_TEMP_DIRS+=("$path")
}

cleanup() {
    local status=$? path
    if [ "$CLI_UI_CURSOR_HIDDEN" -eq 1 ]; then
        printf '\033[?25h'
        CLI_UI_CURSOR_HIDDEN=0
    fi
    for path in "${CLI_UI_TEMP_FILES[@]}"; do
        [ -n "$path" ] && [ -e "$path" ] && rm -f -- "$path"
    done
    for path in "${CLI_UI_TEMP_DIRS[@]}"; do
        [ -n "$path" ] && [ -d "$path" ] && rm -rf -- "$path"
    done
    return "$status"
}

handle_interrupt() {
    printf '\n'
    print_warning "Interrupted. Cleaned up temporary files."
    cleanup
    exit 130
}

init_cli_ui() {
    [ "$CLI_UI_INITIALIZED" -eq 0 ] || return 0
    detect_terminal
    CLI_UI_INITIALIZED=1
    trap cleanup EXIT
    trap handle_interrupt INT TERM
}

print_header() {
    local title=$1 subtitle=${2:-}
    init_cli_ui
    printf '\n'
    printf '%s %s\n' "$(ui_cyan "◆")" "$(ui_bold "$title")"
    [ -z "$subtitle" ] || printf '  %s\n' "$(ui_muted "$subtitle")"
    printf '\n'
}

print_info() {
    printf '  %s %s\n' "$(ui_blue "$(ui_symbol i i)")" "$*"
}

print_success() {
    printf '  %s %s\n' "$(ui_green "$(ui_symbol OK ✓)")" "$*"
}

print_warning() {
    printf '  %s %s\n' "$(ui_yellow "$(ui_symbol WARN !)")" "$*" >&2
}

print_error() {
    printf '  %s %s\n' "$(ui_red "$(ui_symbol ERR x)")" "$*" >&2
}

print_section() {
    local title=$1 detail=${2:-}
    printf '\n%s %s\n' "$(ui_muted "::")" "$(ui_bold "$title")"
    [ -z "$detail" ] || printf '   %s\n' "$(ui_muted "$detail")"
}

confirm_action() {
    local prompt=$1 default=${2:-no} strict=${3:-} answer suffix
    init_cli_ui
    if [ "${HYPRVEIL_ASSUME_YES:-0}" = 1 ]; then
        printf '%s %s %s\n' "$(ui_blue AUTO)" "$prompt" "$(ui_muted "[yes]")"
        return 0
    fi
    if ui_has_gum && ui_is_interactive; then
        if [ "$default" = yes ]; then
            gum confirm --default=true "$prompt"
        elif [ -n "$strict" ]; then
            # Opt-in strict no: keep the "No" button selected so an accidental
            # Enter never proceeds. For system-altering steps.
            gum confirm --default=false "$prompt"
        else
            gum confirm "$prompt"
        fi
        return $?
    fi
    if ! ui_is_interactive; then
        [ "$default" = yes ]
        return $?
    fi
    [ "$default" = yes ] && suffix='[Y/n]' || suffix='[y/N]'
    while true; do
        read -r -p "$(ui_blue "?") $prompt $suffix " answer
        case "${answer:-$default}" in
            y|Y|yes|YES|Yes) return 0 ;;
            n|N|no|NO|No) return 1 ;;
            *) print_warning "Please answer yes or no." ;;
        esac
    done
}

fallback_select_single() {
    local prompt=$1
    shift
    local -a options=("$@")
    local selected=0 key redraw=0 count=${#options[@]} i marker
    [ "$count" -gt 0 ] || return 1

    printf '%s %s\n' "$(ui_blue "?")" "$prompt" >&2
    printf '\033[?25l' >&2
    CLI_UI_CURSOR_HIDDEN=1
    while true; do
        if [ "$redraw" -eq 1 ]; then
            printf '\033[%sA' "$count" >&2
        fi
        for i in "${!options[@]}"; do
            if [ "$i" -eq "$selected" ]; then
                marker="$(ui_cyan "›")"
                printf '\033[2K  %s %s\n' "$marker" "$(ui_bold "${options[$i]}")" >&2
            else
                printf '\033[2K    %s\n' "${options[$i]}" >&2
            fi
        done
        redraw=1
        IFS= read -rsn1 key || return 130
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 -t 0.1 key || true
            case "$key" in
                '[A') selected=$(( (selected + count - 1) % count )) ;;
                '[B') selected=$(( (selected + 1) % count )) ;;
            esac
        elif [[ "$key" == "" ]]; then
            printf '\033[?25h' >&2
            CLI_UI_CURSOR_HIDDEN=0
            printf '%s %s\n' "$(ui_green "$(ui_symbol OK ✓)")" "${options[$selected]}" >&2
            printf '%s\n' "${options[$selected]}"
            return 0
        fi
    done
}

select_option() {
    local prompt=$1
    shift
    init_cli_ui
    if [ "$#" -eq 0 ]; then
        print_error "No options were provided for: $prompt"
        return 1
    fi
    if ui_has_gum && ui_is_interactive; then
        gum choose --header "$prompt" "$@"
        return $?
    fi
    if ui_is_interactive; then
        fallback_select_single "$prompt" "$@"
        return $?
    fi
    printf '%s\n' "$1"
}

fallback_select_multiple() {
    local prompt=$1
    shift
    local -a options=("$@") checked=()
    local selected=0 key redraw=0 count=${#options[@]} i box
    [ "$count" -gt 0 ] || return 1
    for _ in "${options[@]}"; do checked+=(1); done

    printf '%s %s\n' "$(ui_blue "?")" "$prompt" >&2
    printf '  %s\n' "$(ui_muted "All options start selected. Use arrows to move, Space to toggle, Enter to continue.")" >&2
    printf '\033[?25l' >&2
    CLI_UI_CURSOR_HIDDEN=1
    while true; do
        if [ "$redraw" -eq 1 ]; then
            printf '\033[%sA' "$count" >&2
        fi
        for i in "${!options[@]}"; do
            [ "${checked[$i]}" -eq 1 ] && box='[x]' || box='[ ]'
            if [ "$i" -eq "$selected" ]; then
                printf '\033[2K  %s %s %s\n' "$(ui_cyan "›")" "$(ui_bold "$box")" "$(ui_bold "${options[$i]}")" >&2
            else
                printf '\033[2K    %s %s\n' "$box" "${options[$i]}" >&2
            fi
        done
        redraw=1
        IFS= read -rsn1 key || return 130
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsn2 -t 0.1 key || true
            case "$key" in
                '[A') selected=$(( (selected + count - 1) % count )) ;;
                '[B') selected=$(( (selected + 1) % count )) ;;
            esac
        elif [[ "$key" == " " ]]; then
            checked[selected]=$((1 - checked[selected]))
        elif [[ "$key" == "" ]]; then
            printf '\033[?25h' >&2
            CLI_UI_CURSOR_HIDDEN=0
            for i in "${!options[@]}"; do
                [ "${checked[$i]}" -eq 1 ] && printf '%s\n' "${options[$i]}"
            done
            return 0
        fi
    done
}

select_multiple() {
    local prompt=$1
    shift
    init_cli_ui
    if [ "$#" -eq 0 ]; then
        print_error "No options were provided for: $prompt"
        return 1
    fi
    if ui_has_gum && ui_is_interactive; then
        gum choose --no-limit --selected '*' --header "$prompt" "$@"
        return $?
    fi
    if ui_is_interactive; then
        fallback_select_multiple "$prompt" "$@"
        return $?
    fi
    printf '%s\n' "$@"
}

ask_input() {
    local prompt=$1 default=${2:-} validator=${3:-} error_message=${4:-"Please enter a valid value."}
    local value gum_args=()
    init_cli_ui
    while true; do
        if ui_has_gum && ui_is_interactive; then
            [ -n "$default" ] && gum_args=(--value "$default") || gum_args=()
            value=$(gum input "${gum_args[@]}" --prompt "? " --placeholder "$prompt") || return $?
            [ -n "$value" ] || value=$default
        elif ui_is_interactive; then
            if [ -n "$default" ]; then
                read -r -p "$(ui_blue "?") $prompt [$default] " value
                value=${value:-$default}
            else
                read -r -p "$(ui_blue "?") $prompt " value
            fi
        else
            value=$default
        fi

        if [ -z "$validator" ] || "$validator" "$value"; then
            printf '%s\n' "$value"
            return 0
        fi
        print_warning "$error_message"
    done
}

run_with_spinner() {
    local message=$1
    shift
    local pid spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0 char status is_shell_function=0
    init_cli_ui
    if [ "$#" -eq 0 ]; then
        print_error "No command was provided for spinner: $message"
        return 1
    fi
    declare -F "$1" >/dev/null 2>&1 && is_shell_function=1
    if [ "$is_shell_function" -eq 0 ] && ui_has_gum && ui_is_interactive; then
        gum spin --spinner minidot --title "$message" -- "$@"
        return $?
    fi
    if ! ui_is_interactive; then
        print_info "$message"
        "$@"
        return $?
    fi
    "$@" &
    pid=$!
    printf '  %s %s' "$(ui_cyan "$(ui_symbol ... ... )")" "$message"
    while kill -0 "$pid" 2>/dev/null; do
        char=${spinner:i++%${#spinner}:1}
        printf '\r  %s %s' "$(ui_cyan "$char")" "$message"
        sleep 0.1
    done
    wait "$pid"
    status=$?
    if [ "$status" -eq 0 ]; then
        printf '\r'
        print_success "$message"
    else
        printf '\r'
        print_error "$message failed"
    fi
    return "$status"
}

show_progress() {
    local current=$1 total=$2 label=${3:-}
    local width=28 filled empty percent bar
    [ "$total" -gt 0 ] || total=1
    [ "$current" -gt "$total" ] && current=$total
    percent=$(( current * 100 / total ))
    filled=$(( current * width / total ))
    empty=$(( width - filled ))
    bar="$(printf '%*s' "$filled" '' | tr ' ' '#')$(printf '%*s' "$empty" '' | tr ' ' '-')"
    printf '  %s [%s] %3d%%' "$(ui_cyan "progress")" "$bar" "$percent"
    [ -z "$label" ] || printf '  %s' "$label"
    printf '\n'
}

check_dependency() {
    local command_name=$1 install_hint
    install_hint=${2:-"Install $command_name and run this script again."}
    if command -v "$command_name" >/dev/null 2>&1; then
        print_success "$command_name is available"
        return 0
    fi
    print_error "Missing dependency: $command_name"
    print_info "$install_hint"
    return 1
}

init_cli_ui
