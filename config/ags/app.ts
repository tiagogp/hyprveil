// Hyprveil quick-settings + notifications shell (AGS v2 / Astal).
//
// Two layer-shell surfaces:
//   1. transient notification popups (top-right)      -> widget/NotificationPopups
//   2. a toggled glass "Quick Settings" panel with
//      Wi-Fi / Bluetooth / Notifications sections     -> widget/QuickSettings
//
// This process is also the notification daemon (AstalNotifd), replacing SwayNC
// when the `ags` backend is selected. The request handler is the bridge the
// Waybar `custom/notifications` module and Hyprland keybinds talk to
// (see config/waybar/scripts/notification.sh and config/hypr/scripts/
// notification-daemon.sh).
import { App } from "astal/gtk3"
import Notifd from "gi://AstalNotifd"
import style from "./style.scss"
import QuickSettings from "./widget/QuickSettings"
import NotificationPopups from "./widget/NotificationPopups"
import Wallpapers, { openWallpapers, closeWallpapers, toggleWallpapers } from "./widget/Wallpapers"

const QUICK_SETTINGS = "quicksettings"

// Waybar consumes this shape via `custom/notifications` (format-icons keys:
// notification / none / dnd-notification / dnd-none). Keep it in sync with the
// swaync-client -swb contract that notification.sh already understands.
function notifStatus(): string {
    const notifd = Notifd.get_default()
    const count = notifd.notifications.length
    const dnd = notifd.dontDisturb
    const state = dnd
        ? count > 0 ? "dnd-notification" : "dnd-none"
        : count > 0 ? "notification" : "none"
    return JSON.stringify({
        alt: state,
        class: state,
        text: count > 0 ? String(count) : "",
        tooltip: dnd ? "Do not disturb" : `${count} notification${count === 1 ? "" : "s"}`,
    })
}

App.start({
    instanceName: "hyprveil",
    css: style,
    main() {
        NotificationPopups()
        QuickSettings()
        Wallpapers()
    },
    // `ags request <cmd>` (aka `astal -i hyprveil <cmd>`) dispatches here.
    requestHandler(request: string, res: (response: string) => void) {
        const notifd = Notifd.get_default()
        const [cmd] = request.trim().split(/\s+/)
        switch (cmd) {
            case "toggle-quicksettings":
                App.toggle_window(QUICK_SETTINGS)
                return res("ok")
            case "open-quicksettings":
                App.get_window(QUICK_SETTINGS)?.set_visible(true)
                return res("ok")
            case "close-quicksettings":
                App.get_window(QUICK_SETTINGS)?.set_visible(false)
                return res("ok")
            // `wallpaper.sh pick` (SUPER+SHIFT+W) and the Quick Settings button
            // route here; the helper falls back to Rofi when this shell is down.
            case "toggle-wallpapers":
                toggleWallpapers()
                return res("ok")
            case "open-wallpapers":
                openWallpapers()
                return res("ok")
            case "close-wallpapers":
                closeWallpapers()
                return res("ok")
            case "notif-status":
                return res(notifStatus())
            case "notif-dnd":
                notifd.dontDisturb = !notifd.dontDisturb
                return res(notifStatus())
            case "notif-clear":
                notifd.notifications.forEach((n) => n.dismiss())
                return res("ok")
            case "notif-toggle":
                App.toggle_window(QUICK_SETTINGS)
                return res("ok")
            // accent.sh compiles style.scss with dart-sass and pushes the result
            // here rather than restarting the shell: this process is also the
            // notification daemon, and a restart would discard the session's
            // notification history. The path is absolute and may contain spaces.
            case "reload-css": {
                const path = request.trim().split(/\s+/).slice(1).join(" ")
                if (!path) return res("reload-css requires a path")
                // reset=true drops the previous sheet in the same call; without
                // it the old accent rules stay loaded and win on specificity.
                // Astal treats an existing filesystem path as a file to read.
                App.apply_css(path, true)
                return res("ok")
            }
            default:
                return res(`unknown request: ${request}`)
        }
    },
})
