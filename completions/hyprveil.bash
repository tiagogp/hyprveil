_hyprveil() {
    local current previous
    current=${COMP_WORDS[COMP_CWORD]}
    previous=${COMP_WORDS[COMP_CWORD-1]}
    case "${COMP_WORDS[1]:-}" in
        shell)
            case "$previous" in
                toggle|open) COMPREPLY=( $(compgen -W 'launcher quick-settings calendar session preferences wallpapers integrations overview cheatsheet dock-pins' -- "$current") ) ;;
                get) COMPREPLY=( $(compgen -W 'active settings' -- "$current") ) ;;
                dnd) COMPREPLY=( $(compgen -W 'toggle on off' -- "$current") ) ;;
                notifications) COMPREPLY=( $(compgen -W 'count clear' -- "$current") ) ;;
                *) COMPREPLY=( $(compgen -W 'toggle open close back get set reset dnd notifications osd doctor' -- "$current") ) ;;
            esac
            ;;
        wallpaper) COMPREPLY=( $(compgen -W 'list set restore --monitor --fit' -- "$current") ) ;;
        *) COMPREPLY=( $(compgen -W 'setup doctor shell wallpaper update rollback uninstall --help --version' -- "$current") ) ;;
    esac
}
complete -F _hyprveil hyprveil
