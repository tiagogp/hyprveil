#!/usr/bin/env bash
# Stage 1: Fedora-aware Hyprland core installation.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$REPO/scripts/lib/install-common.sh"

hv_section "Stage 1: Fedora and repository detection"
hv_load_fedora
hv_check_supported_release || true
hv_show_enabled_repos

# Official Fedora repositories always win. solopasha/hyprland is offered only
# for individual required packages that the enabled official repos do not have.
STAGE_FAIL=0
hv_install_group required "Hyprland compositor" "solopasha/hyprland" hyprland || STAGE_FAIL=1

hv_install_group optional "Hyprland development headers" "solopasha/hyprland" hyprland-devel

hv_install_group required "core desktop utilities" - \
    kitty mate-polkit xdg-desktop-portal-hyprland qt5-qtwayland qt6-qtwayland || STAGE_FAIL=1

echo
hv_ok "Stage 1 complete. Package choices were recorded in $HV_SOURCE_LOG"
exit "$STAGE_FAIL"
