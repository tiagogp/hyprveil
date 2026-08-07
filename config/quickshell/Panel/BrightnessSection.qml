// Brightness in Quick Settings — backlight always, DDC monitors when detected.
//
// Mirrors NightLightSection's "hide the whole section when the capability is
// absent" contract: a laptop with no panel backlight and no DDC monitor draws
// nothing here rather than a slider that always fails.
import QtQuick
import QtQuick.Layouts
import ".."
import "../Design/Components"
import "../Services"

HvSection {
    id: root
    glyph: "\u{f00e0}"
    title: "Brightness"
    visible: Brightness.available || Brightness.ddcAvailable

    Component.onCompleted: {
        Brightness.watch();
        Brightness.requestDdcProbe();
    }
    Component.onDestruction: Brightness.unwatch()

    RowLayout {
        Layout.fillWidth: true
        visible: Brightness.available
        spacing: Tokens.spacing3

        Glyph {
            text: "\u{f00e0}"
            size: Tokens.iconSm
            color: Tokens.muted
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: Tokens.spacing6

            Rectangle {
                id: groove
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                height: Tokens.spacing1h
                radius: Tokens.radiusPill
                color: Qt.rgba(1, 1, 1, 0.10)

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: parent.width * Brightness.percent / 100
                    radius: Tokens.radiusPill
                    color: Accent.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Motion.duration(Tokens.dur1)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.easeStandard
                        }
                    }
                }

                Rectangle {
                    width: Tokens.spacing4
                    height: Tokens.spacing4
                    radius: Tokens.radiusPill
                    x: Math.max(0, Math.min(parent.width - width,
                        (parent.width * Brightness.percent / 100) - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    color: Accent.accentFg
                    border.width: 1
                    border.color: Accent.accent

                    Behavior on x {
                        NumberAnimation {
                            duration: Motion.duration(Tokens.dur1)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.easeStandard
                        }
                    }
                }
            }

            HvPointerArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function setFromX(x) {
                    if (groove.width <= 0) return;
                    Brightness.setPercent(100 * x / groove.width);
                }
                onPressed: event => setFromX(event.x)
                onPositionChanged: event => { if (pressed) setFromX(event.x); }
            }

            Accessible.role: Accessible.Slider
            Accessible.name: "Brightness"
        }

        Text {
            renderType: Text.NativeRendering
            text: `${Brightness.percent}%`
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            font.weight: Tokens.weightMedium
            color: Tokens.muted
            Layout.preferredWidth: Tokens.spacing8
            horizontalAlignment: Text.AlignRight
        }
    }

    // One row per external monitor DDC could actually talk to — nothing is
    // drawn for a display that did not answer, matching Wi-Fi/Bluetooth's
    // "only known devices" convention.
    Repeater {
        model: Brightness.ddcMonitors

        RowLayout {
            required property var modelData
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing1
            spacing: Tokens.spacing3

            Glyph {
                text: "\u{f0330}"
                size: Tokens.iconSm
                color: Tokens.muted
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: Tokens.spacing6

                Rectangle {
                    id: ddcGroove
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    height: Tokens.spacing1h
                    radius: Tokens.radiusPill
                    color: Qt.rgba(1, 1, 1, 0.10)

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: parent.width * modelData.percent / 100
                        radius: Tokens.radiusPill
                        color: Accent.accent
                    }
                }

                HvPointerArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function setFromX(x) {
                        if (ddcGroove.width <= 0) return;
                        Brightness.setDdcPercent(modelData.bus, 100 * x / ddcGroove.width);
                    }
                    onPressed: event => setFromX(event.x)
                    onPositionChanged: event => { if (pressed) setFromX(event.x); }
                }

                Accessible.role: Accessible.Slider
                Accessible.name: "Monitor brightness, bus " + modelData.bus
            }

            Text {
                renderType: Text.NativeRendering
                text: `${modelData.percent}%`
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textXs
                font.weight: Tokens.weightMedium
                color: Tokens.muted
                Layout.preferredWidth: Tokens.spacing8
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
