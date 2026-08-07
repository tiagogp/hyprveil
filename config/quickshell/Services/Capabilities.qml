// The capability model: what optional integrations are actually usable right
// now, read from the one script that knows (doctor.sh) rather than a second
// probe living in QML that could disagree with it.
//
// This is what "Sistema > Integrações" in Quick Settings renders, and it is
// also why a missing dependency elsewhere in the shell (no backlight, no
// ddcutil, no hyprsunset) is a hidden row instead of a dead control: the
// pattern this singleton exists to generalize was already correct in
// NightLightSection and Brightness.qml before this file existed.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Utils"

Singleton {
    id: root

    readonly property string scriptPath: Paths.hyprScripts + "/doctor.sh"

    // [{ id, label, available, degraded, hint }]
    property var rows: []
    property bool loading: false
    property bool available: true
    readonly property var state: root.rows
    readonly property bool busy: root.loading
    property string error: ""
    property double lastUpdated: 0

    readonly property int availableCount: rows.filter(r => r.available).length
    readonly property int degradedCount: rows.filter(r => r.degraded).length
    readonly property int missingCount:
        rows.filter(r => !r.available && !r.degraded).length

    function refresh(): void {
        root.loading = true;
        probe.running = true;
    }

    Process {
        id: probe
        command: [root.scriptPath, "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    root.rows = JSON.parse(text);
                    root.error = "";
                } catch (e) {
                    root.rows = [];
                    root.error = "Capability report could not be parsed";
                }
                root.lastUpdated = Date.now();
            }
        }
    }

    // Probed once at startup — hardware and installed packages do not change
    // under a running session, so this is the same "probe once" contract as
    // Brightness.available. The panel row still offers a manual refresh for
    // right after installing something the doctor was missing.
    Component.onCompleted: root.refresh()
}
