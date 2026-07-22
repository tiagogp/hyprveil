#!/usr/bin/env bash
# Mocked, non-root checks for P3 wallpaper and motion behavior.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p3.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

export HOME="$TMP/home"
export HYPRVEIL_STATE_HOME="$TMP/state"
export HYPRVEIL_CONFIG_HOME="$TMP/config"
export HYPRVEIL_DEFAULT_WALLPAPER="$TMP/config/hypr/wallpaper-default.jpg"
export HYPRVEIL_WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
export HYPRVEIL_RESTORE_ATTEMPTS=1
export HYPRVEIL_ACCENT_HELPER="$TMP/bin/accent.sh"
export MOCK_ROOT="$TMP"
mkdir -p "$HOME" "$HYPRVEIL_STATE_HOME" "$HYPRVEIL_CONFIG_HOME/hypr" \
    "$HYPRVEIL_WALLPAPER_DIR" "$TMP/bin"
cp -a "$REPO/config/hypr/motion" "$HYPRVEIL_CONFIG_HOME/hypr/motion"
cp -a "$REPO/config/hypr/animations.conf" "$HYPRVEIL_CONFIG_HOME/hypr/animations.conf"
printf 'default image\n' > "$HYPRVEIL_DEFAULT_WALLPAPER"
export PATH="$TMP/bin:$PATH"

# Logs each invocation so the wallpaper->accent hook can be asserted. MOCK_AUTO=off
# reproduces `accent.sh auto off`, the documented opt-out.
cat > "$TMP/bin/accent.sh" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$MOCK_ROOT/accent.log"
if [ "${1:-}" = is-auto ]; then
    [ "${MOCK_AUTO:-on}" = on ]
    exit $?
fi
[ "${MOCK_ACCENT_FAIL:-0}" != 1 ]
EOF
chmod +x "$TMP/bin/accent.sh"

cat > "$TMP/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = -j ] && [ "${2:-}" = monitors ]; then
    if [ -n "${MOCK_MONITORS:-}" ]; then
        printf '%s\n' "$MOCK_MONITORS"
    else
        printf '[{"name":"DP-1"},{"name":"HDMI-A-1"}]\n'
    fi
    exit 0
fi
if [ "${1:-}" = hyprpaper ] && [ "${2:-}" = --help ]; then
    [ "${MOCK_IPC:-modern}" != unavailable ] || exit 1
    if [ "${MOCK_IPC:-modern}" = legacy ]; then
        printf 'preload PATH\nwallpaper MONITOR,PATH\nreload MONITOR,PATH\n'
    else
        # Mirrors `hyprctl hyprpaper --help` on current Hyprpaper: no `reload`,
        # and `wallpaper` takes monitor,[contain:]path with no fit field.
        printf 'listactive\nlistloaded\npreload <path>\nunload <path>\nwallpaper\n'
    fi
    # Real Hyprpaper prints its usage and then exits non-zero; readiness must be
    # judged from the text, so keep this failure status in the mock.
    exit 1
fi
if [ "${1:-}" = hyprpaper ] && { [ "${2:-}" = listloaded ] || [ "${2:-}" = listactive ]; }; then
    [ "${MOCK_IPC:-modern}" != unavailable ] || exit 3
    [ "${MOCK_HYPRPAPER_READY:-1}" = 1 ] || exit 3
    exit 0
fi
if [ "${1:-}" = reload ]; then
    printf 'compositor-reload\n' >> "$MOCK_ROOT/ipc.log"
    [ "${MOCK_RELOAD_FAIL:-0}" != 1 ]
    exit
fi
printf '%s' "${1:-}" >> "$MOCK_ROOT/ipc.log"
shift || true
for arg in "$@"; do
    printf '\t%s' "$arg" >> "$MOCK_ROOT/ipc.log"
done
printf '\n' >> "$MOCK_ROOT/ipc.log"
EOF
cat > "$TMP/bin/rofi" <<'EOF'
#!/usr/bin/env bash
set -u
prompt=
previous=
for arg in "$@"; do
    if [ "$previous" = -p ]; then prompt=$arg; fi
    previous=$arg
