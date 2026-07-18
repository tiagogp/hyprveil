#!/usr/bin/env bash
# Stage 4 (optional extra): SDDM login-screen theming, styled to match
# hyprveil, using SDDM's own Wayland (Weston-backed) greeter instead of X11.
# scripts/05-install-all.sh offers to run this as a separately confirmed final
# step because it changes the SYSTEM display manager for every login, not just
# Hyprland's. Review before running — every sudo/system-wide step is gated
# separately, and step 4 (making sddm the display manager) is the only one that
# actually changes what you see at your next login.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
THEME_SRC="$REPO/config/sddm/hyprveil"
THEME_DST="/usr/share/sddm/themes/hyprveil"

echo "== Step 0: preview the theme — installs/changes nothing =="
echo "  sddm-greeter-qt6 --test-mode --theme \"$THEME_SRC\""
echo "  (falls back to 'sddm-greeter' — only present as a compat symlink on Fedora <= 42)"
read -p "Run the preview now? [y/N] " ans0
if [[ "$ans0" == "y" || "$ans0" == "Y" ]]; then
    GREETER_BIN="$(command -v sddm-greeter-qt6 || command -v sddm-greeter || true)"
    if [ -n "$GREETER_BIN" ]; then
        "$GREETER_BIN" --test-mode --theme "$THEME_SRC"
    else
        echo "Neither sddm-greeter-qt6 nor sddm-greeter found — install sddm first (Step 1), then re-run this step."
    fi
fi

echo
echo "== Step 1: install sddm =="
echo "Fedora's login-screen backend (independent of which SESSION you pick after"
echo "logging in — Hyprland launches fine either way). Fedora's real default is"
echo "the Wayland/Weston greeter; NVIDIA hybrid-GPU setups have an open upstream"
echo "issue with it (sddm#2142) — see README 'Hybrid GPU' section."
read -p "Are you on the NVIDIA hybrid-GPU path from variables.conf? [y/N] " gpu
if [[ "$gpu" == "y" || "$gpu" == "Y" ]]; then
    PKGS="sddm sddm-x11"
    echo "Using the X11 greeter backend (safer on NVIDIA hybrid GPU per sddm#2142)."
else
    PKGS="sddm sddm-wayland-generic"
    echo "Using Fedora's default Wayland/Weston greeter backend."
fi
echo "  sudo dnf install -y $PKGS"
read -p "Run this now? [y/N] " ans1
if [[ "$ans1" == "y" || "$ans1" == "Y" ]]; then
    sudo dnf install -y $PKGS
fi

echo
echo "== Checking Hyprland is actually selectable in the greeter =="
if [ -f /usr/share/wayland-sessions/hyprland.desktop ] || [ -f /usr/share/xsessions/hyprland.desktop ]; then
    echo "OK: found a Hyprland session entry."
else
    echo "WARNING: no hyprland.desktop found under /usr/share/wayland-sessions or"
    echo "         /usr/share/xsessions. The greeter will come up but Hyprland won't"
    echo "         be in the session list. This means the Hyprland package itself"
    echo "         didn't ship one — check 'rpm -ql hyprland | grep sessions'."
fi

echo
echo "== Step 2: install the hyprveil theme + fonts to $THEME_DST (sudo) =="
echo "  sudo rm -rf \"$THEME_DST\""
echo "  sudo cp -r \"$THEME_SRC\" \"$THEME_DST\""
echo "  + download Geist Light/Regular into $THEME_DST/Fonts (the greeter runs as"
echo "    the 'sddm' system user, which can't see ~/.local/share/fonts)"
read -p "Run this now? [y/N] " ans2
if [[ "$ans2" == "y" || "$ans2" == "Y" ]]; then
    sudo rm -rf "$THEME_DST"
    sudo cp -r "$THEME_SRC" "$THEME_DST"
    sudo mkdir -p "$THEME_DST/Fonts"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    if curl -fL "https://github.com/vercel/geist-font/releases/download/v1.7.2/geist-font-v1.7.2.zip" -o "$TMP/geist.zip"; then
        unzip -o -j "$TMP/geist.zip" \
            "geist-font/Geist/ttf/Geist-Light.ttf" \
            "geist-font/Geist/ttf/Geist-Regular.ttf" \
            -d "$TMP/fonts" \
            && sudo cp "$TMP/fonts/Geist-Light.ttf" "$TMP/fonts/Geist-Regular.ttf" "$THEME_DST/Fonts/" \
            || echo "Geist zip layout unexpected — copy Geist-Light.ttf + Geist-Regular.ttf into $THEME_DST/Fonts/ manually from https://vercel.com/font"
    else
        echo "Geist download failed — copy Geist-Light.ttf + Geist-Regular.ttf into $THEME_DST/Fonts/ manually from https://vercel.com/font"
    fi
fi

echo
echo "== Step 3: point sddm at the theme — writes /etc/sddm.conf.d/hyprveil.conf (sudo) =="
echo "  [Theme]"
echo "  Current=hyprveil"
read -p "Write this now? [y/N] " ans3
if [[ "$ans3" == "y" || "$ans3" == "Y" ]]; then
    printf '[Theme]\nCurrent=hyprveil\n' | sudo tee /etc/sddm.conf.d/hyprveil.conf >/dev/null
fi

echo
echo "== Step 4: make sddm the display manager (sudo) =="
echo "THIS REPLACES YOUR CURRENT DISPLAY MANAGER (likely GDM on Fedora Workstation)"
echo "for ALL logins on this machine, not just Hyprland."
echo "  sudo systemctl disable gdm.service"
echo "  sudo systemctl enable sddm.service"
echo "Rollback: sudo systemctl disable sddm.service && sudo systemctl enable gdm.service"
read -p "Really replace the display manager now? [y/N] " ans4
if [[ "$ans4" == "y" || "$ans4" == "Y" ]]; then
    sudo systemctl disable gdm.service || true
    sudo systemctl enable sddm.service
    echo "Reboot to see it live (or: sudo systemctl isolate multi-user.target && sudo systemctl isolate graphical.target)."
fi

echo
echo "Stage 4 (extra) done. See README 'Validation checklist' for what to check after reboot."
