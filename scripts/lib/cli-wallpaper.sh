#!/usr/bin/env bash
# `hyprveil wallpaper` implementation. Sourced by the public entrypoint.

wallpaper_store() {
    if [ -x "$HV_CONFIG_HOME/hypr/scripts/wallpaper.sh" ]; then
        printf '%s\n' "$HV_CONFIG_HOME/hypr/scripts/wallpaper.sh"
    else
        printf '%s\n' "$REPO/config/hypr/scripts/wallpaper.sh"
    fi
}

wallpaper_command() {
    local action=${1:-} path monitor='' fit=cover store
    store=$(wallpaper_store)
    case "$action" in
        list|restore)
            [ "$#" -eq 1 ] || { printf 'Usage: hyprveil wallpaper %s\n' "$action" >&2; return 2; }
            "$store" "$action"
            ;;
        set)
            shift
            path=${1:-}
            [ -n "$path" ] || { printf 'Usage: hyprveil wallpaper set <file> [--monitor NAME] [--fit cover|contain]\n' >&2; return 2; }
            shift
            while [ "$#" -gt 0 ]; do
                case "$1" in
                    --monitor) shift; monitor=${1:-} ;;
                    --fit) shift; fit=${1:-} ;;
                    *) printf 'Unknown wallpaper option: %s\n' "$1" >&2; return 2 ;;
                esac
                shift
            done
            case "$fit" in cover|contain) ;; *) printf 'Invalid wallpaper fit: %s\n' "$fit" >&2; return 2 ;; esac
            [ -f "$path" ] || { printf 'Wallpaper file does not exist: %s\n' "$path" >&2; return 1; }
            "$store" apply "$path" "$monitor" "$fit"
            ;;
        *)
            printf 'Usage: hyprveil wallpaper list|set|restore ...\n' >&2
            return 2
            ;;
    esac
}
