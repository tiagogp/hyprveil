// Hyprveil shell — bar, dock, and notifications in one process.
//
// This replaces Waybar plus AGS. Both were fighting their toolkit rather than
// the design: Waybar cannot render a dynamic list, so the dock was ten
// hand-duplicated modules whose count WAS the pin limit, and a Waybar module has
// one click target, so the media player was four modules polling playerctl four
// times over. AGS needed a dart-sass recompile at runtime to change one color.
//
// The shell is also the notification daemon (see Notif/Popups.qml), which is why
// notification-daemon.sh treats it as a backend and why it must not be restarted
// casually — a restart discards the session's notification history.
import Quickshell
import "Bar"
import "Dock"
import "Notif"
import "Panel"
import "Lock"
import "Services"
import "Osd"
import "Overview"
import "Launcher"
import "Session"

ShellRoot {
    // One bar and one dock per monitor. Variants re-instantiates its delegate
    // for each entry, so hotplugging a display is handled by the model changing
    // rather than by any code of ours.
    // The bar carries the only on-screen route to the two panels below. Both are
    // single session-wide scopes rather than one per bar, so every monitor's bar
    // toggles the same panel and their button states cannot disagree.
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

    // Every dock shares one pin picker, for the same reason the panels are
    // single scopes: two monitors staging different pin lists is not a state
    // worth having, and whichever one applied last would win silently.
    Variants {
        model: Quickshell.screens
        delegate: Dock {
            required property var modelData
            screen: modelData
            pinPicker: dockPins
        }
    }

    PinPicker { id: dockPins }

    // Popups are deliberately NOT per-monitor. The design stacks them top-right
    // on the focused output; drawing the same toast on every screen is noise,
    // and AGS had the multi-monitor path written but never instantiated it.
    Popups { id: notifs; statusCapsule: statusCapsule }

    // The panel reads the popup scope's server rather than owning one, so the
    // history it lists and the toasts that appeared are the same objects.
    //
    // The picker's id is NOT `wallpapers`: QuickSettings has a property of that
    // name, and a property shadows an id of the same name in its own binding
    // scope, so `wallpapers: wallpapers` bound the property to itself and the
    // panel's "Wallpapers…" row opened nothing.
    QuickSettings {
        id: qsPanel
        notifications: notifs
        wallpapers: wallpaperPicker
        cheatsheet: keybindSheet
        integrations: integrationsPanel
        preferences: preferencesPanel
    }

    // "Sistema > Integrações" — the capability doctor, reachable from Quick
    // Settings or `qs ipc call integrations toggle`. One scope, like the
    // other modals.
    Integrations { id: integrationsPanel }

    // Preferences — bar/dock/accent/Calm Mode/launcher providers/monitors/
    // scenes, all through settings-store.sh. Reachable from Quick Settings or
    // `qs ipc call preferences toggle`.
    Preferences { id: preferencesPanel }

    // The wallpaper picker. wallpaper.sh owns the state and the Hyprpaper IPC;
    // this only renders `list` and calls `apply`.
    Wallpapers { id: wallpaperPicker }

    // The keybind cheatsheet, rendered from keybindings.conf itself. Reached
    // from the panel or by SUPER+slash, which goes through the same IPC.
    Cheatsheet { id: keybindSheet }

    // The calendar dropdown, opened by clicking the bar clock. A single scope
    // like the panels above so every monitor's clock toggles the same one.
    Calendar { id: calendarPanel }

    // The window overview (exposé), opened by SUPER+Tab through its IPC target.
    // A single full-screen modal — like the cheatsheet — that reads Hyprland's
    // toplevels directly, so it needs nothing wired in from here.
    Overview { id: overviewPanel }

    // The native launcher — apps, windows, system actions. Opened by SUPER
    // alone, SUPER+Space, or its IPC target; see keybindings.conf. A single
    // scope like the other modals, for the same reason: one keyboard grab,
    // one state, regardless of which monitor was focused when it opened.
    Launcher { id: launcher }

    // The native session/power modal — confirmed lock/suspend/logout/
    // restart/shutdown. Opened by SUPER+Escape, Ctrl+Alt+Delete, or its IPC
    // target; see keybindings.conf. wlogout stays bound as the fallback.
    Session { id: sessionPanel }

    // Holds the session lock. See Lock/Lock.qml and hypr/scripts/lock.sh — a
    // failure here is a lockout, so the script never trusts this unconditionally.
    //
    // Reads the same notification scope the bar and panel do, so the lock can
    // report how many arrived while away. It shows the count only — never the
    // contents.
    Lock { notifications: notifs }

    // Bluetooth connect/disconnect and low-battery notifications. Sends through
    // notify-send so they land in the same history and honour the same DND as
    // everything else.
    BluetoothWatch {}

    // Volume, microphone, and brightness feedback for hardware keys. The helper
    // script owns the system command and this scope only renders the latest
    // value, so repeated keypresses update one overlay instead of stacking.
    Osd {}

    // The transient status capsule — DND and Calm Mode toggles, the two
    // state changes that previously had no on-screen acknowledgment at all.
    // Top-center so it never collides with Osd's bottom-center overlay.
    StatusCapsule { id: statusCapsule }
}
