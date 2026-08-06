// Ticker label for a track name too wide to sit still in the bar. Static
// (and unclipped-looking) whenever the text already fits; only scrolls once
// it genuinely overflows, and resets cleanly if the text changes underneath
// it mid-scroll.
import QtQuick
import ".."
import "../Services"

Item {
    id: root

    property string text: ""
    property real maximumWidth: 140
    property color color: Tokens.muted
    readonly property real gap: Tokens.spacing5
    readonly property bool overflowing: label.implicitWidth > root.maximumWidth
    // Constant px/s so a long title doesn't blur past and a short one
    // doesn't crawl — the duration below scales with content instead.
    readonly property real speed: 20

    implicitWidth: Math.min(maximumWidth, Math.max(label.implicitWidth, 1))
    implicitHeight: label.implicitHeight
    clip: true

    Row {
        id: track
        spacing: root.gap
        // NativeRendering re-rasterizes glyphs every frame the text moves,
        // which is fine for static labels but drops frames on a continuous
        // scroll. Layering caches the row to a texture once and animates
        // that instead, so the scroll stays smooth regardless of how the
        // rest of the bar is redrawing. Only paid while actually scrolling.
        layer.enabled: root.overflowing
        layer.smooth: true

        Text {
            id: label
            text: root.text
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.textXs
            font.weight: Tokens.weightMedium
            color: root.color
            renderType: Text.NativeRendering
        }

        Text {
            visible: root.overflowing
            text: root.text
            font: label.font
            color: root.color
            renderType: Text.NativeRendering
        }
    }

    NumberAnimation {
        id: scroll
        target: track
        property: "x"
        from: 0
        to: -(label.implicitWidth + track.spacing)
        duration: Motion.duration(
            Math.max(3000, (label.implicitWidth + track.spacing) / root.speed * 1000))
        loops: Animation.Infinite
        easing.type: Easing.Linear
        running: root.overflowing && root.visible && !Motion.reduced
    }

    // Holds the label still at its start position whenever the scroll isn't
    // running, instead of leaving it wherever the last loop stopped.
    Binding {
        target: track
        property: "x"
        value: 0
        when: !scroll.running
    }
}
