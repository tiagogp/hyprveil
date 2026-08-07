pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome:
        Quickshell.env("HYPRVEIL_CONFIG_HOME")
        || Quickshell.env("XDG_CONFIG_HOME")
        || home + "/.config"
    readonly property string stateHome:
        Quickshell.env("HYPRVEIL_STATE_HOME")
        || (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/hyprveil"
    readonly property string cacheHome:
        (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/hyprveil"
    readonly property string shellConfigDir: configHome + "/hyprveil"
    readonly property string shellConfig: shellConfigDir + "/shell.json"
    readonly property string legacyShellConfig: stateHome + "/settings.json"
    readonly property string hyprConfig: configHome + "/hypr"
    readonly property string hyprScripts: hyprConfig + "/scripts"
    readonly property string settingsSchema: hyprScripts + "/data/settings-schema.json"
    readonly property string launcherProviders: hyprScripts + "/data/launcher-providers.json"
    readonly property string clipboardThumbs: cacheHome + "/clipboard-thumbs"
    readonly property string fallbackWallpaper: hyprConfig + "/wallpaper-default.jpg"
}
