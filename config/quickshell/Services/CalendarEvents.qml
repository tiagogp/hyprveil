pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/calendar-events.sh"
    property bool available: true
    property var state: []
    readonly property bool busy: loader.running
    property string error: ""
    property double lastUpdated: 0
    function refresh(): void { loader.running = true; }
    Process {
        id: loader
        command: [root.scriptPath, "upcoming", "3"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.state = JSON.parse(text); root.error = ""; }
                catch (e) { root.state = []; root.error = "Calendar source unavailable"; }
                root.lastUpdated = Date.now();
            }
        }
    }
}
