// The window overview (exposé).
//
// The bar's clock replaced a Waybar module; this replaces the one thing rofi
// could only fake — a window switcher that shows the windows. rofi -show window
// is a text list of titles; this lays every open window out as a live tile you
// can point at, across every workspace at once, which is what "where did that
// window go" actually needs.
//
// A full-screen modal like the cheatsheet and the pickers: it covers the
// output, dims the desktop, and holds the keyboard so the search field has it
// from the first keystroke. The tiles are the surfaces — there is no card
// behind them — so the layout reads as the desktop spread out rather than a
// dialog listing it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../Services"
import ".."

Scope {
    id: root

    property bool open: false
    property string query: ""

    // Every open window, filtered by the search box and ordered by workspace
    // then title so the grid does not reshuffle on every keystroke for reasons
    // the eye cannot follow.
    readonly property var windows: {
        const q = root.query.trim().toLowerCase();
        const list = Hyprland.toplevels.values.filter(t => {
            if (!t) return false;
            if (q === "") return true;
            const title = (t.title ?? "").toLowerCase();
            const cls = (t.lastIpcObject?.class ?? "").toLowerCase();
            return title.indexOf(q) !== -1 || cls.indexOf(q) !== -1;
        });
        return list.slice().sort((a, b) => {
            const wa = a.workspace?.id ?? 0;
            const wb = b.workspace?.id ?? 0;
            if (wa !== wb) return wa - wb;
            return (a.title ?? "").localeCompare(b.title ?? "");
        });
    }

    function activate(toplevel): void {
        if (toplevel) Compositor.dispatchTo("focuswindow", toplevel);
        root.open = false;
    }

    onOpenChanged: {
        if (open) {
            root.query = "";
            // The toplevel set is a snapshot; refresh so a window opened since
            // the last event is in the grid the moment the overview appears.
            Hyprland.refreshToplevels();
        }
    }

    PanelWindow {
        id: win
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        // A transient modal must not push the bar and dock out of their space.
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        WlrLayershell.namespace: "hyprveil-overview"
        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusive: the search field is the primary control and must own the
        // keyboard from the moment the overview opens.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacing8
            spacing: Tokens.spacing4

            // Entrance handed to QML — the layer is noanim (see window-rules.conf)
            // because animating the scrim drags the dim across the desktop. The
            // content rises and fades as one block, and collapses to nothing
            // under reduced motion via Motion.duration.
            opacity: root.open ? 1 : 0
            transform: Translate {
                y: root.open ? 0 : Tokens.spacing4
                Behavior on y {
                    NumberAnimation {
                        duration: Motion.duration(Tokens.durModal)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.easeModal
                    }
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.duration(Tokens.dur2h)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeStandard
                }
            }

            // Search pill. Same shape as the cheatsheet's so the two modals
            // share one search affordance rather than inventing a second.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(460, win.width - Tokens.spacing8 * 2)
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
                        focus: true
                        Accessible.role: Accessible.EditableText
                        Accessible.name: "Search windows"
                        color: Tokens.text
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textSm
                        selectionColor: Accent.accentSoft
                        selectedTextColor: Tokens.text
                        clip: true
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: root.open = false
                        // Enter commits to the first match, so a search that
                        // narrows to one window is a type-and-go rather than a
                        // type-then-aim.
                        Keys.onReturnPressed:
                            if (root.windows.length > 0) root.activate(root.windows[0])

                        Connections {
                            target: root
                            function onOpenChanged() {
                                if (root.open) search.text = "";
                            }
                        }

                        Text {
                            renderType: Text.NativeRendering
                            anchors.fill: parent
                            visible: search.text === ""
                            text: "Search windows"
                            font: search.font
                            color: Tokens.dim
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // The grid. Wraps and scrolls rather than shrinking the tiles, so a
            // preview stays legible whether there are three windows or thirty.
            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.windows.length > 0
                clip: true
                contentWidth: width
                contentHeight: flow.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: flow
                    width: flick.width
                    spacing: Tokens.spacing4

                    Repeater {
                        model: root.windows

                        WindowTile {
                            required property var modelData
                            toplevel: modelData
                            onActivated: root.activate(modelData)
                        }
                    }
                }
            }

            // Empty state — no windows at all, or none matching the query.
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
                visible: root.windows.length === 0
                text: root.query.trim() === ""
                    ? "No open windows"
                    : "No window matches “" + root.query + "”"
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textSm
                color: Tokens.dim
            }
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }
        function open(): string { root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
