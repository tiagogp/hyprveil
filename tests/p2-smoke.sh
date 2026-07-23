#!/usr/bin/env bash
# Mocked, non-root checks for P2 backend selection, Waybar, and deployment.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p2.XXXXXX")
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

python3 - "$REPO" <<'PY' || fail "SwayNC or Waybar JSON does not parse"
import json, re, sys
repo = sys.argv[1]
json.load(open(f"{repo}/config/swaync/config.json"))
src = re.sub(r'^\s*//.*$', '', open(f"{repo}/config/waybar/config.jsonc").read(), flags=re.M)
json.loads(src)
PY
for urgency in low normal critical; do
    grep -q "\.notification\.$urgency" "$REPO/config/swaync/style.css" \
        || fail "missing $urgency urgency style"
done
grep -q 'clear-all-button.*true' < <(tr -d '\n' < "$REPO/config/swaync/config.json") \
    || fail "SwayNC clear-all control missing"
grep -q '"dnd"' "$REPO/config/swaync/config.json" || fail "SwayNC DND widget missing"
ok "SwayNC JSON, urgency treatments, clear-all, and DND are configured"

python3 - "$REPO" <<'PY' || fail "SwayNC control-center widgets are missing or malformed"
import json, sys
repo = sys.argv[1]
cfg = json.load(open(f"{repo}/config/swaync/config.json"))
for widget in ("mpris", "buttons-grid", "volume"):
    assert widget in cfg["widgets"], f"{widget} not enabled"
    assert widget in cfg["widget-config"], f"{widget} has no widget-config entry"
actions = cfg["widget-config"]["buttons-grid"]["actions"]
assert len(actions) >= 1, "buttons-grid has no actions"
for action in actions:
    assert action["label"], "buttons-grid action missing a label"
    assert action["command"], "buttons-grid action missing a command"
PY
for widget_class in widget-mpris widget-buttons-grid widget-volume widget-slider; do
    grep -q "\.$widget_class" "$REPO/config/swaync/style.css" \
        || fail "missing style for .$widget_class"
done
ok "SwayNC control-center widgets (mpris, buttons-grid, volume) and their styles are present"

for state in notification none dnd-notification dnd-none inhibited-notification \
             inhibited-none dnd-inhibited-notification dnd-inhibited-none; do
    grep -q "\"$state\"" "$REPO/config/waybar/config.jsonc" \
        || fail "Waybar icon state missing: $state"
done
grep -q 'notification.sh toggle' "$REPO/config/waybar/config.jsonc" || fail "Waybar left-click missing"
grep -q 'notification.sh dnd' "$REPO/config/waybar/config.jsonc" || fail "Waybar right-click missing"
grep -q 'swaync-client -swb' "$REPO/config/waybar/scripts/notification.sh" || fail "SwayNC stream is not used"
ok "Waybar covers empty, populated, DND, and inhibited states with both actions"

"$REPO/scripts/07-select-notification-backend.sh" --backend swaync >/dev/null
[ "$(cat "$HYPRVEIL_STATE_HOME/notification-backend")" = swaync ] || fail "SwayNC selection not saved"
before=$(sha256sum "$HYPRVEIL_STATE_HOME/notification-backend")
"$REPO/scripts/07-select-notification-backend.sh" --ensure >/dev/null
after=$(sha256sum "$HYPRVEIL_STATE_HOME/notification-backend")
[ "$before" = "$after" ] || fail "backend changed on ensure"
printf 'broken\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
"$REPO/scripts/07-select-notification-backend.sh" --backend mako >/dev/null 2>&1
find "$HYPRVEIL_STATE_HOME" -name 'notification-backend.invalid-*' -print -quit | grep -q . \
    || fail "malformed backend state was not preserved"
ok "backend choice persists and malformed state is preserved"

cat > "$TMP/os-release" <<'EOF'
ID=fedora
VERSION_ID=44
PRETTY_NAME="Fedora Linux 44 (Mock)"
EOF
cat > "$TMP/dnf" <<'EOF'
#!/usr/bin/env bash
set -eu
args=" $* "
if [[ "$args" == *" repolist --enabled "* ]]; then
    printf 'repo id repo name\nfedora Fedora\nupdates Updates\n'
