pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Utils"

Singleton {
    id: root
    readonly property string scriptPath: Paths.hyprScripts + "/scenes.sh"
    property bool available: true
    property var state: []
    readonly property bool busy: lister.running
    property string error: ""
    property double lastUpdated: 0

    function refresh(): void { lister.running = true; }
    function run(args: var): void {
        Quickshell.execDetached([scriptPath].concat(args));
        refreshTimer.restart();
    }
    Process {
        id: lister
        command: [root.scriptPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.state = JSON.parse(text); root.error = ""; }
                catch (e) { root.state = []; root.error = "Scenes could not be read"; }
                root.lastUpdated = Date.now();
            }
        }
    }
    Timer { id: refreshTimer; interval: 200; onTriggered: root.refresh() }
}
