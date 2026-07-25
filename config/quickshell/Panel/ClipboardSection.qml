// Clipboard history.
//
// Hyprveil already stores history through cliphist in hypr/autostart.conf and
// exposes a Rofi picker on SUPER+V. This section is a small panel view over the
// same database so there is still one clipboard history, not one per surface.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Section {
    id: root

    glyph: "\u{f014f}"
    title: "Clipboard"

    property string query: ""
    property string status: "Checking clipboard history..."
    property var entries: []
    property bool toolsAvailable: false

    readonly property var filteredEntries: {
        const q = root.query.trim().toLowerCase();
        if (q === "")
            return root.entries;
        return root.entries.filter(entry =>
            root.preview(entry).toLowerCase().includes(q));
    }

    function preview(entry) {
        return entry.replace(/^\s*\d+\s+/, "");
    }

    function reload() {
        lister.running = true;
    }

    function copy(entry) {
        Quickshell.execDetached([
            "sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy",
            "hyprveil-clipboard-copy", entry
        ]);
    }

    function remove(entry) {
        Quickshell.execDetached([
            "sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete",
            "hyprveil-clipboard-delete", entry
        ]);
        reloadTimer.restart();
    }

    function clearAll() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        root.entries = [];
        root.status = "Clipboard history is empty";
    }

    Process {
        id: lister
        command: [
            "sh", "-c",
            "if command -v cliphist >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then cliphist list; else printf '__HYPRVEIL_CLIPBOARD_UNAVAILABLE__\\n'; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim();
                if (trimmed === "__HYPRVEIL_CLIPBOARD_UNAVAILABLE__") {
                    root.toolsAvailable = false;
                    root.entries = [];
                    root.status = "Clipboard tools unavailable";
                    return;
                }

                root.toolsAvailable = true;
                root.entries = trimmed === "" ? [] : trimmed.split("\n");
                root.status = root.entries.length > 0 ? "" : "Clipboard history is empty";
            }
        }
    }

    Timer {
        id: reloadTimer
        interval: 250
        repeat: false
        onTriggered: root.reload()
    }

    Component.onCompleted: root.reload()

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing1
        visible: root.toolsAvailable
        spacing: Tokens.spacing2

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Tokens.spacing8
            radius: Tokens.radiusSm
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: search.activeFocus ? 1 : 0
            border.color: Accent.accent

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.spacing3
                anchors.rightMargin: Tokens.spacing3
                spacing: Tokens.spacing2

                Glyph {
                    text: "\u{f0349}"
                    size: Tokens.iconSm
                    color: Tokens.dim
                }

                TextInput {
                    id: search
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Search clipboard history"
                    color: Tokens.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textSm
                    selectionColor: Accent.accentSoft
                    selectedTextColor: Tokens.text
                    clip: true
                    onTextChanged: root.query = text
                }
            }

            Text {
                renderType: Text.NativeRendering
                anchors {
                    left: parent.left
                    leftMargin: Tokens.spacing8
                    verticalCenter: parent.verticalCenter
                }
                visible: search.text.length === 0
                text: "Search"
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textSm
                color: Tokens.dim
            }
        }

        Rectangle {
            implicitWidth: Tokens.spacing8
            implicitHeight: Tokens.spacing8
            radius: Tokens.radiusSm
            activeFocusOnTab: root.entries.length > 0
            opacity: root.entries.length > 0 ? 1.0 : 0.4
            color: clearAllMouse.containsMouse && root.entries.length > 0
                ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.07)
            border.width: activeFocus ? 1 : 0
            border.color: Accent.accent
            Accessible.role: Accessible.Button
            Accessible.name: "Clear clipboard history"

            Keys.onReturnPressed: if (root.entries.length > 0) root.clearAll()
            Keys.onSpacePressed: if (root.entries.length > 0) root.clearAll()

            Glyph {
                anchors.centerIn: parent
                text: "\u{f00e2}"
                size: Tokens.iconSm
                color: clearAllMouse.containsMouse && root.entries.length > 0
                    ? Accent.accent : Tokens.muted
            }

            MouseArea {
                id: clearAllMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.entries.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (root.entries.length > 0) root.clearAll()
            }
        }
    }

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        visible: !root.toolsAvailable || root.entries.length === 0
            || (root.entries.length > 0 && root.filteredEntries.length === 0)
        text: root.filteredEntries.length === 0 && root.entries.length > 0
            ? "No clipboard item matches \"" + root.query + "\""
            : root.status
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.toolsAvailable && root.filteredEntries.length > 0
        spacing: Tokens.spacing1

        Repeater {
            model: root.filteredEntries.slice(0, 6)

            Rectangle {
                required property string modelData

                Layout.fillWidth: true
                implicitHeight: Tokens.spacing8
                radius: Tokens.radiusSm
                activeFocusOnTab: true
                color: clipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                border.width: activeFocus ? 1 : 0
                border.color: Accent.accent
                Accessible.role: Accessible.Button
                Accessible.name: "Copy clipboard item " + root.preview(modelData)

                Keys.onReturnPressed: root.copy(modelData)
                Keys.onSpacePressed: root.copy(modelData)
                Keys.onDeletePressed: root.remove(modelData)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing2
                    anchors.rightMargin: Tokens.spacing1
                    spacing: Tokens.spacing2

                    Glyph {
                        text: "\u{f014f}"
                        size: Tokens.iconSm
                        color: Tokens.muted
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: root.preview(modelData)
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textXs
                        color: Tokens.muted
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: Tokens.spacing6
                        implicitHeight: Tokens.spacing6
                        radius: Tokens.radiusSm
                        activeFocusOnTab: true
                        color: deleteMouse.containsMouse ? Accent.accentSoft : "transparent"
                        border.width: activeFocus ? 1 : 0
                        border.color: Accent.accent
                        Accessible.role: Accessible.Button
                        Accessible.name: "Clear clipboard item"

                        Keys.onReturnPressed: root.remove(modelData)
                        Keys.onSpacePressed: root.remove(modelData)

                        Glyph {
                            anchors.centerIn: parent
                            text: "\u{f0156}"
                            size: Tokens.iconSm
                            color: deleteMouse.containsMouse ? Accent.accent : Tokens.dim
                        }

                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.remove(modelData)
                        }
                    }
                }

                MouseArea {
                    id: clipMouse
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                        rightMargin: Tokens.spacing6 + Tokens.spacing1
                    }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copy(modelData)
                }
            }
        }
    }
}
