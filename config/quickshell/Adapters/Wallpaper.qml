pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh"
    property bool available: true
    property string state: "idle"
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0

    function refresh(): void { lastUpdated = Date.now(); }
    function apply(path: string, monitor: string, fit: string): void {
        if (!path || busy) return;
        state = "applying";
        lastUpdated = Date.now();
        Quickshell.execDetached([scriptPath, "apply", path, monitor ?? "", fit ?? "cover"]);
    }
    function restore(): void {
        state = "restoring";
        lastUpdated = Date.now();
        Quickshell.execDetached([scriptPath, "restore"]);
    }
}
