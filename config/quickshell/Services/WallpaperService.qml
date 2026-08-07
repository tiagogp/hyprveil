pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Adapters"

Singleton {
    id: root
    property bool available: WallpaperAdapter.available
    property var state: ({ dir: "", images: [], outputs: [] })
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0

    function refresh(): void { busy = true; error = ""; lister.running = true; }
    function apply(path: string, monitor: string, fit: string): void {
        WallpaperAdapter.apply(path, monitor, fit);
        lastUpdated = Date.now();
    }

    Process {
        id: lister
        command: [WallpaperAdapter.scriptPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                root.lastUpdated = Date.now();
                try { root.state = JSON.parse(text); }
                catch (e) { root.error = "Could not read the wallpaper list"; root.state = { dir: "", images: [], outputs: [] }; }
            }
        }
    }
}
