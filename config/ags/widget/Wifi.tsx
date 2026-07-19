// Wi-Fi section for the Quick Settings panel (AstalNetwork).
// Astal exposes live state (enabled, access points, active AP, strength).
// Connecting to a secured network needs the NM secret agent, so first-time
// joins shell out to `nmcli`; already-known networks connect via profile.
import { Variable, bind, execAsync } from "astal"
import { Gtk } from "astal/gtk3"
import Network from "gi://AstalNetwork"

const network = Network.get_default()

function signalIcon(strength: number): string {
    if (strength >= 80) return "󰤨"
    if (strength >= 60) return "󰤥"
    if (strength >= 40) return "󰤢"
    if (strength >= 20) return "󰤟"
    return "󰤯"
}

function connect(ssid: string) {
    // `nmcli` reuses a saved connection or prompts for a secret via the running
    // NM secret agent; keep it non-blocking and report failures to the log.
    execAsync(["nmcli", "device", "wifi", "connect", ssid]).catch((err) =>
        console.error(`wifi connect ${ssid}: ${err}`),
    )
}

function AccessPointRow(ap: Network.AccessPoint, activeSsid: string | null) {
    const active = ap.ssid != null && ap.ssid === activeSsid
    return (
        <button
            className={`wifi-ap${active ? " active" : ""}`}
            onClicked={() => ap.ssid && connect(ap.ssid)}>
            <box>
                <label className="wifi-ap-signal" label={signalIcon(ap.strength)} />
                <label className="wifi-ap-name" label={ap.ssid || "Hidden network"} xalign={0} hexpand />
                {ap.flags !== 0 ? <label className="wifi-ap-lock" label={"\u{f033e}"} /> : <box />}
                {active ? <label className="wifi-ap-active" label={"\u{f012c}"} /> : <box />}
            </box>
        </button>
    )
}

export default function WifiSection() {
    const scanning = Variable(false)

    function scan() {
        const wifi = network.wifi
        if (!wifi) return
        scanning.set(true)
        wifi.scan()
        setTimeout(() => scanning.set(false), 3000)
    }

    return (
        <box className="qs-section wifi" vertical>
            <box className="qs-section-header">
                <label className="qs-section-icon" label={"\u{f05a9}"} />
                <label className="qs-section-title" label="Wi-Fi" xalign={0} hexpand />
                <button
                    className="qs-scan"
                    tooltipText="Rescan"
                    onClicked={scan}>
                    <label label={bind(scanning).as((s) => (s ? "\u{f0772}" : "\u{f0450}"))} />
                </button>
                <switch
                    className="qs-switch"
                    active={bind(network, "wifi").as((w) => w?.enabled ?? false)}
                    onActivate={({ active }) => {
                        if (network.wifi) network.wifi.enabled = active
                    }}
                />
            </box>

            {bind(network, "wifi").as((wifi) => {
                if (!wifi || !wifi.enabled) {
                    return <label className="qs-empty" label="Wi-Fi is off" />
                }
                return (
                    <scrollable className="wifi-list" heightRequest={220} vscroll={Gtk.PolicyType.AUTOMATIC} hscroll={Gtk.PolicyType.NEVER}>
                        <box vertical>
                            {bind(wifi, "accessPoints").as((aps) => {
                                const active = wifi.activeAccessPoint?.ssid ?? null
                                return [...aps]
                                    .filter((ap) => ap.ssid)
                                    .sort((a, b) => b.strength - a.strength)
                                    .map((ap) => AccessPointRow(ap, active))
                            })}
                        </box>
                    </scrollable>
                )
            })}

            <button
                className="qs-advanced"
                onClicked={() => execAsync(["nm-connection-editor"]).catch(() => {})}>
                <label label="Advanced settings…" xalign={0} />
            </button>
        </box>
    )
}
