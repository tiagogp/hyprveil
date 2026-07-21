#!/usr/bin/env bash
# User-facing uninstall helper. Removes Hyprveil-managed config and optional
# assets while deliberately keeping Kitty and zsh.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

REMOVE_PACKAGES=0
PACKAGES_CHOSEN=0
PURGE_STATE=0
DO_SDDM=0
EXPORT_DIR=''

usage() {
    cat <<'EOF'
Usage: ./scripts/uninstall.sh [options]

Removes Hyprveil user config while preserving:
  - ~/.config/kitty
  - ~/.zshrc
  - kitty and zsh packages

Options:
  --packages            Also offer to remove recorded DNF packages, except kitty and zsh.
  --configs-only        Remove configs/assets only.
  --export-state DIR    Copy Hyprveil state and backups to DIR before removal.
  --purge-state         After config removal, also delete Hyprveil state/backups.
  --sddm                Also restore/remove Hyprveil SDDM files (uses sudo).
  --yes, -y             Answer yes to prompts.
  --help, -h            Show this help.
EOF
}

redact() {
    local value=$1
    if [ -n "${HOME:-}" ]; then
        value=${value//$HOME/\~}
    fi
    printf '%s\n' "$value"
}

append_unique() {
    local candidate=$1 existing
    shift
    for existing in "$@"; do
        [ "$candidate" = "$existing" ] && return 1
    done
    printf '%s\n' "$candidate"
}

keep_package() {
    case "$1" in
        kitty|zsh) return 0 ;;
        *) return 1 ;;
    esac
}

known_uninstall_package() {
    case "$1" in
        hyprland|hyprland-devel|mate-polkit|xdg-desktop-portal-hyprland|qt5-qtwayland|qt6-qtwayland|\
        waybar|rofi-wayland|wlogout|gnome-control-center|fira-code-fonts|papirus-icon-theme|\
        quickshell|SwayNotificationCenter|mako|hyprlock|hypridle|hyprpaper|hyprpicker|\
        bluez|blueman|grim|slurp|cliphist|wl-clipboard|playerctl|brightnessctl|btop|rofimoji|tesseract|ImageMagick|\
        adw-gtk3-theme|qt5ct|qt6ct|zsh-autosuggestions|zsh-syntax-highlighting|starship)
            return 0
            ;;
        *) return 1 ;;
    esac
}

remove_extra_user_assets() {
    local backup item label removed=0
    local -a assets=(
        "$HOME/.local/share/icons/Bibata-Modern-Classic"
        "$HOME/.local/share/fonts/geist"
        "$HOME/.local/share/fonts/nerd-symbols"
        "$HOME/.local/bin/papirus-folders"
    )

    backup=$(hv_new_backup_dir)
    for item in "${assets[@]}"; do
        [ -e "$item" ] || continue
        label=${item#"$HOME"/}
        mkdir -p "$backup/home/$(dirname "$label")"
        cp -a "$item" "$backup/home/$label"
        rm -rf "$item"
        printf 'Removed %s\n' "$(redact "$item")"
        removed=$((removed + 1))
    done
    if [ "$removed" -gt 0 ]; then
        printf 'Backed up removed user assets to %s\n' "$(redact "$backup")"
    else
        rmdir "$backup" 2>/dev/null || true
    fi
}

remove_qt_configs() {
    local backup name target removed=0
    backup=$(hv_new_backup_dir)
    for name in qt5ct qt6ct; do
        target="$HV_CONFIG_HOME/$name"
        [ -e "$target" ] || continue
        mkdir -p "$backup/config"
        cp -a "$target" "$backup/config/$name"
        rm -rf "$target"
        printf 'Removed %s\n' "$(redact "$target")"
        removed=$((removed + 1))
    done
    if [ "$removed" -gt 0 ]; then
        printf 'Backed up removed Qt config to %s\n' "$(redact "$backup")"
    else
        rmdir "$backup" 2>/dev/null || true
    fi
}

recorded_packages() {
    local package source feature
    local -a packages=()
    [ -s "$HV_SOURCE_LOG" ] || return 0
    while IFS=$'\t' read -r package source feature; do
        [ -n "$package" ] || continue
        keep_package "$package" && continue
        known_uninstall_package "$package" || continue
        case "$source" in
            unavailable|declined) continue ;;
        esac
        if append_unique "$package" "${packages[@]}" >/dev/null; then
            packages+=("$package")
        fi
    done < "$HV_SOURCE_LOG"
    printf '%s\n' "${packages[@]}"
}

