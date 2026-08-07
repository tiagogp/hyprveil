// Anchored now-playing detail card: artwork, seekable timeline and transport.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import ".."
import "../Design/Components"
import "../Services"

PopupWindow {
    id: root

    property Item anchorItem: null
    property var player: null
    property bool open: false
    readonly property bool active: player !== null
    readonly property bool hovered: hover.hovered
    readonly property bool playing:
        player?.playbackState === MprisPlaybackState.Playing
    readonly property bool hasProgress:
        player !== null && player.positionSupported
        && player.lengthSupported && player.length > 0
    readonly property real progress: hasProgress
        ? Math.max(0, Math.min(1, player.position / player.length)) : 0
    readonly property int bridge: Tokens.spacing2

    function timeText(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0) return "0:00";
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return mins + ":" + String(secs).padStart(2, "0");
    }

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.All
    implicitWidth: 344
    implicitHeight: card.implicitHeight + bridge
    color: "transparent"
    grabFocus: false
    visible: active && (open || card.opacity > 0)

    HoverHandler { id: hover }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.playing && root.hasProgress
        onTriggered: root.player.positionChanged()
    }
    onOpenChanged: if (open && player) player.positionChanged()

    Surface {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: content.implicitHeight + Tokens.spacing3 * 2
        // Rev 02 groups every floating widget — media, OSD, notifications,
        // the calendar and quick-settings dropdowns — on the same shadow
        // tier; tier 3 is reserved for the lock screen's single card.
        elevation: 2
        radius: Tokens.radiusLg
        tint: Tokens.chromeTintMedia
        opacity: root.open ? 1 : 0
        transform: Translate { y: root.open ? 0 : -root.bridge }

        Behavior on opacity {
            enabled: root.active
            NumberAnimation {
                duration: Motion.duration(Tokens.dur2h)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeOut
            }
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.spacing3
            anchors.rightMargin: Tokens.spacing3
            spacing: Tokens.spacing3

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing3

                ClippingRectangle {
                    implicitWidth: 76
                    implicitHeight: 76
                    radius: Tokens.radiusMd
                    color: Tokens.elevated
                    border.width: 2
                    border.color: root.playing ? Accent.accent : Qt.rgba(1, 1, 1, Tokens.elev1Border)

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Motion.duration(Tokens.dur2)
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.easeStandard
                        }
                    }

                    Image {
                        id: albumArt
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Glyph {
                        anchors.centerIn: parent
                        visible: albumArt.status !== Image.Ready
                        text: "\u{f075a}"
                        size: Tokens.iconXl
                        color: Tokens.dim
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing1

                    Text {
                        Layout.fillWidth: true
                        text: (root.player?.identity ?? "MEDIA").toUpperCase()
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.text2xs
                        font.weight: Tokens.weightBold
                        color: Accent.accent
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackTitle || "Nothing playing"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textMd
                        font.weight: Tokens.weightSemibold
                        color: Tokens.text
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackArtist || root.player?.trackAlbum || ""
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textXs
                        color: Tokens.muted
                        elide: Text.ElideRight
                        renderType: Text.NativeRendering
                    }
                }
            }

            Item {
                id: seekArea
                Layout.fillWidth: true
                implicitHeight: Tokens.spacing5
                enabled: root.hasProgress && (root.player?.canSeek ?? false)

                function seekAt(x) {
                    if (!enabled || width <= 0) return;
                    const ratio = Math.max(0, Math.min(1, x / width));
                    root.player.position = ratio * root.player.length;
                    root.player.positionChanged();
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: Tokens.spacing1
                    radius: Tokens.radiusPill
                    color: Tokens.hairline

                    Rectangle {
                        width: parent.width * root.progress
                        height: parent.height
                        radius: parent.radius
                        color: Accent.accent
                    }
                }

                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width,
                        parent.width * root.progress - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: Tokens.spacing3
                    height: width
                    radius: Tokens.radiusPill
                    color: seekMouse.containsMouse ? Accent.accentHover : Accent.accent
                    visible: seekArea.enabled
                }

                HvPointerArea {
                    id: seekMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: seekArea.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: event => seekArea.seekAt(event.x)
                    onPositionChanged: event => {
                        if (pressed) seekArea.seekAt(event.x);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: root.hasProgress ? root.timeText(root.player.position) : "--:--"
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.text2xs
                    color: Tokens.dim
                    renderType: Text.NativeRendering
                }

                RowLayout {
                    spacing: Tokens.spacing1h

                    BarAction {
                        glyph: "\u{f04ae}"
                        tooltip: "Previous"
                        enabled: root.player?.canGoPrevious ?? false
                        onClicked: root.player?.previous()
                    }
                    BarAction {
                        variant: "primary"
                        glyph: root.playing ? "\u{f03e4}" : "\u{f040a}"
                        tooltip: root.playing ? "Pause" : "Play"
                        enabled: root.player?.canTogglePlaying ?? false
                        onClicked: root.player?.togglePlaying()
                    }
                    BarAction {
                        glyph: "\u{f04ad}"
                        tooltip: "Next"
                        enabled: root.player?.canGoNext ?? false
                        onClicked: root.player?.next()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: root.hasProgress ? root.timeText(root.player.length) : "--:--"
                    font.family: Tokens.fontMono
                    font.pixelSize: Tokens.text2xs
                    color: Tokens.dim
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
