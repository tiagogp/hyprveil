// Bluetooth section for the Quick Settings panel (AstalBluetooth).
// Adapter power toggle + device list with connect/disconnect and battery %.
import { bind, execAsync } from "astal"
import { Gtk } from "astal/gtk3"
import Bluetooth from "gi://AstalBluetooth"

const bluetooth = Bluetooth.get_default()

function toggleDevice(device: Bluetooth.Device) {
    if (device.connected) device.disconnect_device(null)
    else device.connect_device(null)
}

function DeviceRow(device: Bluetooth.Device) {
    return (
        <button
            className={`bt-device${device.connected ? " connected" : ""}`}
            onClicked={() => toggleDevice(device)}>
            <box>
                <icon className="bt-device-icon" icon={bind(device, "icon").as((i) => i || "bluetooth-symbolic")} />
                <label className="bt-device-name" label={bind(device, "name").as((n) => n || device.address)} xalign={0} hexpand />
                {bind(device, "batteryPercentage").as((b) =>
                    b > 0 ? <label className="bt-device-battery" label={`${Math.round(b * 100)}%`} /> : <box />,
                )}
                {bind(device, "connecting").as((c) =>
                    c ? <label className="bt-device-state" label={"\u{f0772}"} /> : <box />,
                )}
                {bind(device, "connected").as((c) =>
                    c ? <label className="bt-device-state" label={"\u{f0337}"} /> : <box />,
                )}
            </box>
        </button>
    )
}

export default function BluetoothSection() {
    return (
        <box className="qs-section bluetooth" vertical>
            <box className="qs-section-header">
                <label className="qs-section-icon" label={"\u{f00af}"} />
                <label className="qs-section-title" label="Bluetooth" xalign={0} hexpand />
                <switch
                    className="qs-switch"
                    active={bind(bluetooth, "isPowered")}
                    onActivate={({ active }) => {
                        if (bluetooth.adapter) bluetooth.adapter.powered = active
                    }}
                />
            </box>

            {bind(bluetooth, "isPowered").as((powered) => {
                if (!powered) return <label className="qs-empty" label="Bluetooth is off" />
                return (
                    <scrollable className="bt-list" heightRequest={220} vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER}>
                        <box vertical>
                            {bind(bluetooth, "devices").as((devices) =>
                                devices.filter((d) => d.name).map(DeviceRow),
                            )}
                        </box>
                    </scrollable>
                )
            })}

            <button
                className="qs-advanced"
                onClicked={() => execAsync(["blueman-manager"]).catch(() => {})}>
                <label label="Open Blueman…" xalign={0} />
            </button>
        </box>
    )
}
