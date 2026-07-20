#!/usr/bin/env bash
# Test the hyprveil configs BEFORE installing anything into ~/.config.
#
# Two phases:
#   1. Static checks — always run: config files present, waybar JSON valid,
#      required commands installed, fonts available, Hyprland parse check
#      (--verify-config, if your Hyprland build supports it).
#   2. Nested test — only when run from inside a Wayland session: boots
#      Hyprland in a window with config, state, cache, data, home, and runtime
#      paths redirected to an isolated temporary tree.
#
# Run from the repo root: ./scripts/03-test-config.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$REPO/config"
FAIL=0
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=1; }

echo "== Phase 1: static checks =="

# --- Fedora and selected package sources ---
if hv_load_fedora; then
    ok "Fedora detected: $HV_OS_NAME"
    hv_check_supported_release || warn "release is outside the documented rolling support pair"
    if [ -s "$HV_SOURCE_LOG" ]; then
        ok "chosen package sources: $HV_SOURCE_LOG"
        while IFS=$'\t' read -r package source feature; do
            printf '       %-24s %-22s %s\n' "$package" "$source" "$feature"
        done < "$HV_SOURCE_LOG"
    else
        warn "no package sources recorded yet (run an installer stage or scripts/09-dependency-report.sh)"
    fi
else
    warn "not running on Fedora; package-source validation is unavailable"
fi

# --- config files exist ---
for f in hypr/hyprland.conf hypr/colors.conf hypr/variables.conf hypr/monitors.conf \
         hypr/appearance.conf hypr/animations.conf hypr/window-rules.conf \
         hypr/keybindings.conf hypr/autostart.conf hypr/hyprlock.conf \
         hypr/hypridle.conf hypr/hyprpaper.conf hypr/scripts/zoom.sh \
         hypr/scripts/apply-theme.sh \
         hypr/scripts/hardware-action.sh hypr/scripts/notification-daemon.sh \
         hypr/scripts/wallpaper.sh hypr/scripts/motion-profile.sh \
         hypr/scripts/lib/render-lib.sh \
         hypr/tokens.conf hypr/scripts/accent.sh hypr/scripts/theme.sh \
         hypr/scripts/lock.sh hypr/scripts/dock-manager.sh hypr/scripts/dock-lib.sh \
         hypr/motion/active.conf hypr/motion/standard.conf hypr/motion/reduced.conf \
         hypr/profiles/active.conf hypr/profiles/form-factor/generic.conf \
         hypr/profiles/form-factor/desktop.conf \
         hypr/profiles/form-factor/laptop.conf hypr/profiles/gpu/generic.conf \
         hypr/profiles/gpu/intel.conf hypr/profiles/gpu/amd.conf hypr/profiles/gpu/nvidia.conf \
         waybar/config.jsonc waybar/style.css waybar/scripts/dock.sh \
         waybar/scripts/dock-watch.sh waybar/scripts/dock-icons.json \
         waybar/scripts/battery.sh waybar/scripts/bluetooth.sh waybar/scripts/media.sh \
         waybar/scripts/notification.sh waybar/accent.css \
         kitty/kitty.conf kitty/accent.conf \
         rofi/config.rasi rofi/hyprveil.rasi rofi/accent.rasi swaync/config.json swaync/style.css swaync/accent.css \
         swaync/style.css.in wlogout/style.css.in quickshell/Tokens.qml.in quickshell/Tokens.qml \
         ags/app.ts ags/style.scss ags/_accent.scss ags/tsconfig.json ags/widget/QuickSettings.tsx \
         ags/widget/Wifi.tsx ags/widget/Bluetooth.tsx ags/widget/Notifications.tsx \
         ags/widget/NotificationPopups.tsx \
         wlogout/layout wlogout/style.css wlogout/accent.css \
         gtk-3.0/settings.ini gtk-3.0/gtk.css gtk-3.0/accent.css gtk-4.0/settings.ini gtk-4.0/gtk.css gtk-4.0/accent.css \
         qt5ct/qt5ct.conf qt5ct/colors/hyprveil.conf \
         qt6ct/qt6ct.conf qt6ct/colors/hyprveil.conf \
         starship.toml zsh/.zshrc; do
    if [ -f "$CONF/$f" ]; then
        ok "config/$f"
    else
        bad "missing config/$f"
    fi
done