remove_recorded_packages() {
    local joined
    local -a packages=()
    mapfile -t packages < <(recorded_packages)
    if [ "${#packages[@]}" -eq 0 ]; then
        printf 'No recorded Hyprveil packages found to remove. Kitty and zsh are kept.\n'
        return 0
    fi

    printf 'Recorded packages selected for removal (kitty and zsh kept):\n'
    printf '  %s\n' "${packages[@]}"
    if ! hv_confirm "Remove these packages with dnf now?"; then
        printf 'Package removal skipped.\n'
        return 0
    fi

    joined=$(printf '%s ' "${packages[@]}")
    printf 'Removing packages: %s\n' "${joined% }"
    if [ "${HYPRVEIL_ASSUME_YES:-0}" = 1 ]; then
        hv_root "${HYPRVEIL_DNF:-dnf}" remove -y "${packages[@]}"
    else
        hv_root "${HYPRVEIL_DNF:-dnf}" remove "${packages[@]}"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --packages) REMOVE_PACKAGES=1; PACKAGES_CHOSEN=1 ;;
        --configs-only) REMOVE_PACKAGES=0; PACKAGES_CHOSEN=1 ;;
        --export-state) shift; EXPORT_DIR=${1:-} ;;
        --purge-state) PURGE_STATE=1 ;;
        --sddm) DO_SDDM=1 ;;
        --yes|-y) export HYPRVEIL_ASSUME_YES=1 ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
    shift
done

printf 'Hyprveil uninstall helper\n'
printf 'Config home: %s\n' "$(redact "$HV_CONFIG_HOME")"
printf 'State home:  %s\n' "$(redact "$HV_STATE_HOME")"
printf 'Keeping Kitty config/package and zsh config/package.\n'

if ! hv_confirm "Back up and remove Hyprveil config now?"; then
    printf 'Uninstall cancelled; no changes were made.\n'
    exit 0
fi

if [ -n "$EXPORT_DIR" ]; then
    mkdir -p "$EXPORT_DIR"
    if cp -a "$HV_STATE_HOME/." "$EXPORT_DIR/" 2>/dev/null; then
        printf 'Exported state and backups to %s\n' "$(redact "$EXPORT_DIR")"
    else
        hv_warn "could not export state to $(redact "$EXPORT_DIR")"
    fi
fi

HYPRVEIL_KEEP_MANAGED_NAMES=kitty hv_remove_managed_config
remove_qt_configs
remove_extra_user_assets

if [ "$DO_SDDM" -eq 1 ]; then
    hv_uninstall_sddm
elif [ -e /etc/sddm.conf.d/hyprveil.conf ] || [ -e /usr/share/sddm/themes/hyprveil ]; then
    printf 'A system SDDM theme or selection installed by Hyprveil is still present.\n'
    printf 'Re-run with --sddm to restore or remove it (requires sudo).\n'
fi

if [ "$PACKAGES_CHOSEN" -eq 0 ] && [ -s "$HV_SOURCE_LOG" ]; then
    hv_confirm "Also remove recorded DNF packages, keeping kitty and zsh?" && REMOVE_PACKAGES=1
fi
[ "$REMOVE_PACKAGES" -eq 0 ] || remove_recorded_packages

if [ "$PURGE_STATE" -eq 1 ]; then
    if hv_confirm "Permanently delete all Hyprveil state and backups under $(redact "$HV_STATE_HOME")?"; then
        rm -rf "$HV_STATE_HOME"
        printf 'Removed Hyprveil state and backups.\n'
    else
        printf 'Kept Hyprveil state and backups.\n'
    fi
else
    printf 'Preserved Hyprveil state and backups under %s.\n' "$(redact "$HV_STATE_HOME")"
fi

printf 'Uninstall complete. Kitty and zsh were left alone.\n'
