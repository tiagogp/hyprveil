// The lock screen.
//
// Moved off hyprlock for the things hyprlock structurally cannot express: the
// 104px clock's -0.02em tracking (~2px per character at that size), per-element
// font weights, the pill's inset top highlight, animated affordances, and the
// bottom status row.
// Everything else matches what hyprlock.conf already drew.
//
// The lock uses the same saved wallpaper as the desktop, blurred behind a dark
// wash so the project typography still carries the screen.
//
// SAFETY: this holds an ext-session-lock. If this process dies while locked, the
// compositor keeps the session locked with no client to unlock it — that is the
// protocol's security guarantee, and it is also how a bug here becomes a
// lockout. hypr/scripts/lock.sh falls back to hyprlock whenever this shell
// cannot be confirmed, and hyprlock stays installed for exactly that reason.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import ".."

Scope {
    id: root

    property bool locked: false

    // The notification scope, so the lock can show HOW MANY arrived without
    // showing what they say. Null-safe: the lock still works standalone.
    property var notifications: null
    readonly property string stateHome:
        Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"
    readonly property string wallpaperStatePath: stateHome + "/hyprveil/wallpapers.json"
    readonly property string fallbackWallpaper: Quickshell.env("HOME") + "/.config/hypr/wallpaper-default.jpg"
    property string wallpaperPath: fallbackWallpaper

    FileView {
        id: wallpaperState
        path: root.wallpaperStatePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallpaperPath = root._wallpaperFromState(text())
        onLoadFailed: root.wallpaperPath = root.fallbackWallpaper
    }

    function _wallpaperFromState(raw: string): string {
        try {
            const parsed = JSON.parse(raw);
            if (parsed && parsed.fallback && typeof parsed.fallback.path === "string"
                    && parsed.fallback.path.length > 0)
                return parsed.fallback.path;
        } catch (e) {
            console.warn("wallpapers.json is malformed; using the local lock fallback");
        }
        return fallbackWallpaper;
    }

    WlSessionLock {
        id: session
        locked: root.locked

        surface: WlSessionLockSurface {
            id: lockSurface
            color: "#0d0e11"

            // Authentication state lives on the surface so a multi-monitor lock
            // gets one context per surface rather than a shared one that two
            // screens could drive into conflicting states.
            property string entry: ""
            property bool busy: false
            property string failure: ""
            property bool presented: false
            property bool capsLock: false
            // Counted per surface, and only shown from the second failure on —
            // the first one is already explained by "Wrong password".
            property int attempts: 0

            PamContext {
                id: pam
                // The same config hyprlock uses, so a machine that could unlock
                // before can still unlock now — this deliberately does not
                // introduce a new PAM stack.
                config: "hyprlock"

                onPamMessage: if (responseRequired) respond(entry)

                onCompleted: function (result) {
                    busy = false;
                    entry = "";
                    if (result === PamResult.Success) {
                        attempts = 0;
                        root.locked = false;
                        return;
                    }
                    attempts += 1;
                    failure = result === PamResult.MaxTries
                        ? "Too many attempts" : "Wrong password";
                    shake.restart();
                    // A rejected password is both the moment caps lock matters
                    // most and a natural place to re-read it without polling.
                    // This is what covers the case where the compositor never
                    // delivered the Key_CapsLock press.
                    if (!capsProbe.running) capsProbe.running = true;
                }

                // A PAM failure must not leave the field permanently disabled —
                // that would be a lockout with a working password.
                onError: function (error) {
                    busy = false;
                    entry = "";
                    failure = "Authentication unavailable";
                    shake.restart();
                }
            }

            function submit() {
                if (busy || entry.length === 0) return;
                failure = "";
                busy = true;
                if (!pam.start()) {
                    busy = false;
                    failure = "Authentication unavailable";
                }
            }

            onVisibleChanged: {
                if (visible) {
                    presented = false;
                    // Established BEFORE the first keystroke: a caps lock that
                    // was already on when the screen appeared is exactly the
                    // case the typing heuristic cannot catch, because by the
                    // time it fires the whole password has been typed wrong.
                    capsProbe.running = true;
                    revealDelay.restart();
                }
            }

            // Caps lock is not a modifier QML can query — Qt exposes no lock
            // state — so it is established three ways that agree:
            //   1. this probe, once, when the lock appears;
            //   2. the Key_CapsLock press, for a toggle while locked;
            //   3. the letter-case heuristic below, which self-corrects if
            //      either of the first two missed.
            //
            // The glob matters: the LED is named after the input device index
            // (input2::capslock here), which differs per machine and changes
            // when a keyboard is hotplugged, so no fixed path works. Taking the
            // max over all of them means any keyboard with the light on counts.
            // A machine with no such LED — a VM, some laptops — prints nothing
            // and falls to false, which is the safe default: a missing warning
            // degrades to today's behaviour, a wrong one trains you to ignore it.
            Process {
                id: capsProbe
                command: ["sh", "-c",
                    "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -rn | head -1"]
                stdout: StdioCollector {
                    onStreamFinished: lockSurface.capsLock = text.trim() === "1"
                }
            }

            Timer {
                id: revealDelay
                interval: 16
                repeat: false
                onTriggered: presented = true
            }

            Item {
                id: keyScope
                anchors.fill: parent
                focus: true

                // The lock surface is the only thing on screen, so it should
                // never lose focus — but if it ever does, every keystroke goes
                // nowhere and the screen looks identical to a working one. This
                // takes it back rather than leaving a dead password field.
                Component.onCompleted: forceActiveFocus()
                onActiveFocusChanged: if (!activeFocus) refocus.restart()

                Timer {
                    id: refocus
                    interval: 50
                    onTriggered: keyScope.forceActiveFocus()
                }

                // Anything that reaches the background restores focus. Declared
                // first so it sits UNDER the media transport: later siblings
                // stack on top and get the click first, so this only catches
                // what nothing else wanted.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onPressed: function (mouse) {
                        keyScope.forceActiveFocus();
                        mouse.accepted = true;
                    }
                }

                Image {
                    id: wallpaper
                    anchors.fill: parent
                    source: "file://" + root.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: false
                }

                MultiEffect {
                    anchors.fill: wallpaper
                    source: wallpaper
                    blurEnabled: true
                    blurMax: 64
                    blur: 1.0
                    saturation: 0.82
                    opacity: 0.46
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0.05, 0.055, 0.067, 0.58)
                    opacity: presented ? 1 : 0.78

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Tokens.dur4
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.easeOut
                        }
                    }
                }

                Keys.onPressed: function (event) {
                    // Toggling caps lock produces no text, so the heuristic
                    // below cannot see it — but the key press itself arrives.
                    // Handled before the busy check so the warning stays honest
                    // even while PAM is out.
                    if (event.key === Qt.Key_CapsLock) {
                        capsLock = !capsLock;
                        event.accepted = true;
                        return;
                    }

                    // The self-correcting cross-check: a letter whose case
                    // disagrees with the shift key. Every other key leaves the
                    // flag as it was, so it survives digits and punctuation
                    // rather than flickering off mid-password.
                    if (/^[A-Za-z]$/.test(event.text)) {
                        const shifted = (event.modifiers & Qt.ShiftModifier) !== 0;
                        capsLock = (event.text === event.text.toUpperCase()) !== shifted;
                    }

                    // Swallowed rather than ignored: a keystroke that fell through
                    // while PAM was mid-check would reach whatever had focus next.
                    if (busy) {
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        submit();
                    } else if (event.key === Qt.Key_Backspace) {
                        entry = entry.slice(0, -1);
                        failure = "";
                    } else if (event.key === Qt.Key_Escape) {
                        entry = "";
                        failure = "";
                    } else if (event.text.length > 0
                               && !/[\u0000-\u001f\u007f]/.test(event.text)) {
                        // Accept whatever the layout actually produced rather than
                        // only single ASCII chars. The old `length === 1` test
                        // silently dropped two classes of legitimate password
                        // input: IME / dead-key commits (which arrive as
                        // multi-char text) and astral-plane characters (encoded
                        // as surrogate pairs, so length 2). Both would make a
                        // working password untypeable here. Control bytes are
                        // still rejected, and Return / Backspace / Escape are
                        // handled above so they never reach this branch.
                        entry += event.text;
                        failure = "";
                    }
                    event.accepted = true;
                }

                ColumnLayout {
                    id: content
                    anchors.centerIn: parent
                    spacing: 0
                    opacity: presented ? 1 : 0
                    scale: presented ? 1 : 0.985
                    transformOrigin: Item.Center

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Tokens.dur3
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.easeOut
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Tokens.dur4
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.easeOut
                        }
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignHCenter
                        text: Time.clock
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textClock
                        font.weight: Font.Light
                        // hyprlock has no tracking control at all. At 104px this
                        // is ~2px per character — the difference is visible.
                        font.letterSpacing: -0.02 * Tokens.textClock
                        color: Tokens.text
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.spacing2h
                        text: Time.date
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textLg
                        color: Tokens.muted
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 44
                        implicitWidth: 76
                        implicitHeight: 76
                        radius: width / 2
                        color: Accent.accentSoft
                        border.width: Tokens.spacingHair
                        border.color: Accent.accent

                        Text {
                            renderType: Text.NativeRendering
                            anchors.centerIn: parent
                            text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textAvatar
                            font.weight: Tokens.weightSemibold
                            color: Accent.accent
                        }
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.spacing3
                        text: Quickshell.env("USER") ?? ""
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textMd
                        font.weight: Tokens.weightMedium
                        color: Tokens.text
                    }

                    // The password pill.
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.spacing5 + Tokens.spacingHair
                        implicitWidth: 280
                        implicitHeight: 46
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, keyScope.activeFocus ? 0.08 : 0.06)
                        border.width: 1
                        // The field is live and keystrokes land here. Without
                        // this the pill looked identical whether it had focus
                        // or not, so a dead field and a working one were
                        // indistinguishable until you typed and nothing moved.
                        border.color: failure !== "" ? Tokens.error
                            : keyScope.activeFocus ? Accent.accent
                            : Qt.rgba(1, 1, 1, 0.12)
                        clip: true

                        Behavior on border.color { ColorAnimation { duration: Tokens.dur2 } }
                        Behavior on color { ColorAnimation { duration: Tokens.dur2 } }

                        // Shaken through a Translate rather than by animating x:
                        // the pill's x belongs to the ColumnLayout, and writing
                        // it fights the layout instead of moving the pill.
                        transform: Translate { id: shakeOffset }

                        SequentialAnimation {
                            id: shake
                            loops: 2
                            NumberAnimation {
                                target: shakeOffset; property: "x"
                                to: -8; duration: Tokens.dur1
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: shakeOffset; property: "x"
                                to: 8; duration: Tokens.dur1 * 2
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                target: shakeOffset; property: "x"
                                to: 0; duration: Tokens.dur1
                                easing.type: Easing.InQuad
                            }
                        }

                        // The design's `inset 0 1px 0 rgba(255,255,255,0.08)`.
                        // Qt Quick clips Rectangle children to the bounding box,
                        // not to the rounded radius, so keep the sheen away from
                        // the curved ends instead of drawing a full-width strip.
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: 1
                            anchors.leftMargin: parent.radius
                            anchors.rightMargin: parent.radius
                            height: 1
                            radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.spacing4 + Tokens.spacingHair
                            anchors.rightMargin: Tokens.spacing4 + Tokens.spacingHair
                            spacing: Tokens.spacing2h

                            Item {
                                Layout.preferredWidth: Tokens.iconSm
                                Layout.preferredHeight: Tokens.iconSm

                                Glyph {
                                    anchors.centerIn: parent
                                    visible: !busy
                                    text: "\u{f033e}"
                                    size: Tokens.iconSm
                                    color: failure !== "" ? Tokens.error : Tokens.dim
                                }

                                Row {
                                    anchors.centerIn: parent
                                    visible: busy
                                    spacing: 3

                                    Repeater {
                                        model: 3

                                        Rectangle {
                                            width: 3
                                            height: 3
                                            radius: height / 2
                                            color: Accent.accent
                                            opacity: 0.35

                                            SequentialAnimation on opacity {
                                                running: busy
                                                loops: Animation.Infinite
                                                PauseAnimation { duration: index * 110 }
                                                NumberAnimation {
                                                    to: 1
                                                    duration: Tokens.dur2h
                                                    easing.type: Easing.OutCubic
                                                }
                                                NumberAnimation {
                                                    to: 0.35
                                                    duration: Tokens.dur3
                                                    easing.type: Easing.InOutCubic
                                                }
                                                PauseAnimation { duration: 220 - index * 55 }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                id: pillText
                                renderType: Text.NativeRendering
                                // No longer fillWidth: the caret has to sit
                                // immediately after the last dot, and a Text
                                // that eats the row pushes it to the far edge.
                                Layout.maximumWidth: 190
                                text: {
                                    if (busy) return "Unlocking";
                                    if (failure !== "") return failure;
                                    if (entry.length === 0) return "Enter password";
                                    // Dots rather than the character count, so a
                                    // shoulder-surfer learns nothing from length
                                    // beyond what the field already shows.
                                    return "•".repeat(Math.min(entry.length, 20));
                                }
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textSm
                                color: failure !== "" ? Tokens.error
                                     : entry.length > 0 ? Tokens.text
                                     : Tokens.dim
                                elide: Text.ElideRight
                            }

                            // The caret. The second half of the focus signal:
                            // the accent border says the field is live, this
                            // says it is live RIGHT NOW and waiting on you.
                            // Hidden while PAM is out, because a blinking caret
                            // next to "Checking…" invites typing that the busy
                            // branch is about to swallow.
                            Rectangle {
                                id: caret
                                Layout.preferredWidth: 2
                                Layout.preferredHeight: Tokens.textSm + 4
                                radius: 1
                                color: Accent.accent
                                visible: keyScope.activeFocus && !busy && failure === ""

                                SequentialAnimation {
                                    running: caret.visible
                                    loops: Animation.Infinite
                                    // Restarts from opaque on every show, so the
                                    // caret never appears mid-blink as a ghost.
                                    onStopped: caret.opacity = 1

                                    PropertyAction {
                                        target: caret; property: "opacity"; value: 1
                                    }
                                    PauseAnimation { duration: 500 }
                                    NumberAnimation {
                                        target: caret; property: "opacity"
                                        to: 0; duration: Tokens.dur2
                                    }
                                    PauseAnimation { duration: 300 }
                                    NumberAnimation {
                                        target: caret; property: "opacity"
                                        to: 1; duration: Tokens.dur2
                                    }
                                }
                            }

                            // Absorbs the leftover width so the glyph, text, and
                            // caret stay left-aligned as a group.
                            Item { Layout.fillWidth: true }
                        }
                    }

                    // Caps lock and the repeat-failure hint share one slot: both
                    // answer "why did that not work", and stacking two lines
                    // under the pill would push the composition off centre.
                    // Reserves its height either way so nothing jumps when it
                    // appears mid-typing.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Tokens.spacing3
                        spacing: Tokens.spacing1h
                        opacity: capsLock || attempts > 1 ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Tokens.dur2
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.easeOut
                            }
                        }

                        Glyph {
                            // md-caps_lock vs md-alert — the glyph has to agree
                            // with the line next to it.
                            text: capsLock ? "\u{f0a9b}" : "\u{f0026}"
                            size: Tokens.iconSm
                            color: Tokens.warning
                        }

                        Text {
                            renderType: Text.NativeRendering
                            text: capsLock ? "Caps Lock is on"
                                : attempts + " failed attempts"
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textXs
                            color: Tokens.warning
                        }
                    }
                }

                // The bottom band: media on the left, live status centred,
                // notification count on the right.
                //
                // The two glyphs that used to sit here were decorative — a
                // hardcoded network and battery icon that tracked nothing. A
                // lock screen is exactly where a real battery reading earns its
                // place, so these are bound to the same services the bar uses.
                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.spacing8 + Tokens.spacing1
                    anchors.leftMargin: Tokens.spacing8
                    anchors.rightMargin: Tokens.spacing8
                    implicitHeight: mediaCard.height
                    opacity: presented ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Tokens.dur3
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.easeOut
                        }
                    }

                    // --- Now playing ---
                    //
                    // Prefers a playing player over a paused one, the same rule
                    // Bar/Media.qml applies: a stale paused browser tab must not
                    // outrank the thing actually making sound.
                    readonly property var player: {
                        const all = Mpris.players.values;
                        return all.find(p => p.playbackState === MprisPlaybackState.Playing)
                            ?? all.find(p => p.playbackState === MprisPlaybackState.Paused)
                            ?? null;
                    }

                    Surface {
                        id: mediaCard
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 340
                        height: 76
                        elevation: 1
                        radius: Tokens.radiusLg
                        visible: parent.player !== null

                        readonly property var player: parent.player

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.spacing2h
                            spacing: Tokens.spacing2h

                            Rectangle {
                                Layout.preferredWidth: 52
                                Layout.preferredHeight: 52
                                radius: Tokens.radiusSm
                                color: Accent.accentSoft
                                clip: true
                                antialiasing: true

                                Image {
                                    id: lockArt
                                    anchors.fill: parent
                                    source: mediaCard.player?.trackArtUrl ?? ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                Glyph {
                                    anchors.centerIn: parent
                                    text: "\u{f075a}"
                                    size: Tokens.iconLg
                                    color: Accent.accent
                                    visible: !lockArt.visible
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacingHair

                                Text {
                                    renderType: Text.NativeRendering
                                    Layout.fillWidth: true
                                    text: mediaCard.player?.trackTitle || "Nothing playing"
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.textSm
                                    font.weight: Tokens.weightMedium
                                    color: Tokens.text
                                    elide: Text.ElideRight
                                }

                                Text {
                                    renderType: Text.NativeRendering
                                    Layout.fillWidth: true
                                    text: mediaCard.player?.trackArtist
                                        || mediaCard.player?.identity || ""
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.textXs
                                    color: Tokens.muted
                                    elide: Text.ElideRight
                                }
                            }

                            // Transport. These are bare MouseAreas rather than
                            // BarButton because BarButton carries a tooltip
                            // PopupWindow, and a lock surface is not a window
                            // stack that can host one.
                            //
                            // acceptedButtons is left-only and none of these take
                            // focus: the Item above owns keyboard focus for the
                            // whole surface, and a click that stole it would
                            // leave the password field silently dead.
                            Repeater {
                                model: [
                                    { glyph: "\u{f04ae}", action: "previous" },
                                    { glyph: "toggle",    action: "toggle" },
                                    { glyph: "\u{f04ad}", action: "next" }
                                ]

                                Item {
                                    required property var modelData
                                    implicitWidth: Tokens.iconHit
                                    implicitHeight: Tokens.iconHit

                                    readonly property bool playing:
                                        mediaCard.player?.playbackState === MprisPlaybackState.Playing
                                    readonly property bool available: {
                                        if (!mediaCard.player) return false;
                                        if (modelData.action === "previous")
                                            return mediaCard.player.canGoPrevious;
                                        if (modelData.action === "next")
                                            return mediaCard.player.canGoNext;
                                        return mediaCard.player.canTogglePlaying;
                                    }

                                    Glyph {
                                        anchors.centerIn: parent
                                        text: modelData.glyph === "toggle"
                                            ? (parent.playing ? "\u{f03e4}" : "\u{f040a}")
                                            : modelData.glyph
                                        size: Tokens.iconSm
                                        color: transportHover.hovered
                                            ? Tokens.text : Tokens.muted
                                        opacity: parent.available ? 1 : 0.4

                                        Behavior on color {
                                            ColorAnimation { duration: Tokens.dur1 }
                                        }
                                    }

                                    HoverHandler { id: transportHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: parent.available
                                        acceptedButtons: Qt.LeftButton
                                        onClicked: {
                                            // Belt and braces: these MouseAreas
                                            // do not take focus, but a transport
                                            // click that ever did would leave the
                                            // password field silently dead.
                                            keyScope.forceActiveFocus();
                                            const p = mediaCard.player;
                                            if (!p) return;
                                            if (modelData.action === "previous") p.previous();
                                            else if (modelData.action === "next") p.next();
                                            else p.togglePlaying();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- Live status ---
                    RowLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.spacing6 - Tokens.spacingHair

                        // Battery. Desktops report none, and the group disappears
                        // rather than showing a permanent 0%.
                        RowLayout {
                            readonly property var bat: UPower.displayDevice
                            visible: bat?.isLaptopBattery ?? false
                            spacing: Tokens.spacing1h

                            Glyph {
                                readonly property real pct: parent.bat?.percentage ?? 0
                                readonly property bool charging:
                                    parent.bat?.state === UPowerDeviceState.Charging

                                text: charging ? "\u{f0084}"
                                    : pct > 0.85 ? "\u{f0079}"
                                    : pct > 0.60 ? "\u{f0082}"
                                    : pct > 0.30 ? "\u{f007f}"
                                    : pct > 0.10 ? "\u{f007b}"
                                    : "\u{f007a}"
                                size: Tokens.iconSm
                                color: parent.bat?.percentage <= 0.10 ? Tokens.error
                                     : parent.bat?.percentage <= 0.20 ? Tokens.warning
                                     : Tokens.dim
                            }

                            Text {
                                renderType: Text.NativeRendering
                                text: Math.round((parent.bat?.percentage ?? 0) * 100) + "%"
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textXs
                                color: Tokens.dim
                            }
                        }

                        // Bluetooth, shown only when something is actually
                        // connected — an "off" glyph on a lock screen is noise.
                        Glyph {
                            readonly property int connected:
                                Bluetooth.devices.values.filter(d => d.connected).length

                            visible: connected > 0
                            text: "\u{f00b1}"
                            size: Tokens.iconSm
                            color: Tokens.dim
                        }
                    }

                    // --- Notifications ---
                    //
                    // The count only. Titles and bodies stay behind the lock:
                    // rendering them here would undo the point of locking.
                    RowLayout {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.spacing1h
                        visible: count > 0

                        readonly property int count:
                            root.notifications?.notifications?.values?.length ?? 0

                        Glyph {
                            text: "\u{f009a}"
                            size: Tokens.iconSm
                            color: Accent.accent
                        }

                        Text {
                            renderType: Text.NativeRendering
                            text: parent.count + (parent.count === 1
                                ? " notification" : " notifications")
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textXs
                            color: Tokens.muted
                        }
                    }
                }
            }
        }
    }

    // hypr/scripts/lock.sh calls this, and falls back to hyprlock if it does not
    // answer. `lock` is deliberately one-way: there is no unlock over IPC, or
    // the lock would be trivially bypassable by anything that can reach the
    // socket.
    IpcHandler {
        target: "lock"

        function lock(): string {
            root.locked = true;
            return "locked";
        }

        function isLocked(): string {
            return root.locked ? "locked" : "unlocked";
        }
    }
}
