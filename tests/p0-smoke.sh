#!/usr/bin/env bash
# Mocked, non-root checks for P0 detection, COPR refusal, profiles, and reruns.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/hyprveil-p0.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
ok() { printf 'OK: %s\n' "$*"; }

cat > "$TMP/os-release" <<'EOF'
ID=fedora
VERSION_ID=44
PRETTY_NAME="Fedora Linux 44 (Mock)"
EOF

cat > "$TMP/dnf" <<'EOF'
#!/usr/bin/env bash
set -eu
root=${MOCK_DNF_ROOT:?}
args=" $* "
if [[ "$args" == *" repolist --enabled "* ]]; then
    printf 'repo id repo name\nfedora Fedora\nupdates Updates\n'
    [ ! -f "$root/copr-enabled" ] || printf 'copr:copr.fedorainfracloud.org:solopasha:hyprland COPR\n'
elif [[ "$args" == *" repoquery "* ]]; then
    package=${!#}
    case "$package" in
        official-package) printf 'copr:third:party\nupdates\n' ;;
        fallback-package)
            [ ! -f "$root/copr-enabled" ] || printf 'copr:copr.fedorainfracloud.org:solopasha:hyprland\n'
            ;;
        *) printf 'fedora\n' ;;
    esac
elif [[ "$args" == *" copr enable "* ]]; then
    touch "$root/copr-enabled"
    printf '%s\n' "$*" >> "$root/mutations"
elif [[ "$args" == *" install "* ]]; then
    printf '%s\n' "$*" >> "$root/mutations"
fi
EOF
chmod +x "$TMP/dnf"

export HOME="$TMP/home"
export HYPRVEIL_OS_RELEASE="$TMP/os-release"
export HYPRVEIL_DNF="$TMP/dnf"
export HYPRVEIL_STATE_HOME="$TMP/state"
export HYPRVEIL_CONFIG_HOME="$TMP/config"
export HYPRVEIL_NO_SUDO=1
export MOCK_DNF_ROOT="$TMP"
export PATH="$TMP/bin:$PATH"
mkdir -p "$HOME" "$HYPRVEIL_CONFIG_HOME" "$TMP/bin"

cat > "$TMP/bin/Hyprland" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = --verify-config ]; then
    exit 0
fi
exit 0
EOF
chmod +x "$TMP/bin/Hyprland"
for command in kitty polkit-mate-authentication-agent-1 xdg-desktop-portal-hyprland \
               rofi notify-send quickshell hyprlock hypridle hyprpaper wlogout \
               gio gtk-launch; do
    ln -s Hyprland "$TMP/bin/$command"
done

# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"
hv_load_fedora
[ "$HV_FEDORA_VERSION" = 44 ] || fail "Fedora version detection"
hv_check_supported_release
ok "Fedora 44 detection and support policy"

source=$(hv_package_source official-package)
[ "$source" = updates ] || fail "official repo was not preferred over third-party repo: $source"
ok "official package source preference"

printf 'n\n' | hv_enable_copr solopasha/hyprland "mock optional feature" && fail "COPR refusal returned success"
[ ! -e "$TMP/copr-enabled" ] || fail "COPR refusal changed repository state"
[ ! -e "$TMP/mutations" ] || fail "COPR refusal invoked a mutating dnf command"
ok "declining COPR leaves repository state unchanged"

touch "$TMP/copr-enabled"
hv_enable_copr solopasha/hyprland "already approved mock" >/dev/null
[ ! -e "$TMP/mutations" ] || fail "rerun duplicated an already-enabled COPR"
rm -f "$TMP/copr-enabled"
ok "rerun does not duplicate an enabled COPR"

HYPRVEIL_ASSUME_YES=1 hv_install_group required "mock official feature" \
    solopasha/hyprland official-package >/dev/null
grep -q -- '--enable-repo=updates' "$TMP/mutations" || fail "official install was not pinned to official enabled repos"
grep -q -- '--enable-repo=copr' "$TMP/mutations" && fail "official install enabled a COPR source"
rm -f "$TMP/mutations"
ok "official package installation excludes third-party repositories"

cp -a "$REPO/config/hypr" "$HYPRVEIL_CONFIG_HOME/hypr"
"$REPO/scripts/06-select-profile.sh" --form-factor laptop --gpu amd >/dev/null
profile_before=$(sha256sum "$HYPRVEIL_STATE_HOME/hardware-profile.conf")
"$REPO/scripts/06-select-profile.sh" --ensure >/dev/null
profile_after=$(sha256sum "$HYPRVEIL_STATE_HOME/hardware-profile.conf")
[ "$profile_before" = "$profile_after" ] || fail "profile changed on ensure/rerun"
grep -q 'form-factor/laptop.conf' "$HYPRVEIL_CONFIG_HOME/hypr/profiles/active.conf" || fail "laptop include missing"
grep -q 'gpu/amd.conf' "$HYPRVEIL_CONFIG_HOME/hypr/profiles/active.conf" || fail "AMD include missing"
ok "hardware profile persists unchanged on rerun"