done
if [ "${1:-}" = -e ]; then
    printf '%s\n' "$*" >> "$MOCK_ROOT/rofi-errors"
    exit 0
fi
case "$prompt" in
    wallpaper) sed -n "${MOCK_ROFI_INDEX:-1}p" ;;
    target) printf '%s\n' "${MOCK_ROFI_TARGET:-All monitors}" ;;
    fit) printf '%s\n' "${MOCK_ROFI_FIT:-cover}" ;;
    *) exit 1 ;;
esac
EOF
# A real `qs` may exist on the developer's PATH and a real shell may even be
# running; mock it so picker routing is decided by MOCK_QS_RUNNING alone. The
# mock fails the IPC call when unset, which is exactly how qs_picker detects an
# absent shell and falls through to Rofi.
cat > "$TMP/bin/qs" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = ipc ]; then
    shift
    [ -n "${MOCK_QS_RUNNING:-}" ] || exit 1
    printf '%s\n' "$*" >> "$MOCK_ROOT/qs-requests"
    exit 0
fi
exit 0
EOF
chmod +x "$TMP/bin/qs"

chmod +x "$TMP/bin/hyprctl" "$TMP/bin/rofi"

WALLPAPER="$REPO/config/hypr/scripts/wallpaper.sh"
MOTION="$REPO/config/hypr/scripts/motion-profile.sh"
special="$HYPRVEIL_WALLPAPER_DIR/Sol d'été \"final\".jpg"
printf 'image\n' > "$special"

: > "$TMP/ipc.log"
jq -n --arg path "$HYPRVEIL_DEFAULT_WALLPAPER" \
    '{version: 1, fallback: {path: $path, fit: "cover"}, monitors: {"DP-1": {path: $path, fit: "cover"}}}' \
    > "$HYPRVEIL_STATE_HOME/wallpapers.json"
"$WALLPAPER" apply "$special" contain
jq -e --arg path "$special" \
    '.version == 1 and .fallback == {path: $path, fit: "contain"} and .monitors == {}' \
    "$HYPRVEIL_STATE_HOME/wallpapers.json" >/dev/null \
    || fail "all-monitor selection was not saved safely"
grep -Fqx $'hyprpaper\tpreload\t'"$special" "$TMP/ipc.log" \
    || fail "modern IPC did not preload the image before showing it"
grep -Fqx $'hyprpaper\twallpaper\tDP-1,contain:'"$special" "$TMP/ipc.log" \
    || fail "modern IPC did not target DP-1 with contain mode"
grep -Fqx $'hyprpaper\twallpaper\tHDMI-A-1,contain:'"$special" "$TMP/ipc.log" \
    || fail "modern IPC did not target HDMI-A-1"
grep -Fq ',contain\t' "$TMP/ipc.log" && fail "fit was sent as a separate field"
grep -Fq "$special,contain" "$TMP/ipc.log" && fail "fit was appended to the path"
[ "$(stat -c %a "$HYPRVEIL_STATE_HOME/wallpapers.json")" = 600 ] \
    || fail "wallpaper state permissions are not private"
ok "special-character paths, persistent all-monitor replacement, and modern IPC work"

# --- wallpaper -> accent hook ---
# Picking a wallpaper is what moves the system accent, so the helper must be
# invoked with the chosen image and the failure must never abort the wallpaper.
grep -Fqx "from-wallpaper $special" "$TMP/accent.log" \
    || fail "apply did not derive the accent from the chosen wallpaper"
: > "$TMP/accent.log"
: > "$TMP/ipc.log"
MOCK_MONITORS='[{"name":"DP-1"}]' "$WALLPAPER" restore
grep -Fqx "from-wallpaper $special" "$TMP/accent.log" \
    || fail "restore did not re-derive the accent at login"
[ "$(grep -c '^from-wallpaper ' "$TMP/accent.log")" = 1 ] \
    || fail "restore derived the accent more than once"
