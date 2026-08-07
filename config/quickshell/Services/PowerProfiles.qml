pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property bool available: state.profiles.length > 0
    property var state: ({ current: "", profiles: [] })
    readonly property bool busy: lister.running || setter.running
    property string error: ""
    property double lastUpdated: 0
    function refresh(): void { lister.running = true; }
    function setProfile(profile: string): void {
        if (!available || busy || profile === state.current) return;
        setter.nextProfile = profile; setter.running = true;
    }
    Process {
        id: lister
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get && powerprofilesctl list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const active = (lines.shift() ?? "").trim();
                const found = [];
                for (const line of lines) {
                    const match = line.match(/^\s*\*?\s*([a-z0-9-]+)\s*:/);
                    if (match && found.indexOf(match[1]) < 0) found.push(match[1]);
                }
                root.state = { current: active, profiles: found };
                root.error = found.length ? "" : "Power profiles unavailable";
                root.lastUpdated = Date.now();
            }
        }
    }
    Process { id: setter; property string nextProfile: ""; command: ["powerprofilesctl", "set", nextProfile]; onRunningChanged: if (!running) root.refresh() }
    Component.onCompleted: refresh()
}
