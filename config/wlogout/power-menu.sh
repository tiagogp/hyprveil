#!/usr/bin/env sh
set -eu

buttons=5
button_size=56
column_gap=28
row_height=96

screen_width=1920
screen_height=1080

monitor_size=$(
  hyprctl monitors 2>/dev/null |
    awk '
      /^Monitor / { in_block = 1; width = ""; height = ""; scale = 1 }
      in_block && match($0, /[0-9]+x[0-9]+@/) {
        split(substr($0, RSTART, RLENGTH - 1), size, "x")
        width = size[1]
        height = size[2]
      }
      in_block && /scale:/ {
        scale = $2 + 0
        if (scale <= 0) scale = 1
      }
      in_block && /focused: yes/ {
        if (width != "" && height != "") {
          print int(width / scale) " " int(height / scale)
          exit
        }
      }
    '
)

if [ -n "$monitor_size" ]; then
  set -- $monitor_size
  screen_width=$1
  screen_height=$2
fi

strip_width=$((buttons * button_size + (buttons - 1) * column_gap))
margin_x=$(((screen_width - strip_width) / 2))
margin_y=$(((screen_height - row_height) / 2))

[ "$margin_x" -lt 0 ] && margin_x=0
[ "$margin_y" -lt 0 ] && margin_y=0

pkill wlogout 2>/dev/null && exit 0

exec wlogout \
  --buttons-per-row "$buttons" \
  --column-spacing "$column_gap" \
  --row-spacing 0 \
  --margin-left "$margin_x" \
  --margin-right "$margin_x" \
  --margin-top "$margin_y" \
  --margin-bottom "$margin_y"
