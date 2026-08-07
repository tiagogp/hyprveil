pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Utils"

Singleton {
    id: root
    readonly property string scriptPath: Paths.hyprScripts + "/nightlight.sh"
    readonly property bool available: state !== "missing"
    property string state: "off"
    readonly property bool busy: checker.running || setter.running
    property string error: ""
    property double lastUpdated: 0
    function refresh(): void { checker.running = true; }
    function setEnabled(value: bool): void {
        if (!available || busy || state === (value ? "on" : "off")) return;
        setter.nextState = value ? "on" : "off";
        setter.running = true;
    }
    Process { id: checker; command: [root.scriptPath, "status"]; stdout: StdioCollector { onStreamFinished: { root.state = text.trim(); root.lastUpdated = Date.now(); } } }
    Process { id: setter; property string nextState: "off"; command: [root.scriptPath, nextState]; onRunningChanged: if (!running) root.refresh() }
    Component.onCompleted: refresh()
}
