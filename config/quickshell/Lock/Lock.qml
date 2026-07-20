// The lock screen.
//
// Moved off hyprlock for the things hyprlock structurally cannot express: the
// 104px clock's -0.02em tracking (~2px per character at that size), per-element
// font weights, the pill's inset top highlight, and the bottom status row.
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
import ".."

Scope {
    id: root

    property bool locked: false
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
            color: "#0d0e11"

            // Authentication state lives on the surface so a multi-monitor lock
            // gets one context per surface rather than a shared one that two
            // screens could drive into conflicting states.
            property string entry: ""
            property bool busy: false
            property string failure: ""

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
                        root.locked = false;
                        return;
                    }
                    failure = result === PamResult.MaxTries
                        ? "Too many attempts" : "Wrong password";
                }

                // A PAM failure must not leave the field permanently disabled —
                // that would be a lockout with a working password.
                onError: function (error) {
                    busy = false;
                    entry = "";
                    failure = "Authentication unavailable";
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

            Item {
                anchors.fill: parent
                focus: true

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
                }

                Keys.onPressed: function (event) {
                    if (busy) return;
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        submit();
                    } else if (event.key === Qt.Key_Backspace) {
                        entry = entry.slice(0, -1);
                        failure = "";
                    } else if (event.key === Qt.Key_Escape) {
                        entry = "";
                        failure = "";
                    } else if (event.text && event.text.length === 1
                               && event.text.charCodeAt(0) >= 0x20) {
                        entry += event.text;
                        failure = "";
                    }
                    event.accepted = true;
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
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
                            anchors.centerIn: parent
                            text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textAvatar
                            font.weight: Tokens.weightSemibold
                            color: Accent.accent
                        }
                    }

                    Text {
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
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.width: 1
                        border.color: failure !== ""
                            ? Tokens.error : Qt.rgba(1, 1, 1, 0.12)
                        clip: true

                        Behavior on border.color { ColorAnimation { duration: Tokens.dur2 } }

                        // The design's `inset 0 1px 0 rgba(255,255,255,0.08)`.
                        // hyprlock has no inset-shadow primitive; here it is one
                        // hairline clipped by the pill's own radius.
                        Rectangle {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            anchors.margins: 1
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.spacing4 + Tokens.spacingHair
                            anchors.rightMargin: Tokens.spacing4 + Tokens.spacingHair
                            spacing: Tokens.spacing2h

                            Glyph {
                                text: "\u{f033e}"
                                size: Tokens.iconSm
                                color: Tokens.dim
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    if (busy) return "Checking…";
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
                        }
                    }
                }

                // Status row. The design puts two muted glyphs at the bottom;
                // hyprlock had no bottom widgets at all.
                RowLayout {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Tokens.spacing8 + Tokens.spacing1
                    spacing: Tokens.spacing6 - Tokens.spacingHair

                    Glyph {
                        text: "\u{f05a9}"
                        size: Tokens.iconSm
                        color: Tokens.dim
                    }

                    Glyph {
                        text: "\u{f0425}"
                        size: Tokens.iconSm
                        color: Tokens.dim
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
