#!/usr/bin/env bash
# Stage 4 (optional extra): SDDM login-screen theming, styled to match
# hyprveil, using SDDM's own Wayland (Weston-backed) greeter instead of X11.
# install.sh offers to run this as a separately confirmed final
# step because it changes the SYSTEM display manager for every login, not just
# Hyprland's. Review before running — every sudo/system-wide step is gated
# separately, and step 4 (making sddm the display manager) is the only one that
# actually changes what you see at your next login.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"
THEME_SRC="$REPO/config/sddm/hyprveil"
THEME_DST="/usr/share/sddm/themes/hyprveil"

hv_load_fedora
hv_check_supported_release || true
hv_show_enabled_repos

echo "== Step 0: preview the theme — installs/changes nothing =="
echo "  sddm-greeter-qt6 --test-mode --theme \"$THEME_SRC\""
echo "  (the installed package determines whether the binary has a qt6 suffix)"
if hv_confirm_no "Run the preview now?"; then
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
echo "issue with it (sddm#2142) — see docs/HARDWARE.md."
gpu=$(awk -F= '$1 == "gpu" {print $2}' "$HV_STATE_HOME/hardware-profile.conf" 2>/dev/null || true)
if [[ "$gpu" != intel && "$gpu" != amd && "$gpu" != nvidia ]]; then
    echo "No valid saved GPU path exists; select one before choosing an SDDM backend."
    "$REPO/scripts/06-select-profile.sh"
    gpu=$(awk -F= '$1 == "gpu" {print $2}' "$HV_STATE_HOME/hardware-profile.conf")
fi
if [ "$gpu" = nvidia ]; then
    PKGS="sddm sddm-x11"
    echo "Saved NVIDIA profile detected; selecting the X11 greeter package."
else
    PKGS="sddm sddm-wayland-generic"
    echo "Saved ${gpu:-unselected} GPU profile; selecting Fedora's Wayland greeter package."
fi
# shellcheck disable=SC2086
hv_install_group optional "SDDM login manager" - $PKGS

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
echo "  existing theme is timestamp-backed-up, then replaced cleanly"
echo "  + download Geist Light/Regular into $THEME_DST/Fonts (the greeter runs as"
echo "    the 'sddm' system user, which can't see ~/.local/share/fonts)"
if hv_confirm_no "Back up and install the system theme now?"; then
    if [ -e "$THEME_DST" ]; then
        backup=$(hv_new_backup_dir)
        mkdir -p "$backup/system-themes"
        hv_root cp -a "$THEME_DST" "$backup/system-themes/hyprveil"
        echo "Existing SDDM theme backed up to $backup/system-themes/hyprveil"
    fi
    hv_root rm -rf "$THEME_DST"
    hv_root cp -a "$THEME_SRC" "$THEME_DST"
    hv_root mkdir -p "$THEME_DST/Fonts"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT
    if curl -fL "https://github.com/vercel/geist-font/releases/download/v1.7.2/geist-font-v1.7.2.zip" -o "$TMP/geist.zip"; then
        unzip -o -j "$TMP/geist.zip" \
            "geist-font/Geist/ttf/Geist-Light.ttf" \
            "geist-font/Geist/ttf/Geist-Regular.ttf" \
            -d "$TMP/fonts" \
            && hv_root cp "$TMP/fonts/Geist-Light.ttf" "$TMP/fonts/Geist-Regular.ttf" "$THEME_DST/Fonts/" \
            || echo "Geist zip layout unexpected — copy Geist-Light.ttf + Geist-Regular.ttf into $THEME_DST/Fonts/ manually from https://vercel.com/font"
    else
        echo "Geist download failed — copy Geist-Light.ttf + Geist-Regular.ttf into $THEME_DST/Fonts/ manually from https://vercel.com/font"
    fi
fi

echo
echo "== Step 2b: render the current wallpaper into the greeter backdrop =="
echo "  $REPO/config/hypr/scripts/sddm-backdrop.sh render"
echo "The greeter runs as the 'sddm' system user and \$HOME is 0700, so it cannot"
echo "read ~/Pictures/Wallpapers directly — a blurred copy is baked into the theme"
echo "instead. Skipping this is harmless: the greeter falls back to flat dark."
echo "Re-run that command yourself after changing wallpaper to refresh it."
if hv_confirm_no "Render the backdrop now?"; then
    "$REPO/config/hypr/scripts/sddm-backdrop.sh" render \
        || echo "Backdrop render failed — the greeter will use the flat dark background."
fi

echo
echo "== Step 3: point sddm at the theme — writes /etc/sddm.conf.d/hyprveil.conf (sudo) =="
echo "  [Theme]"
echo "  Current=hyprveil"
if hv_confirm_no "Back up and write the SDDM theme selection?"; then
    if [ -e /etc/sddm.conf.d/hyprveil.conf ]; then
        backup=$(hv_new_backup_dir)
        mkdir -p "$backup/system-config"
        hv_root cp -a /etc/sddm.conf.d/hyprveil.conf "$backup/system-config/hyprveil.conf"
        echo "Existing selection backed up to $backup/system-config/hyprveil.conf"
    fi
    hv_root mkdir -p /etc/sddm.conf.d
    printf '[Theme]\nCurrent=hyprveil\n' | hv_root tee /etc/sddm.conf.d/hyprveil.conf >/dev/null
fi

echo
echo "== Step 4: make sddm the display manager (sudo) =="
echo "THIS REPLACES YOUR CURRENT DISPLAY MANAGER (likely GDM on Fedora Workstation)"
echo "for ALL logins on this machine, not just Hyprland."
echo "  sudo systemctl disable gdm.service"
echo "  sudo systemctl enable sddm.service"
echo "Rollback: sudo systemctl disable sddm.service && sudo systemctl enable gdm.service"
if hv_confirm_no "Really replace the display manager now?"; then
    hv_root systemctl disable gdm.service || true
    hv_root systemctl enable sddm.service
    echo "Reboot to see it live (or: sudo systemctl isolate multi-user.target && sudo systemctl isolate graphical.target)."
fi

echo
echo "Stage 4 (extra) done. See README 'Validation checklist' for what to check after reboot."
