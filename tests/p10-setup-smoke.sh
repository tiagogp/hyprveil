#!/usr/bin/env bash
# Mocked, non-session checks for `hyprveil setup`: monitor detection and
# generation, keyboard/app/idle rendering, preview safety, cancellation safety,
# state persistence, and the --ensure regeneration that keeps setup-owned files
# alive across deploys.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p10.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

cat > "$TMP/os-release" <<'EOF'
ID=fedora
VERSION_ID=44
PRETTY_NAME="Fedora Linux 44 (Mock)"
EOF

export HOME="$TMP/home"
export HYPRVEIL_OS_RELEASE="$TMP/os-release"
export HYPRVEIL_STATE_HOME="$TMP/state"
export HYPRVEIL_CONFIG_HOME="$TMP/config"
export HYPRVEIL_NO_SUDO=1
export PATH="$TMP/bin:$PATH"
mkdir -p "$HOME" "$HYPRVEIL_CONFIG_HOME" "$HYPRVEIL_STATE_HOME" "$TMP/bin"

# A deployed config tree, plus the state the delegates expect so setup stays
# quiet about the profile and backend.
cp -a "$REPO/config/hypr" "$HYPRVEIL_CONFIG_HOME/hypr"
printf 'quickshell\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
cat > "$HYPRVEIL_STATE_HOME/hardware-profile.conf" <<'EOF'
form_factor=desktop
gpu=intel
EOF

SETUP="$REPO/hyprveil setup"
LOCAL="$HYPRVEIL_CONFIG_HOME/hypr/local.conf"
APPS="$HYPRVEIL_CONFIG_HOME/hypr/apps.conf"
IDLE="$HYPRVEIL_CONFIG_HOME/hypr/hypridle.conf"

# A mock monitor dump for the detection path.
cat > "$TMP/monitors.json" <<'EOF'
[{"name":"DP-1","width":2560,"height":1440,"refreshRate":143.998,"x":0,"y":0,"scale":1.0,"transform":0,"focused":true},
 {"name":"HDMI-A-1","width":1920,"height":1080,"refreshRate":60.0,"x":2560,"y":0,"scale":1.0,"transform":0,"focused":false}]
EOF

# --- preview writes nothing --------------------------------------------------
rm -f "$LOCAL"
# shellcheck disable=SC2086
$SETUP --preview --monitor 'DP-1:2560x1440@144:0x0:1:primary' --kb-layout de >/dev/null
[ ! -f "$LOCAL" ] || fail "preview created local.conf"
ok "setup --preview reports the plan without writing anything"

# --- apply with flags renders every surface ----------------------------------
# shellcheck disable=SC2086
$SETUP --yes \
    --monitor 'DP-1:2560x1440@144:0x0:1:primary' \
    --monitor 'HDMI-A-1:1920x1080@60:2560x0:1' \
    --kb-layout de --kb-variant nodeadkeys \
    --terminal alacritty --browser chromium --file-manager thunar --editor nvim \
    --idle-lock 300 --idle-dpms 0 --idle-suspend 1800 >/dev/null

grep -q 'kb_layout = de' "$LOCAL" || fail "kb_layout not rendered"
grep -q 'kb_variant = nodeadkeys' "$LOCAL" || fail "kb_variant not rendered"
grep -q 'monitor = DP-1, 2560x1440@144, 0x0, 1' "$LOCAL" || fail "primary monitor line not rendered"
grep -q 'monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1' "$LOCAL" || fail "second monitor line not rendered"
grep -q '# primary display' "$LOCAL" || fail "primary marker missing"
grep -q 'terminal = alacritty' "$APPS" || fail "terminal not rendered"
grep -q 'browser = chromium' "$APPS" || fail "browser not rendered"
grep -q 'fileManager = thunar' "$APPS" || fail "file manager not rendered"
grep -q 'editor = nvim' "$APPS" || fail "editor not rendered"
grep -q 'timeout = 300' "$IDLE" || fail "lock idle timer not rendered"
grep -q 'timeout = 1800' "$IDLE" || fail "suspend idle timer not rendered"
grep -q 'dpms off' "$IDLE" && fail "disabled (0) dpms listener was still rendered"
ok "setup applies monitors, keyboard, apps, and idle timers from flags"

