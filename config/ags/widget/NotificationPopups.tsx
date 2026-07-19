// Transient notification popups (top-right), one window per monitor.
// Honors AstalNotifd do-not-disturb and auto-dismisses after a timeout.
import { Variable, bind, timeout } from "astal"
import { App, Astal, Gtk, Gdk } from "astal/gtk3"
import Notifd from "gi://AstalNotifd"
import { NotificationCard } from "./Notifications"

const TIMEOUT_MS = 5000
const notifd = Notifd.get_default()

export default function NotificationPopups(gdkmonitor?: Gdk.Monitor) {
    const { TOP, RIGHT } = Astal.WindowAnchor
    // Ids currently shown as popups (newest first).
    const popups = Variable<number[]>([])

    notifd.connect("notified", (_, id: number, replaced: boolean) => {
        if (notifd.dontDisturb) return
        const next = popups.get().filter((i) => i !== id)
        popups.set([id, ...next])
        if (!replaced) {
            timeout(TIMEOUT_MS, () => popups.set(popups.get().filter((i) => i !== id)))
        }
    })
    notifd.connect("resolved", (_, id: number) => {
        popups.set(popups.get().filter((i) => i !== id))
    })

    return (
        <window
            name="notification-popups"
            namespace="hyprveil-notifications"
            className="NotificationPopups"
            gdkmonitor={gdkmonitor}
            anchor={TOP | RIGHT}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            application={App}>
            <box vertical className="popup-list">
                {bind(popups).as((ids) =>
                    ids
                        .map((id) => notifd.get_notification(id))
                        .filter((n) => n != null)
                        .map((n) => (
                            <eventbox
                                onClick={(_, event) => {
                                    // Middle click dismisses; left click closes the popup.
                                    if (event.button === Gdk.BUTTON_MIDDLE) n!.dismiss()
                                    else popups.set(popups.get().filter((i) => i !== n!.id))
                                }}>
                                {NotificationCard(n!)}
                            </eventbox>
                        )),
                )}
            </box>
        </window>
    )
}
