#!/usr/bin/env bash
# `hyprveil shell` implementation. Sourced by the public entrypoint.

settings_store() {
    if [ -x "$HV_CONFIG_HOME/hypr/scripts/settings-store.sh" ]; then
        printf '%s\n' "$HV_CONFIG_HOME/hypr/scripts/settings-store.sh"
    else
        printf '%s\n' "$REPO/config/hypr/scripts/settings-store.sh"
    fi
}

shell_ipc() {
    local qs_bin
    if have qs; then qs_bin=qs
    elif have quickshell; then qs_bin=quickshell
    else
        printf 'The shell IPC client is unavailable; install Quickshell or use the recovery profile.\n' >&2
        return 1
    fi
    "$qs_bin" ipc call surface "$@"
}

shell_command() {
    local action=${1:-} subject=${2:-} key value json_value patch store
    case "$action" in
        toggle|open)
            [ "$#" -eq 2 ] || { printf 'Usage: hyprveil shell %s <surface>\n' "$action" >&2; return 2; }
            case "$subject" in
                launcher|quick-settings|calendar|session|preferences|wallpapers|integrations|overview|cheatsheet|dock-pins) ;;
                *) printf 'Unknown shell surface: %s\n' "$subject" >&2; return 2 ;;
            esac
            shell_ipc "$action" "$subject"
            ;;
        close|back)
            [ "$#" -eq 1 ] || { printf 'Usage: hyprveil shell %s\n' "$action" >&2; return 2; }
            shell_ipc "$action"
            ;;
        get)
            [ "$#" -eq 2 ] || { printf 'Usage: hyprveil shell get active|settings\n' >&2; return 2; }
            case "$subject" in
                active) shell_ipc active ;;
                settings) store=$(settings_store); "$store" get ;;
                *) printf 'Unknown shell state: %s\n' "$subject" >&2; return 2 ;;
            esac
            ;;
        set)
            [ "$#" -eq 3 ] || { printf 'Usage: hyprveil shell set <setting.path> <JSON value>\n' >&2; return 2; }
            key=$2; value=$3
            [[ "$key" =~ ^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z][A-Za-z0-9_-]*)*$ ]] \
                || { printf 'Invalid setting path: %s\n' "$key" >&2; return 2; }
            have jq || { printf 'jq is required to validate setting values.\n' >&2; return 1; }
            json_value=$(jq -ce . 2>/dev/null <<<"$value")
            if [ -z "$json_value" ]; then
                json_value=$(jq -nc --arg value "$value" '$value')
            fi
            patch=$(jq -nc --arg path "$key" --argjson value "$json_value" \
                'setpath($path | split("."); $value)')
            store=$(settings_store)
            "$store" set "$patch" || return
            "$store" get
            ;;
        reset)
            [ "$#" -eq 1 ] || { printf 'Usage: hyprveil shell reset\n' >&2; return 2; }
            store=$(settings_store)
            "$store" reset
            "$store" get
            ;;
        dnd)
            [ "$#" -le 2 ] || { printf 'Usage: hyprveil shell dnd [toggle|on|off]\n' >&2; return 2; }
            subject=${2:-toggle}
            case "$subject" in toggle|on|off) ;; *) printf 'Invalid DND mode: %s\n' "$subject" >&2; return 2 ;; esac
            shell_ipc dnd "$subject"
            ;;
        notifications)
            [ "$#" -eq 2 ] || { printf 'Usage: hyprveil shell notifications count|clear\n' >&2; return 2; }
            case "$subject" in count|clear) ;; *) printf 'Invalid notification action: %s\n' "$subject" >&2; return 2 ;; esac
            shell_ipc notifications "$subject"
            ;;
        osd)
            [ "$#" -eq 4 ] || { printf 'Usage: hyprveil shell osd <kind> <percent> <true|false>\n' >&2; return 2; }
            [[ "$3" =~ ^[0-9]+$ ]] && [ "$3" -le 100 ] \
                || { printf 'OSD percent must be an integer from 0 to 100\n' >&2; return 2; }
            case "$4" in true|false) ;; *) printf 'OSD muted value must be true or false\n' >&2; return 2 ;; esac
            shell_ipc osd "$2" "$3" "$4"
            ;;
        doctor)
            [ "$#" -eq 1 ] || { printf 'Usage: hyprveil shell doctor\n' >&2; return 2; }
            doctor
            ;;
        *)
            printf 'Usage: hyprveil shell toggle|open|close|back|get|set|reset|dnd|notifications|osd|doctor ...\n' >&2
            return 2
            ;;
    esac
}
