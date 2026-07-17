#!/usr/bin/env bash
# Screen zoom stepper (ported from end-4's lua zoomfunction): clamps 1.0–3.0.
# Usage: zoom.sh 0.3 | zoom.sh -0.3
set -euo pipefail

cur=$(hyprctl getoption cursor:zoom_factor -j | jq '.float')
new=$(awk -v c="$cur" -v d="$1" 'BEGIN { n = c + d; if (n < 1) n = 1; if (n > 3) n = 3; print n }')
hyprctl keyword cursor:zoom_factor "$new"
