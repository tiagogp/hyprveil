#!/usr/bin/env bash
# Stage 3: GTK/Qt theming, Bibata cursor, Papirus red folders, zsh + Starship.
# Assumes Stages 1+2 ran (papirus-icon-theme and fonts come from scripts/02).
# Review before running — sudo lines are separate so you can inspect each.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

echo "== Stage 3: Fedora and repository detection =="
hv_load_fedora
hv_check_supported_release || true
hv_show_enabled_repos
hv_install_group optional "application theming and zsh environment" - \
    adw-gtk3-theme qt5ct qt6ct zsh zsh-autosuggestions zsh-syntax-highlighting

echo "== Starship prompt =="
hv_install_group optional "Starship prompt" - starship

echo "== Bibata cursor theme — no sudo, installs to ~/.local/share/icons =="
if hv_confirm "Download and install the Bibata cursor?"; then
    ICONDIR="$HOME/.local/share/icons"
    mkdir -p "$ICONDIR"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    if curl -fL "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz" -o "$TMP/bibata.tar.xz"; then
        mkdir -p "$TMP/bibata"
        if tar -xf "$TMP/bibata.tar.xz" -C "$TMP/bibata" \
            && [ -d "$TMP/bibata/Bibata-Modern-Classic" ]; then
            if [ -e "$ICONDIR/Bibata-Modern-Classic" ]; then
                backup=$(hv_new_backup_dir)
                hv_backup_item "$ICONDIR/Bibata-Modern-Classic" "$backup/icons"
                rm -rf "$ICONDIR/Bibata-Modern-Classic"
                echo "Existing cursor backed up to $backup/icons"
            fi
            mv "$TMP/bibata/Bibata-Modern-Classic" "$ICONDIR/Bibata-Modern-Classic"
            echo "Installed to $ICONDIR/Bibata-Modern-Classic"
        else
            hv_warn "Bibata archive layout changed; existing cursor was not replaced"
        fi
    else
        echo "Download failed — get Bibata-Modern-Classic from https://github.com/ful1e5/Bibata_Cursor/releases and extract to ~/.local/share/icons"
    fi
fi

echo "== Papirus red folder accent (papirus-folders, needs sudo to edit /usr/share/icons) =="
if hv_confirm "Install and apply the Papirus red folder helper?"; then
    mkdir -p "$HOME/.local/bin"
    papirus_tmp=$(mktemp "${TMPDIR:-/tmp}/papirus-folders.XXXXXX")
    if curl -fL "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders" \
            -o "$papirus_tmp"; then
        if [ -e "$HOME/.local/bin/papirus-folders" ]; then
            backup=$(hv_new_backup_dir)
            hv_backup_item "$HOME/.local/bin/papirus-folders" "$backup/bin"
        fi
        mv -f "$papirus_tmp" "$HOME/.local/bin/papirus-folders"
        chmod +x "$HOME/.local/bin/papirus-folders"
        hv_root "$HOME/.local/bin/papirus-folders" -C red --theme Papirus-Dark \
            || echo "papirus-folders failed — folders stay blue, everything else still works"
    else
        rm -f "$papirus_tmp"
        echo "Download failed — see https://github.com/PapirusDevelopmentTeam/papirus-folders"
    fi
fi

echo "== Qt configs -> $HV_CONFIG_HOME (absolute paths expanded) =="
if hv_confirm "Back up and install Qt theme configs?"; then
    backup=
    for toolkit in qt5ct qt6ct; do
        if [ -e "$HV_CONFIG_HOME/$toolkit" ]; then
            [ -n "$backup" ] || backup=$(hv_new_backup_dir)
            hv_backup_item "$HV_CONFIG_HOME/$toolkit" "$backup/config" "$toolkit"
        fi
        rm -rf "${HV_CONFIG_HOME:?}/$toolkit"
        mkdir -p "$HV_CONFIG_HOME/$toolkit/colors"
        sed "s|__HOME__|$HOME|g" "$REPO/config/$toolkit/$toolkit.conf" > "$HV_CONFIG_HOME/$toolkit/$toolkit.conf"
        # The .in template travels with the palette: accent.sh regenerates
        # hyprveil.conf from it on every wallpaper change, and without it the
        # Qt palette is the one consumer that silently keeps the designed red.
        cp -a "$REPO/config/$toolkit/colors/hyprveil.conf" \
            "$REPO/config/$toolkit/colors/hyprveil.conf.in" \
            "$HV_CONFIG_HOME/$toolkit/colors/"
    done
    if [ -x "$HV_CONFIG_HOME/hypr/scripts/accent.sh" ]; then
        "$HV_CONFIG_HOME/hypr/scripts/accent.sh" render || true
    fi
fi

echo "== zsh: install ~/.zshrc and make zsh the login shell =="
if hv_confirm "Back up and install the Hyprveil zsh config?"; then
    if [ -f "$HOME/.zshrc" ] && ! cmp -s "$REPO/config/zsh/.zshrc" "$HOME/.zshrc"; then
        backup=$(hv_new_backup_dir)
        hv_backup_item "$HOME/.zshrc" "$backup/home" .zshrc
        echo "Existing ~/.zshrc backed up to $backup/home/.zshrc"
    fi
    cp -a "$REPO/config/zsh/.zshrc" "$HOME/.zshrc"
    if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
        chsh -s "$(command -v zsh)" || echo "chsh failed — run manually: chsh -s $(command -v zsh)"
    fi
fi

echo
echo "Stage 3 install done. The full installer deploys remaining managed configs safely."
echo "Then reload: hyprctl reload && $HV_CONFIG_HOME/hypr/scripts/apply-theme.sh"
echo "Cursor + Qt env vars only reach apps started after the reload; log out/in for everything."
