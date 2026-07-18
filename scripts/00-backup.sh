#!/usr/bin/env bash
# Backs up any existing configs this project touches. Safe to re-run — never overwrites
# an existing backup, always makes a fresh timestamped one.
set -euo pipefail

STAMP=$(date +%Y%m%d-%H%M%S)
DEST="${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/backups/manual-$STAMP"
suffix=0
while [ -e "$DEST" ]; do
    suffix=$((suffix + 1))
    DEST="${XDG_STATE_HOME:-$HOME/.local/state}/hyprveil/backups/manual-$STAMP-$suffix"
done
mkdir -p "$DEST"

for d in hypr waybar kitty rofi wofi swaync mako dunst hypr-lock wlogout gtk-3.0 gtk-4.0 qt5ct qt6ct; do
    if [ -e "$HOME/.config/$d" ]; then
        cp -a "$HOME/.config/$d" "$DEST/$d"
        echo "backed up ~/.config/$d -> $DEST/$d"
    fi
done

for f in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -e "$f" ]; then
        cp -a "$f" "$DEST/$(basename "$f")"
        echo "backed up $f -> $DEST/$(basename "$f")"
    fi
done

echo "Backup complete: $DEST"
echo "Restore any single item with: cp -r $DEST/<name> ~/.config/<name>"
