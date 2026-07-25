import QtQuick
import ".."
import "../Services"

Item {
    id: slider

    property var node: null
    property real maximum: 1.5

    function clamp(value) {
        return Math.max(0, Math.min(slider.maximum, value));
    }

    function setFromX(x) {
        if (!slider.node?.audio || groove.width <= 0) return;
        slider.node.audio.volume = slider.clamp((x / groove.width) * slider.maximum);
    }

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
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width * Math.min(slider.maximum,
                slider.node?.audio?.volume ?? 0) / slider.maximum
            radius: Tokens.radiusPill
            color: slider.node?.audio?.muted ? Tokens.dim : Accent.accent

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
                (parent.width * Math.min(slider.maximum,
                    slider.node?.audio?.volume ?? 0) / slider.maximum) - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            color: slider.node?.audio?.muted ? Tokens.muted : Accent.accentFg
            border.width: 1
            border.color: slider.node?.audio?.muted ? Tokens.dim : Accent.accent

            Behavior on x {
                NumberAnimation {
                    duration: Motion.duration(Tokens.dur1)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.easeStandard
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: event => slider.setFromX(event.x)
        onPositionChanged: event => {
            if (pressed) slider.setFromX(event.x);
        }
    }
}
