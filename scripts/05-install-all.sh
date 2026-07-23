#!/usr/bin/env bash
# One-shot install + config: runs backup, all package stages (01-04), deploys the
# managed config trees, and applies/reloads the selected shell/backend.
#
# Safe to re-run. Every destructive step still asks before it acts; deployment
# backs up managed config trees before replacing them.
#
# Run from the repo root: ./scripts/05-install-all.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

echo "== hyprveil: full install + config =="
echo "This will: back up existing configs, run package install stages 1-3,"
echo "then deploy Hyprveil-managed configs into $HV_CONFIG_HOME."
read -r -p "Continue? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || exit 0

echo
echo "########## Step 0: backup ##########"
"$REPO/scripts/00-backup.sh"

echo
echo "########## Step 1: Hyprland core ##########"
"$REPO/scripts/01-install-fedora-core.sh"

echo
echo "########## Step 2: desktop shell ##########"
"$REPO/scripts/02-install-fedora-shell.sh"

echo
echo "########## Step 3: theming + shell env ##########"
"$REPO/scripts/04-install-fedora-theming.sh"

echo
echo "########## Step 4: deploy configs into $HV_CONFIG_HOME ##########"
read -r -p "Back up and replace Hyprveil-managed config trees now? [y/N] " ans2
if [[ "$ans2" == "y" || "$ans2" == "Y" ]]; then
    hv_deploy_configs
    "$REPO/scripts/06-select-profile.sh" --ensure
    "$REPO/scripts/07-select-notification-backend.sh" --ensure
    "$HV_CONFIG_HOME/hypr/scripts/motion-profile.sh" --ensure
    if [ -x "$HV_CONFIG_HOME/hypr/scripts/accent.sh" ]; then
        "$HV_CONFIG_HOME/hypr/scripts/accent.sh" render || true
    fi
    echo "Configs deployed."
else
    echo "Skipped config deployment."
fi

echo
echo "########## Step 5: reload ##########"
if [[ "$ans2" == "y" || "$ans2" == "Y" ]]; then
    hv_reload_live_session
else
    echo "No configs were deployed in this run."
fi

echo
echo "All done. Edit hypr/monitors.conf for your layout if you haven't already."
echo "Run scripts/03-test-config.sh any time to re-validate the installed configs."
