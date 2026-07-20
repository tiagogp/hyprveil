#!/usr/bin/env bash
# Mocked, non-root checks for P5: the Quickshell quick-settings panel +
# notifications backend, its Waybar/daemon bridge, and Hyprland integration. No
# Wayland session or real Quickshell install is required; mock `quickshell`/`qs`
# binaries stand in for the running shell.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p5.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

export HOME="$TMP/home"
export HYPRVEIL_STATE_HOME="$TMP/state"
export HYPRVEIL_CONFIG_HOME="$TMP/config"
export HYPRVEIL_NOTIFICATION_HELPER="$REPO/config/hypr/scripts/notification-daemon.sh"
export MOCK_ROOT="$TMP"
mkdir -p "$HOME" "$HYPRVEIL_STATE_HOME" "$HYPRVEIL_CONFIG_HOME" "$TMP/bin"
export PATH="$TMP/bin:$PATH"

# --- Shell layer-shell surfaces have their compositor glass rules ---
# Derived from the QML rather than listed, so a surface added later is covered
# without anyone remembering to extend this. The glass is the compositor's: a
# namespace Hyprland has no rule for renders as a flat fill no matter what the
# QML asks for, and nothing about that failure points at the missing rule.
while IFS= read -r ns; do
    grep -q "layerrule = blur, $ns" "$REPO/config/hypr/window-rules.conf" \
        || fail "shell surface $ns has no blur layerrule"
    grep -Eq "layerrule = ignorealpha [0-9.]+, $ns" "$REPO/config/hypr/window-rules.conf" \
        || fail "shell surface $ns has no ignorealpha layerrule"
done < <(grep -rh 'WlrLayershell.namespace' "$REPO/config/quickshell" \
    | sed 's/.*"\(.*\)".*/\1/' | sort -u)
ok "every Quickshell layer-shell surface has its blur rules"

# A pragma Singleton with no qmldir entry resolves to the uninstantiated TYPE,
# so every property on it reads as undefined — which QML renders as 0 without
# raising anything. The shell loads and looks plausible with the singleton
# entirely unbound, so this cannot be left to review.
for dir in "$REPO/config/quickshell" "$REPO/config/quickshell/Services"; do
    while IFS= read -r file; do
        name=$(basename "$file" .qml)
        grep -q "^singleton $name " "$dir/qmldir" \
            || fail "$name is a pragma Singleton with no qmldir entry in ${dir#"$REPO/"}"
    done < <(grep -rl '^pragma Singleton' "$dir" --include='*.qml' -m1 \
        | while IFS= read -r f; do [ "$(dirname "$f")" = "$dir" ] && printf '%s\n' "$f"; done)
done
ok "every shell singleton is registered in its qmldir"
grep -q 'displayTitle(title: string)' "$REPO/config/quickshell/Services/Compositor.qml" \
    || fail "Compositor does not normalize focused window titles"
grep -q ' - hyprveil - Visual Studio Code' "$REPO/config/quickshell/Services/Compositor.qml" \
    || fail "VS Code workspace segment is not stripped from the bar title"
grep -q 'Visual Studio Code - ' "$REPO/config/quickshell/Services/Compositor.qml" \
    || fail "Quickshell title does not put VS Code before the file name"
grep -q '"^(.*) - hyprveil - Visual Studio Code$"' "$REPO/config/waybar/config.jsonc" \
    || fail "Waybar window title does not strip the VS Code workspace segment"
grep -q '"Visual Studio Code - \$1"' "$REPO/config/waybar/config.jsonc" \
    || fail "Waybar title does not put VS Code before the file name"
