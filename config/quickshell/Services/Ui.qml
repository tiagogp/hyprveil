pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property bool available: Settings.available
    readonly property var state: ({
        density: Settings.appearance.density ?? "comfortable",
        highContrast: Settings.accessibility.highContrast ?? false,
        largeTargets: Settings.accessibility.largeTargets ?? false
    })
    readonly property bool busy: Settings.busy
    readonly property string error: Settings.error
    readonly property double lastUpdated: Settings.lastUpdated

    readonly property bool compact: state.density === "compact"
    readonly property bool highContrast: state.highContrast
    readonly property bool largeTargets: state.largeTargets
    readonly property int controlHeight: largeTargets ? 48 : compact ? 36 : 40
    readonly property int iconButtonSize: largeTargets ? 48 : compact ? 36 : 40
    readonly property int rowHeight: largeTargets ? 52 : compact ? 40 : 44
    readonly property int rowHeightWithSubtitle: largeTargets ? 64 : compact ? 50 : 56
    readonly property int outlineWidth: highContrast ? 2 : 1

    function refresh(): void { Settings.refresh(); }
}
