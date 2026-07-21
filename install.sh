#!/usr/bin/env bash
# One-shot P0 installer. Repository and profile choices persist across reruns;
# managed configuration is backed up and replaced rather than merged.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

hv_banner "Fedora template installer"
hv_load_fedora
hv_check_supported_release || true
hv_show_enabled_repos
hv_note "Installs packages in stages, selects a persistent hardware profile,"
hv_note "reports dependencies, then offers to deploy the managed configuration."
hv_confirm "Continue?" || exit 0
PACKAGE_STAGE_FAIL=0

hv_step 0 "Backup existing configs"
"$REPO/scripts/00-backup.sh"

hv_step 1 "Hyprland core"
"$REPO/scripts/01-install-fedora-core.sh" || PACKAGE_STAGE_FAIL=1

hv_step 2 "Desktop shell"
"$REPO/scripts/02-install-fedora-shell.sh" || PACKAGE_STAGE_FAIL=1

hv_step 3 "Theming and shell environment"
"$REPO/scripts/04-install-fedora-theming.sh" || PACKAGE_STAGE_FAIL=1

hv_step 4 "Persistent hardware profile"
if [ -f "$HV_STATE_HOME/hardware-profile.conf" ]; then
    "$REPO/scripts/06-select-profile.sh" --ensure
else
    "$REPO/scripts/06-select-profile.sh"
fi

if [ -f "$HV_NOTIFICATION_STATE" ]; then
    "$REPO/scripts/07-select-notification-backend.sh" --ensure
fi

hv_step 5 "Dependency report before config copy"
PREFLIGHT_OK=1
"$REPO/scripts/09-dependency-report.sh" --preflight || PREFLIGHT_OK=0
[ "$PACKAGE_STAGE_FAIL" -eq 0 ] || PREFLIGHT_OK=0

hv_step 6 "Safe configuration deployment"
if [ "$PREFLIGHT_OK" -ne 1 ]; then
    echo "Required dependencies are unavailable. Configs were not copied."
    echo "Resolve the failures above, then rerun this installer."
    INSTALL_OK=0
elif hv_confirm "Back up and replace Hyprveil-managed config trees now?"; then
    hv_deploy_configs
    "$REPO/scripts/06-select-profile.sh" --ensure
    "$REPO/scripts/07-select-notification-backend.sh" --ensure
    "$HV_CONFIG_HOME/hypr/scripts/motion-profile.sh" --ensure
    # Deployment replaced every generated accent fragment with the default-red
    # copy committed to the repo. `render` rewrites them from the saved state,
    # so a wallpaper-derived accent survives a rerun; with no state yet it
    # simply re-renders the default, which is why it is safe on a fresh install.
    if [ -x "$HV_CONFIG_HOME/hypr/scripts/accent.sh" ]; then
        "$HV_CONFIG_HOME/hypr/scripts/accent.sh" render || true
    fi
    INSTALL_OK=1
else
    echo "Skipped configuration deployment; package and hardware-profile state were retained."
    INSTALL_OK=0
fi

hv_step 7 "Verify and reload"
if [ "$INSTALL_OK" -ne 1 ]; then
    echo "No configs were deployed in this run."
elif ! cmp -s "$REPO/config/hypr/hyprland.conf" "$HV_CONFIG_HOME/hypr/hyprland.conf"; then
    echo "FAIL: installed hyprland.conf does not match the managed template."
    INSTALL_OK=0
else
    hv_reload_live_session
fi

hv_section "Optional SDDM theme"
echo "SDDM changes system-wide login configuration and remains separately gated."
if hv_confirm "Run scripts/05-install-fedora-sddm.sh now?"; then
    "$REPO/scripts/05-install-fedora-sddm.sh"
fi

echo
echo "Installer finished. Run scripts/03-test-config.sh for the full validation report."
