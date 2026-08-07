pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Utils"

Singleton {
    id: root

    property bool available: false
    property var entries: []
    property bool busy: lister.running || thumbnailer.running
    property string error: ""
    property double lastUpdated: 0
    property var thumbnailQueue: []
    property var thumbnailPending: ({})
    property string currentEntry: ""
    property string currentPath: ""
    signal thumbnailReady(string path)

    function refresh(): void {
        if (!lister.running) lister.running = true;
    }

    function copy(entry: string): void {
        if (available && entry) Quickshell.execDetached([
            "sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "hyprveil-clipboard-copy", entry]);
    }

    function remove(entry: string): void {
        if (!available || !entry) return;
        Quickshell.execDetached([
            "sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "hyprveil-clipboard-delete", entry]);
        reloadTimer.restart();
    }

    function clear(): void {
        if (!available) return;
        Quickshell.execDetached(["cliphist", "wipe"]);
        Quickshell.execDetached(["sh", "-c", "rm -rf -- \"$1\"", "hyprveil-clipboard-cache", Paths.clipboardThumbs]);
        entries = [];
        lastUpdated = Date.now();
    }

    function ensureThumbnail(entry: string, path: string): void {
        if (!entry || !path || thumbnailPending[path]) return;
        const nextPending = Object.assign({}, thumbnailPending);
        nextPending[path] = true;
        thumbnailPending = nextPending;
        thumbnailQueue = thumbnailQueue.concat([{ entry, path }]);
        startNextThumbnail();
    }

    function startNextThumbnail(): void {
        if (thumbnailer.running || thumbnailQueue.length === 0) return;
        const next = thumbnailQueue[0];
        thumbnailQueue = thumbnailQueue.slice(1);
        currentEntry = next.entry;
        currentPath = next.path;
        thumbnailer.running = true;
    }

    Process {
        id: lister
        command: ["sh", "-c",
            "if command -v cliphist >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then cliphist list; else printf '__HYPRVEIL_CLIPBOARD_UNAVAILABLE__\\n'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                root.available = output !== "__HYPRVEIL_CLIPBOARD_UNAVAILABLE__";
                root.entries = root.available && output !== "" ? output.split("\n") : [];
                root.error = root.available ? "" : "Clipboard tools unavailable";
                root.lastUpdated = Date.now();
            }
        }
    }

    Process {
        id: thumbnailer
        command: ["sh", "-c", `
            mkdir -p "$(dirname "$2")" || exit 0
            [ -f "$2" ] && exit 0
            im=$(command -v magick || command -v convert) || exit 0
            printf '%s\\n' "$1" | cliphist decode | "$im" - -resize 64x64 "$2" 2>/dev/null || true
        `, "_", root.currentEntry, root.currentPath]
        onRunningChanged: if (!running && root.currentPath !== "") {
            const completed = root.currentPath;
            const nextPending = Object.assign({}, root.thumbnailPending);
            delete nextPending[completed];
            root.thumbnailPending = nextPending;
            root.currentEntry = "";
            root.currentPath = "";
            root.thumbnailReady(completed);
            root.startNextThumbnail();
        }
    }

    Timer { id: reloadTimer; interval: 250; onTriggered: root.refresh() }
}