printf 'old wallpaper\n' > "$HYPRVEIL_CONFIG_HOME/hypr/wallpaper.jpg"
printf 'stale\n' > "$HYPRVEIL_CONFIG_HOME/hypr/stale-managed.conf"
mkdir -p "$HYPRVEIL_STATE_HOME"
printf '{"pins":[]}\n' > "$HYPRVEIL_STATE_HOME/dock-pins.json"
hv_deploy_configs >/dev/null
[ ! -e "$HYPRVEIL_CONFIG_HOME/hypr/stale-managed.conf" ] || fail "stale managed file survived replacement"
grep -q 'old wallpaper' "$HYPRVEIL_CONFIG_HOME/hypr/wallpaper.jpg" || fail "wallpaper was not preserved"
grep -q 'pins' "$HYPRVEIL_STATE_HOME/dock-pins.json" || fail "persistent state was overwritten"
find "$HYPRVEIL_STATE_HOME/backups" -path '*/config/hypr/stale-managed.conf' -print -quit | grep -q . \
    || fail "existing config was not timestamp-backed-up"
ok "rerun removes stale files while preserving backup, wallpaper, and state"

"$REPO/scripts/06-select-profile.sh" --ensure >/dev/null
grep -q 'form-factor/laptop.conf' "$HYPRVEIL_CONFIG_HOME/hypr/profiles/active.conf" || fail "profile not restored after deploy"
ok "saved profile restored after clean config replacement"

mkdir -p "$TMP/empty-sys/class/backlight" "$TMP/empty-sys/class/power_supply"
HYPRVEIL_SYSFS_ROOT="$TMP/empty-sys" "$REPO/config/hypr/scripts/hardware-action.sh" brightness-up
battery_output=$(HYPRVEIL_SYSFS_ROOT="$TMP/empty-sys" "$REPO/config/waybar/scripts/battery.sh")
printf '%s' "$battery_output" | grep -q '"text":""' || fail "battery module did not hide without a battery"
ok "absent brightness and battery hardware is handled safely"

report=$("$REPO/scripts/09-dependency-report.sh")
printf '%s' "$report" | grep -q 'Fedora: Fedora Linux 44 (Mock)' || fail "dependency report omitted Fedora version"
printf '%s' "$report" | grep -q 'Chosen package sources:' || fail "dependency report omitted package sources"
ok "dependency report includes Fedora version and package sources"

printf 'quickshell\n' > "$HYPRVEIL_STATE_HOME/notification-backend"
printf 'standard\n' > "$HYPRVEIL_STATE_HOME/motion-profile"
printf '[]\n' > "$HYPRVEIL_STATE_HOME/dock-pins.json"
cat > "$HYPRVEIL_STATE_HOME/wallpapers.json" <<EOF
{"version":1,"fallback":{"path":"$HYPRVEIL_CONFIG_HOME/hypr/wallpaper-default.jpg","fit":"cover"},"monitors":{}}
EOF
cat > "$HYPRVEIL_STATE_HOME/accent.json" <<'EOF'
{"version":1,"accent":"#e14658","source":"default","auto":true,"chromeAlpha":"0.87"}
EOF
doctor=$("$REPO/hyprveil" doctor)
printf '%s' "$doctor" | grep -q 'Fedora Linux 44 (Mock) is supported' || fail "doctor omitted Fedora support"
printf '%s' "$doctor" | grep -q 'notification backend: quickshell' || fail "doctor omitted notification backend"
printf '%s' "$doctor" | grep -q 'Doctor found no failures' || fail "doctor did not complete a clean mocked report"
ok "doctor reports Fedora, dependencies, shell, and state in a mocked install"

printf '{broken json\n' > "$HYPRVEIL_STATE_HOME/wallpapers.json"
wallpaper_before=$(sha256sum "$HYPRVEIL_STATE_HOME/wallpapers.json")
doctor_status=0
doctor_bad=$("$REPO/hyprveil" doctor 2>&1) || doctor_status=$?
[ "$doctor_status" -ne 0 ] || fail "doctor succeeded with malformed wallpaper state"
printf '%s' "$doctor_bad" | grep -q 'wallpaper state is malformed' || fail "doctor did not explain malformed wallpaper state"
printf '%s' "$doctor_bad" | grep -q 'wallpaper.sh restore' || fail "doctor did not print wallpaper recovery command"
wallpaper_after=$(sha256sum "$HYPRVEIL_STATE_HOME/wallpapers.json")
[ "$wallpaper_before" = "$wallpaper_after" ] || fail "doctor modified malformed wallpaper state"
ok "doctor detects malformed state without modifying it"

printf 'not-a-profile\n' > "$HYPRVEIL_STATE_HOME/hardware-profile.conf"
"$REPO/scripts/06-select-profile.sh" --form-factor desktop --gpu intel >/dev/null 2>&1
find "$HYPRVEIL_STATE_HOME" -name 'hardware-profile.conf.invalid-*' -print -quit | grep -q . \
    || fail "malformed profile was not preserved"
ok "malformed profile state is preserved before recovery"

printf 'P0 smoke tests passed.\n'
