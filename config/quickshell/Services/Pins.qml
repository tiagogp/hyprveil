// The dock's pinned apps.
//
// State lives at $XDG_STATE_HOME/hyprveil/dock-pins.json, outside the config
// tree, because hv_deploy_configs replaces managed trees wholesale on upgrade
// and pins have to survive that. The schema is a flat array, unchanged from the
// shell implementation so dock-manager.sh's Rofi menu keeps working against the
// same file:
//
//     [ { "app_id": "kitty", "desktop_id": "kitty.desktop" }, ... ]
//
// The ten-slot pool the Waybar dock used is gone. It only existed because Waybar
// cannot render a dynamic list, and DOCK_LIMIT was that pool's size wearing a
// policy hat — a Repeater has no such ceiling.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Utils"

Singleton {
    id: root

    readonly property string path: Paths.stateHome + "/dock-pins.json"
    readonly property string scriptPath: Paths.hyprScripts + "/dock-manager.sh"

    property var pins: []
    property bool available: true
    readonly property var state: root.pins
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0
    property var catalog: []
    property int limit: 10

    function refresh(): void { file.reload(); }
    function refreshCatalog(): void { catalogue.running = true; }
    function set(desktopIds: var): void { Quickshell.execDetached([scriptPath, "set"].concat(desktopIds)); }
    function remove(id: string): void { if (id) Quickshell.execDetached([scriptPath, "remove", id]); }
    function move(id: string, position: int): void { if (id) Quickshell.execDetached([scriptPath, "move", id, String(position)]); }

    Process {
        id: catalogue
        command: [root.scriptPath, "entries"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.limit = parsed.limit ?? 10;
                    root.catalog = (parsed.entries ?? []).slice().sort((a, b) => a.name.localeCompare(b.name));
                    root.error = "";
                } catch (e) { root.catalog = []; root.error = "Could not read the application list"; }
                root.lastUpdated = Date.now();
            }
        }
    }

    FileView {
        id: file
        path: root.path
        // The Rofi pin manager and any future in-shell reorder both write this
        // file; watching it means the dock follows either without a signal.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { root.pins = root._parse(text()); root.error = ""; root.lastUpdated = Date.now(); }
        // A missing file is the first-run state, not an error.
        onLoadFailed: { root.pins = []; root.lastUpdated = Date.now(); }
    }

    // Rejects a malformed file rather than propagating it: a half-written array
    // would otherwise render as a dock with missing tiles and no explanation.
    // dock-lib.sh applies the same shape check before writing.
    function _parse(raw: string): var {
        try {
            const parsed = JSON.parse(raw);
            if (!Array.isArray(parsed)) return [];
            return parsed.filter(p => p && typeof p.app_id === "string" && p.app_id.length > 0);
        } catch (e) {
            console.warn("dock-pins.json is malformed; showing running windows only");
            return [];
        }
    }

    function desktopIdForApp(appId: string): string {
        const wanted = appId.toLowerCase();
        for (const pin of root.pins) {
            if ((pin.app_id ?? "").toLowerCase() === wanted)
                return pin.desktop_id ?? "";
        }
        return "";
    }
}
