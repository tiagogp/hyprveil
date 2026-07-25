#!/usr/bin/env bash
# Stage 3: GTK/Qt theming, Bibata cursor, Papirus red folders, zsh + Starship.
# Assumes Stages 1+2 ran (papirus-icon-theme and fonts come from scripts/02).
# Review before running — sudo lines are separate so you can inspect each.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

hv_section "Stage 3: Fedora and repository detection"
hv_load_fedora
hv_check_supported_release || true
hv_show_enabled_repos
hv_install_group optional "application theming and zsh environment" - \
    adw-gtk3-theme qt5ct qt6ct zsh zsh-autosuggestions zsh-syntax-highlighting fzf zoxide

hv_section "Starship prompt"
hv_install_group optional "Starship prompt" - starship

hv_section "Bibata cursor theme" "No sudo; installs to ~/.local/share/icons"
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

hv_section "Papirus red folder accent" "Uses papirus-folders and sudo to edit /usr/share/icons"
if hv_confirm "Install and apply the Papirus red folder helper?"; then
    mkdir -p "$HOME/.local/bin"
    # Pinned to a reviewed commit (v1.14.0, 2025-05-28) instead of the mutable
    # master branch, and checksummed before it is ever executed — this script
    # runs with sudo below. To take a newer release: review the diff at
    # https://github.com/PapirusDevelopmentTeam/papirus-folders/compare/<this sha>...master,
    # then update both papirus_sha and papirus_sha256 together.
    papirus_sha=0f838ee5679229e3a3e97e3b333c222c9e9615b4
    papirus_sha256=b30a6848a00690302accffc050549218b0b114d3178b28bd3a16891817821b06
    papirus_tmp=$(mktemp "${TMPDIR:-/tmp}/papirus-folders.XXXXXX")
    if curl -fL "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/$papirus_sha/papirus-folders" \
            -o "$papirus_tmp" \
        && printf '%s  %s\n' "$papirus_sha256" "$papirus_tmp" | sha256sum -c - >/dev/null 2>&1; then
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
        hv_warn "papirus-folders download failed or did not match the pinned checksum; nothing was run as root"
        echo "Get it yourself from https://github.com/PapirusDevelopmentTeam/papirus-folders"
    fi
fi

hv_section "Qt configs" "$HV_CONFIG_HOME with absolute paths expanded"
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

hv_section "zsh" "Install ~/.zshrc and make zsh the login shell"
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

hv_section "pokemon-colorscripts" "Optional Pokémon splash for new shells; stays off unless enabled in ~/.zshrc"
if hv_confirm "Clone and install pokemon-colorscripts to /usr/local (needs sudo)?"; then
    # Pinned to a reviewed commit on the default branch (this project has no
    # tagged releases to pin to instead) rather than whatever HEAD currently
    # is — install.sh runs with sudo below, so the checkout is fixed to a
    # known commit before it is ever handed to root. To take a newer commit:
    # review the diff at
    # https://gitlab.com/phoneybadger/pokemon-colorscripts/-/compare/<this sha>...main,
    # then update POKEMON_SHA.
    POKEMON_SHA=5802ff67520be2ff6117a0abc78a08501f6252ad
    POKEMON_TMP=$(mktemp -d)
    if git clone -q https://gitlab.com/phoneybadger/pokemon-colorscripts.git "$POKEMON_TMP/pokemon-colorscripts" \
        && git -C "$POKEMON_TMP/pokemon-colorscripts" checkout -q "$POKEMON_SHA"; then
        if (cd "$POKEMON_TMP/pokemon-colorscripts" && hv_root sh install.sh); then
            hv_ok "pokemon-colorscripts installed. It stays silent until you set HYPRVEIL_POKEMON_SHELL=true near the bottom of ~/.zshrc"
        else
            hv_warn "pokemon-colorscripts install.sh failed; see output above"
        fi
    else
        hv_warn "pokemon-colorscripts clone failed or the pinned commit is unavailable; nothing was run as root"
        echo "See https://gitlab.com/phoneybadger/pokemon-colorscripts"
    fi
    rm -rf "$POKEMON_TMP"
fi

echo
hv_ok "Stage 3 install done. The full installer deploys remaining managed configs safely."
hv_note "Then reload: hyprctl reload && $HV_CONFIG_HOME/hypr/scripts/apply-theme.sh"
hv_note "Cursor + Qt env vars only reach apps started after the reload; log out/in for everything."
