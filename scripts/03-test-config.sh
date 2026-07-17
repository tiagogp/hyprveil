#!/usr/bin/env bash
# Test the hyprveil configs BEFORE installing anything into ~/.config.
#
# Two phases:
#   1. Static checks — always run: config files present, waybar JSON valid,
#      required commands installed, fonts available, Hyprland parse check
#      (--verify-config, if your Hyprland build supports it).
#   2. Nested test — only when run from inside a Wayland session: boots
#      Hyprland in a window using THIS repo's configs via a staged
#      XDG_CONFIG_HOME. Your real ~/.config (e.g. end-4) is never touched.
#
# Run from the repo root: ./scripts/03-test-config.sh
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$REPO/config"
FAIL=0

ok()   { printf '  \033[32mOK\033[0m   %s\n' "$1"; }
warn() { printf '  \033[33mWARN\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=1; }

echo "== Phase 1: static checks =="

# --- config files exist ---
for f in hypr/hyprland.conf hypr/colors.conf hypr/variables.conf hypr/monitors.conf \
         hypr/appearance.conf hypr/animations.conf hypr/window-rules.conf \
         hypr/keybindings.conf hypr/autostart.conf hypr/hyprlock.conf \
         hypr/hypridle.conf hypr/hyprpaper.conf hypr/scripts/zoom.sh \
         hypr/scripts/apply-theme.sh \
         waybar/config.jsonc waybar/style.css kitty/kitty.conf \
         rofi/config.rasi rofi/hyprveil.rasi mako/config \
         wlogout/layout wlogout/style.css \
         gtk-3.0/settings.ini gtk-3.0/gtk.css gtk-4.0/settings.ini gtk-4.0/gtk.css \
         qt5ct/qt5ct.conf qt5ct/colors/hyprveil.conf \
         qt6ct/qt6ct.conf qt6ct/colors/hyprveil.conf \
         starship.toml zsh/.zshrc; do
    [ -f "$CONF/$f" ] && ok "config/$f" || bad "missing config/$f"
done

# --- waybar JSON (strip // comments) + wlogout layout ---
if command -v python3 >/dev/null; then
    python3 - "$CONF" <<'PY' && ok "waybar config.jsonc + wlogout layout parse as JSON" || bad "JSON error in waybar config or wlogout layout (see above)"
import json, re, sys
conf = sys.argv[1]
src = re.sub(r'^\s*//.*$', '', open(f'{conf}/waybar/config.jsonc').read(), flags=re.M)
json.loads(src)
for line in open(f'{conf}/wlogout/layout'):
    if line.strip():
        json.loads(line)
PY
else
    warn "python3 not found — skipped JSON validation"
fi

# --- commands the configs call ---
NEEDED="hyprctl kitty waybar rofi mako makoctl hyprlock hypridle hyprpaper wlogout grim slurp wl-copy cliphist playerctl hyprpicker jq"
OPTIONAL="rofimoji tesseract brightnessctl nautilus firefox code btop zsh starship qt6ct gsettings"
for c in $NEEDED; do
    command -v "$c" >/dev/null && ok "command: $c" || bad "command missing: $c (scripts/01 + 02 install these)"
done
for c in $OPTIONAL; do
    command -v "$c" >/dev/null || warn "optional command missing: $c"
done

# --- fonts ---
if command -v fc-list >/dev/null; then
    fc-list | grep -qi "geist"        && ok "font: Geist"        || warn "font Geist not installed (script 02 fonts step)"
    fc-list | grep -qi "fira code"    && ok "font: Fira Code"    || warn "font Fira Code not installed"
    fc-list | grep -qi "symbols nerd" && ok "font: Nerd symbols" || warn "Nerd symbols font missing — bar/launcher icons will be boxes"
fi

# --- wallpaper ---
[ -f "$HOME/.config/hypr/wallpaper.jpg" ] \
    && ok "wallpaper present at ~/.config/hypr/wallpaper.jpg" \
    || warn "no wallpaper yet (script 02 downloads it) — hyprpaper will just log an error"

# --- Hyprland parse check on a staged copy (also used by phase 2) ---
stage_configs() {
    STAGE="$(mktemp -d /tmp/hyprveil-test.XXXXXX)"
    cp -r "$CONF/." "$STAGE/"
    # repo configs reference ~/.config/hypr — point them at the stage instead
    sed -i "s|~/.config/hypr|$STAGE/hypr|g" "$STAGE/hypr/hyprland.conf" "$STAGE/hypr/keybindings.conf" "$STAGE/hypr/autostart.conf" 2>/dev/null
    sed -i "s|~/.config/hypr/wallpaper.jpg|$STAGE/hypr/wallpaper.jpg|g" "$STAGE/hypr/hyprpaper.conf"
    [ -f "$HOME/.config/hypr/wallpaper.jpg" ] && cp "$HOME/.config/hypr/wallpaper.jpg" "$STAGE/hypr/wallpaper.jpg"
    chmod +x "$STAGE/hypr/scripts/"*.sh 2>/dev/null
}

if command -v Hyprland >/dev/null; then
    if Hyprland --help 2>&1 | grep -q -- "--verify-config"; then
        stage_configs
        if Hyprland --verify-config -c "$STAGE/hypr/hyprland.conf" >/tmp/hyprveil-verify.log 2>&1; then
            ok "Hyprland --verify-config: no parse errors"
        else
            bad "Hyprland config has errors — see /tmp/hyprveil-verify.log"
        fi
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
    echo "hyprveil in a window without touching your real config."
    exit 0
fi

echo
echo "== Phase 2: nested live test =="
echo "This boots Hyprland IN A WINDOW using the repo's configs (staged copy,"
echo "your ~/.config stays untouched). Exit the nested session with SUPER+SHIFT+Q."
read -p "Launch nested session now? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || exit 0

[ -n "${STAGE:-}" ] || stage_configs

# waybar/rofi/mako/kitty inside the nested session read the staged configs
export XDG_CONFIG_HOME="$STAGE"
echo "staged config: $STAGE (kept after exit for inspection; rm -rf it when done)"
Hyprland -c "$STAGE/hypr/hyprland.conf"
echo "Nested session ended. Logs above; staged config left at $STAGE"