: > "$TMP/ipc.log"
MOCK_HYPRPAPER_READY=0 MOCK_MONITORS='[{"name":"DP-1"}]' "$WALLPAPER" restore 2> "$TMP/not-ready-warning"
[ ! -s "$TMP/ipc.log" ] || fail "restore applied wallpaper before Hyprpaper IPC was ready"
grep -q 'Hyprpaper IPC did not become ready' "$TMP/not-ready-warning" \
    || fail "restore did not explain an unavailable Hyprpaper IPC"
# `auto off` must leave the wallpaper working and the accent untouched.
: > "$TMP/accent.log"
MOCK_AUTO=off "$WALLPAPER" apply "$special" contain
grep -q '^from-wallpaper ' "$TMP/accent.log" \
    && fail "auto off did not stop the accent from tracking the wallpaper"
jq -e --arg path "$special" '.fallback.path == $path' \
    "$HYPRVEIL_STATE_HOME/wallpapers.json" >/dev/null \
    || fail "auto off prevented the wallpaper from being applied"
# A failed extraction (greyscale image, missing ImageMagick) warns and continues.
: > "$TMP/ipc.log"
status=0
MOCK_ACCENT_FAIL=1 "$WALLPAPER" apply "$special" contain 2> "$TMP/accent-warning" || status=$?
[ "$status" -eq 0 ] || fail "a failed accent extraction aborted apply (exit $status)"
grep -q 'accent could not be derived' "$TMP/accent-warning" \
    || fail "a failed accent extraction was not explained"
grep -Fqx $'hyprpaper\twallpaper\tDP-1,contain:'"$special" "$TMP/ipc.log" \
    || fail "a failed accent extraction blocked the wallpaper"
ok "accent tracks the wallpaper on apply and login, and opts out without blocking it"

: > "$TMP/ipc.log"
"$WALLPAPER" apply "$special" DP-9 cover >/dev/null 2>&1
jq -e --arg path "$special" '.monitors["DP-9"] == {path: $path, fit: "cover"}' \
    "$HYPRVEIL_STATE_HOME/wallpapers.json" >/dev/null \
    || fail "disconnected monitor mapping was not retained"
grep -Fq $'\tDP-9,' "$TMP/ipc.log" && fail "disconnected monitor received an IPC request"
MOCK_MONITORS='[{"name":"DP-1"}]' "$WALLPAPER" restore
grep -Fq $'\tDP-9,' "$TMP/ipc.log" && fail "restore did not ignore a disconnected mapping"
: > "$TMP/ipc.log"
MOCK_MONITORS='[{"name":"DP-9"}]' "$WALLPAPER" restore
grep -Fqx $'hyprpaper\twallpaper\tDP-9,'"$special" "$TMP/ipc.log" \
    || fail "mapping was not restored when its monitor reconnected"
ok "per-monitor choices persist across disconnection and reconnection"

rm -f "$special"
: > "$TMP/ipc.log"
MOCK_MONITORS='[{"name":"DP-9"}]' "$WALLPAPER" restore 2> "$TMP/missing-warning"
grep -Fqx $'hyprpaper\twallpaper\tDP-9,'"$HYPRVEIL_DEFAULT_WALLPAPER" "$TMP/ipc.log" \
    || fail "missing per-monitor file did not use bundled default"
grep -q 'saved file is missing' "$TMP/missing-warning" \
    || fail "missing wallpaper fallback was not explained"
printf '{broken json\n' > "$HYPRVEIL_STATE_HOME/wallpapers.json"
"$WALLPAPER" restore >/dev/null 2>&1
find "$HYPRVEIL_STATE_HOME" -name 'wallpapers.json.invalid-*' -print -quit | grep -q . \
    || fail "malformed wallpaper state was not preserved"
