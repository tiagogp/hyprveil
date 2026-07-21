#!/usr/bin/env bash
# Stage 2: Fedora-aware shell, utility, font, and wallpaper installation.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

hv_section "Stage 2: Fedora and repository detection"
hv_load_fedora
hv_check_supported_release || true
hv_show_enabled_repos

STAGE_FAIL=0
hv_install_group required "Fedora desktop shell" - \
    waybar rofi-wayland wlogout gnome-control-center fira-code-fonts papirus-icon-theme || STAGE_FAIL=1

hv_section "Notification + quick-settings backend"
# Quickshell is the default: it draws the bar, dock, and quick-settings panel and
# also serves notifications (popups, history, DND). SwayNC and Mako remain
# notification-only fallbacks for systems where the Quickshell COPR is declined
# or unavailable.

install_swaync_or_mako() {
    # Shared fallback path when Quickshell is unavailable or declined.
    echo "SwayNC provides popup history, clear-all, and persistent do-not-disturb."
    hv_install_group optional "SwayNC notification center" \
        "erikreider/SwayNotificationCenter" SwayNotificationCenter
    # Gate on the installed package, not a stray swaync binary on PATH, so a
    # declined COPR reliably falls through to the Mako fallback.
    if command -v rpm >/dev/null 2>&1 && rpm -q SwayNotificationCenter >/dev/null 2>&1; then
        "$REPO/scripts/07-select-notification-backend.sh" --backend swaync
    else
        hv_warn "SwayNC was not installed; preserving notifications with the official Mako fallback"
        hv_install_group required "Mako notification fallback" - mako || STAGE_FAIL=1
        "$REPO/scripts/07-select-notification-backend.sh" --backend mako
    fi
}

saved_backend=$(hv_notification_backend || true)
case "$saved_backend" in
    quickshell)
        echo "Keeping saved Quickshell shell + notifications backend."
        hv_install_group required "Quickshell shell (bar, dock, notifications)" \
            "errornointernet/quickshell" quickshell || STAGE_FAIL=1
        "$REPO/scripts/07-select-notification-backend.sh" --ensure
        ;;
    mako)
        echo "Keeping saved Mako fallback; the Quickshell/SwayNC COPRs will not be offered on this rerun."
        hv_install_group required "Mako notification fallback" - mako || STAGE_FAIL=1
        "$REPO/scripts/07-select-notification-backend.sh" --ensure
        ;;
    swaync)
        echo "Keeping saved SwayNC backend."
        hv_install_group required "SwayNC notification center" \
            "erikreider/SwayNotificationCenter" SwayNotificationCenter || STAGE_FAIL=1
        "$REPO/scripts/07-select-notification-backend.sh" --ensure
        ;;
    *)
        echo "Quickshell draws the bar, dock, and quick-settings panel (Wi-Fi/Bluetooth) and serves notifications (popups, history, DND)."
        hv_install_group optional "Quickshell shell (bar, dock, notifications)" \
            "errornointernet/quickshell" quickshell
        # Gate on the package we tried to install, not any `quickshell` binary
        # already on PATH — a stray/older build must not mask a declined or
        # failed COPR install.
        if command -v rpm >/dev/null 2>&1 && rpm -q quickshell >/dev/null 2>&1; then
            "$REPO/scripts/07-select-notification-backend.sh" --backend quickshell
        else
            hv_warn "Quickshell was not installed; falling back to the SwayNC notification center"
            install_swaync_or_mako
        fi
        ;;
esac

hv_install_group required "Hyprland lock, idle, and wallpaper services" "solopasha/hyprland" \
    hyprlock hypridle hyprpaper || STAGE_FAIL=1

hv_install_group optional "color picker shortcut" "solopasha/hyprland" hyprpicker

hv_install_group optional "Bluetooth status and manager" - bluez blueman

hv_install_group required "Waybar helper and desktop-entry dock runtime" - jq util-linux glib2

hv_install_group optional "screenshots, clipboard, media, brightness, and OCR" - \
    grim slurp cliphist wl-clipboard playerctl brightnessctl btop rofimoji tesseract ImageMagick

hv_section "Fonts: Geist and Nerd Font symbols (user-local)"
if hv_confirm "Download and install the user-local fonts?"; then
    FONTDIR="$HOME/.local/share/fonts"
    mkdir -p "$FONTDIR"
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    if curl -fL "https://github.com/vercel/geist-font/releases/download/v1.7.2/geist-font-v1.7.2.zip" -o "$TMP/geist.zip"; then
        mkdir -p "$TMP/geist"
        if unzip -o -j "$TMP/geist.zip" "geist-font/Geist/ttf/*.ttf" -d "$TMP/geist"; then
            if [ -e "$FONTDIR/geist" ]; then
                backup=$(hv_new_backup_dir)
                hv_backup_item "$FONTDIR/geist" "$backup/fonts"
            fi
            rm -rf "$FONTDIR/geist"
            mv "$TMP/geist" "$FONTDIR/geist"
        else
            hv_warn "Geist archive layout changed; see https://vercel.com/font"
        fi
    else
        hv_warn "Geist download failed; the desktop will use its fallback UI font"
    fi
    if curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip" -o "$TMP/nerd.zip"; then
        mkdir -p "$TMP/nerd-symbols"
        if unzip -o -j "$TMP/nerd.zip" "*.ttf" -d "$TMP/nerd-symbols"; then
            if [ -e "$FONTDIR/nerd-symbols" ]; then
                backup=$(hv_new_backup_dir)
                hv_backup_item "$FONTDIR/nerd-symbols" "$backup/fonts"
            fi
            rm -rf "$FONTDIR/nerd-symbols"
            mv "$TMP/nerd-symbols" "$FONTDIR/nerd-symbols"
        fi
    else
        hv_warn "Nerd symbols download failed; bar icons may render as boxes"
    fi
    command -v fc-cache >/dev/null && fc-cache -f
fi

hv_section "Bundled fallback wallpaper"
mkdir -p "$HV_CONFIG_HOME/hypr"
wallpaper_tmp=$(mktemp "$HV_CONFIG_HOME/hypr/.wallpaper-default.XXXXXX")
cp -a "$REPO/config/hypr/wallpaper-default.jpg" \
    "$wallpaper_tmp"
mv -f "$wallpaper_tmp" "$HV_CONFIG_HOME/hypr/wallpaper-default.jpg"
echo "Installed $HV_CONFIG_HOME/hypr/wallpaper-default.jpg; saved wallpaper choices remain unchanged."

echo
hv_ok "Stage 2 complete. Package choices were recorded in $HV_SOURCE_LOG"
exit "$STAGE_FAIL"
