#!/usr/bin/env bash
# Stage 3: GTK/Qt theming, Bibata cursor, Papirus red folders, zsh + Starship.
# Assumes Stages 1+2 ran (papirus-icon-theme and fonts come from scripts/02).
# Review before running — sudo lines are separate so you can inspect each.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

echo "== Theming + shell packages =="
echo "  sudo dnf install -y adw-gtk3-theme qt5ct qt6ct zsh zsh-autosuggestions zsh-syntax-highlighting"
read -p "Run this now? [y/N] " ans
if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    sudo dnf install -y adw-gtk3-theme qt5ct qt6ct zsh zsh-autosuggestions zsh-syntax-highlighting
fi

echo "== Starship prompt =="
echo "  sudo dnf install -y starship   (falls back to the official installer if not packaged)"
read -p "Run this now? [y/N] " anss
if [[ "$anss" == "y" || "$anss" == "Y" ]]; then
    sudo dnf install -y starship \
        || curl -sS https://starship.rs/install.sh | sh -s -- --bin-dir "$HOME/.local/bin"
fi

echo "== Bibata cursor theme — no sudo, installs to ~/.local/share/icons =="
read -p "Download and install now? [y/N] " ans2
if [[ "$ans2" == "y" || "$ans2" == "Y" ]]; then
    ICONDIR="$HOME/.local/share/icons"
    mkdir -p "$ICONDIR"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    if curl -fL "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz" -o "$TMP/bibata.tar.xz"; then
        tar -xf "$TMP/bibata.tar.xz" -C "$ICONDIR"
        echo "Installed to $ICONDIR/Bibata-Modern-Classic"
    else
        echo "Download failed — get Bibata-Modern-Classic from https://github.com/ful1e5/Bibata_Cursor/releases and extract to ~/.local/share/icons"
    fi
fi

echo "== Papirus red folder accent (papirus-folders, needs sudo to edit /usr/share/icons) =="
read -p "Install and apply now? [y/N] " ans3
if [[ "$ans3" == "y" || "$ans3" == "Y" ]]; then
    mkdir -p "$HOME/.local/bin"
    if curl -fL "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders" \
            -o "$HOME/.local/bin/papirus-folders"; then
        chmod +x "$HOME/.local/bin/papirus-folders"
        sudo "$HOME/.local/bin/papirus-folders" -C red --theme Papirus-Dark \
            || echo "papirus-folders failed — folders stay blue, everything else still works"
    else
        echo "Download failed — see https://github.com/PapirusDevelopmentTeam/papirus-folders"
    fi
fi

echo "== Qt configs -> ~/.config (qt6ct needs absolute paths, so this expands __HOME__) =="
read -p "Install now? [y/N] " ans4
if [[ "$ans4" == "y" || "$ans4" == "Y" ]]; then
    mkdir -p "$HOME/.config/qt5ct/colors" "$HOME/.config/qt6ct/colors"
    sed "s|__HOME__|$HOME|g" "$REPO/config/qt5ct/qt5ct.conf" > "$HOME/.config/qt5ct/qt5ct.conf"
    sed "s|__HOME__|$HOME|g" "$REPO/config/qt6ct/qt6ct.conf" > "$HOME/.config/qt6ct/qt6ct.conf"
    cp "$REPO/config/qt5ct/colors/hyprveil.conf" "$HOME/.config/qt5ct/colors/"
    cp "$REPO/config/qt6ct/colors/hyprveil.conf" "$HOME/.config/qt6ct/colors/"
fi

echo "== zsh: install ~/.zshrc and make zsh the login shell =="
read -p "Do this now? [y/N] " ans5
if [[ "$ans5" == "y" || "$ans5" == "Y" ]]; then
    if [ -f "$HOME/.zshrc" ] && ! cmp -s "$REPO/config/zsh/.zshrc" "$HOME/.zshrc"; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.bak-hyprveil"
        echo "Existing ~/.zshrc backed up to ~/.zshrc.bak-hyprveil"
    fi
    cp "$REPO/config/zsh/.zshrc" "$HOME/.zshrc"
    if [ "$(basename "${SHELL:-}")" != "zsh" ]; then
        chsh -s "$(command -v zsh)" || echo "chsh failed — run manually: chsh -s $(command -v zsh)"
    fi
fi

echo
echo "Stage 3 install done. Now copy the remaining configs (from the repo root):"
echo "  cp -r config/gtk-3.0 config/gtk-4.0 config/starship.toml ~/.config/"
echo "  cp -r config/hypr ~/.config/    # picks up the new env vars + apply-theme.sh"
echo "Then reload: hyprctl reload && ~/.config/hypr/scripts/apply-theme.sh"
echo "Cursor + Qt env vars only reach apps started after the reload; log out/in for everything."
