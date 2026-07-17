#!/usr/bin/env bash
# Pushes the Stage 3 theme into the running session. settings.ini doesn't reach
# libadwaita apps — they read gsettings — so this runs once per login (autostart.conf).
# Safe to re-run any time; does nothing destructive.

if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'
    gsettings set org.gnome.desktop.interface cursor-size 24
    gsettings set org.gnome.desktop.interface font-name 'Geist 11'
    gsettings set org.gnome.desktop.interface document-font-name 'Geist 11'
    gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code 11'
fi

# apply the cursor to already-running Hyprland (env vars only cover new clients)
command -v hyprctl >/dev/null && hyprctl setcursor Bibata-Modern-Classic 24 >/dev/null
