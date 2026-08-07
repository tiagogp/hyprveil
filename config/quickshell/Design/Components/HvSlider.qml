import QtQuick
import "../.."

Item {
    id: root
    property real from: 0
    property real to: node ? maximum : 1
    property real value: node?.audio?.volume ?? 0
    property real stepSize: 0
    property var node: null
    property real maximum: 1.5
    property string accessibleName: "Value"
    signal moved(real value)
    onMoved: next => { if (node?.audio) node.audio.volume = next; }

    implicitWidth: 180
    implicitHeight: Tokens.iconHit
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName
    Accessible.value: value

    function clamp(next): real { return Math.max(from, Math.min(to, next)); }
    function setFromPosition(x): void {
        let ratio = Math.max(0, Math.min(1, x / width));
        let next = from + ratio * (to - from);
        if (stepSize > 0) next = Math.round(next / stepSize) * stepSize;
        moved(clamp(next));
    }
    Keys.onLeftPressed: moved(clamp(value - (stepSize || (to - from) / 20)))
    Keys.onRightPressed: moved(clamp(value + (stepSize || (to - from) / 20)))

    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.12) }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * ((root.value - root.from) / Math.max(0.0001, root.to - root.from)); height: 4; radius: 2; color: Accent.accent }
    Rectangle { x: Math.max(0, Math.min(parent.width - width, parent.width * ((root.value - root.from) / Math.max(0.0001, root.to - root.from)) - width / 2)); anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; radius: 9; color: Accent.accent }
    TapHandler { onTapped: eventPoint => root.setFromPosition(eventPoint.position.x) }
    DragHandler { target: null; xAxis.enabled: true; yAxis.enabled: false; onActiveTranslationChanged: root.setFromPosition(centroid.position.x) }
    HvFocusRing { target: root }
}
