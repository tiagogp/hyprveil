// Preferences — the roadmap's "Preferências gráficas v1": bar, dock, motion,
// accent, wallpaper, and the opcionais the criterion asks for.
//
// Motion and wallpaper are NOT reimplemented here — motion-profile.sh and
// Wallpapers.qml already own that state and already work; this only adds
// the one motion control that was previously unreachable after first run
// (see the toggle below) and a shortcut into the wallpaper picker that
// already exists. Everything else writes through Settings.set()/
// setMonitorOverride(), which always goes back through settings-store.sh —
// the same one-writer discipline Wallpapers.qml and AccentSection.qml
// already use for their own state files. That is also why this stays a
// flat list of sections instead of growing a tree of sub-pages: the roadmap
// explicitly warns against "virar settings infinito", and a flat surface is
// the cheapest way to keep that promise honest.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../Design/Components"
import "../Services"

Scope {
    id: root

    property bool open: false
    property var targetScreen: null
    // The Wallpapers scope, passed down from shell.qml — the same reference
    // QuickSettings.qml already holds, not a second instance.
    property var wallpapers: null

    // "Save current as…" staging for the Scenes section — held here rather
    // than as a global so closing the panel discards an unfinished name
    // instead of it lingering into the next time Preferences opens.
    property string newSceneName: ""
    readonly property var sceneNames: Scenes.state

    onOpenChanged: {
        if (open) {
            Capabilities.refresh();
            Scenes.refresh();
        }
    }

    function runScenes(args) { Scenes.run(args); }

    function reapplyAccent() {
        AccentService.reapplyFromWallpaper(Settings.appearance.accentProvider ?? "hyprveil");
    }

    readonly property bool matugenAvailable:
        (Capabilities.rows.find(r => r.id === "matugen")?.available) ?? false

    PanelWindow {
        id: win
        screen: root.targetScreen ?? Quickshell.screens[0]
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "hyprveil-preferences"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)
            TapHandler { onTapped: root.open = false }
        }

        HvDialog {
            anchors.centerIn: parent
            elevation: 3
            presented: root.open
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

            implicitWidth: Math.min(480, parent.width - Tokens.spacing8 * 2)
            implicitHeight: Math.min(640, parent.height - Tokens.spacing8 * 2)

            focus: true
            Keys.onEscapePressed: root.open = false

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Tokens.spacing4
                spacing: Tokens.spacing3

                HvHeader {
                    Layout.fillWidth: true
                    title: "Preferences"
                    subtitle: "Appearance, behavior, providers, and monitors"
                    canClose: true
                    onClose: root.open = false
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: body.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: body
                        width: parent.width
                        spacing: Tokens.spacing3

                        // --- Bar --------------------------------------------
                        HvSection {
                            Layout.fillWidth: true
                            glyph: "\u{f005c}"
                            title: "Bar"

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    renderType: Text.NativeRendering
                                    Layout.fillWidth: true
                                    text: "Workspaces"
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.textXs
                                    color: Tokens.muted
                                }
                                Segmented {
                                    options: ["Dynamic", "Fixed 1-5"]
                                    values: ["dynamic", "fixed"]
                                    current: Settings.bar.workspacesMode ?? "dynamic"
                                    accessibleName: "Workspace display mode"
                                    onPicked: value => Settings.set({ bar: { workspacesMode: value } })
                                }
                            }
                        }

                        // --- Dock -------------------------------------------
                        HvSection {
                            Layout.fillWidth: true
                            glyph: "\u{f0a79}"
                            title: "Dock"

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    renderType: Text.NativeRendering
                                    Layout.fillWidth: true
                                    text: "Autohide"
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.textXs
                                    color: Tokens.muted
                                }
                                HvToggle {
                                    checked: Settings.dock.autohide ?? false
                                    accessibleName: "Dock autohide"
                                    onToggled: value => Settings.set({ dock: { autohide: value } })
                                }
                            }

                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                visible: monitorRepeater.count > 0
                                text: "Per-monitor override"
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.text2xs
                                font.weight: Tokens.weightSemibold
                                color: Tokens.dim
                            }

                            Repeater {
                                id: monitorRepeater
                                model: Quickshell.screens

                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Text {
                                        renderType: Text.NativeRendering
                                        Layout.fillWidth: true
                                        text: modelData.name ?? "Unknown"
                                        font.family: Tokens.fontUi
                                        font.pixelSize: Tokens.textXs
                                        color: Tokens.muted
                                    }
                                    HvToggle {
                                        checked: Settings.dockAutohideFor(modelData.name ?? "")
                                        accessibleName: "Dock autohide on " + (modelData.name ?? "this monitor")
                                        onToggled: value =>
                                            Settings.setMonitorOverride(modelData.name ?? "", { dockAutohide: value })
                                    }
                                }
                            }
                        }

                        // --- Accent ------------------------------------------
                        HvSection {
                            Layout.fillWidth: true
                            glyph: "\u{f0765}"
                            title: "Accent"

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    renderType: Text.NativeRendering
                                    Layout.fillWidth: true
                                    text: "Provider"
                                    font.family: Tokens.fontUi
                                    font.pixelSize: Tokens.textXs
                                    color: Tokens.muted
                                }
                                Segmented {
                                    options: ["Hyprveil", "Matugen"]
                                    values: ["hyprveil", "matugen"]
                                    current: Settings.appearance.accentProvider ?? "hyprveil"
                                    accessibleName: "Accent provider"
                                    onPicked: value => Settings.set({ appearance: { accentProvider: value } })
                                }
                            }

                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                visible: (Settings.appearance.accentProvider ?? "hyprveil") === "matugen" && !root.matugenAvailable
                                text: "Matugen is not installed — the Hyprveil algorithm stays active until it is. See Integrations."
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.text2xs
                                color: Tokens.warning
                                wrapMode: Text.WordWrap
                            }

                            HvActionRow {
                                Layout.fillWidth: true
                                text: "Re-apply from current wallpaper"
                                onClicked: root.reapplyAccent()
                            }
                        }

                        // --- Calm Mode ---------------------------------------
                        HvSection {
                            Layout.fillWidth: true
                            glyph: "\u{f0e63}"
                            title: "Calm Mode"

                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        renderType: Text.NativeRendering
                                        text: "Enabled"
                                        font.family: Tokens.fontUi
                                        font.pixelSize: Tokens.textXs
                                        color: Tokens.muted
                                    }
                                    Text {
                                        renderType: Text.NativeRendering
                                        visible: CalmMode.active
                                        text: CalmMode.reason === "battery"
                                            ? "Active now — battery is low" : "Active now — turned on here"
                                        font.family: Tokens.fontUi
                                        font.pixelSize: Tokens.text2xs
                                        color: Accent.accent
                                    }
                                }
                                HvToggle {
                                    checked: CalmMode.manualOn
                                    accessibleName: "Calm Mode"
                                    onToggled: CalmMode.toggleManual()
                                }
                            }
                        }

                        // --- Launcher providers ------------------------------
                        HvSection {
                            Layout.fillWidth: true
                            glyph: "\u{f0349}"
                            title: "Launcher providers"

                            Repeater {
                                model: [
                                    { key: "calculator", label: "Calculator" },
                                    { key: "files", label: "Files" },
                                    { key: "emoji", label: "Emoji" }
                                ]

                                RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Text {
                                        renderType: Text.NativeRendering
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        font.family: Tokens.fontUi
                                        font.pixelSize: Tokens.textXs
                                        color: Tokens.muted
                                    }
                                    HvToggle {
                                        checked: Settings.providers.launcher?.[modelData.key] ?? false
                                        accessibleName: modelData.label + " launcher provider"
                                        onToggled: value => {
                                            const next = Object.assign({}, Settings.providers.launcher);
                                            next[modelData.key] = value;
                                            Settings.set({ providers: Object.assign({}, Settings.providers, { launcher: next }) });
                                        }
                                    }
                                }
                            }
                        }

                        // --- Popups -------------------------------------------
                        HvSection {
                            Layout.fillWidth: true
                            glyph: "\u{f0403}"
                            title: "Popup monitor"

                            Segmented {
                                Layout.fillWidth: true
                                options: ["Focused"].concat(Quickshell.screens.map(s => s.name ?? "?"))
                                values: ["focused"].concat(Quickshell.screens.map(s => s.name ?? "?"))
                                current: Settings.surfaces.popupMonitor ?? "focused"
                                accessibleName: "Preferred monitor for launcher, quick settings, calendar, and integrations"
                                onPicked: value => Settings.set({ surfaces: { popupMonitor: value } })
                            }
                        }

                        // --- Scenes -------------------------------------------
                        HvSection {
                            Layout.fillWidth: true
                            glyph: "\u{f0a1e}"
                            title: "Scenes"

                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                visible: root.sceneNames.length === 0
                                text: "No saved scenes yet."
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textXs
                                color: Tokens.dim
                            }

                            Repeater {
                                model: root.sceneNames

                                RowLayout {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing1

                                    Text {
                                        renderType: Text.NativeRendering
                                        Layout.fillWidth: true
                                        text: modelData
                                        font.family: Tokens.fontUi
                                        font.pixelSize: Tokens.textXs
                                        color: Tokens.text
                                    }
                                    HvActionRow {
                                        implicitWidth: 64
                                        text: "Apply"
                                        onClicked: root.runScenes(["apply", parent.modelData])
                                    }
                                    HvActionRow {
                                        implicitWidth: 32
                                        text: "\u{f0156}"
                                        accessibleName: "Delete scene " + modelData
                                        onClicked: root.runScenes(["remove", parent.modelData])
                                    }
                                }
                            }

                            HvActionRow {
                                Layout.fillWidth: true
                                text: "Revert last scene"
                                onClicked: root.runScenes(["revert"])
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing2

                                HvTextField {
                                    id: nameInput
                                    Layout.fillWidth: true
                                    placeholderText: "New scene name"
                                    accessibleName: "New scene name"
                                    onTextChanged: root.newSceneName = text
                                    onAccepted: {
                                        if (root.newSceneName.trim() === "") return;
                                        root.runScenes(["save", root.newSceneName.trim()]);
                                        nameInput.text = "";
                                    }
                                }

                                HvActionRow {
                                    implicitWidth: 96
                                    text: "Save as…"
                                    onClicked: {
                                        if (root.newSceneName.trim() === "") return;
                                        root.runScenes(["save", root.newSceneName.trim()]);
                                        nameInput.text = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
