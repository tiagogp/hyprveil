// GUI accent-preset picker, wrapping the existing `accent.sh preset` CLI.
//
// Presets stay data, not code: this reads the same curated JSON list
// accent.sh already ships and applies a preset the same way the CLI does, so
// there is exactly one place a preset is defined.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Section {
    id: root

    glyph: "\u{f0598}"
    title: "Accent"

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/hypr/scripts/accent.sh"
    property var presets: []

    function apply(name) {
        if (applier.running) return;
        applier.presetName = name;
        applier.running = true;
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/hypr/scripts/data/accent-presets.json"
        onLoaded: {
            try {
                root.presets = JSON.parse(text());
            } catch (e) {
                root.presets = [];
            }
        }
    }

    Process {
        id: applier
        property string presetName: ""
        command: [root.scriptPath, "preset", presetName]
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing2

        Repeater {
            model: root.presets

            Rectangle {
                id: swatch
                required property var modelData

                implicitWidth: Tokens.iconRing * 0.6
                implicitHeight: implicitWidth
                radius: Tokens.radiusPill
                color: modelData.hex
                activeFocusOnTab: true
                border.width: activeFocus || hoverArea.containsMouse ? 2 : 0
                border.color: Tokens.text
                Accessible.role: Accessible.Button
                Accessible.name: "Apply " + modelData.name + " accent"

                Keys.onReturnPressed: root.apply(modelData.name)
                Keys.onSpacePressed: root.apply(modelData.name)

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.apply(modelData.name)
                }
            }
        }

        Text {
            renderType: Text.NativeRendering
            Layout.fillWidth: true
            visible: root.presets.length === 0
            text: "No accent presets found"
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            color: Tokens.dim
        }
    }
}
