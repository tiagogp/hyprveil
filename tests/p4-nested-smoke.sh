#!/usr/bin/env bash
# Prove that the nested-session launcher cannot touch real user config or state.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p4-nested.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

mkdir -p "$TMP/bin" "$TMP/real-home/.config" "$TMP/real-state/hyprveil"
printf 'real config marker\n' > "$TMP/real-home/.config/keep"
printf 'real state marker\n' > "$TMP/real-state/hyprveil/keep"

cat > "$TMP/bin/Hyprland" <<'EOF'
#!/usr/bin/env bash
set -eu
stage=${HYPRVEIL_NESTED_STAGE:?}
[ "$HOME" = "$stage/home" ]
[ "$XDG_CONFIG_HOME" = "$stage/config" ]
[ "$XDG_STATE_HOME" = "$stage/state" ]
[ "$XDG_CACHE_HOME" = "$stage/cache" ]
[ "$XDG_DATA_HOME" = "$stage/data" ]
[ "$XDG_RUNTIME_DIR" = "$stage/runtime" ]
[ "$HYPRVEIL_CONFIG_HOME" = "$stage/config" ]
[ "$HYPRVEIL_STATE_HOME" = "$stage/state/hyprveil" ]
[ "$HYPRVEIL_NESTED_SESSION" = 1 ]
[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]
[ -L "$HOME/.config" ]
[ "$(readlink "$HOME/.config")" = "$stage/config" ]
[ "$1" = -c ]
[ "$2" = "$stage/config/hypr/hyprland.conf" ]
[ "$(cat "$stage/state/hyprveil/notification-backend")" = "${EXPECTED_BACKEND:?}" ]
[ "$(cat "$stage/state/hyprveil/motion-profile")" = standard ]
jq -e 'type == "array" and length == 0' "$stage/state/hyprveil/dock-pins.json" >/dev/null
jq -e '.version == 1 and (.fallback.path | startswith($stage)) and .monitors == {}' \
    --arg stage "$stage" "$stage/state/hyprveil/wallpapers.json" >/dev/null
grep -Fq "source = $stage/config/hypr/motion/standard.conf" \
    "$stage/config/hypr/motion/active.conf"
! grep -R -Fq '~/.config/hypr' "$stage/config/hypr" --include='*.conf'
printf '%s\n' "$stage" >> "${MOCK_LOG:?}"
EOF
cat > "$TMP/bin/dbus-run-session" <<'EOF'
#!/usr/bin/env bash
set -eu
[ "$1" = -- ]
case "$XDG_RUNTIME_DIR" in
    */hyprveil-nested.*/runtime) ;;
    *) exit 1 ;;
esac
shift
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/mock-bus"
exec "$@"
EOF
chmod +x "$TMP/bin/Hyprland" "$TMP/bin/dbus-run-session"

for backend in quickshell swaync mako; do
    EXPECTED_BACKEND=$backend MOCK_LOG="$TMP/launches" \
        HOME="$TMP/real-home" XDG_STATE_HOME="$TMP/real-state" \
        WAYLAND_DISPLAY=wayland-mock PATH="$TMP/bin:/usr/bin:/bin" \
        "$REPO/scripts/08-test-nested-session.sh" --backend "$backend" >/dev/null
done

[ "$(cat "$TMP/real-home/.config/keep")" = 'real config marker' ] \
    || fail "nested check modified real config"
[ "$(cat "$TMP/real-state/hyprveil/keep")" = 'real state marker' ] \
    || fail "nested check modified real state"
[ "$(wc -l < "$TMP/launches")" -eq 3 ] || fail "all backend paths were not launched"
while IFS= read -r stage; do
    [ ! -e "$stage" ] || fail "temporary nested stage was not cleaned up"
done < "$TMP/launches"

ok "nested Quickshell, SwayNC, and Mako sessions isolate config, state, cache, data, home, and runtime"
ok "nested preflight generates both motion profiles and valid dock/wallpaper state"

# Nested notification startup must not kill a same-named process in the parent
# process namespace; the isolated D-Bus keeps the nested daemon service separate.
mkdir -p "$TMP/nested-bin" "$TMP/nested-state"
printf 'swaync\n' > "$TMP/nested-state/notification-backend"
cat > "$TMP/nested-bin/pkill" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/nested-kills"
EOF
cat > "$TMP/nested-bin/pgrep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/nested-pgreps"
exit 1
EOF
cat > "$TMP/nested-bin/swaync" <<'EOF'
#!/usr/bin/env bash
printf 'nested swaync started\n' >> "$MOCK_ROOT/nested-started"
EOF
chmod +x "$TMP/nested-bin/"*
MOCK_ROOT="$TMP" HYPRVEIL_NESTED_SESSION=1 HYPRVEIL_STATE_HOME="$TMP/nested-state" \
    PATH="$TMP/nested-bin:/usr/bin:/bin" \
    "$REPO/config/hypr/scripts/notification-daemon.sh" start
[ -s "$TMP/nested-started" ] || fail "nested notification backend did not start"
[ ! -e "$TMP/nested-kills" ] || fail "nested notification startup used pkill"
[ ! -e "$TMP/nested-pgreps" ] || fail "nested notification startup inspected parent processes"
ok "nested notification startup cannot stop or reuse a parent-session daemon"
printf 'P4 nested-session smoke tests passed.\n'
