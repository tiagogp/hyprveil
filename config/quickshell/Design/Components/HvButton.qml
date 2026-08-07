import QtQuick
import "../.."
import "../../Services"

Rectangle {
    id: root

    property string text: ""
    property string accessibleName: text
    property string accessibleDescription: ""
    property bool primary: false
    property bool busy: false
    property string labelFontFamily: Tokens.fontUi
    property int labelPixelSize: Tokens.textSm
    property bool hovered: hover.hovered
    property bool pressed: tap.pressed
    signal clicked()

    implicitWidth: Math.max(Tokens.iconHit, label.implicitWidth + Tokens.spacing3 * 2)
    implicitHeight: Tokens.iconHit
    radius: Tokens.radiusSm
    activeFocusOnTab: enabled && !busy
    opacity: enabled ? 1 : 0.42
    scale: pressed && enabled && !busy ? 0.97 : 1
    color: primary
        ? (pressed ? Accent.accent : Accent.accentSoft)
        : (hovered || activeFocus ? Tokens.stateHoverSurface : Qt.rgba(1, 1, 1, 0.06))

    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.description: accessibleDescription
    Accessible.focusable: activeFocusOnTab

    function activate(): void {
        if (enabled && !busy) clicked();
    }

    Keys.onReturnPressed: event => { activate(); event.accepted = true; }
    Keys.onEnterPressed: event => { activate(); event.accepted = true; }
    Keys.onSpacePressed: event => { activate(); event.accepted = true; }

    Behavior on scale {
        NumberAnimation { duration: Motion.duration(Tokens.dur1); easing.type: Easing.OutCubic }
    }
    Behavior on color {
        ColorAnimation { duration: Motion.duration(Tokens.dur1) }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.busy ? "…" : root.text
        renderType: Text.NativeRendering
        font.family: root.labelFontFamily
        font.pixelSize: root.labelPixelSize
        font.weight: root.primary ? Tokens.weightSemibold : Tokens.weightMedium
        color: root.primary ? Accent.accent : Tokens.text
    }

    HoverHandler { id: hover; enabled: root.enabled }
    TapHandler { id: tap; enabled: root.enabled && !root.busy; onTapped: root.clicked() }
    HvFocusRing { target: root }
}
