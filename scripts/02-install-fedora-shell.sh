#!/usr/bin/env bash
# Stage 2 packages: everything the desktop shell design needs — Waybar, Rofi,
# mako, hyprlock, hypridle, hyprpaper, wlogout — plus fonts and the wallpaper.
# Assumes the solopasha/hyprland COPR is already enabled (scripts/01).
# Review before running — sudo lines are separate so you can inspect each.
set -euo pipefail

echo "== Shell components (hyprlock/hypridle/hyprpaper/hyprpicker come from the COPR) =="
echo "  sudo dnf install -y waybar rofi-wayland mako hyprlock hypridle hyprpaper hyprpicker wlogout pavucontrol fira-code-fonts papirus-icon-theme"
read -p "Run this now? [y/N] " ans
if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    sudo dnf install -y waybar rofi-wayland mako hyprlock hypridle hyprpaper hyprpicker wlogout pavucontrol fira-code-fonts papirus-icon-theme
fi

echo "== Keybind utilities (end-4-style: screenshots, clipboard history, media, OCR) =="
echo "  sudo dnf install -y grim slurp cliphist wl-clipboard playerctl brightnessctl btop jq rofimoji tesseract"
read -p "Run this now? [y/N] " ansu
if [[ "$ansu" == "y" || "$ansu" == "Y" ]]; then
    sudo dnf install -y grim slurp cliphist wl-clipboard playerctl brightnessctl btop jq rofimoji tesseract \
        || echo "If rofimoji isn't packaged on your release: pipx install rofimoji (SUPER+Period). tesseract is only needed for SUPER+SHIFT+X OCR."
fi

echo "== Fonts: Geist (UI) + Nerd Font symbols (Waybar/Rofi icons) — no sudo, installs to ~/.local/share/fonts =="
read -p "Download and install now? [y/N] " ans2
if [[ "$ans2" == "y" || "$ans2" == "Y" ]]; then
    FONTDIR="$HOME/.local/share/fonts"
    mkdir -p "$FONTDIR"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    echo "-- Geist --"
    if curl -fL "https://github.com/vercel/geist-font/releases/download/v1.7.2/geist-font-v1.7.2.zip" -o "$TMP/geist.zip"; then
        unzip -o -j "$TMP/geist.zip" "geist-font/Geist/ttf/*.ttf" -d "$FONTDIR/geist" || echo "Geist zip layout unexpected — install manually from https://vercel.com/font"
    else
        echo "Geist download failed — install manually from https://vercel.com/font"
    fi

    echo "-- Nerd Font symbols --"
    if curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip" -o "$TMP/nerd.zip"; then
        unzip -o -j "$TMP/nerd.zip" "*.ttf" -d "$FONTDIR/nerd-symbols"
    else
        echo "Nerd symbols download failed — get NerdFontsSymbolsOnly from https://www.nerdfonts.com/font-downloads"
    fi

    fc-cache -f
fi

echo "== Wallpaper (Elliott Engelmann, Unsplash) -> ~/.config/hypr/wallpaper.jpg =="
echo "  Required: hyprpaper.conf points at this file and hyprpaper will show no background at all until it exists."
read -p "Download now? [y/N] " ans3
if [[ "$ans3" == "y" || "$ans3" == "Y" ]]; then
    mkdir -p "$HOME/.config/hypr"
    if ! curl -fL "https://unsplash.com/photos/DjlKxYFJlTc/download?force=true&w=3840" \
        -o "$HOME/.config/hypr/wallpaper.jpg"; then
        echo "Download failed — save any dark desert-dune wallpaper to ~/.config/hypr/wallpaper.jpg"
    fi
else
    echo "Skipped — remember to save any wallpaper to ~/.config/hypr/wallpaper.jpg before starting Hyprland,"
    echo "or hyprpaper will start with no background."
fi

echo
echo "Stage 2 install done. Now copy configs (from the repo root):"
echo "  cp -r config/hypr config/waybar config/kitty config/rofi config/mako config/wlogout ~/.config/"
echo "Then: hyprctl reload && pkill waybar; waybar & disown"
