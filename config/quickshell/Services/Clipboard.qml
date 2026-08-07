pragma Singleton

import QtQuick
import Quickshell
import "../Adapters"
import "../Utils"

Singleton {
    readonly property bool available: ClipboardAdapter.available
    readonly property var state: ClipboardAdapter.entries
    readonly property bool busy: ClipboardAdapter.busy
    readonly property string error: ClipboardAdapter.error
    readonly property double lastUpdated: ClipboardAdapter.lastUpdated
    readonly property var entries: ClipboardAdapter.entries
    readonly property string thumbnailDirectory: Paths.clipboardThumbs
    signal thumbnailReady(string path)

    function refresh(): void { ClipboardAdapter.refresh(); }
    function preview(entry: string): string { return Strings.clipboardPreview(entry); }
    function isImage(entry: string): bool { return Strings.isClipboardImage(entry); }
    function copy(entry: string): void { ClipboardAdapter.copy(entry); }
    function remove(entry: string): void { ClipboardAdapter.remove(entry); }
    function clear(): void { ClipboardAdapter.clear(); }
    function ensureThumbnail(entry: string, path: string): void { ClipboardAdapter.ensureThumbnail(entry, path); }

    Connections {
        target: ClipboardAdapter
        function onThumbnailReady(path: string) { thumbnailReady(path); }
    }
}
