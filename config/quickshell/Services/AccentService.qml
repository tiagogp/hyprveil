pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Utils"

Singleton {
    id: root
    readonly property string scriptPath: Paths.hyprScripts + "/accent.sh"
    readonly property string provider: Settings.appearance.accentProvider ?? "hyprveil"
    property bool initialized: false
    property bool available: true
    property var state: []
    readonly property bool busy: applier.running
    property string error: ""
    property double lastUpdated: 0

    function refresh(): void { presets.reload(); lastUpdated = Date.now(); }
    function applyPreset(name: string): void {
        if (!name || busy) return;
        applier.presetName = name;
        applier.running = true;
    }
    function reapplyFromWallpaper(provider: string): void {
        Quickshell.execDetached([Paths.hyprScripts + "/accent-provider.sh", provider]);
        lastUpdated = Date.now();
    }
    onProviderChanged: if (initialized) reapplyFromWallpaper(provider)
    Component.onCompleted: initialized = true
    FileView {
        id: presets
        path: Paths.hyprScripts + "/data/accent-presets.json"
        onLoaded: {
            try { root.state = JSON.parse(text()); root.error = ""; }
            catch (e) { root.state = []; root.error = "Accent presets could not be read"; }
            root.lastUpdated = Date.now();
        }
    }
    Process {
        id: applier
        property string presetName: ""
        command: [root.scriptPath, "preset", presetName]
        onRunningChanged: if (!running) root.lastUpdated = Date.now()
    }
}
