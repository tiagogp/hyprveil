// Discovery point for persistent and session-wide shell state. Feature code
// binds here or to the typed child service; it never opens a JSON store.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property bool available: Settings.available && WallpaperService.available && Pins.available
    readonly property var state: ({
        settings: Settings.state,
        wallpapers: WallpaperService.state,
        pins: Pins.state,
        notifications: NotificationStore.state,
        shell: ShellActions.state
    })
    readonly property bool busy: Settings.busy || WallpaperService.busy || Pins.busy
    readonly property string error: Settings.error || WallpaperService.error || Pins.error
    readonly property double lastUpdated: Math.max(Settings.lastUpdated,
        WallpaperService.lastUpdated, Pins.lastUpdated, NotificationStore.lastUpdated,
        ShellActions.lastUpdated)

    function refresh(): void {
        Settings.refresh();
        WallpaperService.refresh();
        Pins.refresh();
        NotificationStore.refresh();
        ShellActions.refresh();
    }
}
