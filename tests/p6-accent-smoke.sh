#!/usr/bin/env bash
# Mocked, non-root checks for the wallpaper-derived accent: extraction scoring,
# fragment rendering across every consumer, state handling, and the live-reload
# fan-out. No Wayland session, ImageMagick, or dart-sass install is required;
# mock `magick`/`sass`/`ags` stand in for them.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p6.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

export HOME="$TMP/home"
export HYPRVEIL_STATE_HOME="$TMP/state"
export HYPRVEIL_CONFIG_HOME="$TMP/config"
export MOCK_ROOT="$TMP"
mkdir -p "$HOME" "$HYPRVEIL_STATE_HOME" "$TMP/bin"
export PATH="$TMP/bin:$PATH"

ACCENT="$REPO/config/hypr/scripts/accent.sh"
DEFAULT_ACCENT="#e14658"
DEFAULT_HOVER="#e86a79"

# The real config tree, so rendering writes into the same layout it does on a
# deployed system: write_if_changed skips any target whose directory is absent,
# and the templated consumers need their .in files present.
for name in hypr ags waybar swaync wlogout gtk-3.0 gtk-4.0 rofi kitty mako qt5ct qt6ct quickshell; do
    [ -d "$REPO/config/$name" ] || fail "missing managed config tree: config/$name"
    mkdir -p "$HYPRVEIL_CONFIG_HOME/$name"
    cp -a "$REPO/config/$name/." "$HYPRVEIL_CONFIG_HOME/$name/"
done

# --- mocks ---
# `magick IMG ... histogram:info:-` in the real -format %c shape. MOCK_IMAGE
# selects which canned image is being "read".
cat > "$TMP/bin/magick" <<'EOF'
#!/usr/bin/env bash
set -u
case "${MOCK_IMAGE:-vivid}" in
    vivid)
        # A dark background dominating by pixel share, plus a smaller vivid
        # blue region: the accent must come from the blue, not the majority.
        printf '  120000: ( 18, 20, 26) #12141A srgb(18,20,26)\n'
        printf '   40000: ( 59,130,246) #3B82F6 srgb(59,130,246)\n'
        printf '   20000: (240,240,242) #F0F0F2 srgb(240,240,242)\n'
        ;;
    grey)
        printf '  120000: ( 18, 18, 18) #121212 srgb(18,18,18)\n'
        printf '   60000: (128,129,128) #808180 srgb(128,129,128)\n'
        printf '   20000: (240,240,241) #F0F0F1 srgb(240,240,241)\n'
        ;;
    white)
        # The anchor case: $chrome-alpha is documented as exactly the alpha a
        # blown-out white strip demands, so this must solve to the ceiling.
        printf '  120000: (255,255,255) #FFFFFF srgb(255,255,255)\n'
        ;;
    dark)
        # Nothing bright anywhere: the chrome solve must reach its floor rather
        # than the ceiling, and the accent must still come out of the blue.
        printf '  120000: (  8,  9, 14) #08090E srgb(8,9,14)\n'
        printf '   40000: ( 40, 60, 96) #283C60 srgb(40,60,96)\n'
        ;;
    empty) ;;
esac
exit 0
EOF

cat > "$TMP/bin/sass" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$MOCK_ROOT/sass.log"
[ "${MOCK_SASS_FAIL:-0}" != 1 ] || exit 1
printf '/* compiled */\n' > "${*: -1}"
EOF

cat > "$TMP/bin/ags" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$MOCK_ROOT/ags.log"
[ "${1:-}" != list ] || printf 'hyprveil\n'
exit 0
EOF

# Everything the reload fan-out probes for. pgrep reports each daemon as running
# so the reload paths are actually taken rather than skipped.
cat > "$TMP/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$MOCK_ROOT/pgrep.log"
exit 0
EOF

for tool in pkill hyprctl swaync-client makoctl; do
    cat > "$TMP/bin/$tool" <<EOF
#!/usr/bin/env bash
set -u
printf '$tool %s\n' "\$*" >> "\$MOCK_ROOT/reload.log"
exit 0
EOF
done

chmod +x "$TMP/bin/"*
: > "$TMP/ags.log"
: > "$TMP/sass.log"
: > "$TMP/reload.log"

