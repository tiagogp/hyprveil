// Clipboard history.
//
// Hyprveil already stores history through cliphist in hypr/autostart.conf and
// exposes a Rofi picker on SUPER+V. This section is a small panel view over the
// same database so there is still one clipboard history, not one per surface.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."
import "../Adapters"
import "../Design/Components"

HvSection {
    id: root

    glyph: "\u{f014f}"
    title: "Clipboard"

    property string query: ""
    property string status: "Checking clipboard history..."
    property var entries: []
    property bool toolsAvailable: false

    readonly property var filteredEntries: {
        const q = root.query.trim().toLowerCase();
        if (q === "")
            return root.entries;
        return root.entries.filter(entry =>
            root.preview(entry).toLowerCase().includes(q));
    }

    function preview(entry) {
        return entry.replace(/^\s*\d+\s+/, "");
    }

    // cliphist prints a binary entry as e.g. "[[ binary data 312 B png
    // 8x8 ]]" — "binary data" followed eventually by the decoded format
    // name, NOT an "image/…" mime string (verified against a real
    // `cliphist store`/`cliphist list` round trip). Anything binary that is
    // not one of the common image formats — a copied PDF, say — is left
    // alone rather than guessed at.
    function isImageEntry(entry) {
        return /binary data.*\b(png|jpe?g|gif|bmp|webp|tiff|ico)\b/i.test(entry);
    }

    // Discardable, capped, never the persistent history: a thumbnail is a
    // resized decode of something already IN cliphist's own database, kept
    // only long enough to draw a preview. Wiped by clearAll() below and safe
    // to lose entirely — reload() would just regenerate what is still
    // there.
    readonly property string thumbCacheDir:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
        + "/hyprveil/clipboard-thumbs"

    function reload() {
        lister.running = true;
    }

    function copy(entry) {
        SystemActions.clipboardCopy(entry);
    }

    function remove(entry) {
        SystemActions.clipboardDelete(entry);
        reloadTimer.restart();
    }

    function clearAll() {
        SystemActions.clipboardClear(root.thumbCacheDir);
        root.entries = [];
        root.status = "Clipboard history is empty";
    }

    Process {
        id: lister
        command: [
            "sh", "-c",
            "if command -v cliphist >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then cliphist list; else printf '__HYPRVEIL_CLIPBOARD_UNAVAILABLE__\\n'; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim();
                if (trimmed === "__HYPRVEIL_CLIPBOARD_UNAVAILABLE__") {
                    root.toolsAvailable = false;
                    root.entries = [];
                    root.status = "Clipboard tools unavailable";
                    return;
                }

                root.toolsAvailable = true;
                root.entries = trimmed === "" ? [] : trimmed.split("\n");
                root.status = root.entries.length > 0 ? "" : "Clipboard history is empty";
            }
        }
    }

    Timer {
        id: reloadTimer
        interval: 250
        repeat: false
        onTriggered: root.reload()
    }

    Component.onCompleted: root.reload()

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacing1
        visible: root.toolsAvailable
        spacing: Tokens.spacing2

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Tokens.spacing8
            radius: Tokens.radiusSm
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: search.activeFocus ? 1 : 0
            border.color: Accent.accent

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.spacing3
                anchors.rightMargin: Tokens.spacing3
                spacing: Tokens.spacing2

                Glyph {
                    text: "\u{f0349}"
                    size: Tokens.iconSm
                    color: Tokens.dim
                }

                TextInput {
                    id: search
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Search clipboard history"
                    color: Tokens.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textSm
                    selectionColor: Accent.accentSoft
                    selectedTextColor: Tokens.text
                    clip: true
                    onTextChanged: root.query = text
                }
            }

            Text {
                renderType: Text.NativeRendering
                anchors {
                    left: parent.left
                    leftMargin: Tokens.spacing8
                    verticalCenter: parent.verticalCenter
                }
                visible: search.text.length === 0
                text: "Search"
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textSm
                color: Tokens.dim
            }
        }

        Rectangle {
            implicitWidth: Tokens.spacing8
            implicitHeight: Tokens.spacing8
            radius: Tokens.radiusSm
            activeFocusOnTab: root.entries.length > 0
            opacity: root.entries.length > 0 ? 1.0 : 0.4
            color: clearAllMouse.containsMouse && root.entries.length > 0
                ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.07)
            border.width: activeFocus ? 1 : 0
            border.color: Accent.accent
            Accessible.role: Accessible.Button
            Accessible.name: "Clear clipboard history"

            Keys.onReturnPressed: if (root.entries.length > 0) root.clearAll()
            Keys.onSpacePressed: if (root.entries.length > 0) root.clearAll()

            Glyph {
                anchors.centerIn: parent
                text: "\u{f00e2}"
                size: Tokens.iconSm
                color: clearAllMouse.containsMouse && root.entries.length > 0
                    ? Accent.accent : Tokens.muted
            }

            MouseArea {
                id: clearAllMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.entries.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (root.entries.length > 0) root.clearAll()
            }
        }
    }

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        visible: !root.toolsAvailable || root.entries.length === 0
            || (root.entries.length > 0 && root.filteredEntries.length === 0)
        text: root.filteredEntries.length === 0 && root.entries.length > 0
            ? "No clipboard item matches \"" + root.query + "\""
            : root.status
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.toolsAvailable && root.filteredEntries.length > 0
        spacing: Tokens.spacing1

        Repeater {
            model: root.filteredEntries.slice(0, 6)

            Rectangle {
                id: entryRow
                required property string modelData
                readonly property bool isImage: root.isImageEntry(modelData)
                // cliphist's own entry id — already unique and stable, so it
                // doubles as the thumbnail cache key without hashing
                // anything.
                readonly property string entryId:
                    (modelData.match(/^\s*(\d+)/) ?? ["", ""])[1]
                readonly property string thumbPath:
                    entryId !== "" ? root.thumbCacheDir + "/" + entryId + ".png" : ""
                property bool thumbReady: false

                Layout.fillWidth: true
                implicitHeight: Tokens.spacing8
                radius: Tokens.radiusSm
                activeFocusOnTab: true
                color: clipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                border.width: activeFocus ? 1 : 0
                border.color: Accent.accent
                Accessible.role: Accessible.Button
                Accessible.name: (isImage ? "Copy clipboard image " : "Copy clipboard item ") + root.preview(modelData)

                Keys.onReturnPressed: root.copy(modelData)
                Keys.onSpacePressed: root.copy(modelData)
                Keys.onDeletePressed: root.remove(modelData)

                // Decodes and downsizes ONCE per entry id, to a capped
                // 64x64 PNG under thumbCacheDir — small enough that a full
                // panel of image entries stays cheap, and never the
                // original resolution/bytes cliphist itself holds.
                Process {
                    id: thumbGen
                    running: entryRow.isImage && entryRow.entryId !== ""
                    // A template literal (backtick string), not a regular
                    // QML string, specifically so this shell script can use
                    // ordinary double quotes around "$2" without escaping
                    // every one of them. `magick` preferred over the
                    // deprecated `convert` — same preference accent.sh's
                    // magick_cmd() already uses.
                    command: ["sh", "-c", `
                        mkdir -p "$(dirname "$2")" || exit 0
                        [ -f "$2" ] && exit 0
                        im=$(command -v magick || command -v convert) || exit 0
                        printf '%s\\n' "$1" | cliphist decode | "$im" - -resize 64x64 "$2" 2>/dev/null || true
                    `, "_", entryRow.modelData, entryRow.thumbPath]
                    onRunningChanged: if (!running) entryRow.thumbReady = true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacing2
                    anchors.rightMargin: Tokens.spacing1
                    spacing: Tokens.spacing2

                    Image {
                        id: thumbImage
                        visible: entryRow.isImage && status === Image.Ready
                        Layout.preferredWidth: Tokens.iconSm
                        Layout.preferredHeight: Tokens.iconSm
                        fillMode: Image.PreserveAspectCrop
                        source: (entryRow.isImage && entryRow.thumbReady && entryRow.thumbPath !== "")
                            ? "file://" + entryRow.thumbPath : ""
                        asynchronous: true
                    }

                    // The glyph doubles as the pending/failed state for an
                    // image entry — a picture icon while ImageMagick is not
                    // installed or the decode failed is still a truthful
                    // "this is an image", not a broken-image square.
                    Glyph {
                        visible: !entryRow.isImage || thumbImage.status !== Image.Ready
                        text: entryRow.isImage ? "\u{f021f}" : "\u{f014f}"
                        size: Tokens.iconSm
                        color: Tokens.muted
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: root.preview(modelData)
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textXs
                        color: Tokens.muted
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: Tokens.spacing6
                        implicitHeight: Tokens.spacing6
                        radius: Tokens.radiusSm
                        activeFocusOnTab: true
                        color: deleteMouse.containsMouse ? Accent.accentSoft : "transparent"
                        border.width: activeFocus ? 1 : 0
                        border.color: Accent.accent
                        Accessible.role: Accessible.Button
                        Accessible.name: "Clear clipboard item"

                        Keys.onReturnPressed: root.remove(modelData)
                        Keys.onSpacePressed: root.remove(modelData)

                        Glyph {
                            anchors.centerIn: parent
                            text: "\u{f0156}"
                            size: Tokens.iconSm
                            color: deleteMouse.containsMouse ? Accent.accent : Tokens.dim
                        }

                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.remove(modelData)
                        }
                    }
                }

                MouseArea {
                    id: clipMouse
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        bottom: parent.bottom
                        rightMargin: Tokens.spacing6 + Tokens.spacing1
                    }
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copy(modelData)
                }
            }
        }
    }
}
