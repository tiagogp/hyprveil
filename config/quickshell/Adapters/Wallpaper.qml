pragma Singleton

import QtQuick
import Quickshell
import "../Utils"

Singleton {
    readonly property string scriptPath: Paths.hyprScripts + "/wallpaper.sh"
    property bool available: true
    property string state: "idle"
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0

    function refresh(): void { lastUpdated = Date.now(); }
    function apply(path: string, monitor: string, fit: string): void {
        if (!path || busy) return;
        busy = true;
        state = "applying";
        lastUpdated = Date.now();
        Quickshell.execDetached([scriptPath, "apply", path, monitor ?? "", fit ?? "cover"]);
        Qt.callLater(() => { busy = false; state = "idle"; lastUpdated = Date.now(); });
    }
    function restore(): void {
        if (busy) return;
        busy = true;
        state = "restoring";
        lastUpdated = Date.now();
        Quickshell.execDetached([scriptPath, "restore"]);
        Qt.callLater(() => { busy = false; state = "idle"; lastUpdated = Date.now(); });
    }
}