# --- state persisted under XDG state, private --------------------------------
[ -f "$HYPRVEIL_STATE_HOME/setup.conf" ] || fail "setup.conf state not written"
[ -f "$HYPRVEIL_STATE_HOME/monitors.tsv" ] || fail "monitors.tsv state not written"
perms=$(stat -c '%a' "$HYPRVEIL_STATE_HOME/setup.conf")
[ "$perms" = 600 ] || fail "setup.conf is not private (0600): $perms"
grep -q 'completed_at=' "$HYPRVEIL_STATE_HOME/setup.conf" || fail "completion timestamp not recorded"
ok "setup persists private state with a completion marker"

# --- re-running is safe and re-openable (no completion gate) ------------------
# shellcheck disable=SC2086
$SETUP --yes --kb-layout us >/dev/null
grep -q 'kb_layout = us' "$LOCAL" || fail "re-run did not update kb_layout"
grep -q 'monitor = DP-1' "$LOCAL" || fail "re-run dropped saved monitors"
ok "setup can be re-run and reuses saved monitors while updating changed values"

# --- cancellation leaves the deployment intact -------------------------------
before=$(sha256sum "$LOCAL" "$APPS" "$IDLE")
# Not a TTY and no --yes: the final confirmation reads 'n' from stdin.
# shellcheck disable=SC2086
printf 'n\n' | $SETUP --kb-layout fr --terminal foot >/dev/null || true
after=$(sha256sum "$LOCAL" "$APPS" "$IDLE")
[ "$before" = "$after" ] || fail "declining setup still modified the deployed config"
ok "declining setup leaves the deployed config unchanged"

# --- --ensure regenerates setup-owned files after a deploy reset -------------
printf 'clobbered by a fresh deploy\n' > "$LOCAL"
printf 'clobbered\n' > "$APPS"
# shellcheck disable=SC2086
$SETUP --ensure >/dev/null
grep -q 'kb_layout = us' "$LOCAL" || fail "--ensure did not regenerate local.conf from saved state"
grep -q 'monitor = DP-1' "$LOCAL" || fail "--ensure did not restore saved monitors"
grep -q 'terminal = alacritty' "$APPS" || fail "--ensure did not regenerate apps.conf"
ok "setup --ensure regenerates setup-owned files from saved state"

# --- update() re-applies setup state after a full deploy ---------------------
# A fresh deploy resets local.conf to the repository default; the update hook
# must call setup --ensure to bring the saved monitors back.
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"
hv_load_fedora >/dev/null 2>&1 || true
hv_deploy_configs >/dev/null
grep -q 'monitor = DP-1' "$LOCAL" && fail "deploy unexpectedly kept generated monitors"
"$REPO/scripts/10-first-run-setup.sh" --ensure >/dev/null
grep -q 'monitor = DP-1' "$LOCAL" || fail "setup --ensure did not survive a deploy reset"
ok "a deploy resets local.conf and the setup --ensure hook restores saved state"

# --- --ensure with no saved state is a quiet no-op ---------------------------
CLEAN=$(mktemp -d "$TMP/clean.XXXXXX")
HYPRVEIL_STATE_HOME="$CLEAN/state" HYPRVEIL_CONFIG_HOME="$CLEAN/config" \
    bash -c 'mkdir -p "$HYPRVEIL_CONFIG_HOME/hypr" "$HYPRVEIL_STATE_HOME"; exit 0'
out=$(HYPRVEIL_STATE_HOME="$CLEAN/state" HYPRVEIL_CONFIG_HOME="$CLEAN/config" \
    "$REPO/hyprveil" setup --ensure; echo "exit=$?")
printf '%s' "$out" | grep -q 'exit=0' || fail "--ensure without saved state did not exit 0"
[ ! -f "$CLEAN/config/hypr/local.conf" ] || fail "--ensure without saved state wrote local.conf"
ok "setup --ensure is a no-op when setup has never run"

