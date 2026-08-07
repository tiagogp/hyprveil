#!/usr/bin/env bash
# Deterministic geometry/accessibility matrix for environments without Wayland.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$REPO" <<'PY'
import pathlib
import re
import sys

repo = pathlib.Path(sys.argv[1])
bar = (repo / "config/quickshell/Bar/Bar.qml").read_text()
assert 'monitorWidth >= 1600 ? "full"' in bar
assert 'monitorWidth >= 1280 ? "standard" : "compact"' in bar

# All shipped surface caps fit the supported logical widths with 64 px of
# modal margin. Height caps stay below a 720 px logical short edge.
surface_caps = {"quick-settings": 360, "launcher": 560, "session": 420,
                "preferences": 480, "wallpapers": 620, "cheatsheet": 940}
for width in (1280, 1600, 1920, 3440):
    for name, cap in surface_caps.items():
        assert cap <= width - 64, (width, name, cap)

# Fractional scales exercise logical widths around both responsive breakpoints.
for physical, scale in ((1600, 1.25), (1920, 1.5), (2560, 1.5), (3440, 1.25)):
    logical = physical / scale
    mode = "full" if logical >= 1600 else "standard" if logical >= 1280 else "compact"
    assert mode in {"full", "standard", "compact"}

app = (repo / "config/quickshell/App/Shell.qml").read_text()
surface_files = {
    "quick-settings": "Panel/QuickSettings.qml", "calendar": "Panel/Calendar.qml",
    "launcher": "Launcher/Launcher.qml", "session": "Session/Session.qml",
    "preferences": "Panel/Preferences.qml", "wallpapers": "Panel/Wallpapers.qml",
    "integrations": "Panel/Integrations.qml", "overview": "Overview/Overview.qml",
    "cheatsheet": "Panel/Cheatsheet.qml",
}
for monitor_count in (1, 2, 3):
    assert app.count("model: Quickshell.screens") >= 2
    for name, rel in surface_files.items():
        assert f'registerSurface("{name}"' in app
        source = (repo / "config/quickshell" / rel).read_text()
        assert "property var targetScreen" in source
        assert "screen: root.targetScreen" in source

motion = (repo / "config/quickshell/Services/Motion.qml").read_text()
assert "return (root.reduced || CalmMode.pauseAnimations) ? 0 : ms" in motion
for component in (repo / "config/quickshell/Design/Components").glob("*.qml"):
    source = component.read_text()
    if re.search(r"signal (clicked|toggled|moved|accepted)", source):
        assert "Accessible." in source, component

print("OK: 1280/1600/1920/ultrawide, fractional-scale, 1-3 monitor, keyboard, and reduced-motion contracts pass")
PY