image="$TMP/wallpaper.jpg"
printf 'image\n' > "$image"

# --------------------------------------------------------------------------
# Extraction
# --------------------------------------------------------------------------
vivid=$(MOCK_IMAGE=vivid "$ACCENT" extract "$image")
[[ "$vivid" =~ ^#[0-9a-f]{6}$ ]] || fail "extract did not print a normalized hex: $vivid"
[ "$vivid" != "$DEFAULT_ACCENT" ] || fail "a vivid wallpaper did not move the accent"
# The blue region must win over the dark majority, and the result must land in
# the legibility band the scorer clamps to (S 0.45-0.85, L 0.52-0.68).
read -r r g b <<< "$(printf '%d %d %d\n' "0x${vivid:1:2}" "0x${vivid:3:2}" "0x${vivid:5:2}")"
[ "$b" -gt "$r" ] && [ "$b" -gt "$g" ] \
    || fail "extract did not pick the vivid blue region: $vivid"
[ "$((r + g + b))" -gt 200 ] || fail "extracted accent is too dark to read on #0f1115: $vivid"

grey=$(MOCK_IMAGE=grey "$ACCENT" extract "$image" 2> "$TMP/grey-warning")
[ "$grey" = "$DEFAULT_ACCENT" ] \
    || fail "a greyscale wallpaper invented a hue instead of keeping the design: $grey"
grep -q 'greyscale' "$TMP/grey-warning" || fail "the greyscale fallback was not explained"

emptyout=$(MOCK_IMAGE=empty "$ACCENT" extract "$image" 2>/dev/null)
[ "$emptyout" = "$DEFAULT_ACCENT" ] || fail "an unreadable image did not fall back to the design"
ok "extraction favors vivid regions over pixel share and keeps the design when there is no hue"

# --------------------------------------------------------------------------
# Rendering every consumer
# --------------------------------------------------------------------------
"$ACCENT" set '#3B82F6' >/dev/null
accent="#3b82f6"

jq -e --arg a "$accent" '.version == 1 and .accent == $a and .source == "manual" and .auto == true' \
    "$HYPRVEIL_STATE_HOME/accent.json" >/dev/null \
    || fail "set did not save normalized state"
[ "$(stat -c %a "$HYPRVEIL_STATE_HOME/accent.json")" = 600 ] \
    || fail "accent state permissions are not private"

C="$HYPRVEIL_CONFIG_HOME"
grep -q "rgba(3b82f6ff)" "$C/hypr/accent.conf" || fail "Hyprland fragment not rendered"
grep -q "rgba(3b82f626)" "$C/hypr/accent.conf" || fail "accent-soft not rendered for Hyprland"
for name in waybar swaync wlogout gtk-3.0 gtk-4.0; do
    grep -q "@define-color accent $accent;" "$C/$name/accent.css" \
        || fail "GTK CSS fragment not rendered for $name"
done
# libadwaita role names are what recolor stock GTK widgets.
grep -q "@define-color accent_bg_color $accent;" "$C/gtk-4.0/accent.css" \
    || fail "libadwaita accent roles not rendered"
grep -q "\$accent: $accent;" "$C/ags/_accent.scss" || fail "AGS Sass fragment not rendered"
# QML has no include mechanism for values, so the shell gets a generated
# singleton. Quickshell watches its config dir, so this write is also the reload.
grep -q "property color accent: *\"$accent\"" "$C/quickshell/Accent.qml" \
    || fail "Quickshell accent singleton not rendered"
grep -q "accent:     $accent;" "$C/rofi/accent.rasi" || fail "Rofi fragment not rendered"
grep -q "cursor                  $accent" "$C/kitty/accent.conf" || fail "Kitty fragment not rendered"
# Templated consumers have no include mechanism and are regenerated from .in.
grep -qi "3B82F6" "$C/mako/config" || fail "Mako config not rendered from template"
for dir in qt5ct qt6ct; do
    grep -q "3b82f6" "$C/$dir/colors/hyprveil.conf" || fail "$dir palette not rendered from template"
done
for name in lock logout reboot shutdown suspend; do
    grep -qi "3b82f6" "$C/wlogout/assets/$name-accent.svg" \
        || fail "wlogout $name icon not recolored"
done
grep -q '@accent' "$C/mako/config" && fail "an unsubstituted placeholder survived rendering"
ok "set renders the accent into every include-based and templated consumer"

# --------------------------------------------------------------------------
# Live reload fan-out
# --------------------------------------------------------------------------
# The AGS shell is also the notification daemon, so the accent is pushed as a
# recompiled stylesheet instead of a restart. This is the regression guard for
# the request handler: `reload-css` has to exist in app.ts to receive it.
compiled="$HYPRVEIL_STATE_HOME/ags-style.css"
grep -Fqx "request -i hyprveil reload-css $compiled" "$TMP/ags.log" \
    || fail "the compiled stylesheet was not pushed to the AGS shell"
grep -q 'case "reload-css":' "$REPO/config/ags/app.ts" \
    || fail "app.ts has no reload-css handler; the accent push is a silent no-op"
grep -q 'apply_css' "$REPO/config/ags/app.ts" \
    || fail "the reload-css handler does not apply the stylesheet it is handed"
grep -Fq "$C/ags/style.scss" "$TMP/sass.log" || fail "the AGS stylesheet was not compiled"
grep -Fqx 'hyprctl reload' "$TMP/reload.log" || fail "Hyprland was not reloaded"
grep -Fqx 'pkill -SIGUSR2 -x waybar' "$TMP/reload.log" || fail "Waybar was not signalled"
grep -Fqx 'swaync-client --reload-css' "$TMP/reload.log" || fail "SwayNC was not reloaded"
grep -Fqx 'makoctl reload' "$TMP/reload.log" || fail "Mako was not reloaded"
# A missing dart-sass must not take the rest of the fan-out down with it.
: > "$TMP/reload.log"
MOCK_SASS_FAIL=1 "$ACCENT" set '#22c55e' 2> "$TMP/sass-warning" >/dev/null
grep -q 'could not compile' "$TMP/sass-warning" || fail "a failed Sass compile was not explained"
grep -Fqx 'hyprctl reload' "$TMP/reload.log" \
    || fail "a failed Sass compile aborted the rest of the reload fan-out"
grep -q '@define-color accent #22c55e;' "$C/waybar/accent.css" \
    || fail "a failed Sass compile prevented the fragments from being written"
ok "applying an accent reloads every live component and survives a broken Sass toolchain"

# --------------------------------------------------------------------------
# render: the repair path after a deployment overwrites the fragments
# --------------------------------------------------------------------------
"$ACCENT" set '#3B82F6' >/dev/null
# hv_deploy_configs replaces each managed tree wholesale, restoring the
# default-red copies committed to the repo. `render` is what puts the derived
# accent back, and install.sh has to call it.
for name in waybar ags rofi kitty hypr; do
    cp -a "$REPO/config/$name/." "$HYPRVEIL_CONFIG_HOME/$name/"
done
grep -q "$DEFAULT_ACCENT" "$C/waybar/accent.css" || fail "the fixture did not reproduce a deployment"
"$ACCENT" render >/dev/null
grep -q "@define-color accent $accent;" "$C/waybar/accent.css" \
    || fail "render did not restore the saved accent after a deployment"
grep -q "\$accent: $accent;" "$C/ags/_accent.scss" || fail "render skipped the AGS fragment"
grep -q "accent.sh\" render\|accent.sh render" "$REPO/install.sh" \
    || fail "install.sh does not re-render the accent after replacing the config trees"
# Every .in template must be deployed alongside its output, or that consumer
# silently keeps the designed red: render_template returns early when the
# template is absent. The Qt palettes are installed by the theming stage rather
# than hv_deploy_configs, so they need their own check.
grep -q 'hyprveil.conf.in' "$REPO/scripts/04-install-fedora-theming.sh" \
    || fail "the theming stage installs the Qt palette without its .in template"
ok "render repairs every fragment after a deployment, and the installer calls it"

# --------------------------------------------------------------------------
# auto opt-out and reset
# --------------------------------------------------------------------------
"$ACCENT" auto off >/dev/null
"$ACCENT" is-auto && fail "auto off did not disable wallpaper tracking"
[ "$("$ACCENT" auto)" = off ] || fail "auto did not report its state"
# Opting out only stops wallpaper tracking; explicit commands must still work.
"$ACCENT" render >/dev/null || fail "render stopped working with tracking off"
grep -q "@define-color accent $accent;" "$C/waybar/accent.css" \
    || fail "render with tracking off did not rewrite the fragments"
"$ACCENT" auto on >/dev/null
"$ACCENT" is-auto || fail "auto on did not re-enable wallpaper tracking"

"$ACCENT" reset >/dev/null
grep -q "@define-color accent $DEFAULT_ACCENT;" "$C/waybar/accent.css" \
    || fail "reset did not restore the designed accent"
grep -q "@define-color accent-hover $DEFAULT_HOVER;" "$C/waybar/accent.css" \
    || fail "reset did not restore the designed hover shade"
jq -e --arg a "$DEFAULT_ACCENT" '.accent == $a and .source == "default"' \
    "$HYPRVEIL_STATE_HOME/accent.json" >/dev/null || fail "reset did not save default state"
ok "wallpaper tracking opts out without disabling explicit commands, and reset restores the design"

# --------------------------------------------------------------------------
# Adaptive chrome alpha
# --------------------------------------------------------------------------
ceiling=$(sed -n 's/^\$chrome-alpha *= *//p' "$C/hypr/tokens.conf")
floor=$(sed -n 's/^\$chrome-alpha-min *= *//p' "$C/hypr/tokens.conf")
[ -n "$ceiling" ] && [ -n "$floor" ] || fail "the chrome alpha range is not in tokens.conf"

# A blown-out band has to pay the full ceiling, a dark one drops to the floor.
# These are the two ends of the whole point: one fixed alpha cannot do both.
#
# Pure white is the anchor $chrome-alpha is documented against, so it pins the
# ceiling exactly — if the solver ever drifts from the number in tokens.conf,
# the doc and the token are both wrong and this is where it shows up.
white=$(MOCK_IMAGE=white "$ACCENT" extract-chrome "$image")
[ "$white" = "$ceiling" ] \
    || fail "a white wallpaper did not solve to \$chrome-alpha ($ceiling): $white"
# Merely bright lands just under it: the ceiling is the worst case, not a
# plateau everything light snaps to.
bright=$(MOCK_IMAGE=vivid "$ACCENT" extract-chrome "$image")
awk -v b="$bright" -v c="$ceiling" 'BEGIN { exit !(b < c && c - b <= 0.05) }' \
    || fail "a near-white wallpaper did not land just under $ceiling: $bright"
dark=$(MOCK_IMAGE=dark "$ACCENT" extract-chrome "$image")
[ "$dark" = "$floor" ] || fail "a dark wallpaper did not reach the floor $floor: $dark"

# An unmeasurable image must fail SAFE — opaque, not invisible.
unreadable=$(MOCK_IMAGE=empty "$ACCENT" extract-chrome "$image" 2>/dev/null)
[ "$unreadable" = "$ceiling" ] \
    || fail "an unreadable image did not fall back to the opaque ceiling: $unreadable"

# The solved value has to reach the singleton the bar actually reads, and be a
# bare QML number rather than a quoted string.
MOCK_IMAGE=dark "$ACCENT" chrome "$image" >/dev/null
grep -Eq "readonly property real chromeAlpha: $floor\$" "$C/quickshell/Accent.qml" \
    || fail "chrome did not render the solved alpha into Accent.qml"
jq -e --arg a "$floor" '.chromeAlpha == $a' "$HYPRVEIL_STATE_HOME/accent.json" \
    >/dev/null || fail "chrome did not persist the solved alpha"

# `chrome` must not touch the accent — it is a separate concern reusing the
# same measurement pass, and an alpha refresh that recolors the desktop would
# make wallpaper.sh's opted-out path do exactly what the opt-out forbids.
jq -e --arg a "$DEFAULT_ACCENT" '.accent == $a' "$HYPRVEIL_STATE_HOME/accent.json" \
    >/dev/null || fail "chrome changed the accent"

# Legibility is not opt-out-able: with tracking off, a wallpaper change must
# still re-solve the alpha even though the accent stays put.
"$ACCENT" auto off >/dev/null
MOCK_IMAGE=white "$ACCENT" chrome "$image" >/dev/null
grep -Eq "readonly property real chromeAlpha: $ceiling\$" "$C/quickshell/Accent.qml" \
    || fail "chrome stopped tracking the wallpaper when accent tracking was off"
grep -q 'ACCENT_HELPER" chrome' "$C/hypr/scripts/wallpaper.sh" \
    || fail "wallpaper.sh does not refresh chrome on the opted-out path"
"$ACCENT" auto on >/dev/null

# A state file predating chromeAlpha is not corrupt — it must keep its accent
# and pick up the default, not be reset to red.
jq 'del(.chromeAlpha)' "$HYPRVEIL_STATE_HOME/accent.json" > "$TMP/legacy.json"
jq --arg a '#3b82f6' '.accent = $a' "$TMP/legacy.json" > "$HYPRVEIL_STATE_HOME/accent.json"
"$ACCENT" render >/dev/null
jq -e '.accent == "#3b82f6"' "$HYPRVEIL_STATE_HOME/accent.json" >/dev/null \
    || fail "a state file without chromeAlpha was treated as malformed"
grep -Eq "readonly property real chromeAlpha: [01]\.[0-9]+\$" "$C/quickshell/Accent.qml" \
    || fail "render did not supply a chrome alpha for a legacy state file"
"$ACCENT" reset >/dev/null
ok "chrome alpha tracks wallpaper brightness, fails safe, and ignores the accent opt-out"

# --------------------------------------------------------------------------
# Malformed state and invalid input
# --------------------------------------------------------------------------
printf '{broken json\n' > "$HYPRVEIL_STATE_HOME/accent.json"
"$ACCENT" render >/dev/null 2> "$TMP/state-warning"
jq -e --arg a "$DEFAULT_ACCENT" '.version == 1 and .accent == $a' \
    "$HYPRVEIL_STATE_HOME/accent.json" >/dev/null \
    || fail "malformed accent state did not recover to defaults"
grep -q 'malformed accent state' "$TMP/state-warning" || fail "state recovery was not explained"

"$ACCENT" set 'nonsense' >/dev/null 2>&1 && fail "an invalid color was accepted"
"$ACCENT" set >/dev/null 2>&1 && fail "set without a color was accepted"
"$ACCENT" from-wallpaper >/dev/null 2>&1 && fail "from-wallpaper without a path was accepted"
"$ACCENT" from-wallpaper "$TMP/missing.jpg" >/dev/null 2>&1 \
    && fail "from-wallpaper accepted a nonexistent image"
# Uppercase input is normalized rather than rejected, so state stays comparable.
"$ACCENT" set '#ABCDEF' >/dev/null
jq -e '.accent == "#abcdef"' "$HYPRVEIL_STATE_HOME/accent.json" >/dev/null \
    || fail "an uppercase color was not normalized"
ok "malformed state recovers and invalid colors are rejected"

# --------------------------------------------------------------------------
# Static contract: committed fragments carry the designed accent
# --------------------------------------------------------------------------
# An unrendered checkout has to look identical to a rendered default, or a fresh
# clone shows a half-themed desktop.
for f in config/hypr/accent.conf config/waybar/accent.css config/swaync/accent.css \
         config/wlogout/accent.css config/gtk-3.0/accent.css config/gtk-4.0/accent.css \
         config/ags/_accent.scss config/rofi/accent.rasi config/kitty/accent.conf \
         config/quickshell/Accent.qml; do
    [ -f "$REPO/$f" ] || fail "missing committed accent fragment: $f"
    grep -qi "${DEFAULT_ACCENT#\#}" "$REPO/$f" \
        || fail "committed fragment does not carry the designed accent: $f"
done
# Each consumer must actually pull its fragment in.
grep -q 'source = ~/.config/hypr/accent.conf' "$REPO/config/hypr/colors.conf" \
    || fail "colors.conf does not source the accent fragment"
grep -q 'accent.css' "$REPO/config/waybar/style.css" || fail "Waybar does not import accent.css"
grep -q 'accent.rasi' "$REPO/config/rofi/hyprveil.rasi" || fail "Rofi does not import accent.rasi"
grep -q 'include accent.conf' "$REPO/config/kitty/kitty.conf" || fail "Kitty does not include accent.conf"
ok "committed fragments carry the designed accent and every consumer imports one"

printf 'P6 accent smoke tests passed.\n'
