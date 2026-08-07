pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Adapters"

Singleton {
    id: root
    readonly property bool available: WallpaperAdapter.available
        && (Settings.providers.wallpaper ?? "hyprpaper") === "hyprpaper"
    property var state: ({ dir: "", images: [], outputs: [] })
    property bool listing: false
    readonly property bool busy: listing || WallpaperAdapter.busy
    property string error: ""
    property double lastUpdated: 0

    function refresh(): void { listing = true; error = ""; lister.running = true; }
    function apply(path: string, monitor: string, fit: string): void {
        WallpaperAdapter.apply(path, monitor, fit);
        lastUpdated = Date.now();
    }

    Process {
        id: lister
        command: [WallpaperAdapter.scriptPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.listing = false;
                root.lastUpdated = Date.now();
                try { root.state = JSON.parse(text); }
                catch (e) { root.error = "Could not read the wallpaper list"; root.state = { dir: "", images: [], outputs: [] }; }
            }
        }
    }
}
