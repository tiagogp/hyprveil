// Compact bar presentation for the active MPRIS player.
//
// The former component mixed player selection, three inline transport buttons,
// title layout, screen-coordinate measurement, and a 300-line hover card. The
// chip now owns only selection and bar interaction; MediaCard owns the anchored
// detail UI.
import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root

    property string displayMode: "full" // full | icon
    property real labelMaximumWidth: 180
    readonly property var player: {
        const all = Mpris.players.values;
        return all.find(p => p.playbackState === MprisPlaybackState.Playing)
            ?? all.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? null;
    }
    readonly property bool active: player !== null
    readonly property bool playing:
        player?.playbackState === MprisPlaybackState.Playing
    readonly property bool hovered: action.hovered || card.hovered
    property bool previewOpen: false

    function playerText(fallback) {
        if (!root.player) return fallback;
        const artist = root.player.trackArtist ?? "";
        const title = root.player.trackTitle ?? "";
        if (artist && title) return artist + " — " + title;
        return title || artist || fallback;
    }

    implicitWidth: action.implicitWidth
    implicitHeight: action.implicitHeight
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

    BarAction {
        id: action
        anchors.fill: parent
        glyph: root.playing ? "\u{f03e4}" : "\u{f040a}"
        label: root.playerText("Media")
        showLabel: root.displayMode === "full"
        labelMaximumWidth: root.labelMaximumWidth
        accessibleName: root.playing ? "Pause media" : "Play media"
        active: root.playing
        enabled: root.player?.canTogglePlaying ?? false
        onClicked: root.player?.togglePlaying()
    }

    MediaCard {
        id: card
        anchorItem: action
        player: root.player
        open: root.previewOpen
    }
}
