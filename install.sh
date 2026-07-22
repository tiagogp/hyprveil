#!/usr/bin/env bash
# Prompt-driven Hyprveil installer. The UI helpers live in scripts/lib/cli-ui.sh
# and are reusable from any Bash script in this repository.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

PACKAGE_STAGE_FAIL=0
PREFLIGHT_OK=1
INSTALL_OK=0

config_home_is_valid() {
    local value=$1 parent
    [ -n "$value" ] || return 1
    [[ "$value" = /* ]] || return 1
    parent=$(dirname "$value")
    [ -d "$value" ] || [ -w "$parent" ]
}

selected_contains() {
    local needle=$1 item
    shift
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

run_step() {
    local current=$1 total=$2 title=$3
    shift 3
    show_progress "$current" "$total" "$title"
    hv_step "$current" "$title"
    "$@"
}

print_header "Hyprveil installer" "Prompt-driven setup for the managed Fedora Hyprland environment."

hv_section "System requirements"
REQ_OK=1
check_dependency bash "Install Bash with your distribution package manager." || REQ_OK=0
if command -v gum >/dev/null 2>&1; then
    hv_ok "gum is available; interactive prompts will use enhanced controls"
else
    hv_warn "gum is not installed; using the built-in Bash prompt fallback"
    hv_note "Optional: sudo dnf install gum"
fi

hv_load_fedora
hv_check_supported_release || true
if command -v dnf >/dev/null 2>&1; then
    hv_show_enabled_repos
else
    hv_warn "dnf is unavailable; package components will be disabled unless dnf is installed"
fi

if [ "$REQ_OK" -ne 1 ]; then
    hv_bad "One or more required dependencies are missing."
    hv_note "Resolve the dependency errors above, then rerun ./install.sh."
    exit 1
fi

MODE=$(select_option "What would you like to do?" \
    "Full install" \
    "Configure only" \
    "Packages only")

case "$MODE" in
    "Full install")
        DEFAULT_COMPONENTS=(
            "Manual backup snapshot"
            "Hyprland core packages"
            "Desktop shell packages"
            "Theming packages"
            "Hardware profile"
            "Notification backend"
            "Dependency report"
            "Deploy managed configs"
            "Optional SDDM theme"
        )
        ;;
    "Configure only")
        DEFAULT_COMPONENTS=(
            "Manual backup snapshot"
            "Hardware profile"
            "Notification backend"
            "Dependency report"
            "Deploy managed configs"
            "Optional SDDM theme"
        )
        ;;
    "Packages only")
        DEFAULT_COMPONENTS=(
            "Hyprland core packages"
            "Desktop shell packages"
            "Theming packages"
            "Dependency report"
        )
        ;;
    *)
        hv_bad "Unknown install mode: $MODE"
        exit 2
        ;;
esac

COMPONENTS=()
while IFS= read -r component; do
    [ -n "$component" ] && COMPONENTS+=("$component")
done < <(select_multiple "Select components to run" "${DEFAULT_COMPONENTS[@]}")
if [ "${#COMPONENTS[@]}" -eq 0 ]; then
    hv_warn "No components selected."
    exit 0
fi

if selected_contains "Deploy managed configs" "${COMPONENTS[@]}"; then
    HV_CONFIG_HOME=$(ask_input \
        "Config home" \
        "$HV_CONFIG_HOME" \
        config_home_is_valid \
        "Enter an absolute path whose parent directory is writable.")
fi

if { selected_contains "Hyprland core packages" "${COMPONENTS[@]}" \
    || selected_contains "Desktop shell packages" "${COMPONENTS[@]}" \
    || selected_contains "Theming packages" "${COMPONENTS[@]}"; } \
    && ! command -v dnf >/dev/null 2>&1; then
    hv_bad "Package components require dnf."
    hv_note "Install dnf, or rerun ./install.sh and choose Configure only."
    exit 1
fi

hv_section "Summary"
printf '  %-22s %s\n' "Mode" "$MODE"
printf '  %-22s %s\n' "Repository" "$REPO"
printf '  %-22s %s\n' "State home" "$HV_STATE_HOME"
printf '  %-22s %s\n' "Config home" "$HV_CONFIG_HOME"
printf '  %-22s\n' "Components"
for component in "${COMPONENTS[@]}"; do
    printf '    - %s\n' "$component"
done

hv_note "Package stages may request sudo and can take several minutes."
confirm_action "Continue with this plan?" no || exit 0

TOTAL=${#COMPONENTS[@]}
CURRENT=0

if selected_contains "Manual backup snapshot" "${COMPONENTS[@]}"; then
    CURRENT=$((CURRENT + 1))
    show_progress "$CURRENT" "$TOTAL" "Manual backup snapshot"
    hv_step "$CURRENT" "Manual backup snapshot"
    run_with_spinner "Creating backup snapshot" "$REPO/scripts/00-backup.sh"
fi

if selected_contains "Hyprland core packages" "${COMPONENTS[@]}"; then
    CURRENT=$((CURRENT + 1))
    run_step "$CURRENT" "$TOTAL" "Hyprland core packages" "$REPO/scripts/01-install-fedora-core.sh" || PACKAGE_STAGE_FAIL=1
fi

if selected_contains "Desktop shell packages" "${COMPONENTS[@]}"; then
    CURRENT=$((CURRENT + 1))
    run_step "$CURRENT" "$TOTAL" "Desktop shell packages" "$REPO/scripts/02-install-fedora-shell.sh" || PACKAGE_STAGE_FAIL=1
fi

if selected_contains "Theming packages" "${COMPONENTS[@]}"; then
    CURRENT=$((CURRENT + 1))
    run_step "$CURRENT" "$TOTAL" "Theming packages" "$REPO/scripts/04-install-fedora-theming.sh" || PACKAGE_STAGE_FAIL=1
fi

if selected_contains "Hardware profile" "${COMPONENTS[@]}"; then
    CURRENT=$((CURRENT + 1))
    show_progress "$CURRENT" "$TOTAL" "Hardware profile"
    hv_step "$CURRENT" "Hardware profile"
    if [ -f "$HV_STATE_HOME/hardware-profile.conf" ]; then
        "$REPO/scripts/06-select-profile.sh" --ensure
    else
        "$REPO/scripts/06-select-profile.sh"
    fi
fi

if selected_contains "Notification backend" "${COMPONENTS[@]}"; then
    CURRENT=$((CURRENT + 1))
    show_progress "$CURRENT" "$TOTAL" "Notification backend"
    hv_step "$CURRENT" "Notification backend"
    if [ -f "$HV_NOTIFICATION_STATE" ]; then
        "$REPO/scripts/07-select-notification-backend.sh" --ensure
    else
        "$REPO/scripts/07-select-notification-backend.sh"
    fi
fi

if selected_contains "Dependency report" "${COMPONENTS[@]}"; then
    CURRENT=$((CURRENT + 1))
    show_progress "$CURRENT" "$TOTAL" "Dependency report"
    hv_step "$CURRENT" "Dependency report"
    "$REPO/scripts/09-dependency-report.sh" --preflight || PREFLIGHT_OK=0
fi

[ "$PACKAGE_STAGE_FAIL" -eq 0 ] || PREFLIGHT_OK=0

if selected_contains "Deploy managed configs" "${COMPONENTS[@]}"; then
    CURRENT=$((CURRENT + 1))
    show_progress "$CURRENT" "$TOTAL" "Deploy managed configs"
    hv_step "$CURRENT" "Deploy managed configs"
    if [ "$PREFLIGHT_OK" -ne 1 ]; then
        hv_bad "Required dependencies are unavailable. Configs were not copied."
        hv_note "Resolve the failures above, then rerun this installer."
        INSTALL_OK=0
    elif confirm_action "Back up and replace Hyprveil-managed config trees now?" yes; then
        run_with_spinner "Backing up and deploying managed configs" hv_deploy_configs
        "$REPO/scripts/06-select-profile.sh" --ensure
        "$REPO/scripts/07-select-notification-backend.sh" --ensure
        "$HV_CONFIG_HOME/hypr/scripts/motion-profile.sh" --ensure
        if [ -x "$HV_CONFIG_HOME/hypr/scripts/accent.sh" ]; then
            "$HV_CONFIG_HOME/hypr/scripts/accent.sh" render || true
        fi
        INSTALL_OK=1
    else
        hv_warn "Skipped configuration deployment; package and profile state were retained."
        INSTALL_OK=0
    fi
fi

if selected_contains "Deploy managed configs" "${COMPONENTS[@]}"; then
    hv_step "$((TOTAL + 1))" "Verify and reload"
    if [ "$INSTALL_OK" -ne 1 ]; then
        hv_warn "No configs were deployed in this run."
    elif ! cmp -s "$REPO/config/hypr/hyprland.conf" "$HV_CONFIG_HOME/hypr/hyprland.conf"; then
        hv_bad "Installed hyprland.conf does not match the managed template."
        INSTALL_OK=0
    else
        hv_reload_live_session
    fi
fi

if selected_contains "Optional SDDM theme" "${COMPONENTS[@]}"; then
    CURRENT=$((CURRENT + 1))
    show_progress "$CURRENT" "$TOTAL" "Optional SDDM theme"
    hv_section "Optional SDDM theme"
    hv_note "SDDM changes system-wide login configuration and remains separately gated."
    if hv_confirm_no "Run scripts/05-install-fedora-sddm.sh now?"; then
        "$REPO/scripts/05-install-fedora-sddm.sh"
    fi
fi

hv_section "Result"
if [ "$PACKAGE_STAGE_FAIL" -ne 0 ]; then
    hv_bad "Installer finished with package-stage failures."
    hv_note "Review the failed package messages above, fix repository or dependency issues, then rerun ./install.sh."
    exit 1
fi
if selected_contains "Deploy managed configs" "${COMPONENTS[@]}" && [ "$INSTALL_OK" -ne 1 ]; then
    hv_warn "Installer finished without deploying configs."
else
    hv_ok "Installer finished successfully."
fi
hv_note "Run scripts/03-test-config.sh for the full validation report."
