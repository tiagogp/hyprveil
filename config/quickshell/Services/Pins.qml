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

Singleton {
    id: root

    readonly property string path:
        (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state")
        + "/hyprveil/dock-pins.json"

    property var pins: []

    FileView {
        id: file
        path: root.path
        // The Rofi pin manager and any future in-shell reorder both write this
        // file; watching it means the dock follows either without a signal.
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.pins = root._parse(text())
        // A missing file is the first-run state, not an error.
        onLoadFailed: root.pins = []
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
