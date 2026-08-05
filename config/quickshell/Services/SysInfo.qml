// CPU, memory, and temperature, read straight from the kernel.
//
// There is no D-Bus subscription for these the way there is for battery or
// audio, so this is the one service that genuinely has to poll — but it polls
// procfs through FileView, which reads the file in-process rather than spawning
// `cat`/`top` on a timer the way a Waybar module would. One singleton feeds
// every consumer, so a second monitor added later is another binding, not
// another reader.
//
// /proc files do not emit inotify, so FileView.reload() is driven by the Timer
// below; blockLoading makes text() return the freshly reloaded content on the
// same tick. The whole service idles when nothing is watching it — see `active`.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Bumped by consumers while they are on screen; polling runs only when at
    // least one is. A CPU meter nobody is looking at does not need to wake the
    // shell every few seconds.
    property int watchers: 0
    readonly property bool active: watchers > 0

    readonly property int interval: 3000

    // 0..1 for the meters; raw numbers for the tooltips.
    property real cpu: 0
    property real memory: 0
    property int memUsedMb: 0
    property int memTotalMb: 0

    // Rolling CPU samples for the bar's sparkline (rev 02, frame 2a/2b). Capped
    // at historyLength and reassigned rather than pushed-in-place: a `var`
    // array only notifies bindings on assignment, and the sparkline's Canvas
    // has to repaint on every tick.
    readonly property int historyLength: 20
    property var cpuHistory: []

    // NaN until a usable thermal zone is found — hasTemperature gates the glyph
    // so a machine without one shows CPU and RAM alone rather than "0°".
    property real temperature: NaN
    readonly property bool hasTemperature: !isNaN(temperature)

    // Previous /proc/stat totals, so the meter reads utilisation over the
    // interval rather than since boot (which barely moves and would sit near
    // idle forever).
    property var _prevCpu: null

    // Resolved once at startup: the temp file of the first zone whose type looks
    // like a CPU sensor. Empty when none matches, which keeps temperature NaN.
    property string _thermalPath: ""

    function watch(): void { root.watchers++; }
    function unwatch(): void { if (root.watchers > 0) root.watchers--; }

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true }
    FileView {
        id: thermalFile
        path: root._thermalPath
        blockLoading: true
    }

    function _readCpu(): void {
        statFile.reload();
        const line = statFile.text().split("\n").find(l => l.startsWith("cpu "));
        if (!line) return;
        // "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
        const parts = line.split(/\s+/).slice(1).map(Number).filter(n => !isNaN(n));
        if (parts.length < 5) return;
        const idle = parts[3] + (parts[4] ?? 0); // idle + iowait
        const total = parts.reduce((a, b) => a + b, 0);
        if (root._prevCpu) {
            const dTotal = total - root._prevCpu.total;
            const dIdle = idle - root._prevCpu.idle;
            root.cpu = dTotal > 0 ? Math.max(0, Math.min(1, 1 - dIdle / dTotal)) : 0;
            root.cpuHistory = root.cpuHistory.concat([root.cpu]).slice(-root.historyLength);
        }
        root._prevCpu = { total: total, idle: idle };
    }

    function _readMem(): void {
        memFile.reload();
        const text = memFile.text();
        const grab = key => {
            const m = text.match(new RegExp("^" + key + ":\\s+(\\d+)", "m"));
            return m ? Number(m[1]) : NaN; // kB
        };
        const total = grab("MemTotal");
        // MemAvailable is the kernel's own estimate of reclaimable memory and is
        // what "used" should be measured against — MemFree alone counts cache as
        // used and reads permanently near full.
        const avail = grab("MemAvailable");
        if (isNaN(total) || isNaN(avail) || total <= 0) return;
        const used = Math.max(0, total - avail);
        root.memory = Math.max(0, Math.min(1, used / total));
        root.memUsedMb = Math.round(used / 1024);
        root.memTotalMb = Math.round(total / 1024);
    }

    function _readTemp(): void {
        if (root._thermalPath === "") return;
        thermalFile.reload();
        const raw = Number(thermalFile.text().trim());
        // Thermal zones report millidegrees. A blank or bogus read leaves the
        // last good value rather than flashing NaN through the display.
        if (!isNaN(raw) && raw > 0) root.temperature = raw / 1000;
    }

    function poll(): void {
        root._readCpu();
        root._readMem();
        root._readTemp();
    }

    Timer {
        interval: root.interval
        running: root.active
        repeat: true
        // First tick fires immediately so a freshly shown meter is not blank for
        // one interval; the CPU value needs two reads to have a delta, so it
        // lands one tick later, which is why the meter starts at 0 not blank.
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    // One spawn, at startup, to pick a CPU-ish thermal zone. Everything after is
    // FileView reads. If nothing matches, _thermalPath stays empty and the temp
    // simply never appears.
    Process {
        id: thermalProbe
        running: true
        command: ["sh", "-c",
            "for z in /sys/class/thermal/thermal_zone*; do " +
            "t=$(cat \"$z/type\" 2>/dev/null); " +
            "case \"$t\" in x86_pkg_temp|coretemp|*cpu*|*Cpu*|*CPU*|acpitz) " +
            "printf '%s' \"$z/temp\"; exit 0;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: root._thermalPath = this.text.trim()
        }
    }
}
