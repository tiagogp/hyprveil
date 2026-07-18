#!/usr/bin/env bash
# Stage 1 packages only: Hyprland core + terminal + basics needed for it to launch.
# Review before running — sudo lines are separate so you can inspect each.
set -euo pipefail

echo "== Enabling Hyprland COPR (needs sudo) =="
echo "Run manually if you'd rather review first:"
echo "  sudo dnf copr enable solopasha/hyprland"
echo "  sudo dnf install -y hyprland hyprland-devel"
read -p "Run these two now? [y/N] " ans
if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    sudo dnf copr enable solopasha/hyprland
    sudo dnf install -y hyprland hyprland-devel
fi

echo "== Core utilities (no COPR needed) =="
echo "  sudo dnf install -y kitty polkit-gnome xdg-desktop-portal-hyprland qt5-qtwayland qt6-qtwayland"
read -p "Run this now? [y/N] " ans2
if [[ "$ans2" == "y" || "$ans2" == "Y" ]]; then
    sudo dnf install -y kitty polkit-gnome xdg-desktop-portal-hyprland qt5-qtwayland qt6-qtwayland
fi

echo "== hyprland-qtutils =="
echo "As of Fedora's Qt 6.10 update, the COPR's hyprland-qt-support/hyprland-qtutils"
echo "builds still target Qt 6.9's private API, so 'dnf install hyprland-qtutils' fails"
echo "with an unresolvable libQt6Core.so.6(Qt_6.9_PRIVATE_API) dependency until the COPR"
echo "rebuilds. Rebuilding both SRPMs locally against your installed Qt 6.10 fixes it."
read -p "Rebuild and install hyprland-qt-support + hyprland-qtutils from SRPM now? [y/N] " ans3
if [[ "$ans3" == "y" || "$ans3" == "Y" ]]; then
    sudo dnf install -y rpm-build rpmdevtools cmake gcc-c++ qt6-rpm-macros \
        qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel \
        hyprlang-devel hyprutils-devel wayland-devel
    rpmdev-setuptree
    SRPM_DIR="$(mktemp -d)"
    dnf download --disablerepo='*' --enablerepo='copr:copr.fedorainfracloud.org:solopasha:hyprland' \
        --source hyprland-qt-support hyprland-qtutils --destdir "$SRPM_DIR"
    rpm -ivh "$SRPM_DIR"/hyprland-qt-support-*.src.rpm "$SRPM_DIR"/hyprland-qtutils-*.src.rpm
    rpmbuild -bb ~/rpmbuild/SPECS/hyprland-qt-support.spec
    rpmbuild -bb ~/rpmbuild/SPECS/hyprland-qtutils.spec
    sudo dnf install -y ~/rpmbuild/RPMS/x86_64/hyprland-qt-support-[0-9]*.x86_64.rpm \
        ~/rpmbuild/RPMS/x86_64/hyprland-qtutils-[0-9]*.x86_64.rpm
    rm -rf "$SRPM_DIR"
fi

echo "Stage 1 install step done. Next stages (waybar, rofi, mako, hyprlock, etc.) come separately."
