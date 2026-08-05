// Reusable icon-or-label action for the top bar.
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."
import "../Services"

Item {
    id: root

    property string glyph: ""
    property string iconSource: ""
    property string label: ""
    property bool showLabel: false
    property real labelMaximumWidth: 220
    property string tooltip: ""
    property string accessibleName: tooltip || label
    property color glyphColor: Tokens.muted
    property bool active: false
    property bool accentOnHover: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked()
    signal rightClicked()
    signal middleClicked()

    implicitWidth: Math.max(Tokens.iconHit,
        content.implicitWidth + Tokens.spacing2 * 2)
    implicitHeight: Tokens.iconHit
    opacity: enabled ? 1 : 0.4

    Accessible.role: Accessible.Button
    Accessible.name: accessibleName

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radiusSm
        color: root.active ? Accent.accentSoft
            : mouse.containsMouse ? Tokens.stateHoverSurface : "transparent"
        border.width: root.active ? 1 : 0
        border.color: Accent.accentOnChrome

        Behavior on color {
            ColorAnimation {
                duration: Motion.duration(Tokens.dur1)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeStandard
            }
        }
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Tokens.spacing1h
        scale: mouse.pressed ? 0.9 : 1

        IconImage {
            visible: root.iconSource !== ""
            source: root.iconSource
            implicitSize: Tokens.iconSm
        }

        Glyph {
            visible: root.iconSource === "" && root.glyph !== ""
            text: root.glyph
            size: Tokens.iconSm
            color: mouse.containsMouse
                ? (root.accentOnHover ? Accent.accentOnChrome : Tokens.text)
                : root.active ? Accent.accentOnChrome : root.glyphColor

            Behavior on color {
                ColorAnimation {
                    duration: Motion.duration(Tokens.dur1)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeStandard
                }
            }
        }

        Text {
            Layout.maximumWidth: root.labelMaximumWidth
            visible: root.showLabel && root.label !== ""
            text: root.label
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            font.weight: Tokens.weightMedium
            color: root.active ? Accent.accentOnChrome : Tokens.muted
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Behavior on scale {
            NumberAnimation {
                duration: Motion.duration(Tokens.dur1)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeOut
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function (event) {
            if (!root.enabled) return;
            if (event.button === Qt.RightButton) root.rightClicked();
            else if (event.button === Qt.MiddleButton) root.middleClicked();
            else root.clicked();
        }
    }

    BarTooltip {
        target: root
        text: root.tooltip
        requested: root.enabled && mouse.containsMouse && !mouse.pressed
    }
}
