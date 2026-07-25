#!/usr/bin/env bash
# Pushes the Stage 3 theme into the running session. settings.ini doesn't reach
# libadwaita apps — they read gsettings — so this runs once per login (autostart.conf).
# Safe to re-run any time; does nothing destructive.

# Cursor theme/size are declared once in variables.conf's env lines; read them
# back here instead of hardcoding a second copy that could drift out of sync.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIABLES_CONF="$SCRIPT_DIR/../variables.conf"
CURSOR_THEME=$(sed -n 's/^env = XCURSOR_THEME,\(.*\)$/\1/p' "$VARIABLES_CONF" 2>/dev/null | head -n1)
CURSOR_SIZE=$(sed -n 's/^env = XCURSOR_SIZE,\(.*\)$/\1/p' "$VARIABLES_CONF" 2>/dev/null | head -n1)
CURSOR_THEME="${CURSOR_THEME:-Bibata-Modern-Classic}"
CURSOR_SIZE="${CURSOR_SIZE:-24}"

if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"
    gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE"
    gsettings set org.gnome.desktop.interface font-name 'Geist 11'
    gsettings set org.gnome.desktop.interface document-font-name 'Geist 11'
    gsettings set org.gnome.desktop.interface monospace-font-name 'Fira Code 11'
fi

# apply the cursor to already-running Hyprland (env vars only cover new clients)
command -v hyprctl >/dev/null && hyprctl setcursor "$CURSOR_THEME" "$CURSOR_SIZE" >/dev/null