ok "bar title removes the hyprveil workspace segment and puts VS Code first"
# --- Mocks standing in for the running shell ---
cat > "$TMP/bin/qs" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/qs"
exit 0
EOF
cat > "$TMP/bin/quickshell" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/quickshell"
EOF
cat > "$TMP/bin/pkill" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/killed"
EOF
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/pgrep"
cat > "$TMP/bin/swaync" <<'EOF'
#!/usr/bin/env bash
printf 'started\n' >> "$MOCK_ROOT/swaync"
EOF
chmod +x "$TMP/bin/qs" "$TMP/bin/quickshell" "$TMP/bin/pkill" "$TMP/bin/pgrep" "$TMP/bin/swaync"

# --- Backend selection accepts quickshell and defaults to it ---
rm -f "$HYPRVEIL_STATE_HOME/notification-backend"
"$REPO/scripts/07-select-notification-backend.sh" --backend quickshell >/dev/null
[ "$(cat "$HYPRVEIL_STATE_HOME/notification-backend")" = quickshell ] \
    || fail "Quickshell backend was not saved"
rm -f "$HYPRVEIL_STATE_HOME/notification-backend"
[ "$("$REPO/config/hypr/scripts/notification-daemon.sh" backend)" = quickshell ] \
    || fail "daemon default backend is not quickshell"
# A state file naming the retired AGS backend must not select it, and must not
# leave the session with no daemon either: it reads as unset and gets the default.
printf 'ags\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
[ "$("$REPO/config/hypr/scripts/notification-daemon.sh" backend)" = quickshell ] \
    || fail "a stale ags state file did not fall through to the default backend"
ok "backend selection accepts quickshell, defaults to it, and ignores a stale ags choice"

# --- An unavailable shell degrades to a fallback instead of no notifications ---
# Quickshell is selected but absent; the daemon must hand off to swaync/mako
# rather than leaving the session with nothing serving notifications.
#
# The PATH here deliberately excludes /usr/bin: a developer running this on a
# machine with Quickshell actually installed would otherwise find the real
# binary and never exercise the fallback. Only bash is linked in, because
# `#!/usr/bin/env bash` still has to resolve an interpreter.
mkdir -p "$TMP/minimal"
ln -sf "$(command -v bash)" "$TMP/minimal/bash"
printf 'quickshell\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
rm -f "$TMP/swaync" "$TMP/quickshell"
mv "$TMP/bin/quickshell" "$TMP/quickshell.hidden"
PATH="$TMP/bin:$TMP/minimal" "$REPO/config/hypr/scripts/notification-daemon.sh" start 2>/dev/null
mv "$TMP/quickshell.hidden" "$TMP/bin/quickshell"
[ -s "$TMP/swaync" ] \
    || fail "an unavailable Quickshell did not fall back to a working daemon"
ok "an unavailable shell falls back instead of leaving the session without notifications"

# --- Quickshell daemonizes in a real session and stays foregrounded in nested tests ---
printf 'quickshell\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
rm -f "$TMP/quickshell" "$TMP/killed"
"$REPO/config/hypr/scripts/notification-daemon.sh" start
grep -qx -- '--daemonize' "$TMP/quickshell" || fail "quickshell backend was not daemonized for a normal session"
grep -qx -- '-x swaync' "$TMP/killed" || fail "quickshell startup did not stop SwayNC"
grep -qx -- '-x mako' "$TMP/killed" || fail "quickshell startup did not stop Mako"
rm -f "$TMP/quickshell"
HYPRVEIL_NESTED_SESSION=1 "$REPO/config/hypr/scripts/notification-daemon.sh" start
[ -s "$TMP/quickshell" ] || fail "nested quickshell backend did not start"
! grep -qx -- '--daemonize' "$TMP/quickshell" || fail "nested quickshell backend daemonized instead of staying attached"
ok "quickshell backend daemonizes only for the real session"

# --- Daemon toggle/dnd route to the Quickshell panel over IPC ---
printf 'quickshell\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
rm -f "$TMP/qs"
"$REPO/config/hypr/scripts/notification-daemon.sh" toggle
"$REPO/config/hypr/scripts/notification-daemon.sh" dnd
grep -q 'quicksettings toggle' "$TMP/qs" \
    || fail "SUPER+N/center toggle did not reach the Quickshell panel"
