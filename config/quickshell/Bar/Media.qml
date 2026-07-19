// Media transport and now-playing label.
//
// This was four Waybar modules (media-previous/toggle/next/label), each spawning
// playerctl every 2 seconds — eight process spawns per second at idle, whether
// or not anything was playing. Mpris is a property subscription: nothing runs
// until the player state actually changes.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import ".."

RowLayout {
    id: root
    spacing: Tokens.spacing1h

    // Prefer a playing player over a paused one, matching what select_player()
    // did in media.sh — otherwise a stale paused browser tab outranks the
    // thing actually making sound.
    readonly property var player: {
        const all = Mpris.players.values;
        return all.find(p => p.playbackState === MprisPlaybackState.Playing)
            ?? all.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? null;
    }
    readonly property bool active: player !== null

    visible: active

    BarButton {
        glyph: "\u{f04ae}"
        tooltip: "Previous"
        enabled: root.player?.canGoPrevious ?? false
        opacity: enabled ? 1 : 0.4
        onClicked: root.player.previous()
    }

    BarButton {
        glyph: root.player?.playbackState === MprisPlaybackState.Playing
            ? "\u{f03e4}" : "\u{f040a}"
        tooltip: root.player?.playbackState === MprisPlaybackState.Playing ? "Pause" : "Play"
        enabled: root.player?.canTogglePlaying ?? false
        opacity: enabled ? 1 : 0.4
        onClicked: root.player.togglePlaying()
    }

    BarButton {
        glyph: "\u{f04ad}"
        tooltip: "Next"
        enabled: root.player?.canGoNext ?? false
        opacity: enabled ? 1 : 0.4
        onClicked: root.player.next()
    }

    // Elided at a width rather than truncated at 48 characters as media.sh did:
    // a character count guesses at the rendered width and gets it wrong for any
    // title that is not mostly latin.
    Text {
        Layout.maximumWidth: 220
        text: {
            if (!root.player) return "";
            const artist = root.player.trackArtist ?? "";
            const title = root.player.trackTitle ?? "";
            if (artist && title) return artist + " — " + title;
            return title || artist;
        }
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.muted
        elide: Text.ElideRight
    }
}