jq -e --arg path "$HYPRVEIL_DEFAULT_WALLPAPER" \
    '.fallback == {path: $path, fit: "cover"} and .monitors == {}' \
    "$HYPRVEIL_STATE_HOME/wallpapers.json" >/dev/null \
    || fail "malformed state did not recover to safe defaults"
ok "missing files and malformed state recover to the bundled default"

legacy="$HYPRVEIL_WALLPAPER_DIR/legacy image.png"
printf 'legacy\n' > "$legacy"
: > "$TMP/ipc.log"
MOCK_IPC=legacy "$WALLPAPER" apply "$legacy" DP-1 contain
grep -Fqx $'hyprpaper\treload\tDP-1,contain:'"$legacy" "$TMP/ipc.log" \
    || fail "legacy reload IPC did not encode contain mode"
ok "legacy Hyprpaper reload IPC is detected at runtime"

rm -f "$legacy"
rm -f "$HYPRVEIL_STATE_HOME/wallpapers.json"
"$WALLPAPER" pick >/dev/null 2>&1
[ ! -e "$HYPRVEIL_STATE_HOME/wallpapers.json" ] \
    || fail "empty picker changed wallpaper state"
grep -q 'No supported images' "$TMP/rofi-errors" \
    || fail "empty picker did not show a useful message"
picker="$HYPRVEIL_WALLPAPER_DIR/夜空 \"one\".webp"
printf 'picker\n' > "$picker"
: > "$TMP/ipc.log"
MOCK_ROFI_TARGET=DP-1 MOCK_ROFI_FIT=cover "$WALLPAPER" pick
jq -e --arg path "$picker" '.monitors["DP-1"] == {path: $path, fit: "cover"}' \
    "$HYPRVEIL_STATE_HOME/wallpapers.json" >/dev/null \
    || fail "picker did not preserve its special-character path"
ok "picker handles empty directories and special-character image names"

# --- `list` feeds the Quickshell grid with the same catalog Rofi shows ---

catalog=$("$WALLPAPER" list)
jq -e --arg path "$picker" '.images | index($path) != null' <<<"$catalog" >/dev/null \
    || fail "list omitted a special-character image"
jq -e '.images | all(test("\\.(jpg|jpeg|png|webp|jxl|bmp)$"; "i"))' <<<"$catalog" >/dev/null \
    || fail "list returned unsupported file types"
jq -e '.outputs == ["DP-1", "HDMI-A-1"]' <<<"$catalog" >/dev/null \
    || fail "list did not report connected outputs"
jq -e --arg path "$picker" '.monitors["DP-1"].path == $path' <<<"$catalog" >/dev/null \
    || fail "list did not report the saved per-monitor selection"
jq -e '.fallback.path | type == "string"' <<<"$catalog" >/dev/null \
    || fail "list did not report a fallback selection"

# An unreadable wallpaper directory still yields a well-formed empty catalog, so
# the grid can render its "add images here" state instead of failing to open.
HYPRVEIL_WALLPAPER_DIR="$TMP/absent" "$WALLPAPER" list \
    | jq -e '.images == [] and (.dir | type == "string")' >/dev/null \
    || fail "list did not degrade to an empty catalog for a missing directory"
ok "list reports images, outputs, and saved selections as JSON"

# --- pick prefers the Quickshell grid only when that shell is actually running ---
rm -f "$TMP/qs-requests"
: > "$TMP/rofi-errors"
MOCK_QS_RUNNING=1 "$WALLPAPER" pick
grep -q 'wallpapers open' "$TMP/qs-requests" \
    || fail "pick did not delegate to the running Quickshell grid"
[ ! -s "$TMP/rofi-errors" ] || fail "pick ran the Rofi flow while the Quickshell grid was up"

rm -f "$TMP/qs-requests"
: > "$TMP/ipc.log"
# No Quickshell instance: the Rofi flow must still work unchanged.
MOCK_ROFI_TARGET=DP-1 MOCK_ROFI_FIT=contain "$WALLPAPER" pick
[ ! -e "$TMP/qs-requests" ] || fail "pick reached the shell when no instance was running"
jq -e --arg path "$picker" '.monitors["DP-1"] == {path: $path, fit: "contain"}' \
    "$HYPRVEIL_STATE_HOME/wallpapers.json" >/dev/null \
    || fail "Rofi fallback did not apply its selection"