elif [[ "$args" == *" repoquery "* ]]; then
    package=${!#}
    case "$package" in
        SwayNotificationCenter|quickshell) ;;
        *) printf 'fedora\n' ;;
    esac
elif [[ "$args" == *" copr enable "* ]]; then
    printf 'COPR MUTATION: %s\n' "$*" >> "$MOCK_ROOT/dnf-mutations"
elif [[ "$args" == *" install "* ]]; then
    printf 'INSTALL: %s\n' "$*" >> "$MOCK_ROOT/dnf-mutations"
fi
EOF
chmod +x "$TMP/dnf"
# Installer gates the Quickshell/SwayNC backends on rpm-verified packages; a hermetic
# "nothing installed" rpm forces the full decline path regardless of host binaries.
printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/rpm"
chmod +x "$TMP/bin/rpm"
rm -f "$HYPRVEIL_STATE_HOME/notification-backend" "$TMP/dnf-mutations"
# cli-ui.sh's confirm_action only honors read answers when stdin/stderr look like
# a real terminal (ui_is_interactive); over a plain pipe every hv_confirm would
# silently take its "no" default instead of the scripted answer. Route the
# installer through a pty (with TERM forced past bash's "dumb" default for a
# termcap-less environment) so it sees a real terminal, same as an interactive run.
# A real terminal also makes confirm_action delegate to gum if it finds one on
# PATH, so stand in for it with a scriptable confirm that reads the same
# answers instead of depending on (or hanging in) a host's real gum TUI.
cat > "$TMP/bin/gum" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = confirm ]; then
    read -r answer || answer=
    case "$answer" in
        y|Y|yes|YES|Yes) exit 0 ;;
        *) exit 1 ;;
    esac
fi
exit 1
EOF
chmod +x "$TMP/bin/gum"
cat > "$TMP/pty-runner.py" <<'PY'
import os, pty, sys

outfile = sys.argv[1]
argv = sys.argv[2:]

with open(outfile, "wb") as out:
    def read(fd):
        data = os.read(fd, 1024)
        out.write(data)
        out.flush()
        return data
    status = pty.spawn(argv, read)

sys.exit(os.waitstatus_to_exitcode(status))
PY
# Prompts: desktop-shell(y), decline Quickshell COPR(n), decline SwayNC COPR(n),
# accept Mako(y), then y for the remaining official groups, n for the fonts prompt.
answers=$'y\nn\nn\ny\ny\ny\ny\ny\ny\nn\n'
printf '%s' "$answers" | \
    HYPRVEIL_OS_RELEASE="$TMP/os-release" HYPRVEIL_DNF="$TMP/dnf" HYPRVEIL_NO_SUDO=1 \
    TERM=xterm \
    python3 "$TMP/pty-runner.py" "$TMP/installer-output" \
        "$REPO/scripts/02-install-fedora-shell.sh" \
    || fail "shell installer failed on the notification COPR refusal path"
[ "$(cat "$HYPRVEIL_STATE_HOME/notification-backend")" = mako ] \
    || fail "declining Quickshell and SwayNC did not select Mako"
grep -q 'declined COPR errornointernet/quickshell' "$TMP/installer-output" \
    || fail "Quickshell refusal was not explained"
grep -q 'declined COPR erikreider/SwayNotificationCenter' "$TMP/installer-output" \
    || fail "SwayNC refusal was not explained"
grep -q 'INSTALL: .* mako' "$TMP/dnf-mutations" || fail "Mako fallback was not installed"
if grep -q 'COPR MUTATION' "$TMP/dnf-mutations"; then
    fail "declining the notification COPRs changed repository state"
fi
rm -f "$TMP/bin/rpm"
ok "declining the Quickshell and SwayNC COPRs leaves repositories unchanged and selects Mako"

for command in swaync mako; do
    printf "#!/usr/bin/env bash\nprintf '%%s\\n' '%s' >> \"\$MOCK_ROOT/started\"\n" \
        "$command" > "$TMP/bin/$command"
    chmod +x "$TMP/bin/$command"
