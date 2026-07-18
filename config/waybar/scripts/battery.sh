#!/usr/bin/env bash
# Render the first real system battery, or render nothing when none exists.
set -euo pipefail
shopt -s nullglob

batteries=("${HYPRVEIL_SYSFS_ROOT:-/sys}"/class/power_supply/BAT*)
[ "${#batteries[@]}" -gt 0 ] || { printf '{"text":"","tooltip":"","class":"absent"}\n'; exit 0; }
battery=${batteries[0]}
[ -r "$battery/capacity" ] || { printf '{"text":"","tooltip":"","class":"absent"}\n'; exit 0; }

capacity=$(<"$battery/capacity")
if [ -r "$battery/status" ]; then status=$(<"$battery/status"); else status=Unknown; fi
case "$status" in
    Charging) icon='󰂄' class=charging ;;
    Full) icon='󰁹' class=full ;;
    *)
        if [ "$capacity" -le 10 ]; then class=critical
        elif [ "$capacity" -le 20 ]; then class=warning
        else class=discharging
        fi
        if [ "$capacity" -le 10 ]; then icon='󰁺'
        elif [ "$capacity" -le 30 ]; then icon='󰁼'
        elif [ "$capacity" -le 60 ]; then icon='󰁾'
        elif [ "$capacity" -le 85 ]; then icon='󰂀'
        else icon='󰁹'
        fi
        ;;
esac
printf '{"text":"%s %s%%","tooltip":"Battery: %s%% (%s)","class":"%s"}\n' \
    "$icon" "$capacity" "$capacity" "$status" "$class"
