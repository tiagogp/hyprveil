// Coalesced media-key on-screen display.
//
// Hyprland repeats XF86 bindings quickly, so stacking one notification per
// press is noisy. The helper script updates the value, then calls this IPC
// target; repeated calls change the existing overlay and restart the same hide
// timer.
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
    property string kind: "volume"
    property int percent: 0
    property bool muted: false

    readonly property int cappedPercent: Math.max(0, Math.min(percent, 100))
    readonly property string title: {
        if (kind === "brightness") return "Brightness";
        if (kind === "microphone") return "Microphone";
        if (kind === "recording") return "Recording";
        return "Volume";
    }
    // For "recording", `muted` is reused with the same polarity it has for
    // volume/mic (true = the thing just turned off): record.sh calls
    // `show recording 0 false` on start and `show recording 0 true` on stop.
    readonly property string glyph: {
        if (kind === "brightness") return "\u{f00e0}";
        if (kind === "microphone") return muted ? "\u{f036d}" : "\u{f036c}";
        if (kind === "recording") return muted ? "\u{f04db}" : "\u{f0130}";
        if (muted) return "\u{f075f}";
        if (percent > 50) return "\u{f057e}";
        if (percent > 0) return "\u{f0580}";
        return "\u{f0581}";
    }

    PanelWindow {
        visible: root.open
        anchors { bottom: true; left: true; right: true }
        margins { bottom: Tokens.spacing8 * 2 }

        implicitHeight: 88
        color: "transparent"
        WlrLayershell.namespace: "hyprveil-osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0

        Surface {
            width: Math.max(0, Math.min(parent.width - Tokens.spacing4 * 2, 320))
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Tokens.radiusLg
            // Rev 02 groups every floating widget on one shadow tier — see
            // MediaCard.qml.
            elevation: 2

            // The overlay takes no keyboard focus, but an orca-style reader can
            // still voice a live region: name it "Volume 40 percent" / "Muted"
            // so the level is spoken, not just drawn.
            Accessible.role: Accessible.Indicator
            Accessible.name: root.title + ", " + (root.muted ? "muted" : root.percent + " percent")

            RowLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing4
                spacing: Tokens.spacing3

                Glyph {
                    Layout.preferredWidth: Tokens.iconRing
                    Layout.preferredHeight: Tokens.iconRing
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: root.glyph
                    size: Tokens.iconXl
                    color: root.muted ? Tokens.muted : Accent.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing2

                        Text {
                            renderType: Text.NativeRendering
                            Layout.fillWidth: true
                            text: root.title
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textSm
                            font.weight: Tokens.weightSemibold
                            color: Tokens.text
                            elide: Text.ElideRight
                        }

                        Text {
                            renderType: Text.NativeRendering
                            text: root.muted ? "Muted" : `${root.percent}%`
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textSm
                            font.weight: Tokens.weightMedium
                            color: root.muted ? Tokens.muted : Tokens.text
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Tokens.spacing2
                        radius: Tokens.radiusPill
                        color: Qt.rgba(1, 1, 1, 0.10)
                        clip: true

                        Rectangle {
                            width: parent.width * root.cappedPercent / 100
                            height: parent.height
                            radius: Tokens.radiusPill
                            color: root.muted ? Tokens.dim : Accent.accent

                            Behavior on width {
                                NumberAnimation {
                                    duration: Motion.duration(Tokens.dur2)
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Tokens.easeOut
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 900
        onTriggered: root.open = false
    }

    IpcHandler {
        target: "osd"

        function show(kind: string, percent: string, muted: string): string {
            root.kind = kind;
            root.percent = Math.round(Number(percent));
            root.muted = muted === "true";
            root.open = true;
            hideTimer.restart();
            return "shown";
        }
    }
}
