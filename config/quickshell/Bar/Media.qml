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
    // The bar this row lives in. The hover card hangs off the bar's own
    // geometry rather than a measured offset — see `banner` below.
    property var barWindow: null
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
    readonly property bool playing:
        root.player?.playbackState === MprisPlaybackState.Playing

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

    // Grace period on leave. The bridge strip below keeps the pointer inside a
    // hover region on the way down, so this only has to cover a cursor that
    // clips the edge of the row on its way somewhere else.
    Timer {
        id: hidePreview

        interval: 180
        onTriggered: root.previewOpen = false
    }

    // MPRIS does not push position: org.mpris.MediaPlayer2.Player.Position is
    // explicitly exempt from PropertiesChanged, because a signal per second per
    // player is exactly the traffic D-Bus does not want. Quickshell mirrors that
    // — `player.position` is read on demand and otherwise frozen at whatever the
    // last seek or track change left it, which is why the card's timeline sat
    // still. Emitting positionChanged() forces the re-read.
    //
    // Polled only while the card is actually on screen AND something is playing:
    // a paused player's position does not move, and a card nobody is looking at
    // does not need a clock. That keeps the idle cost at zero, which is the
    // whole reason this stopped being a playerctl poll.
    Timer {
        interval: 1000
        repeat: true
        running: banner.visible && root.playing && root.hasProgress
        onTriggered: root.player.positionChanged()
    }

    // One read on open, so a card summoned mid-track does not show a stale
    // position for up to a second before the timer's first tick.
    onPreviewOpenChanged: if (previewOpen && root.player) root.player.positionChanged()

    BarButton {
        glyph: "\u{f04ae}"
        tooltip: "Previous"
        enabled: root.player?.canGoPrevious ?? false
        opacity: enabled ? 1 : 0.4
        onClicked: root.player.previous()
    }

    BarButton {
        glyph: root.playing ? "\u{f03e4}" : "\u{f040a}"
        tooltip: root.playing ? "Pause" : "Play"
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

    // The now-playing card.
    //
    // It used to be placed at `top: spacing2, right: spacing2h + 168` — a top
    // margin SHORTER than the bar's own (spacing2h) so the card was drawn on top
    // of the bar it hangs from, and a right margin whose 168 was a hand-measure
    // of the controls sitting to Media's right. Those controls are not a fixed
    // width: the clock, the notification badge, and the status glyphs all come
    // and go, so the card drifted out from under its own row.
    //
    // Both numbers now come from the bar itself. The card is flush with the
    // bar's right edge and starts at the bar's bottom edge, so it cannot overlap
    // and cannot drift.
    PanelWindow {
        id: banner

        // Transparent strip between the bar and the card. It belongs to this
        // window, so the pointer travelling down from the row stays inside a
        // hover region the whole way — without it the 180ms grace timer is the
        // only thing keeping the card open during the crossing, and any pause in
        // the gap closes it out from under the cursor.
        readonly property int bridge: Tokens.spacing2

        readonly property int barTop: Tokens.spacing
        readonly property int barBottom: barTop + (root.barWindow?.height ?? 44)

        screen: root.screen
        anchors { top: true; right: true }
        margins {
            top: barTop;
            right: (root.barWindow?.margins.right ?? Tokens.spacing2h ) + 168;
        }

        implicitWidth: 344
        implicitHeight: card.implicitHeight + bridge
        color: "transparent"
        // Held open through the close animation so the card fades out rather
        // than being cut mid-frame by the window disappearing.
        visible: root.active && (root.previewOpen || card.opacity > 0)
        WlrLayershell.namespace: "hyprveil-media-preview"
        WlrLayershell.layer: WlrLayer.Top
        exclusiveZone: 0

        HoverHandler {
            id: bannerHover
        }

        Surface {
            id: card

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitHeight: content.implicitHeight + Tokens.spacing3 * 2
            elevation: 3
            radius: Tokens.radiusLg
            tint: "#151817"

            // Drops out from behind the bar. At `bridge` the card's top edge is
            // level with the window's, which is the bar's bottom edge — so the
            // travel reads as the card emerging from the bar rather than fading
            // in over the wallpaper.
            anchors.bottomMargin: root.previewOpen ? 0 : banner.bridge
            opacity: root.previewOpen ? 1 : 0

            // Disabled once the player is gone, so opacity snaps to 0 rather
            // than easing there. The window's `visible` is gated on `active`
            // as well, so an eased fade-out would run against a hidden window,
            // stall part-way, and leave a ghost card on screen the next time a
            // player appeared.
            Behavior on opacity {
                enabled: root.active
                NumberAnimation {
                    duration: Tokens.dur2h
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeOut
                }
            }

            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: Tokens.dur2h
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Tokens.easeOut
                }
            }

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: Tokens.spacing3
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing3

                    // Album art carries the same hairline every other surface
                    // does. Cover art is arbitrary imagery and frequently light
                    // at the edges; without the stroke it bleeds into the card
                    // instead of reading as a tile sitting on it.
                    Rectangle {
                        Layout.preferredWidth: 76
                        Layout.preferredHeight: 76
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

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, Tokens.elev1Border)
                            antialiasing: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Tokens.spacing1

                        // Which app is playing. Two players are routinely alive
                        // at once — a browser tab and Spotify — and `player`
                        // picks between them on playback state alone, so the
                        // card has to say which one it landed on.
                        Text {
                            renderType: Text.NativeRendering
                            Layout.fillWidth: true
                            text: (root.player?.identity ?? "").toUpperCase()
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.text2xs
                            font.weight: Tokens.weightSemibold
                            font.letterSpacing: 0.6
                            color: Tokens.dim
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }

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
                            text: root.player?.trackArtist || root.player?.trackAlbum || ""
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textSm
                            color: Tokens.muted
                            elide: Text.ElideRight
                            visible: text.length > 0
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // Progress. The times sit UNDER the track rather than flanking
                // it, which is what let the track go full width — flanked, it
                // lost ~90px to two labels and the seek target was a 4px ribbon
                // in the middle of the card.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing1

                    Item {
                        id: track

                        readonly property bool seekable:
                            root.hasProgress && (root.player?.canSeek ?? false)

                        Layout.fillWidth: true
                        // The hit area, not the track: a 4px bar is a 4px bar to
                        // aim at, and seeking is a drag, not a tap.
                        implicitHeight: Tokens.spacing4

                        Rectangle {
                            id: groove

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: Tokens.spacing1
                            radius: Tokens.radiusPill
                            color: Qt.rgba(1, 1, 1, 0.10)

                            Rectangle {
                                width: groove.width * root.progress
                                height: parent.height
                                radius: Tokens.radiusPill
                                color: Accent.accent

                                // Only the once-a-second tick is smoothed. A
                                // seek or a track change is a jump, and easing
                                // it makes the bar look like it is still playing
                                // the old position.
                                Behavior on width {
                                    enabled: root.playing && !seek.pressed
                                    NumberAnimation { duration: 1000 }
                                }
                            }
                        }

                        // The playhead. Appears on hover only — parked on the
                        // bar at rest it reads as a permanent bead, and the
                        // point of showing it is to say "this is draggable".
                        Rectangle {
                            id: head

                            width: Tokens.spacing2h
                            height: width
                            radius: Tokens.radiusPill
                            color: Tokens.text
                            antialiasing: true
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(track.width - width,
                                groove.width * root.progress - width / 2))
                            opacity: track.seekable && (seekHover.hovered || seek.pressed) ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Tokens.dur1
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Tokens.easeStandard
                                }
                            }
                        }

                        HoverHandler { id: seekHover }

                        MouseArea {
                            id: seek

                            anchors.fill: parent
                            enabled: track.seekable
                            cursorShape: Qt.PointingHandCursor

                            function seekTo(x) {
                                if (!track.seekable || groove.width <= 0) return;
                                const ratio = Math.max(0, Math.min(1, x / groove.width));
                                root.player.position = ratio * root.player.length;
                            }

                            onPressed: event => seekTo(event.x)
                            onPositionChanged: event => { if (pressed) seekTo(event.x); }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            renderType: Text.NativeRendering
                            text: root.hasProgress ? root.timeText(root.player.position) : "--:--"
                            font.family: Tokens.fontMono
                            font.pixelSize: Tokens.text2xs
                            color: Tokens.dim
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            renderType: Text.NativeRendering
                            text: root.hasProgress ? root.timeText(root.player.length) : "--:--"
                            font.family: Tokens.fontMono
                            font.pixelSize: Tokens.text2xs
                            color: Tokens.dim
                        }
                    }
                }

                // Transport. Play/pause is a filled disc rather than a fourth
                // bare glyph — in the bar the three controls are peers, but the
                // card is a place you land on to do one thing, and that thing is
                // almost always pause.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing4

                    Item { Layout.fillWidth: true }

                    BarButton {
                        glyph: "\u{f04ae}"
                        tooltip: "Previous"
                        enabled: root.player?.canGoPrevious ?? false
                        opacity: enabled ? 1 : 0.4
                        onClicked: root.player.previous()
                    }

                    Rectangle {
                        id: playButton

                        implicitWidth: Tokens.iconHit - Tokens.spacing1
                        implicitHeight: implicitWidth
                        radius: Tokens.radiusPill
                        color: playMouse.containsMouse ? Accent.accentHover : Accent.accent
                        opacity: (root.player?.canTogglePlaying ?? false) ? 1 : 0.4
                        antialiasing: true
                        scale: playMouse.pressed ? 0.92 : 1.0

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.dur1
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Tokens.easeStandard
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Tokens.dur1
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Tokens.easeOut
                            }
                        }

                        Glyph {
                            anchors.centerIn: parent
                            text: root.playing ? "\u{f03e4}" : "\u{f040a}"
                            size: Tokens.iconMd
                            color: Accent.accentFg
                        }

                        MouseArea {
                            id: playMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.player?.canTogglePlaying ?? false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.player.togglePlaying()
                        }
                    }

                    BarButton {
                        glyph: "\u{f04ad}"
                        tooltip: "Next"
                        enabled: root.player?.canGoNext ?? false
                        opacity: enabled ? 1 : 0.4
                        onClicked: root.player.next()
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
