// The toggled glass "Quick Settings" panel: Wi-Fi + Bluetooth + Notifications.
// Anchored top-right under the Waybar top bar; toggled via `ags request
// toggle-quicksettings` (Waybar icons + SUPER+N keybind).
import { App, Astal, Gtk } from "astal/gtk3"
import WifiSection from "./Wifi"
import BluetoothSection from "./Bluetooth"
import NotificationSection from "./Notifications"
import { openWallpapers } from "./Wallpapers"

export default function QuickSettings() {
    const { TOP, RIGHT } = Astal.WindowAnchor

    return (
        <window
            name="quicksettings"
            namespace="hyprveil-quicksettings"
            className="QuickSettings"
            anchor={TOP | RIGHT}
            layer={Astal.Layer.TOP}
            exclusivity={Astal.Exclusivity.NORMAL}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={false}
            application={App}
            onKeyPressEvent={(self, event) => {
                // Escape closes the panel.
                if (event.get_keyval()[1] === Gdk_KEY_Escape) self.hide()
            }}>
            <box className="qs-panel" vertical>
                <box className="qs-titlebar">
                    <label className="qs-title" label="Quick Settings" xalign={0} hexpand />
                    <button className="qs-close" onClicked={() => App.get_window("quicksettings")?.hide()}>
                        <label label={"\u{f0156}"} />
                    </button>
                </box>
                <WifiSection />
                <BluetoothSection />
                <NotificationSection />
                <button
                    className="qs-wallpapers"
                    onClicked={() => {
                        App.get_window("quicksettings")?.hide()
                        openWallpapers()
                    }}>
                    <box>
                        <label className="qs-section-icon" label="󰸉" />
                        <label label="Wallpapers…" xalign={0} hexpand />
                        <label className="qs-wallpapers-chevron" label={"\u{f0142}"} />
                    </box>
                </button>
            </box>
        </window>
    )
}

// Gdk keyval for Escape (avoids importing the full Gdk keysyms surface).
const Gdk_KEY_Escape = 0xff1b
