#!/usr/bin/env bash
# Report Fedora, package sources, and required/optional runtime dependencies.
# No -e: this script accumulates every missing dependency into one report
# instead of aborting at the first miss, so -e is deliberately left off.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

FAIL=0
MODE=${1:-report}

printf '== Hyprveil dependency report ==\n'
if hv_load_fedora; then
    printf 'Fedora: %s\n' "$HV_OS_NAME"
    hv_check_supported_release || true
    hv_show_enabled_repos || FAIL=1
else
    FAIL=1
fi

printf '\nDependencies:\n'
notification_backend=$(hv_notification_backend || true)
while IFS='|' read -r importance package command feature; do
    [ -n "$importance" ] || continue
    [[ "$importance" = \#* ]] && continue
    if [ "$importance" = backend ]; then
        case "$notification_backend:$package" in
            swaync:SwayNotificationCenter|mako:mako) importance=required ;;
            quickshell:quickshell) importance=required ;;
            *) continue ;;
        esac
    fi
    installed=no
    source=$(hv_package_source "$package" || true)
    if command -v "$command" >/dev/null 2>&1 \
        || { command -v rpm >/dev/null 2>&1 && rpm -q "$package" >/dev/null 2>&1; }; then
        installed=yes
        printf '  %-8s %-28s installed (%s)\n' "$importance" "$package" "$feature"
    elif [ "$source" != unavailable ]; then
        if [ "$MODE" = --preflight ] && [ "$importance" = required ]; then
            printf '  REQUIRED %-28s NOT INSTALLED — available from %s; install package %s\n' "$package" "$source" "$package"
            FAIL=1
        else
            printf '  %-8s %-28s available from %s; install package %s\n' "$importance" "$package" "$source" "$package"
        fi
    elif [ "$importance" = required ]; then
        printf '  REQUIRED %-28s UNAVAILABLE — %s cannot start; review enabled repos or the recorded COPR decision\n' "$package" "$feature"
        FAIL=1
    else
        printf '  optional %-28s unavailable — only %s is disabled\n' "$package" "$feature"
    fi
    if ! hv_source_recorded "$package"; then
        if [ "$installed" = yes ] && [ "$source" = unavailable ]; then
            hv_record_source "$package" installed "$feature"
        else
            hv_record_source "$package" "$source" "$feature"
        fi
    fi
done < "$REPO/scripts/data/dependencies.tsv"

if [ -n "$notification_backend" ]; then
    printf '\nNotification backend: %s\n' "$notification_backend"
else
    printf '\nNotification backend: not selected (run scripts/07-select-notification-backend.sh)\n'
    [ "$MODE" != --preflight ] || FAIL=1
fi

printf '\nChosen package sources:\n'
if [ -s "$HV_SOURCE_LOG" ]; then
    while IFS=$'\t' read -r package source feature; do
        printf '  %-28s %-24s %s\n' "$package" "$source" "$feature"
    done < "$HV_SOURCE_LOG"
else
    printf '  none recorded yet\n'
fi

if [ -f "$HV_STATE_HOME/hardware-profile.conf" ]; then
    form=$(awk -F= '$1 == "form_factor" {print $2}' "$HV_STATE_HOME/hardware-profile.conf")
    gpu=$(awk -F= '$1 == "gpu" {print $2}' "$HV_STATE_HOME/hardware-profile.conf")
    printf '\nHardware profile: %s / %s\n' "${form:-invalid}" "${gpu:-invalid}"
else
    printf '\nHardware profile: not selected (run scripts/06-select-profile.sh)\n'
    [ "$MODE" != --preflight ] || FAIL=1
fi

if [ "$FAIL" -ne 0 ]; then
    printf '\nDependency report FAILED. Resolve required items before copying configs.\n' >&2
    exit 1
fi
printf '\nDependency report passed; optional unavailable features may remain disabled.\n'
