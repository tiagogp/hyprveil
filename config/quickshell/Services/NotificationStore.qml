pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/notification-store.sh"
    property bool available: true
    property var state: []
    readonly property bool busy: loader.running
    property string error: ""
    property double lastUpdated: 0
    function refresh(): void { loader.running = true; }
    function append(app: string, summary: string, image: string, urgency: string): void {
        Quickshell.execDetached([scriptPath, "append", app, summary, image, urgency]);
        lastUpdated = Date.now();
    }
    function remove(sid: string): void {
        state = state.filter(row => row.sid !== sid);
        Quickshell.execDetached([scriptPath, "remove", sid]);
        lastUpdated = Date.now();
    }
    function clear(): void {
        state = [];
        Quickshell.execDetached([scriptPath, "clear"]);
        lastUpdated = Date.now();
    }
    Process {
        id: loader
        command: [root.scriptPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.state = JSON.parse(text).reverse(); root.error = ""; }
                catch (e) { root.state = []; root.error = "Notification history could not be read"; }
                root.lastUpdated = Date.now();
            }
        }
    }
}