grep -q 'notifications dnd' "$TMP/qs" || fail "DND did not reach the Quickshell panel"
ok "daemon toggle and DND route through the Quickshell IPC bridge"

# --- Waybar bridge degrades cleanly under the Quickshell backend ---
# Waybar is the legacy bar and has no channel into the shell's own indicator, so
# the bridge must emit well-formed JSON rather than querying a backend it cannot
# talk to. Malformed output here blanks the whole Waybar module.
render=$("$REPO/config/waybar/scripts/notification.sh" render)
printf '%s' "$render" | jq -e '.text != null and .alt != null and .class != null' >/dev/null \
    || fail "Waybar bridge did not emit a well-formed module payload"
ok "Waybar notification bridge degrades cleanly under the Quickshell backend"

# --- Hyprland + Waybar integration wiring ---
grep -q 'notification-daemon.sh toggle' "$REPO/config/waybar/config.jsonc" \
    || fail "Waybar does not toggle the panel through the backend-aware helper"
for ns in hyprveil-quicksettings hyprveil-notifications; do
    grep -q "blur, $ns" "$REPO/config/hypr/window-rules.conf" \
        || fail "missing blur layer rule for $ns"
done
grep -q 'notification-daemon.sh start' "$REPO/config/hypr/autostart.conf" \
    || fail "autostart does not launch the backend-aware daemon"
ok "Waybar toggle, layer blur rules, and autostart are wired for the shell"

# --- Deployment installs only the selected backend tree ---
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"
printf 'quickshell\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
mkdir -p "$HYPRVEIL_CONFIG_HOME/swaync" "$HYPRVEIL_CONFIG_HOME/mako" "$HYPRVEIL_CONFIG_HOME/ags"
printf 'stale\n' > "$HYPRVEIL_CONFIG_HOME/swaync/config.json"
printf 'stale\n' > "$HYPRVEIL_CONFIG_HOME/mako/config"
printf 'stale\n' > "$HYPRVEIL_CONFIG_HOME/ags/app.ts"
hv_deploy_configs >/dev/null
[ -f "$HYPRVEIL_CONFIG_HOME/quickshell/shell.qml" ] \
    || fail "Quickshell config was not deployed"
[ ! -e "$HYPRVEIL_CONFIG_HOME/swaync" ] || fail "inactive SwayNC tree survived deployment"
[ ! -e "$HYPRVEIL_CONFIG_HOME/mako" ] || fail "inactive Mako tree survived deployment"
# A machine that once ran the retired AGS backend must get its stale tree cleaned
# up, or ~/.config/ags is stranded forever with nothing left that would remove it.
[ ! -e "$HYPRVEIL_CONFIG_HOME/ags" ] || fail "a stale AGS tree survived deployment"
ok "deployment installs only the selected backend and clears the inactive trees"

# --- A misresolved HV_REPO must not destroy the installed configuration ---
# Each target tree is removed immediately before its replacement is moved in, so
# a source that does not exist used to empty the target and install nothing:
# cp printed an error and the loop continued to the rm. Sourcing this library
# from a shell without BASH_SOURCE (zsh) is one way to land there.
deploy_guard_marker="$HYPRVEIL_CONFIG_HOME/hypr/hyprland.conf"
[ -f "$deploy_guard_marker" ] || fail "fixture precondition: hypr was not deployed"
(
    HV_REPO="$TMP/definitely-not-the-repo"
    hv_deploy_configs >/dev/null 2>&1
) && fail "hv_deploy_configs succeeded against a missing source tree"
[ -f "$deploy_guard_marker" ] \
    || fail "a missing source tree destroyed the installed configuration"
[ -s "$deploy_guard_marker" ] \
    || fail "a missing source tree emptied the installed configuration"
ok "deployment refuses a missing source tree instead of emptying the target"

printf 'P5 smoke tests passed.\n'
