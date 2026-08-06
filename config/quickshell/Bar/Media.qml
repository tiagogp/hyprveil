// Compact bar presentation for the active MPRIS player.
//
// The chip sits at divider height rather than the bar's full row height, and
// carries its own previous/play/next transport plus a marquee title inline —
// no need to open MediaCard just to skip a track. MediaCard still owns the
// anchored artwork/seek detail on hover.
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import ".."
import "../Services"

Item {
    id: root

    property string displayMode: "full" // full | icon
    property real labelMaximumWidth: 140
    readonly property var player: {
        const all = Mpris.players.values;
        return all.find(p => p.playbackState === MprisPlaybackState.Playing)
            ?? all.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? null;
    }
    readonly property bool active: player !== null
    readonly property bool playing:
        player?.playbackState === MprisPlaybackState.Playing
    readonly property bool hovered: chromeHover.hovered || card.hovered
    property bool previewOpen: false

    function playerText(fallback) {
        if (!root.player) return fallback;
        const artist = root.player.trackArtist ?? "";
        const title = root.player.trackTitle ?? "";
        if (artist && title) return artist + " — " + title;
        return title || artist || fallback;
    }

    implicitWidth: surface.implicitWidth
    implicitHeight: Tokens.spacing5
    visible: active

    onHoveredChanged: {
        if (hovered) {
            hidePreview.stop();
            previewOpen = true;
        } else {
            hidePreview.restart();
        }
    }
    onActiveChanged: if (!active) previewOpen = false

    Timer {
        id: hidePreview
        interval: 180
        onTriggered: root.previewOpen = false
    }

    Rectangle {
        id: surface
        anchors.verticalCenter: parent.verticalCenter
        readonly property real pad: root.hovered ? Tokens.spacing2h : Tokens.spacing1

        implicitWidth: row.implicitWidth + pad * 2
        implicitHeight: Tokens.spacing5
        radius: root.hovered ? Tokens.radiusXs : Tokens.radiusSm
        color: root.playing ? Accent.accentSoft
            : root.hovered ? Tokens.stateHoverSurface : "transparent"
        border.width: root.playing ? 1 : 0
        border.color: Accent.accentOnChrome

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Motion.duration(Tokens.dur2h)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeOut
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: Motion.duration(Tokens.dur1)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeStandard
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Motion.duration(Tokens.dur1)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeStandard
            }
        }

        HoverHandler { id: chromeHover }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Tokens.spacing1h

            MediaButton {
                glyph: "\u{f04ae}"
                accessibleName: "Previous track"
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player?.previous()
            }

            MediaButton {
                glyph: root.playing ? "\u{f03e4}" : "\u{f040a}"
                accessibleName: root.playing ? "Pause media" : "Play media"
                active: root.playing
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player?.togglePlaying()
            }

            MediaButton {
                glyph: "\u{f04ad}"
                accessibleName: "Next track"
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player?.next()
            }

            MediaMarquee {
                Layout.leftMargin: Tokens.spacing1
                visible: root.displayMode === "full"
                text: root.playerText("Media")
                maximumWidth: root.labelMaximumWidth
                color: root.playing ? Accent.accentOnChrome : Tokens.muted
            }
        }
    }

    MediaCard {
        id: card
        anchorItem: surface
        player: root.player
        open: root.previewOpen
    }
}
