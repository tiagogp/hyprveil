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
import Quickshell.Wayland
import ".."

RowLayout {
    id: root
    spacing: Tokens.spacing1h

    property var screen: null
    property bool hovered: hover.hovered || bannerHover.hovered
    property bool previewOpen: false

    function playerText(fallback) {
        if (!root.player) return fallback;
        const artist = root.player.trackArtist ?? "";
        const title = root.player.trackTitle ?? "";
        if (artist && title) return artist + " — " + title;
        return title || artist || fallback;
    }

    function timeText(seconds) {
        if (!Number.isFinite(seconds) || seconds < 0) return "0:00";
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return mins + ":" + String(secs).padStart(2, "0");
    }

    readonly property bool hasProgress:
        root.player !== null
        && root.player.positionSupported
        && root.player.lengthSupported
        && root.player.length > 0
    readonly property real progress:
        hasProgress ? Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0

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
        renderType: Text.NativeRendering
        Layout.maximumWidth: 220
        text: root.playerText("")
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.muted
        elide: Text.ElideRight
    }

    HoverHandler {
        id: hover
    }

    PanelWindow {
        id: banner

        screen: root.screen
        anchors { top: true; right: true }
        margins { top:Tokens.spacing2; right: Tokens.spacing2h + 168 }

        implicitWidth: 360
        implicitHeight: 142
        color: "transparent"
        visible: root.active && root.previewOpen
        WlrLayershell.namespace: "hyprveil-media-preview"
        WlrLayershell.layer: WlrLayer.Top
        exclusiveZone: 0

        Surface {
            anchors.fill: parent
            elevation: 3
            radius: Tokens.radiusLg
            tint: "#151817"

            HoverHandler {
                id: bannerHover
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Tokens.spacing3
                spacing: Tokens.spacing3

                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 96
                    radius: Tokens.radiusMd
                    color: Accent.accentSoft
                    clip: true
                    antialiasing: true

                    Image {
                        id: art

                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Glyph {
                        anchors.centerIn: parent
                        text: "\u{f075a}"
                        size: Tokens.iconXl
                        color: Accent.accent
                        visible: !art.visible
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Tokens.spacing2

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: root.player?.trackTitle || root.playerText("Nothing playing")
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textLg
                        font.weight: Tokens.weightBold
                        color: Tokens.text
                        elide: Text.ElideRight
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: root.player?.trackArtist || root.player?.identity || "Media player"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textSm
                        color: Tokens.muted
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing2

                        Text {
                            renderType: Text.NativeRendering
                            text: root.hasProgress ? root.timeText(root.player.position) : "--:--"
                            font.family: Tokens.fontMono
                            font.pixelSize: Tokens.text2xs
                            color: Tokens.dim
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Tokens.spacing1
                            radius: Tokens.radiusPill
                            color: Qt.rgba(1, 1, 1, 0.10)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * root.progress
                                height: parent.height
                                radius: Tokens.radiusPill
                                color: Accent.accent
                            }
                        }

                        Text {
                            renderType: Text.NativeRendering
                            text: root.hasProgress ? root.timeText(root.player.length) : "--:--"
                            font.family: Tokens.fontMono
                            font.pixelSize: Tokens.text2xs
                            color: Tokens.dim
                        }
                    }

                    RowLayout {
                        spacing: Tokens.spacing3
                        Layout.alignment: Qt.AlignHCenter

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
                    }
                }
            }
        }
    }
}