ok "pick uses the Quickshell grid when present and falls back to Rofi otherwise"

: > "$TMP/ipc.log"
HYPRLAND_INSTANCE_SIGNATURE=mock "$MOTION" reduced >/dev/null
[ "$(cat "$HYPRVEIL_STATE_HOME/motion-profile")" = reduced ] \
    || fail "reduced motion choice was not saved"
grep -q 'motion/reduced.conf' "$HYPRVEIL_CONFIG_HOME/hypr/motion/active.conf" \
    || fail "reduced profile was not activated"
grep -qx compositor-reload "$TMP/ipc.log" || fail "Hyprland was not reloaded after switching"
"$MOTION" --ensure >/dev/null
[ "$(cat "$HYPRVEIL_STATE_HOME/motion-profile")" = reduced ] \
    || fail "ensure changed the selected motion profile"
grep -Fq "enabled = \$hyprveil_animations_enabled" "$REPO/config/hypr/motion/standard.conf" \
    || fail "standard profile does not honor the global animation toggle"
grep -Fq "enabled = \$hyprveil_animations_enabled" "$REPO/config/hypr/motion/reduced.conf" \
    || fail "reduced profile does not honor the global animation toggle"
ok "standard/reduced selection persists, reloads, and honors global disable"

wallpaper_before=$(sha256sum "$HYPRVEIL_STATE_HOME/wallpapers.json")
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"
hv_deploy_configs >/dev/null
wallpaper_after=$(sha256sum "$HYPRVEIL_STATE_HOME/wallpapers.json")
[ "$wallpaper_before" = "$wallpaper_after" ] \
    || fail "clean deployment changed wallpaper state"
"$HYPRVEIL_CONFIG_HOME/hypr/scripts/motion-profile.sh" --ensure >/dev/null
grep -q 'motion/reduced.conf' "$HYPRVEIL_CONFIG_HOME/hypr/motion/active.conf" \
    || fail "clean deployment did not restore the saved motion profile"
[ -f "$HYPRVEIL_CONFIG_HOME/hypr/wallpaper-default.jpg" ] \
    || fail "clean deployment omitted the bundled fallback wallpaper"
ok "clean installer deployment preserves wallpaper and motion state"

"$MOTION" standard >/dev/null
: > "$TMP/ipc.log"
if HYPRLAND_INSTANCE_SIGNATURE=mock MOCK_RELOAD_FAIL=1 "$MOTION" reduced >/dev/null 2>&1; then
    fail "failed Hyprland reload was reported as successful"
fi
[ "$(cat "$HYPRVEIL_STATE_HOME/motion-profile")" = standard ] \
    || fail "failed reload did not roll back motion state"
grep -q 'motion/standard.conf' "$HYPRVEIL_CONFIG_HOME/hypr/motion/active.conf" \
    || fail "failed reload did not roll back active motion config"
printf 'invalid\n' > "$HYPRVEIL_STATE_HOME/motion-profile"
"$MOTION" --ensure >/dev/null 2>&1
find "$HYPRVEIL_STATE_HOME" -name 'motion-profile.invalid-*' -print -quit | grep -q . \
    || fail "malformed motion state was not preserved"
[ "$(cat "$HYPRVEIL_STATE_HOME/motion-profile")" = standard ] \
    || fail "malformed motion state did not recover to standard"
ok "motion reload failure and malformed state both roll back safely"

grep -q 'wallpaper.sh restore' "$REPO/config/hypr/autostart.conf" \
    || fail "wallpaper restore is not started after Hyprpaper"
grep -q 'wallpaper.sh pick' "$REPO/config/hypr/keybindings.conf" \
    || fail "SUPER+SHIFT+W picker binding is missing"
printf 'P3 smoke tests passed.\n'
