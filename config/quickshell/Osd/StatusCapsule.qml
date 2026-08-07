// The transient status capsule — the roadmap's "Status capsule transitória".
//
// ChillPill's single temporary "status capsule" for volume/timer/hotspot was
// the idea worth taking without taking the permanently-morphing pill bar
// with it (see the competitive analysis' rejected-by-default list). This is
// scoped even narrower than that: only two events that previously changed
// state with NO on-screen acknowledgment at all — do-not-disturb and Calm
// Mode toggling — get a capsule. Volume/brightness/media already have
// Osd.qml; this does not duplicate that, it fills the two gaps beside it.
//
// Top-center, Osd.qml stays bottom-center: the two can be visible at once
// (DND toggled right after a volume change) without overlapping.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../Services"

Scope {
    id: root

    property bool enabled: true

    property bool open: false
    property string glyph: ""
    property string text: ""

    function show(glyph, text) {
        if (!root.enabled) return;
        root.glyph = glyph;
        root.text = text;
        root.open = true;
        hideTimer.restart();
    }

    // Calm Mode is a singleton, so this watches it directly rather than
    // needing shell.qml to wire a reference the way Popups.qml does below —
    // one less property to thread through for a service that already has a
    // single well-known name everywhere else in the shell.
    Connections {
        target: CalmMode
        function onActiveChanged() {
            root.show(CalmMode.active ? "\u{f0e63}" : "\u{f0e64}",
                "Calm Mode " + (CalmMode.active ? "on" : "off")
                + (CalmMode.active && CalmMode.reason === "battery" ? " (low battery)" : ""));
        }
    }

    Timer {
        id: hideTimer
        // Longer than Osd.qml's 900ms: this is a state change to read, not a
        // level to glance at mid-adjustment, so it gets a beat longer to
        // register before it goes away on its own.
        interval: 2200
        onTriggered: root.open = false
    }

    PanelWindow {
        visible: root.enabled && root.open
        anchors { top: true; left: true; right: true }
        margins { top: Tokens.spacing8 * 2 }

        implicitHeight: 56
        color: "transparent"
        WlrLayershell.namespace: "hyprveil-status-capsule"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0

        Surface {
            width: row.implicitWidth + Tokens.spacing4 * 2
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Tokens.radiusPill
            elevation: 2

            Accessible.role: Accessible.Indicator
            Accessible.name: root.text

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: Tokens.spacing2

                Glyph {
                    text: root.glyph
                    size: Tokens.iconMd
                    color: Accent.accent
                }

                Text {
                    renderType: Text.NativeRendering
                    text: root.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textSm
                    font.weight: Tokens.weightMedium
                    color: Tokens.text
                }
            }
        }
    }

}
