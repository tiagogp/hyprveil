#!/usr/bin/env bash
# One-shot install + config: runs backup, all package stages (01-04), copies every
# config/ directory into ~/.config, and applies the theme. Equivalent to running
# 00 through 04 by hand plus the manual "cp -r config/..." steps each of their
# banners tell you to run afterward.
#
# Safe to re-run. Every destructive step still asks before it acts; only the
# config copy is unconditional (00-backup.sh runs first so your old files are saved).
#
# Run from the repo root: ./scripts/05-install-all.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$REPO/config"

echo "== hyprveil: full install + config =="
echo "This will: back up existing configs, run package install stages 1-3,"
echo "then copy every config/ directory into ~/.config."
read -p "Continue? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || exit 0

echo
echo "########## Step 0: backup ##########"
"$REPO/scripts/00-backup.sh"

echo
echo "########## Step 1: Hyprland core ##########"
"$REPO/scripts/01-install-fedora-core.sh"

echo
echo "########## Step 2: desktop shell ##########"
"$REPO/scripts/02-install-fedora-shell.sh"

echo
echo "########## Step 3: theming + shell env ##########"
"$REPO/scripts/04-install-fedora-theming.sh"

echo
echo "########## Step 4: copy configs into ~/.config ##########"
read -p "Copy config/* into ~/.config now? [y/N] " ans2
if [[ "$ans2" == "y" || "$ans2" == "Y" ]]; then
    mkdir -p "$HOME/.config"
    cp -r "$CONF"/hypr "$CONF"/waybar "$CONF"/kitty "$CONF"/rofi "$CONF"/mako \
          "$CONF"/wlogout "$CONF"/gtk-3.0 "$CONF"/gtk-4.0 "$HOME/.config/"
    chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true
    cp "$CONF/starship.toml" "$HOME/.config/starship.toml"
    echo "Configs copied."
else
    echo "Skipped — copy manually later with:"
    echo "  cp -r config/hypr config/waybar config/kitty config/rofi config/mako config/wlogout config/gtk-3.0 config/gtk-4.0 ~/.config/"
    echo "  cp config/starship.toml ~/.config/starship.toml"
fi

echo
echo "########## Step 5: reload ##########"
if command -v hyprctl >/dev/null && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload
    pkill waybar 2>/dev/null || true
    (waybar & disown) 2>/dev/null || true
    [ -x "$HOME/.config/hypr/scripts/apply-theme.sh" ] && "$HOME/.config/hypr/scripts/apply-theme.sh"
    echo "Reloaded Hyprland + waybar and applied theme."
else
    echo "Not running inside Hyprland yet — log in to it, then run:"
    echo "  hyprctl reload && pkill waybar; waybar & disown"
    echo "  ~/.config/hypr/scripts/apply-theme.sh"
fi

echo
echo "All done. Edit hypr/monitors.conf for your layout if you haven't already."
echo "Run scripts/03-test-config.sh any time to re-validate the installed configs."
