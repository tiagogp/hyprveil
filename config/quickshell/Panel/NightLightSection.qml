// Night light, toggling the hyprsunset daemon via nightlight.sh.
//
// No separate service singleton: like PowerProfileSection, the system tool
// (hyprsunset via nightlight.sh) stays the source of truth and this just
// mirrors its running/not-running state and asks for a change on click.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Section {
    id: root

    glyph: "\u{f0599}"
    title: "Night Light"

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/nightlight.sh"
    // "on" | "off" | "missing" (hyprsunset not installed)
    property string state: "off"
    readonly property bool available: root.state !== "missing"

    function refresh() {
        checker.running = true;
    }

    Process {
        id: checker
        command: [root.scriptPath, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.state = text.trim()
        }
    }

    Process {
        id: setter
        property string nextState: "off"
        command: [root.scriptPath, nextState]
        onRunningChanged: if (!running) root.refresh()
    }

    Component.onCompleted: root.refresh()

    Toggle {
        Layout.alignment: Qt.AlignRight
        visible: root.available
        accessibleName: "Night Light"
        checked: root.state === "on"
        onToggled: value => {
            if (setter.running) return;
            setter.nextState = value ? "on" : "off";
            setter.running = true;
        }
    }

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        visible: !root.available
        text: "hyprsunset is not installed"
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }
}
