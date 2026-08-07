#!/usr/bin/env bash
# The capability doctor: one script, two callers.
#
# Run directly (`doctor.sh`) it is Silere's check.sh idea — a human-readable
# report of every OPTIONAL integration Hyprveil can use, what state it is in,
# and the one command that would fix it. Run as `doctor.sh --json` it is the
# same data for Services/Capabilities.qml's "Sistema > Integrações" panel, so
# the script stays the single source of truth for what "available" means
# rather than the shell re-implementing each probe in QML.
#
# A missing OPTIONAL dependency is not a failure — the exit code only reflects
# whether the report itself could be produced, matching this file's job
# (report state), not install.sh's (make state correct).
set -uo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

# id|label|available(0/1)|degraded(0/1)|hint
checks=()

add() {
    checks+=("$1|$2|$3|$4|$5")
}

# --- Backlight -------------------------------------------------------------
if have brightnessctl; then
    shopt -s nullglob
    backlights=("${HYPRVEIL_SYSFS_ROOT:-/sys}"/class/backlight/*)
    if [ "${#backlights[@]}" -gt 0 ]; then
        add backlight "Backlight brightness" 1 0 ""
    else
        add backlight "Backlight brightness" 0 0 "No /sys/class/backlight device — expected on desktops without an eDP panel"
    fi
else
    add backlight "Backlight brightness" 0 0 "sudo dnf install brightnessctl"
fi

# --- DDC (external monitor brightness) -------------------------------------
if have ddcutil; then
    if ddcutil detect --brief >/dev/null 2>&1; then
        add ddc "External monitor brightness (DDC)" 1 0 ""
    else
        add ddc "External monitor brightness (DDC)" 0 0 "ddcutil installed but no display answered — check the i2c-dev kernel module is loaded"
    fi
else
    add ddc "External monitor brightness (DDC)" 0 0 "sudo dnf install ddcutil (and load the i2c-dev module)"
fi

# --- Bluetooth ---------------------------------------------------------------
if have bluetoothctl; then
    add bluetooth "Bluetooth" 1 0 ""
else
    add bluetooth "Bluetooth" 0 0 "sudo dnf install bluez bluez-utils"
fi

# --- Night light -------------------------------------------------------------
if have hyprsunset; then
    add nightlight "Night light" 1 0 ""
else
    add nightlight "Night light" 0 0 "sudo dnf install hyprsunset"
fi

# --- Power profiles ------------------------------------------------------
if have powerprofilesctl; then
    add powerprofiles "Power profiles" 1 0 ""
else
    add powerprofiles "Power profiles" 0 0 "sudo dnf install power-profiles-daemon"
fi

# --- Clipboard -----------------------------------------------------------
if have cliphist && have wl-copy; then
    add clipboard "Clipboard history" 1 0 ""
elif have wl-copy; then
    add clipboard "Clipboard history" 0 1 "sudo dnf install cliphist (wl-clipboard is already present)"
else
    add clipboard "Clipboard history" 0 0 "sudo dnf install cliphist wl-clipboard"
fi

# --- Screenshot / OCR ------------------------------------------------------
if have grim && have slurp; then
    add screenshot "Screenshot / region capture" 1 0 ""
else
    add screenshot "Screenshot / region capture" 0 0 "sudo dnf install grim slurp"
fi
if have tesseract; then
    add ocr "Screenshot OCR" 1 0 ""
else
    add ocr "Screenshot OCR" 0 0 "sudo dnf install tesseract"
fi

# --- Wallpaper-derived accent (Matugen, optional alternative provider) -----
if have matugen; then
    add matugen "Matugen (optional accent provider)" 1 0 ""
else
    add matugen "Matugen (optional accent provider)" 0 0 "cargo install matugen — optional; Hyprveil's own accent algorithm is the default and needs nothing"
fi

# --- Calendar events (EDS) --------------------------------------------------
if have gdbus && gdbus call --session \
        --dest org.gnome.evolution.dataserver.Calendar8 \
        --object-path /org/gnome/evolution/dataserver/CalendarFactory \
        --method org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
    add calendar-events "Calendar events (EDS)" 1 0 ""
else
    add calendar-events "Calendar events (EDS)" 0 0 "sudo dnf install evolution-data-server; add an account in gnome-online-accounts"
fi

# --- Notification backend ---------------------------------------------------
if pgrep -x quickshell >/dev/null 2>&1 || pgrep -x qs >/dev/null 2>&1; then
    add notifications "Notification backend" 1 0 ""
else
    add notifications "Notification backend" 0 0 "$HOME/.config/hypr/scripts/notification-daemon.sh start"
fi

emit_text() {
    local id label available degraded hint status
    printf 'Hyprveil doctor — optional integrations\n\n'
    for row in "${checks[@]}"; do
        IFS='|' read -r id label available degraded hint <<<"$row"
        if [ "$available" = 1 ]; then status="available"
        elif [ "$degraded" = 1 ]; then status="degraded"
        else status="missing"; fi
        printf '[%-9s] %s\n' "$status" "$label"
        [ -z "$hint" ] || printf '            %s\n' "$hint"
    done
}

emit_json() {
    local id label available degraded hint first=1
    printf '['
    for row in "${checks[@]}"; do
        IFS='|' read -r id label available degraded hint <<<"$row"
        [ "$first" = 1 ] || printf ','
        first=0
        printf '{"id":"%s","label":"%s","available":%s,"degraded":%s,"hint":"%s"}' \
            "$id" "$label" \
            "$([ "$available" = 1 ] && echo true || echo false)" \
            "$([ "$degraded" = 1 ] && echo true || echo false)" \
            "$(printf '%s' "$hint" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    done
    printf ']\n'
}

case "${1:-}" in
    --json) emit_json ;;
    *)      emit_text ;;
esac
