pragma Singleton

import QtQuick
import Quickshell

Singleton {
    function clipboardPreview(entry: string): string {
        return entry.replace(/^\s*\d+\s+/, "");
    }

    function isClipboardImage(entry: string): bool {
        return /binary data.*\b(png|jpe?g|gif|bmp|webp|tiff|ico)\b/i.test(entry);
    }

    function basename(path: string): string {
        const parts = path.split("/").filter(part => part.length > 0);
        return parts.length > 0 ? parts[parts.length - 1] : path;
    }
}