# --- unattended first run adopts detected monitors ---------------------------
FRESH="$TMP/fresh"
mkdir -p "$FRESH/state" "$FRESH/config"
cp -a "$REPO/config/hypr" "$FRESH/config/hypr"
printf 'quickshell\n' > "$FRESH/state/notification-backend"
printf 'form_factor=desktop\ngpu=intel\n' > "$FRESH/state/hardware-profile.conf"
HYPRVEIL_STATE_HOME="$FRESH/state" HYPRVEIL_CONFIG_HOME="$FRESH/config" \
    HYPRVEIL_MONITORS_JSON="$TMP/monitors.json" \
    "$REPO/hyprveil" setup --yes >/dev/null
grep -q 'monitor = DP-1, 2560x1440@144, 0x0, 1' "$FRESH/config/hypr/local.conf" \
    || fail "unattended first run did not adopt detected monitors"
ok "unattended first run detects and adopts connected monitors"

# --- idle-timer defaults follow battery presence when nothing overrides them -
DESKTOP_SYS="$TMP/sys-no-battery"
mkdir -p "$DESKTOP_SYS/class/power_supply"
LAPTOP_SYS="$TMP/sys-battery"
mkdir -p "$LAPTOP_SYS/class/power_supply/BAT0"

NOBAT="$TMP/nobat"
mkdir -p "$NOBAT/state" "$NOBAT/config"
cp -a "$REPO/config/hypr" "$NOBAT/config/hypr"
printf 'quickshell\n' > "$NOBAT/state/notification-backend"
printf 'form_factor=desktop\ngpu=intel\n' > "$NOBAT/state/hardware-profile.conf"
HYPRVEIL_STATE_HOME="$NOBAT/state" HYPRVEIL_CONFIG_HOME="$NOBAT/config" \
    HYPRVEIL_SYSFS_ROOT="$DESKTOP_SYS" \
    "$REPO/hyprveil" setup --yes >/dev/null
grep -q 'timeout = 600' "$NOBAT/config/hypr/hypridle.conf" \
    || fail "no-battery default did not keep the desktop lock timeout"
grep -q 'timeout = 1800' "$NOBAT/config/hypr/hypridle.conf" \
    || fail "no-battery default did not keep the desktop suspend timeout"

BAT="$TMP/bat"
mkdir -p "$BAT/state" "$BAT/config"
cp -a "$REPO/config/hypr" "$BAT/config/hypr"
printf 'quickshell\n' > "$BAT/state/notification-backend"
printf 'form_factor=laptop\ngpu=intel\n' > "$BAT/state/hardware-profile.conf"
HYPRVEIL_STATE_HOME="$BAT/state" HYPRVEIL_CONFIG_HOME="$BAT/config" \
    HYPRVEIL_SYSFS_ROOT="$LAPTOP_SYS" \
    "$REPO/hyprveil" setup --yes >/dev/null
grep -q 'timeout = 300' "$BAT/config/hypr/hypridle.conf" \
    || fail "battery-detected default did not shorten the lock timeout"
grep -q 'timeout = 900' "$BAT/config/hypr/hypridle.conf" \
    || fail "battery-detected default did not shorten the suspend timeout"

# An explicit flag still wins over the battery-detected default.
BATFLAG="$TMP/batflag"
mkdir -p "$BATFLAG/state" "$BATFLAG/config"
cp -a "$REPO/config/hypr" "$BATFLAG/config/hypr"
printf 'quickshell\n' > "$BATFLAG/state/notification-backend"
printf 'form_factor=laptop\ngpu=intel\n' > "$BATFLAG/state/hardware-profile.conf"
HYPRVEIL_STATE_HOME="$BATFLAG/state" HYPRVEIL_CONFIG_HOME="$BATFLAG/config" \
    HYPRVEIL_SYSFS_ROOT="$LAPTOP_SYS" \
    "$REPO/hyprveil" setup --yes --idle-lock 1200 >/dev/null
grep -q 'timeout = 1200' "$BATFLAG/config/hypr/hypridle.conf" \
    || fail "explicit --idle-lock did not override the battery-detected default"
ok "idle-timer defaults shorten when a battery is detected, and flags still override them"

printf '\nP10 first-run setup smoke tests passed.\n'
