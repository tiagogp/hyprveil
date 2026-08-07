// The native launcher — apps, open windows, and five system actions in one
// index, keyboard-first.
//
// Rofi drew a themed window but shared no state, animation, or keyboard
// convention with the rest of the shell — see the roadmap's "launcher nativo"
// gap. This MVP intentionally does not grow into a plugin host: arquivos,
// cálculo, and providers stay off by default (Providers.qml, launched from
// Quick Settings > Preferences, is where those live when enabled). Rofi
// remains bound as a fallback (`$mod SHIFT, Space`) in keybindings.conf.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import ".."
import "../Services"

Scope {
    id: root

    property bool open: false
    property string query: ""
    property int selected: 0

    // Files/calculator/emoji — off by default except calculator; see
    // Providers.qml and Panel/Preferences.qml's "Launcher providers" section.
    Providers { id: providers }
    onQueryChanged: providers.search(root.query)

    readonly property var systemActions: [
        { kind: "action", id: "lock", label: "Lock", glyph: "\u{f033e}",
          run: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"]) },
        { kind: "action", id: "suspend", label: "Suspend", glyph: "\u{f04b2}",
          run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { kind: "action", id: "reboot", label: "Restart", glyph: "\u{f0453}",
          run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { kind: "action", id: "shutdown", label: "Shut down", glyph: "\u{f0425}",
          run: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
        { kind: "action", id: "logout", label: "Log out", glyph: "\u{f0343}",
          run: () => Hyprland.dispatch("exit") }
    ]

    // Apps: every entry Quickshell knows about, minus anything that declares
    // itself hidden from menus. Sorted once here rather than per keystroke —
    // the filter below only narrows the list, it never reorders it.
    readonly property var appEntries: {
        const out = [];
        for (const e of (DesktopEntries.applications?.values ?? [])) {
            if (e.noDisplay) continue;
            out.push({ kind: "app", id: e.id, label: e.name,
                icon: Icons.resolve(e.icon, e.id, e.id, true), entry: e });
        }
        out.sort((a, b) => a.label.localeCompare(b.label));
        return out;
    }

    // Windows: one row per open toplevel, so a launcher search doubles as an
    // alt-tab. Distinct from the dock's per-CLASS grouping — every window is
    // addressable here, not just the first of its class.
    readonly property var windowEntries: {
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const cls = t.lastIpcObject?.class ?? "";
            const title = t.title !== "" ? t.title : cls;
            if (title === "") continue;
            out.push({ kind: "window", id: t.address, label: title,
                sub: cls, icon: Compositor.iconSourceForWindow(t), toplevel: t });
        }
        return out;
    }

    function _matches(label, sub, q) {
        if (q === "") return true;
        return label.toLowerCase().includes(q) || (sub ?? "").toLowerCase().includes(q);
    }

    readonly property var results: {
        const q = root.query.trim().toLowerCase();
        const apps = root.appEntries.filter(e => root._matches(e.label, "", q));
        const wins = root.windowEntries.filter(e => root._matches(e.label, e.sub, q));
        const actions = root.systemActions.filter(e => root._matches(e.label, "", q));
        // A calculator hit answers the exact query, so it leads. Windows
        // before apps: a launcher search is most often "switch to the thing
        // I already have open", and system actions are rare enough to sit
        // last without costing a keystroke in the common case. Provider
        // files/emoji sit just before actions — opt-in and specific, but not
        // as immediately actionable as a window switch or an app launch.
        const calc = root.query.trim() !== "" ? providers.calculatorResult(root.query) : null;
        const emoji = root.query.trim() !== "" ? providers.emojiResults(root.query) : [];
        const files = providers.fileResults;
        const leading = calc ? [calc] : [];
        return leading.concat(wins).concat(apps).concat(files).concat(emoji).concat(actions);
    }

    function activate(index) {
        const item = root.results[index];
        if (!item) return;
        if (item.kind === "app") item.entry.execute();
        else if (item.kind === "window") Compositor.dispatchTo("focuswindow", item.toplevel);
        else if (item.kind === "action") item.run();
        root.open = false;
    }

    onOpenChanged: {
        if (open) {
            root.query = "";
            root.selected = 0;
            Hyprland.refreshToplevels();
        }
    }

    onResultsChanged: if (root.selected >= root.results.length)
        root.selected = Math.max(0, root.results.length - 1);

    PanelWindow {
        id: win
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "hyprveil-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            MouseArea { anchors.fill: parent; onClicked: root.open = false }
        }

        Surface {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.16
            elevation: 3
            radius: Tokens.radiusLg

            transform: Translate {
                y: root.open ? 0 : -Tokens.spacing6
                Behavior on y {
                    NumberAnimation {
                        duration: Motion.duration(Tokens.durModal)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.easeModal
                    }
                }
            }

            implicitWidth: Math.min(560, parent.width - Tokens.spacing8 * 2)
            implicitHeight: column.implicitHeight + Tokens.spacing4 * 2

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Tokens.spacing4
                spacing: Tokens.spacing3

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.spacing8
                    radius: Tokens.radiusSm
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: search.activeFocus ? 1 : 0
                    border.color: Accent.accent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.spacing3
                        anchors.rightMargin: Tokens.spacing3
                        spacing: Tokens.spacing2

                        Glyph { text: "\u{f0349}"; size: Tokens.iconSm; color: Tokens.dim }

                        TextInput {
                            id: search
                            renderType: Text.NativeRendering
                            Layout.fillWidth: true
                            focus: true
                            Accessible.role: Accessible.EditableText
                            Accessible.name: "Search apps, windows, and actions"
                            color: Tokens.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textSm
                            selectionColor: Accent.accentSoft
                            selectedTextColor: Tokens.text
                            clip: true
                            onTextChanged: { root.query = text; root.selected = 0; }

                            Keys.onEscapePressed: root.open = false
                            Keys.onReturnPressed: root.activate(root.selected)
                            Keys.onDownPressed: root.selected =
                                Math.min(root.results.length - 1, root.selected + 1)
                            Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)

                            Connections {
                                target: root
                                function onOpenChanged() { if (root.open) search.text = ""; }
                            }

                            Text {
                                renderType: Text.NativeRendering
                                anchors.fill: parent
                                visible: search.text === ""
                                text: "Search apps, windows, actions…"
                                font: search.font
                                color: Tokens.dim
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    visible: root.results.length === 0
                    text: "No matches"
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textXs
                    color: Tokens.dim
                }

                ColumnLayout {
                    id: list
                    Layout.fillWidth: true
                    spacing: Tokens.spacingHair
                    visible: root.results.length > 0

                    Repeater {
                        // Capped so the launcher never grows to hundreds of
                        // rows on an unfiltered query; scrolling is left for a
                        // later pass — narrowing by typing is the primary path.
                        model: root.results.slice(0, 9)

                        Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: Tokens.spacing8
                            radius: Tokens.radiusSm
                            color: root.selected === index
                                ? Accent.accentSoft : "transparent"

                            Accessible.role: Accessible.ListItem
                            Accessible.name: modelData.label

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.spacing2
                                anchors.rightMargin: Tokens.spacing2
                                spacing: Tokens.spacing2h

                                IconImage {
                                    visible: modelData.kind !== "action" && modelData.icon
                                    source: modelData.icon ?? ""
                                    implicitSize: Tokens.iconMd
                                }
                                Glyph {
                                    visible: modelData.kind === "action"
                                    text: modelData.glyph ?? ""
                                    size: Tokens.iconMd
                                    color: Tokens.muted
                                }

                                Text {
                                    renderType: Text.NativeRendering
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.textSm
                                    font.weight: root.selected === index
                                        ? Tokens.weightSemibold : Tokens.weightMedium
                                    color: Tokens.text
                                    elide: Text.ElideRight
                                }

                                Text {
                                    renderType: Text.NativeRendering
                                    visible: modelData.kind === "window"
                                    text: modelData.sub ?? ""
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.text2xs
                                    color: Tokens.dim
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selected = index
                                onClicked: root.activate(index)
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }
        function open(): string { root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
