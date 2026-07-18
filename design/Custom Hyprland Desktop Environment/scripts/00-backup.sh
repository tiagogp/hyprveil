#!/usr/bin/env bash
# Backs up any existing configs this project touches. Safe to re-run — never overwrites
# an existing backup, always makes a fresh timestamped one.
set -euo pipefail

STAMP=$(date +%Y%m%d-%H%M%S)
DEST="$HOME/.config-backup-$STAMP"
mkdir -p "$DEST"

for d in hypr waybar kitty rofi wofi mako dunst hypr-lock zsh; do
    if [ -e "$HOME/.config/$d" ]; then
        cp -r "$HOME/.config/$d" "$DEST/$d"
        echo "backed up ~/.config/$d -> $DEST/$d"
    fi
done

for f in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -e "$f" ]; then
        cp "$f" "$DEST/$(basename "$f")"
        echo "backed up $f -> $DEST/$(basename "$f")"
    fi
done

echo "Backup complete: $DEST"
echo "Restore any single item with: cp -r $DEST/<name> ~/.config/<name>"
