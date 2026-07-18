#!/usr/bin/env bash
# Stage 1 packages only: Hyprland core + terminal + basics needed for it to launch.
# Review before running — sudo lines are separate so you can inspect each.
set -euo pipefail

echo "== Enabling Hyprland COPR (needs sudo) =="
echo "Run manually if you'd rather review first:"
echo "  sudo dnf copr enable solopasha/hyprland"
echo "  sudo dnf install -y hyprland hyprland-devel"
read -p "Run these two now? [y/N] " ans
if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    sudo dnf copr enable solopasha/hyprland
    sudo dnf install -y hyprland hyprland-devel
fi

echo "== Core utilities (no COPR needed) =="
echo "  sudo dnf install -y kitty polkit-gnome xdg-desktop-portal-hyprland qt5-qtwayland qt6-qtwayland"
read -p "Run this now? [y/N] " ans2
if [[ "$ans2" == "y" || "$ans2" == "Y" ]]; then
    sudo dnf install -y kitty polkit-gnome xdg-desktop-portal-hyprland qt5-qtwayland qt6-qtwayland
fi

echo "Stage 1 install step done. Next stages (waybar, rofi, mako, hyprlock, etc.) come separately."
