// Runtime composition depends only on the public feature module. Hosts own
// their controllers and are the only layer that registers interactive
// surfaces with the session-wide coordinator.
import Quickshell
import ".."
import "../Features"
import "../Services"

ShellRoot {
    id: app

    AnchoredHost {
        id: anchoredHost

        QuickSettingsFeature {
            id: qsPanel
            notifications: notifs
            wallpapers: wallpaperPicker
            cheatsheet: keybindSheet
            integrations: integrationsPanel
            preferences: preferencesPanel
        }
        CalendarFeature { id: calendarPanel }

        Component.onCompleted: {
            registerSurface("quick-settings", qsPanel);
            registerSurface("calendar", calendarPanel);
        }
        Connections { target: qsPanel; function onOpenChanged() { anchoredHost.reportState("quick-settings", qsPanel.open); } }
        Connections { target: calendarPanel; function onOpenChanged() { anchoredHost.reportState("calendar", calendarPanel.open); } }
    }

    ModalHost {
        id: modalHost

        PinPickerFeature { id: dockPins }
        LauncherFeature { id: launcherPanel }
        SessionFeature { id: sessionPanel }
        PreferencesFeature { id: preferencesPanel; wallpapers: wallpaperPicker }
        WallpapersFeature { id: wallpaperPicker }
        IntegrationsFeature { id: integrationsPanel }

        Component.onCompleted: {
            registerSurface("dock-pins", dockPins);
            registerSurface("launcher", launcherPanel);
            registerSurface("session", sessionPanel);
            registerSurface("preferences", preferencesPanel);
            registerSurface("wallpapers", wallpaperPicker);
            registerSurface("integrations", integrationsPanel);
        }
        Connections { target: dockPins; function onOpenChanged() { modalHost.reportState("dock-pins", dockPins.open); } }
        Connections { target: launcherPanel; function onOpenChanged() { modalHost.reportState("launcher", launcherPanel.open); } }
        Connections { target: sessionPanel; function onOpenChanged() { modalHost.reportState("session", sessionPanel.open); } }
        Connections { target: preferencesPanel; function onOpenChanged() { modalHost.reportState("preferences", preferencesPanel.open); } }
        Connections { target: wallpaperPicker; function onOpenChanged() { modalHost.reportState("wallpapers", wallpaperPicker.open); } }
        Connections { target: integrationsPanel; function onOpenChanged() { modalHost.reportState("integrations", integrationsPanel.open); } }
    }

    FullscreenHost {
        id: fullscreenHost

        OverviewFeature { id: overviewPanel }
        CheatsheetFeature { id: keybindSheet }

        Component.onCompleted: {
            registerSurface("overview", overviewPanel);
            registerSurface("cheatsheet", keybindSheet);
        }
        Connections { target: overviewPanel; function onOpenChanged() { fullscreenHost.reportState("overview", overviewPanel.open); } }
        Connections { target: keybindSheet; function onOpenChanged() { fullscreenHost.reportState("cheatsheet", keybindSheet.open); } }
    }

    PassiveHost {
        id: passiveHost

        StatusCapsuleFeature {
            id: statusCapsule
            enabled: Settings.modules.enabled?.osd ?? true
        }
        NotificationPopupsFeature {
            id: notifs
            enabled: (Settings.modules.enabled?.notifications ?? true)
                && (Settings.providers.notifications ?? "quickshell") === "quickshell"
            statusCapsule: statusCapsule
        }
        OsdFeature {
            id: osd
            enabled: Settings.modules.enabled?.osd ?? true
        }

        Component.onCompleted: {
            registerSurface("notifications", notifs);
            registerSurface("osd", osd);
            registerSurface("status", statusCapsule);
        }
    }

    Variants {
        model: (Settings.modules.enabled?.bar ?? true) ? Quickshell.screens : []
        delegate: BarFeature {
            required property var modelData
            screen: modelData
            notifications: notifs
            quickSettings: qsPanel
            wallpapers: wallpaperPicker
            calendar: calendarPanel
        }
    }

    Variants {
        model: (Settings.modules.enabled?.dock ?? true) ? Quickshell.screens : []
        delegate: DockFeature {
            required property var modelData
            screen: modelData
            pinPicker: dockPins
        }
    }

    // Authentication remains outside every navigation host.
    LockFeature { notifications: notifs }
    BluetoothWatch {}

    Connections { target: ShellActions; function onDndRequested(enabled) { notifs.dontDisturb = enabled; } }
    Connections { target: notifs; function onDontDisturbChanged() { ShellActions.state = { dnd: notifs.dontDisturb }; } }
}
