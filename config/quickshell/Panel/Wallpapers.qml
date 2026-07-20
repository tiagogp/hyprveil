// The wallpaper picker.
//
// A front-end over hypr/scripts/wallpaper.sh — it owns the state, the Hyprpaper
// IPC, and the accent derivation, so this only renders `list` and calls `apply`.
// Nothing here is a second source of truth.
//
// The AGS version hand-rolled a thumbnail cache: SHA256 of path+mtime, scaled
// with GdkPixbuf into $XDG_CACHE_HOME, decoded off-frame via GLib.idle_add to
// keep the window responsive. QML's Image does all of that with three
// properties, which is most of why this file is a third the size.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

Scope {
    id: root

    property bool open: false

    property string dir: ""
    property var images: []
    property var outputs: []
    // "" means every monitor, matching what wallpaper.sh apply expects.
    property string target: ""
    property string fit: "cover"
    property string status: ""

    Process {
        id: lister
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text);
                    root.dir = c.dir ?? "";
                    root.images = c.images ?? [];
                    root.outputs = c.outputs ?? [];
                    // A monitor can disappear between openings; fall back to
                    // "all" rather than silently applying to a dead output.
                    if (root.target !== "" && !root.outputs.includes(root.target))
                        root.target = "";
                    root.status = "";
                } catch (e) {
                    root.images = [];
                    root.status = "Could not read the wallpaper list";
                }
            }
        }
    }

    Process {
        id: applier
        stdout: StdioCollector {}
        onExited: function (code) {
            root.status = code === 0 ? "" : "Could not apply that wallpaper";
            // The accent is derived from the new wallpaper, so re-read state.
            lister.running = true;
        }
    }

    function apply(path: string) {
        root.status = "Applying…";
        applier.command = [
            Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh",
            "apply", path, root.target, root.fit
        ];
        applier.running = true;
    }

    onOpenChanged: if (open) lister.running = true

    PanelWindow {
        visible: root.open
        anchors.top: true
        margins.top: Tokens.spacing8 + Tokens.spacing4

        implicitWidth: 620
        implicitHeight: Math.min(column.implicitHeight + Tokens.spacing4 * 2, 720)
        color: "transparent"
        WlrLayershell.namespace: "hyprveil-wallpapers"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Surface {
            anchors.fill: parent
            elevation: 0
            radius: Tokens.radiusLg

            focus: true
            Keys.onEscapePressed: root.open = false

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Tokens.spacing4
                spacing: Tokens.spacing3

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Wallpapers"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textLg
                        font.weight: Tokens.weightBold
                        color: Tokens.text
                    }

                    Rectangle {
                        implicitWidth: Tokens.spacing6
                        implicitHeight: Tokens.spacing6
                        radius: Tokens.radiusPill
                        color: closeMouse.containsMouse
                            ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.08)

                        Glyph {
                            anchors.centerIn: parent
                            text: "\u{f0156}"
                            size: Tokens.iconSm
                            color: closeMouse.containsMouse ? Accent.accent : Tokens.muted
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.open = false
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing2

                    Segmented {
                        options: ["All monitors"].concat(root.outputs)
                        values: [""].concat(root.outputs)
                        current: root.target
                        onPicked: v => root.target = v
                    }

                    Item { Layout.fillWidth: true }

                    Segmented {
                        options: ["Cover", "Contain"]
                        values: ["cover", "contain"]
                        current: root.fit
                        onPicked: v => root.fit = v
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.images.length === 0
                    text: root.status !== "" ? root.status
                        : "No images in " + root.dir
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textXs
                    color: Tokens.dim
                }

                GridView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 400)
                    visible: root.images.length > 0
                    clip: true
                    cellWidth: 192
                    cellHeight: 132
                    model: root.images

                    delegate: Item {
                        required property string modelData
                        width: 192
                        height: 132

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Tokens.spacing2
                            radius: Tokens.radiusSm
                            color: "#1c1f26"
                            border.width: tileMouse.containsMouse ? 1 : 0
                            border.color: Accent.accent
                            clip: true

                            // sourceSize decodes at thumbnail resolution rather
                            // than loading a 5120x2880 original and scaling it,
                            // asynchronous keeps the decode off the render
                            // thread, and cache keeps it across reopenings.
                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: "file://" + modelData
                                sourceSize.width: 176
                                sourceSize.height: 99
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectCrop
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Tokens.spacing1
                                text: modelData.split("/").pop()
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.text2xs
                                color: Tokens.text
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.75)
                            }

                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.apply(modelData)
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.status !== "" && root.images.length > 0
                    text: root.status
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textXs
                    color: Tokens.dim
                }
            }
        }
    }

    // wallpaper.sh pick calls this when the shell is running, and falls back to
    // its own Rofi flow when it is not — the same shape the AGS picker used.
    IpcHandler {
        target: "wallpapers"

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }
        function open(): string { root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
