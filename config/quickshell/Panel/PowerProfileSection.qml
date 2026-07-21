// Laptop power profiles.
//
// The system service stays the source of truth. powerprofilesctl already knows
// which modes this machine exposes and why a mode might be unavailable; the
// shell only mirrors the list and asks for a new active profile on click.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Section {
    id: root

    glyph: "\u{f0241}"
    title: "Power"

    property string current: ""
    property var profiles: []
    property string status: "Checking power profiles..."

    readonly property var orderedProfiles: {
        const preferred = ["performance", "balanced", "power-saver"];
        const present = new Set(root.profiles);
        const ordered = preferred.filter(p => present.has(p));
        return ordered.concat(root.profiles.filter(p => preferred.indexOf(p) === -1).sort());
    }

    readonly property var labels: root.orderedProfiles.map(profile => {
        if (profile === "performance") return "Performance";
        if (profile === "balanced") return "Balanced";
        if (profile === "power-saver") return "Saver";
        return profile.replace(/-/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    })

    readonly property bool available: root.orderedProfiles.length > 0

    function refresh() {
        lister.running = true;
    }

    function parseProfiles(text) {
        const found = [];
        for (const line of text.split("\n")) {
            const match = line.match(/^\s*\*?\s*([a-z0-9-]+)\s*:/);
            if (match && found.indexOf(match[1]) === -1)
                found.push(match[1]);
        }
        return found;
    }

    Process {
        id: lister
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get && powerprofilesctl list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const active = lines.shift() ?? "";
                const listed = root.parseProfiles(lines.join("\n"));
                root.current = active.trim();
                root.profiles = listed;
                root.status = listed.length > 0 ? "" : "Power profiles unavailable";
            }
        }
    }

    Process {
        id: setter
        property string nextProfile: ""
        command: ["powerprofilesctl", "set", nextProfile]
        onRunningChanged: if (!running) root.refresh()
    }

    Component.onCompleted: root.refresh()

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        visible: !root.available
        text: root.status
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }

    Segmented {
        Layout.fillWidth: true
        visible: root.available
        options: root.labels
        values: root.orderedProfiles
        current: root.current
        accessibleName: "Power profile"
        onPicked: value => {
            if (value === root.current || setter.running)
                return;
            setter.nextProfile = value;
            setter.running = true;
        }
    }
}