done
cat > "$TMP/bin/pkill" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/killed"
EOF
cat > "$TMP/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat > "$TMP/bin/swaync-client" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/client"
printf '{"text":"1","alt":"notification","class":"notification"}\n'
EOF
cat > "$TMP/bin/makoctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_ROOT/makoctl"
if [ "${1:-}" = mode ] && [ "$#" -eq 1 ] && [ "${MOCK_MAKO_DND:-0}" = 1 ]; then
    printf 'default\ndo-not-disturb\n'
fi
EOF
chmod +x "$TMP/bin/pkill" "$TMP/bin/pgrep" "$TMP/bin/swaync-client" "$TMP/bin/makoctl"

printf 'swaync\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
"$REPO/config/hypr/scripts/notification-daemon.sh" start
grep -qx -- '-x mako' "$TMP/killed" || fail "SwayNC startup did not stop Mako"
grep -qx swaync "$TMP/started" || fail "SwayNC did not start"

rm -f "$TMP/killed" "$TMP/started"
printf 'mako\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
"$REPO/config/hypr/scripts/notification-daemon.sh" start
grep -qx -- '-x swaync' "$TMP/killed" || fail "Mako startup did not stop SwayNC"
grep -qx mako "$TMP/started" || fail "Mako did not start"
ok "each backend stops the alternative and starts exactly one daemon"

printf 'swaync\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
render=$("$REPO/config/waybar/scripts/notification.sh" render)
printf '%s' "$render" | grep -q '"alt":"notification"' || fail "SwayNC Waybar stream not forwarded"
grep -qx -- '-swb' "$TMP/client" || fail "Waybar did not call swaync-client -swb"
"$REPO/config/waybar/scripts/notification.sh" toggle >/dev/null
"$REPO/config/waybar/scripts/notification.sh" dnd >/dev/null
grep -q -- '-t -sw' "$TMP/client" || fail "SwayNC center toggle missing"
grep -q -- '-d -sw' "$TMP/client" || fail "SwayNC DND toggle missing"

printf 'mako\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
render=$(MOCK_MAKO_DND=1 "$REPO/config/waybar/scripts/notification.sh" render)
printf '%s' "$render" | grep -q '"alt":"dnd-none"' || fail "Mako DND state not rendered"
MOCK_MAKO_DND=1 "$REPO/config/waybar/scripts/notification.sh" dnd
grep -q 'mode -t do-not-disturb' "$TMP/makoctl" || fail "Mako DND toggle missing"
ok "Waybar stream and actions consistently follow the selected backend"

# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"
printf 'swaync\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
mkdir -p "$HYPRVEIL_CONFIG_HOME/mako"
printf 'old fallback\n' > "$HYPRVEIL_CONFIG_HOME/mako/config"
hv_deploy_configs >/dev/null
[ -f "$HYPRVEIL_CONFIG_HOME/swaync/config.json" ] || fail "selected SwayNC config not deployed"
[ ! -e "$HYPRVEIL_CONFIG_HOME/mako" ] || fail "inactive Mako config survived deployment"

printf 'mako\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
hv_deploy_configs >/dev/null
[ -f "$HYPRVEIL_CONFIG_HOME/mako/config" ] || fail "selected Mako config not deployed"
[ ! -e "$HYPRVEIL_CONFIG_HOME/swaync" ] || fail "inactive SwayNC config survived deployment"
ok "deployment installs only the selected backend and backs up the inactive tree"

grep -q 'notification-daemon.sh start' "$REPO/config/hypr/autostart.conf" \
    || fail "notification launcher missing from autostart"
if grep -Eq '^exec-once = (mako|swaync)$' "$REPO/config/hypr/autostart.conf"; then
    fail "a daemon still autostarts directly"
fi
grep -q 'notification-daemon.sh toggle' "$REPO/config/hypr/keybindings.conf" \
    || fail "SUPER+N does not use backend-aware center toggle"
ok "startup and SUPER+N use the backend-aware helper"

printf 'P2 smoke tests passed.\n'
