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
        clipboard: Clipboard.state,
        launcherProviders: LauncherProviders.state,
        shell: ShellActions.state
    })
    readonly property bool busy: Settings.busy || WallpaperService.busy || Pins.busy
        || Clipboard.busy || LauncherProviders.busy
    readonly property string error: Settings.error || WallpaperService.error || Pins.error
        || Clipboard.error || LauncherProviders.error
    readonly property double lastUpdated: Math.max(Settings.lastUpdated,
        WallpaperService.lastUpdated, Pins.lastUpdated, NotificationStore.lastUpdated,
        ShellActions.lastUpdated, Clipboard.lastUpdated, LauncherProviders.lastUpdated)

    function refresh(): void {
        Settings.refresh();
        WallpaperService.refresh();
        Pins.refresh();
        NotificationStore.refresh();
        Clipboard.refresh();
        LauncherProviders.refresh();
        ShellActions.refresh();
    }
}
