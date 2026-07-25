// The keybind cheatsheet.
//
// A reader over Services/Keybinds, which parses keybindings.conf. Nothing here
// knows any bind — the modal renders whatever the file says, so the one way to
// change this screen is to change the config it documents.
//
// Two columns rather than one long list: the sections are short and unrelated,
// and stacking them makes the reader scroll past Media to reach Window when
// both would have fit on screen at once.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../Services"

Scope {
    id: root

    property bool open: false
    property string query: ""

    readonly property var visibleSections: _filter(Keybinds.sections, query.trim().toLowerCase())

    // Balanced by row count, not by section count: Workspace has three rows and
    // Window has a dozen, so splitting the list down the middle leaves one
    // column half empty.
    readonly property var columns: {
        const a = [], b = [];
        let ha = 0, hb = 0;
        for (const s of root.visibleSections) {
            let h = 2;
            for (const g of s.groups)
                h += (g.label !== "" ? 1 : 0) + g.binds.length;
            if (ha <= hb) { a.push(s); ha += h; } else { b.push(s); hb += h; }
        }
        return [a, b];
    }

    function _filter(sections, q) {
        if (q === "")
            return sections;
        const out = [];
        for (const s of sections) {
            const groups = [];
            for (const g of s.groups) {
                const binds = g.binds.filter(b => b.search.indexOf(q) !== -1);
                if (binds.length > 0)
                    groups.push({ label: g.label, binds: binds });
            }
            if (groups.length > 0)
                out.push({ title: s.title, groups: groups });
        }
        return out;
    }

    onOpenChanged: {
        if (open) {
            root.query = "";
            sheet.contentY = 0;
            // keybindings.conf is edited by hand; a cheatsheet that shows the
            // scheme as it was when the shell started is worse than none.
            Keybinds.refresh();
        }
    }

    // A modal for the same reason the wallpaper and pin pickers are: it covers
    // the output, dims what is behind it, and holds the keyboard. Unlike those
    // two it commits nothing — the only exits are Escape, the scrim, and the
    // close button.
    PanelWindow {
        id: win
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        // Covering the screen must not push the bar and dock out of their own
        // space — the modal is transient, the reserved layout is not.
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        WlrLayershell.namespace: "hyprveil-cheatsheet"
        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusive: the search field is the primary control, and a modal that
        // owns Escape only once it has been clicked is not a modal.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5)

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
            }
        }

        Surface {
            anchors.centerIn: parent
            elevation: 3
            radius: Tokens.radiusLg

            // Matches the other two modals' entrance; see Panel/Wallpapers.qml
            // for why the motion is on the dialog and not on the layer.
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

            // Wide enough for two columns of a full combo plus its command, and
            // capped against the output so a short screen scrolls rather than
            // hanging the dialog off both ends.
            implicitWidth: Math.min(940, parent.width - Tokens.spacing8 * 2)
            implicitHeight: Math.min(column.implicitHeight + Tokens.spacing4 * 2,
                                     parent.height - Tokens.spacing8 * 2)

            // Stops a click inside the dialog reaching the scrim and dismissing
            // the thing the user is aiming at.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: column
                anchors.fill: parent
                anchors.margins: Tokens.spacing4
                spacing: Tokens.spacing3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing2

                    Text {
                        renderType: Text.NativeRendering
                        text: "Keyboard shortcuts"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textLg
                        font.weight: Tokens.weightBold
                        color: Tokens.text
                    }

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: Keybinds.failed ? "" : Keybinds.count + " binds"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.text2xs
                        color: Tokens.dim
                    }

                    Rectangle {
                        implicitWidth: Tokens.spacing6
                        implicitHeight: Tokens.spacing6
                        radius: Tokens.radiusPill
                        activeFocusOnTab: true
                        color: closeMouse.containsMouse
                            ? Accent.accentSoft : Qt.rgba(1, 1, 1, 0.08)
                        border.width: activeFocus ? 1 : 0
                        border.color: Accent.accent
                        Accessible.role: Accessible.Button
                        Accessible.name: "Close keyboard shortcuts"

                        Keys.onReturnPressed: root.open = false
                        Keys.onSpacePressed: root.open = false

                        Glyph {
                            anchors.centerIn: parent
                            text: "\u{f0156}"
                            size: Tokens.iconSm
                            color: closeMouse.containsMouse ? Accent.accent : Tokens.muted
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.open = false
                        }
                    }
                }

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

                        Glyph {
                            text: "\u{f0349}"
                            size: Tokens.iconSm
                            color: Tokens.dim
                        }

                        TextInput {
                            id: search
                            renderType: Text.NativeRendering
                            Layout.fillWidth: true
                            focus: true
                            Accessible.role: Accessible.EditableText
                            Accessible.name: "Search keyboard shortcuts"
                            color: Tokens.text
                            font.family: Tokens.fontUi
                            font.pixelSize: Tokens.textSm
                            selectionColor: Accent.accentSoft
                            selectedTextColor: Tokens.text
                            clip: true
                            onTextChanged: root.query = text
                            // The modal holds the keyboard exclusively, so the
                            // field has it from the moment it opens — which
                            // means Escape has to be handled here or it is
                            // handled nowhere.
                            Keys.onEscapePressed: root.open = false

                            // Cleared through the property rather than by
                            // binding text to it: binding both ways makes the
                            // field fight the user's own typing.
                            Connections {
                                target: root
                                function onOpenChanged() {
                                    if (root.open) search.text = "";
                                }
                            }

                            Text {
                                renderType: Text.NativeRendering
                                anchors.fill: parent
                                visible: search.text === ""
                                text: "Search keys or actions"
                                font: search.font
                                color: Tokens.dim
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                Flickable {
                    id: sheet
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // Grows to the whole scheme where the output allows it and
                    // scrolls where it does not. A fixed cap left a third of a
                    // 1080p screen empty while rows sat clipped below the fold.
                    // The subtrahend is the header, search field, footer, and
                    // the margins around them.
                    Layout.preferredHeight: Math.min(grid.implicitHeight,
                                                     win.height - 240)
                    visible: root.visibleSections.length > 0
                    clip: true
                    contentWidth: width
                    contentHeight: grid.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    // Only when there is something below the fold — a track on
                    // a list that fits is a scrollbar that lies.
                    Rectangle {
                        anchors.right: parent.right
                        width: Tokens.spacingHair
                        radius: width / 2
                        color: Tokens.hairline
                        visible: sheet.contentHeight > sheet.height

                        y: sheet.contentY
                           + sheet.height * (sheet.contentY / sheet.contentHeight)
                        height: sheet.height * (sheet.height / sheet.contentHeight)
                    }

                    RowLayout {
                        id: grid
                        // The gutter the scroll indicator lives in, reserved
                        // unconditionally: sizing it to whether the sheet
                        // currently overflows would make the column width an
                        // input to the content height that decides it.
                        width: sheet.width - Tokens.spacing3
                        spacing: Tokens.spacing3

                        Repeater {
                            model: root.columns

                            ColumnLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: Tokens.spacing3

                                Repeater {
                                    model: parent.modelData

                                    Surface {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        elevation: 1
                                        radius: Tokens.radiusSm
                                        implicitHeight: card.implicitHeight + Tokens.spacing3 * 2

                                        ColumnLayout {
                                            id: card
                                            anchors.fill: parent
                                            anchors.margins: Tokens.spacing3
                                            spacing: Tokens.spacing2

                                            Text {
                                                renderType: Text.NativeRendering
                                                Layout.fillWidth: true
                                                text: modelData.title
                                                font.family: Tokens.fontUi
                                                font.pixelSize: Tokens.textSm
                                                font.weight: Tokens.weightSemibold
                                                color: Accent.accent
                                            }

                                            Repeater {
                                                model: modelData.groups

                                                ColumnLayout {
                                                    required property var modelData

                                                    Layout.fillWidth: true
                                                    spacing: Tokens.spacingHair

                                                    // The file's own comment above
                                                    // a cluster of binds, kept as
                                                    // the heading it already was.
                                                    Text {
                                                        renderType: Text.NativeRendering
                                                        Layout.fillWidth: true
                                                        Layout.topMargin: Tokens.spacing1
                                                        visible: parent.modelData.label !== ""
                                                        text: parent.modelData.label
                                                        font.family: Tokens.fontUi
                                                        font.pixelSize: Tokens.text2xs
                                                        color: Tokens.dim
                                                        elide: Text.ElideRight
                                                    }

                                                    Repeater {
                                                        model: parent.modelData.binds

                                                        BindRow {
                                                            required property var modelData

                                                            Layout.fillWidth: true
                                                            keys: modelData.keys
                                                            action: modelData.desc
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
                }

                Text {
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    visible: root.visibleSections.length === 0
                    text: Keybinds.failed
                        ? "Could not read " + Keybinds.path
                        : "No shortcut matches “" + root.query + "”"
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textXs
                    color: Keybinds.failed ? Tokens.warning : Tokens.dim
                    elide: Text.ElideMiddle
                }

                Text {
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    text: "Read from ~/.config/hypr/keybindings.conf — edit that file to change any of these."
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.text2xs
                    color: Tokens.dim
                    elide: Text.ElideRight
                }
            }
        }
    }

    IpcHandler {
        target: "cheatsheet"

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }
        function open(): string { root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
