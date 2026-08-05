// The calendar dropdown.
//
// The bar has always carried a clock and nothing behind it — clicking the time
// did nothing, which is the one place a calendar is expected. This is the panel
// that answers that click. It reads today from the shared Time singleton (see
// Time.qml) so the highlighted day rolls over at midnight without a poll of its
// own, and keeps its OWN view month/year so paging back to April does not touch
// what the rest of the shell thinks the date is.
//
// A top-right dropdown rather than a centred modal: it is a glance, not a task,
// and it sits under the clock it was opened from — the same family as the
// quick-settings panel, and anchored the same way.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

Scope {
    id: root

    property bool open: false

    // The month on screen, held apart from Time.today so paging does not move
    // the shell's clock. Reset to the current month every time the panel opens —
    // a calendar that reopens on March because that is where it was left is a
    // calendar answering a question nobody asked.
    property int viewYear: Time.today.getFullYear()
    property int viewMonth: Time.today.getMonth() // 0-11

    onOpenChanged: if (open) resetToToday()

    function resetToToday(): void {
        root.viewYear = Time.today.getFullYear();
        root.viewMonth = Time.today.getMonth();
    }

    function step(delta: int): void {
        let m = root.viewMonth + delta;
        let y = root.viewYear;
        // Normalise across year boundaries in both directions.
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        root.viewMonth = m;
        root.viewYear = y;
    }

    // The cells of the month grid, padded to whole Sunday-first weeks. 0 is a
    // blank leading/trailing cell; 1..N are the days. Built once per view month
    // rather than per cell so the 42 delegates below read an array instead of
    // each recomputing the month's shape.
    readonly property int _daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()
    readonly property int _leading: new Date(viewYear, viewMonth, 1).getDay() // 0=Sun
    readonly property var cells: {
        const out = [];
        for (let i = 0; i < root._leading; i++) out.push(0);
        for (let d = 1; d <= root._daysInMonth; d++) out.push(d);
        while (out.length % 7 !== 0) out.push(0);
        return out;
    }

    // The view month contains today, so a day number is today only when the
    // month and year also match — otherwise the same date one month back would
    // light up too.
    readonly property bool _viewIsThisMonth:
        viewYear === Time.today.getFullYear() && viewMonth === Time.today.getMonth()
    readonly property int _todayDate: Time.today.getDate()

    readonly property string monthLabel:
        Qt.formatDate(new Date(viewYear, viewMonth, 1), "MMMM yyyy")

    // The UI is English throughout the shell (Quick Settings, Notifications,
    // Wallpaper), so the headers are too rather than following the locale into a
    // language the rest of the bar does not speak.
    readonly property var weekdayLabels: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    PanelWindow {
        id: win
        visible: root.open
        anchors { top: true; right: true }
        margins { top: Tokens.spacing2h; right: Tokens.spacing2h }

        implicitWidth: 300
        implicitHeight: column.implicitHeight + Tokens.spacing3 * 2
        color: "transparent"
        WlrLayershell.namespace: "hyprveil-calendar"
        WlrLayershell.layer: WlrLayer.Top
        // OnDemand for the same reason as the quick-settings panel: it needs
        // Escape, but must not pull the keyboard off the focused window merely
        // by being open.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        Surface {
            anchors.fill: parent
            // Rev 02 draws the calendar dropdown with the same shadow as
            // every other floating widget (frame 2e) rather than sitting flat.
            elevation: 2
            radius: Tokens.radiusLg

            focus: true
            Keys.onEscapePressed: root.open = false

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Tokens.spacing3
                spacing: Tokens.spacing2

                // Header: month label plus the two pagers. The label is itself
                // the "jump to today" control — the discoverable place to undo a
                // page is the thing that says which month you paged to.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing2

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: root.monthLabel
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textLg
                        font.weight: Tokens.weightBold
                        color: Tokens.text

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.resetToToday()
                        }
                    }

                    CalendarPager {
                        glyph: "\u{f0141}" // chevron-left
                        onClicked: root.step(-1)
                    }
                    CalendarPager {
                        glyph: "\u{f0142}" // chevron-right
                        onClicked: root.step(1)
                    }
                }

                // Weekday header row. Same seven-column metrics as the grid so
                // the labels sit over their columns rather than being centred on
                // their own row and drifting off the days below.
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 0
                    rowSpacing: 0

                    Repeater {
                        model: root.weekdayLabels
                        Text {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: Tokens.spacing6
                            renderType: Text.NativeRendering
                            text: modelData
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.text2xs
                            font.weight: Tokens.weightSemibold
                            color: Tokens.dim
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 0
                    rowSpacing: Tokens.spacing1

                    Repeater {
                        model: root.cells

                        Item {
                            required property var modelData
                            readonly property bool isDay: modelData > 0
                            readonly property bool isToday:
                                isDay && root._viewIsThisMonth
                                && modelData === root._todayDate

                            Layout.fillWidth: true
                            Layout.preferredHeight: Tokens.spacing6

                            // Today gets the same soft accent disc the panel uses
                            // for a selected chip. Sized to the row so the pill is
                            // a circle rather than a stretched oval.
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height)
                                height: width
                                radius: width / 2
                                visible: parent.isToday
                                color: Accent.accentSoft
                                border.width: 1
                                border.color: Accent.accent
                            }

                            Text {
                                anchors.centerIn: parent
                                renderType: Text.NativeRendering
                                visible: parent.isDay
                                text: parent.isDay ? String(parent.modelData) : ""
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textSm
                                font.weight: parent.isToday
                                    ? Tokens.weightSemibold : Tokens.weightMedium
                                color: parent.isToday ? Accent.accent : Tokens.text
                            }
                        }
                    }
                }
            }
        }
    }

    // Symmetry with the other panels: SUPER-key routing goes through a helper
    // script that hits this IPC target, so a future keybind needs no code here.
    IpcHandler {
        target: "calendar"

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }
        function open(): string { root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
