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
import "../Services"

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
    // The staged choice. Picking a tile only stages it; nothing reaches
    // Hyprpaper until Apply is pressed, so a misclick costs a second click
    // rather than a wallpaper change and an accent re-derivation.
    property string selected: ""

    Process {
        id: lister
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text);
                    root.dir = c.dir ?? "";
                    // Reassigning root.images always replaces the GridView's
                    // model with a new array, even when the contents are
                    // identical — the view can't tell it's the same list, so
                    // it tears down and rebuilds every delegate, and every
                    // thumbnail Image with it. That's the blank-then-pop-in
                    // flash on reopen despite the Image cache below: the
                    // pixmap is cached, but the Image *element* holding it
                    // was just destroyed and recreated. Keeping the old
                    // array when nothing changed keeps the delegates (and
                    // their decoded thumbnails) alive across reopenings.
                    const newImages = c.images ?? [];
                    const sameImages = newImages.length === root.images.length
                        && newImages.every((p, i) => p === root.images[i]);
                    if (!sameImages)
                        root.images = newImages;
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

    // Detached, not a Process: applying a wallpaper re-derives the accent, which
    // rewrites Accent.qml, which is a full config reload. That reload destroys
    // this Scope, and a Process child dies with the object that owns it — so the
    // helper would be killed partway through the very work the click asked for.
    // Handing it to the session instead lets it outlive the reload it causes.
    //
    // The exit code goes with it, but there was never much in it: apply_command
    // reports a wedged Hyprpaper by warning to stderr and returning 0, so a
    // non-zero code only ever meant a bad argument or a file that vanished
    // between listing and clicking. The modal closes on Apply either way.
    function apply() {
        if (root.selected === "")
            return;
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh",
            "apply", root.selected, root.target, root.fit
        ]);
        root.open = false;
    }

    onOpenChanged: {
        if (open) {
            // Each opening starts with nothing staged, so Apply is never armed
            // with a choice the user made in some earlier session.
            root.selected = "";
            lister.running = true;
        }
    }

    // A modal, not a panel: it spans the output, dims what is behind it, and
    // holds the keyboard. Picking a wallpaper is a committed choice with a
    // confirm step, so the surrounding desktop should read as unavailable
    // rather than as something you could keep working in.
    PanelWindow {
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        // Covering the screen must not push the bar and dock out of their own
        // space — the modal is transient, the reserved layout is not.
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        WlrLayershell.namespace: "hyprveil-wallpapers"
        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusive, unlike the panels: a modal owning Escape only when it
        // happens to have been clicked is not a modal.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            id: scrim
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)

            // The layer appears at once (noanim); the entrance runs here so the
            // scrim and the dialog can move on their own timing instead of the
            // compositor fading the whole surface as one block. See the
            // hyprveil-wallpapers layer rule in hypr/window-rules.conf.
            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.duration(Tokens.durModal)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeModal
                }
            }

            focus: true
            Keys.onEscapePressed: root.open = false

            // Click-outside-to-dismiss. Sits under the dialog, so the dialog's
            // own MouseArea below swallows clicks that land on it.
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }
        }

        Surface {
            id: card
            anchors.centerIn: parent
            elevation: 3
            radius: Tokens.radiusSm
            border.color: Accent.accent

            // The dialog carries its own entrance so it blooms from the centre
            // while the scrim fades independently behind it. A full-screen layer
            // cannot slide or fade on the compositor without dragging the dim
            // across the desktop, so the motion lives here — the same way the
            // sibling modals in Dock/PinPicker.qml and Panel/Cheatsheet.qml do.
            // Opacity fades on the plain ease-out; the scale carries the
            // overshoot so the card blooms slightly past full size and settles.
            // Overshoot belongs on the transform, never the opacity — a fade
            // that ran past 1 would just clip and hold a flat spot.
            opacity: root.open ? 1 : 0
            transform: Scale {
                origin.x: card.width / 2
                origin.y: card.height / 2
                xScale: root.open ? 1 : 0.94
                yScale: xScale

                Behavior on xScale {
                    NumberAnimation {
                        duration: Motion.duration(Tokens.durModal)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.easeBloom
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.duration(Tokens.durModal)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeModal
                }
            }

            implicitWidth: Math.max(0, Math.min(620, parent.width - Tokens.spacing4 * 2))
            implicitHeight: Math.min(column.implicitHeight + Tokens.spacing4 * 2,
                                     parent.height - Tokens.spacing8 * 2)

            // Stops a click inside the dialog from reaching the scrim and
            // dismissing the thing the user is aiming at.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Tokens.spacing4
                spacing: Tokens.spacing3

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        renderType: Text.NativeRendering
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
                        activeFocusOnTab: true
                        color: closeMouse.containsMouse
                            ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.08)
                        border.width: activeFocus ? 1 : 0
                        border.color: Accent.accent
                        Accessible.role: Accessible.Button
                        Accessible.name: "Close wallpaper picker"

                        Keys.onReturnPressed: root.open = false
                        Keys.onSpacePressed: root.open = false

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
                        accessibleName: "Wallpaper target monitor"
                        options: ["All monitors"].concat(root.outputs)
                        values: [""].concat(root.outputs)
                        current: root.target
                        onPicked: v => root.target = v
                    }

                    Item { Layout.fillWidth: true }

                    Segmented {
                        accessibleName: "Wallpaper fit"
                        options: ["Cover", "Contain"]
                        values: ["cover", "contain"]
                        current: root.fit
                        onPicked: v => root.fit = v
                    }
                }

                // Only the empty state; errors and progress belong to the
                // footer status line, which is on screen either way.
                Text {
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    visible: root.images.length === 0
                    text: "No images in " + root.dir
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
                        readonly property bool chosen: root.selected === modelData
                        width: 192
                        height: 132

                        Rectangle {
                            id: tileFrame

                            anchors.fill: parent
                            anchors.margins: Tokens.spacing2
                            radius: Tokens.radiusSm
                            activeFocusOnTab: true
                            color: Tokens.elevated
                            antialiasing: true
                            property int imageInset: Tokens.spacing1
                            // The staged tile carries a heavier border than a
                            // hovered one, so the choice stays legible once the
                            // pointer has moved on to Apply.
                            border.width: parent.chosen || activeFocus ? 2
                                        : tileMouse.containsMouse ? 1 : 0
                            border.color: Accent.accent
                            Accessible.role: Accessible.Button
                            Accessible.name: "Select wallpaper " + modelData.split("/").pop()

                            Keys.onReturnPressed: root.selected = modelData
                            Keys.onSpacePressed: root.selected = modelData

                            // sourceSize decodes at thumbnail resolution rather
                            // than loading a 5120x2880 original and scaling it,
                            // asynchronous keeps the decode off the render
                            // thread, and cache keeps it across reopenings.
                            Image {
                                anchors.fill: parent
                                anchors.margins: tileFrame.imageInset
                                source: "file://" + modelData
                                sourceSize.width: 176
                                sourceSize.height: 99
                                asynchronous: true
                                cache: true
                                fillMode: Image.PreserveAspectCrop
                            }

                            Text {
                                renderType: Text.NativeRendering
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
                                onClicked: root.selected = modelData
                                // Double-click is the shortcut for people who
                                // already know which one they want.
                                onDoubleClicked: {
                                    root.selected = modelData;
                                    root.apply();
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing2

                    // The status line shares the footer rather than owning a
                    // row of its own, so the dialog does not change height as a
                    // message appears and clears. Only `list` reports here now;
                    // `apply` is detached and has no result to wait for.
                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: root.status !== "" ? root.status
                            : root.selected !== "" ? root.selected.split("/").pop()
                            : "Pick a wallpaper"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textXs
                        color: Tokens.dim
                        elide: Text.ElideMiddle
                    }

                    Button {
                        text: "Cancel"
                        onClicked: root.open = false
                    }

                    Button {
                        text: "Apply"
                        primary: true
                        enabled: root.selected !== ""
                        onClicked: root.apply()
                    }
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
