pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property bool available: true
    property var state: ({ dnd: false })
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0
    signal dndRequested(bool enabled)

    function refresh(): void { lastUpdated = Date.now(); }
    function setDnd(enabled: bool): void {
        if (state.dnd === enabled) return;
        state = { dnd: enabled };
        lastUpdated = Date.now();
        dndRequested(enabled);
    }
    function toggleDnd(): void { setDnd(!state.dnd); }
}
