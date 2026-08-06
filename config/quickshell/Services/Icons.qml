// Application icon lookup, as a chain rather than a single guess.
//
// The desktop entry is the good source — it is the only one that knows the app's
// declared Icon= — but DesktopEntries comes up empty on some Quickshell builds
// (0.3.0 on the Fedora COPR indexes nothing), and a dock of blank squares is a
// worse failure than a slightly wrong icon. So the entry is the first candidate,
// not the only one: the desktop id and the window class are both real icon names
// in every theme this ships against.
//
// This lives here rather than in DockTile because the pin picker resolves icons
// for apps that have no tile yet, and two copies of a fallback chain drift.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property var preferredIcons: ({
        // Kitty also ships a hicolor icon, and user themes may provide their own
        // `kitty.svg`; the legacy Waybar dock already uses Papirus here, so keep
        // the Quickshell bar/dock on the same artwork.
        "kitty": "file:///usr/share/icons/Papirus/64x64/apps/kitty.svg"
    })

    function preferred(entryIcon, desktopId, appId): string {
        const keys = [
            appId ?? "",
            (desktopId ?? "").replace(/\.desktop$/, ""),
            entryIcon ?? ""
        ];
        for (const raw of keys) {
            const key = raw.toLowerCase();
            const path = preferredIcons[key] ?? "";
            if (path !== "")
                return path;
        }
        return "";
    }

    // Untyped parameters on purpose: callers pass `entry?.icon`, which is
    // undefined whenever the entry is missing — precisely the case this exists
    // to survive — and a `string` annotation rejects it.
    //
    // iconPath's second argument is a NAME to fall back to in the string
    // overload, but `true` selects the check overload, which returns "" when the
    // theme has no such icon. That is what makes this a chain at all — without
    // it every candidate "resolves" to an image:// URL that renders as nothing.
    function resolve(entryIcon, desktopId, appId, generic) {
        const preferredPath = preferred(entryIcon, desktopId, appId);
        if (preferredPath !== "")
            return preferredPath;

        const candidates = [
            entryIcon ?? "",
            (desktopId ?? "").replace(/\.desktop$/, ""),
            appId ?? "",
            // Only where a generic square beats an empty one. A tile carrying
            // its own glyph is meant to draw that glyph, not a mystery binary.
            generic ? "application-x-executable" : ""
        ];
        for (const name of candidates) {
            if (name === "")
                continue;
            const path = Quickshell.iconPath(name, true);
            if (path !== "")
                return path;
        }
        return "";
    }
}