# --- waybar JSON (strip // comments) + wlogout layout ---
if command -v python3 >/dev/null; then
if python3 - "$CONF" <<'PY'
import json, re, sys
conf = sys.argv[1]
src = re.sub(r'^\s*//.*$', '', open(f'{conf}/waybar/config.jsonc').read(), flags=re.M)
json.loads(src)
json.load(open(f'{conf}/swaync/config.json'))
json.load(open(f'{conf}/waybar/scripts/dock-icons.json'))
for line in open(f'{conf}/wlogout/layout'):
    if line.strip():
        json.loads(line)
PY
then
    ok "Waybar, SwayNC, dock icons, and wlogout configs parse as JSON"
else
    bad "JSON error in Waybar, SwayNC, dock icons, or wlogout config (see above)"
fi
else
    warn "python3 not found — skipped JSON validation"
fi

# --- executable entrypoints ---
while IFS= read -r script; do
    if [ -x "$script" ]; then
        ok "executable: ${script#"$REPO/"}"
    else
        bad "script is not executable: ${script#"$REPO/"}"
    fi
done < <(find "$REPO/scripts" "$REPO/tests" "$CONF" -type f -name '*.sh' -print | sort)

# --- commands the configs call ---
# hyprlock stays required even under Quickshell: it is the lock fallback that
# hypr/scripts/lock.sh drops to whenever the shell cannot be confirmed.
NEEDED="hyprctl kitty rofi hyprlock hypridle hyprpaper wlogout jq flock gio"
OPTIONAL="grim slurp wl-copy cliphist playerctl bluetoothctl blueman-manager hyprpicker rofimoji tesseract brightnessctl nautilus firefox code btop zsh starship qt6ct gsettings"
notification_backend=$(hv_notification_backend || true)
case "$notification_backend" in
    quickshell) NEEDED="$NEEDED quickshell qs" ;;
    ags) NEEDED="$NEEDED ags sass" ;;
    swaync) NEEDED="$NEEDED swaync swaync-client" ;;
    mako)
        NEEDED="$NEEDED mako makoctl"
        if [ -f "$CONF/mako/config" ]; then
            ok "config/mako/config"
        else
            bad "missing Mako fallback config"
        fi
        ;;
    *) warn "notification backend not selected (run scripts/07-select-notification-backend.sh)" ;;
esac
for c in $NEEDED; do
    if command -v "$c" >/dev/null; then
        ok "command: $c"
    else
        bad "command missing: $c (scripts/01 + 02 install these)"
    fi
done
for c in $OPTIONAL; do
    command -v "$c" >/dev/null || warn "optional command missing: $c"
done

# --- fonts ---
# Note: fc-list piped straight into `grep -q` can trip `pipefail` — grep exits
# as soon as it finds a match, and the SIGPIPE that hits fc-list becomes the
# pipeline's exit status even though the match succeeded. Capture output first.
if command -v fc-list >/dev/null; then
    FONT_LIST="$(fc-list)"
    if grep -qi "geist" <<<"$FONT_LIST"; then ok "font: Geist"; else warn "font Geist not installed (script 02 fonts step)"; fi
    if grep -qi "fira code" <<<"$FONT_LIST"; then ok "font: Fira Code"; else warn "font Fira Code not installed"; fi
    if grep -qi "symbols nerd" <<<"$FONT_LIST"; then ok "font: Nerd symbols"; else warn "Nerd symbols font missing — bar/launcher icons will be boxes"; fi
fi

# --- wallpaper and motion state ---
if [ -f "$HV_CONFIG_HOME/hypr/wallpaper-default.jpg" ]; then
    ok "bundled fallback wallpaper is installed"
else
    warn "bundled fallback is installed during deployment; repo validation uses the design asset"
fi
if [ -f "$HV_NOTIFICATION_STATE" ]; then
    if grep -Eq '^(quickshell|ags|swaync|mako)$' "$HV_NOTIFICATION_STATE"; then
        ok "notification backend state is valid"
    else
        bad "invalid notification backend state (run scripts/07-select-notification-backend.sh)"
    fi
fi
if [ -f "$HV_STATE_HOME/dock-pins.json" ]; then
    if jq -e 'type == "array" and length <= 10 and all(.[];
        type == "object" and (.app_id | type == "string" and length > 0) and
        ((.desktop_id == null) or (.desktop_id | type == "string")))' \
        "$HV_STATE_HOME/dock-pins.json" >/dev/null; then
        ok "dock state has the P1 schema"
    else
        bad "malformed dock state (run dock-manager.sh list to preserve and recover it)"
    fi
