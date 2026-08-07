// Runtime composition. The root entry point stays tiny; all surface ownership
// and feature wiring lives here.
import Quickshell
import ".."
import "../Bar"
import "../Dock"
import "../Notif"
import "../Panel"
import "../Lock"
import "../Services"
import "../Osd"
import "../Overview"
import "../Launcher"
import "../Session"

ShellRoot {
    id: app

    AnchoredHost { id: anchoredHost }
    ModalHost { id: modalHost }
    FullscreenHost { id: fullscreenHost }
    PassiveHost { id: passiveHost }

    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
            notifications: notifs
            quickSettings: qsPanel
            wallpapers: wallpaperPicker
            calendar: calendarPanel
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Dock {
            required property var modelData
            screen: modelData
            pinPicker: dockPins
        }
    }

    PinPicker { id: dockPins }
    Popups { id: notifs; statusCapsule: statusCapsule }
    QuickSettings {
        id: qsPanel
        notifications: notifs
        wallpapers: wallpaperPicker
        cheatsheet: keybindSheet
        integrations: integrationsPanel
        preferences: preferencesPanel
    }
    Integrations { id: integrationsPanel }
    Preferences { id: preferencesPanel; wallpapers: wallpaperPicker }
    Wallpapers { id: wallpaperPicker }
    Cheatsheet { id: keybindSheet }
    Calendar { id: calendarPanel }
    Overview { id: overviewPanel }
    Launcher { id: launcherPanel }
    Session { id: sessionPanel }

    // Security/passive surfaces deliberately stay outside interactive hosts.
    Lock { notifications: notifs }
    BluetoothWatch {}
    Osd {}
    StatusCapsule { id: statusCapsule }

    Component.onCompleted: {
        SurfaceCoordinator.registerSurface("quick-settings", qsPanel, "anchored");
        SurfaceCoordinator.registerSurface("calendar", calendarPanel, "anchored");
        SurfaceCoordinator.registerSurface("launcher", launcherPanel, "modal");
        SurfaceCoordinator.registerSurface("session", sessionPanel, "modal");
        SurfaceCoordinator.registerSurface("preferences", preferencesPanel, "modal");
        SurfaceCoordinator.registerSurface("wallpapers", wallpaperPicker, "modal");
        SurfaceCoordinator.registerSurface("integrations", integrationsPanel, "modal");
        SurfaceCoordinator.registerSurface("overview", overviewPanel, "fullscreen");
        SurfaceCoordinator.registerSurface("cheatsheet", keybindSheet, "fullscreen");
    }

    Connections { target: qsPanel; function onOpenChanged() { SurfaceCoordinator.reportState("quick-settings", qsPanel.open); } }
    Connections { target: calendarPanel; function onOpenChanged() { SurfaceCoordinator.reportState("calendar", calendarPanel.open); } }
    Connections { target: launcherPanel; function onOpenChanged() { SurfaceCoordinator.reportState("launcher", launcherPanel.open); } }
    Connections { target: sessionPanel; function onOpenChanged() { SurfaceCoordinator.reportState("session", sessionPanel.open); } }
    Connections { target: preferencesPanel; function onOpenChanged() { SurfaceCoordinator.reportState("preferences", preferencesPanel.open); } }
    Connections { target: wallpaperPicker; function onOpenChanged() { SurfaceCoordinator.reportState("wallpapers", wallpaperPicker.open); } }
    Connections { target: integrationsPanel; function onOpenChanged() { SurfaceCoordinator.reportState("integrations", integrationsPanel.open); } }
    Connections { target: overviewPanel; function onOpenChanged() { SurfaceCoordinator.reportState("overview", overviewPanel.open); } }
    Connections { target: keybindSheet; function onOpenChanged() { SurfaceCoordinator.reportState("cheatsheet", keybindSheet.open); } }
    Connections { target: ShellActions; function onDndRequested(enabled) { notifs.dontDisturb = enabled; } }
    Connections { target: notifs; function onDontDisturbChanged() { ShellActions.state = { dnd: notifs.dontDisturb }; } }
}