fi
if [ -f "$HV_STATE_HOME/wallpapers.json" ]; then
    if jq -e '.version == 1 and (.fallback | type == "object") and (.monitors | type == "object")' \
        "$HV_STATE_HOME/wallpapers.json" >/dev/null; then
        ok "wallpaper state has the P3 schema"
    else
        bad "malformed wallpaper state (run wallpaper.sh restore to preserve and recover it)"
    fi
fi
if [ -f "$HV_STATE_HOME/motion-profile" ]; then
    if grep -Eq '^(standard|reduced)$' "$HV_STATE_HOME/motion-profile"; then
        ok "motion profile state is valid"
    else
        bad "invalid motion profile state (run motion-profile.sh --ensure to recover it)"
    fi
fi

# --- Hyprland parse check on a staged copy (also used by phase 2) ---
stage_configs() {
    STAGE="$(mktemp -d /tmp/hyprveil-test.XXXXXX)"
    cp -r "$CONF/." "$STAGE/"
    # repo configs reference ~/.config/hypr — point them at the stage instead
    while IFS= read -r file; do
        sed -i "s|~/.config/hypr|$STAGE/hypr|g" "$file"
    done < <(find "$STAGE/hypr" -type f -name '*.conf')
    cp "$REPO/design/Custom Hyprland Desktop Environment/uploads/elliott-engelmann-DjlKxYFJlTc-unsplash.jpg" \
        "$STAGE/hypr/wallpaper-default.jpg"
    [ -f "$HOME/.config/hypr/wallpaper.jpg" ] && cp "$HOME/.config/hypr/wallpaper.jpg" "$STAGE/hypr/wallpaper.jpg"
    chmod +x "$STAGE/hypr/scripts/"*.sh 2>/dev/null
    chmod +x "$STAGE/waybar/scripts/"*.sh 2>/dev/null
}

if command -v Hyprland >/dev/null; then
    if Hyprland --help 2>&1 | grep -q -- "--verify-config"; then
        stage_configs
        if Hyprland --verify-config -c "$STAGE/hypr/hyprland.conf" >/tmp/hyprveil-verify.log 2>&1; then
            ok "Hyprland --verify-config: no parse errors"
        else
            bad "Hyprland config has errors — see /tmp/hyprveil-verify.log"
        fi
        rm -rf "${STAGE:?}"
        unset STAGE
    else
        warn "this Hyprland build has no --verify-config; parse errors will show on nested launch instead"
    fi
else
    warn "Hyprland not installed on this machine — static file checks only"
fi

echo
if [ "$FAIL" -ne 0 ]; then
    echo "Static checks FAILED — fix the items above before a live test."
    exit 1
fi
echo "Static checks passed."

# == Phase 2: nested live test ==
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    echo "Not inside a Wayland session — skipping the nested live test."
    echo "Log into any Wayland desktop (your current one is fine) and re-run to boot"
    echo "hyprveil in a window without touching your real config or state."
    exit 0
fi

echo
echo "== Phase 2: nested live test =="
echo "This boots Hyprland IN A WINDOW using isolated config and state paths."
echo "Your real home and XDG directories stay untouched. Exit with SUPER+SHIFT+Q."
read -r -p "Launch nested session now? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || exit 0

"$REPO/scripts/08-test-nested-session.sh" --backend "${notification_backend:-swaync}" --keep-stage
echo "Nested session ended. The isolated stage path is shown above for inspection."

echo
if hv_confirm "Looked right? Back up and replace the managed configs now?"; then
    hv_deploy_configs
    if [ -f "$HV_STATE_HOME/hardware-profile.conf" ]; then
        "$REPO/scripts/06-select-profile.sh" --ensure
    else
        "$REPO/scripts/06-select-profile.sh"
    fi
    if [ -f "$HV_NOTIFICATION_STATE" ]; then
        "$REPO/scripts/07-select-notification-backend.sh" --ensure
    else
        "$REPO/scripts/07-select-notification-backend.sh"
    fi
    "$HV_CONFIG_HOME/hypr/scripts/motion-profile.sh" --ensure
    echo "Installed to $HV_CONFIG_HOME. Reload with: hyprctl reload && pkill waybar; waybar & disown"
else
    echo "Skipped. Re-run this script or install.sh when ready."
fi
