// The dock pin picker.
//
// Before this, the dock's own contents were the one thing on the dock you could
// not change from the dock: pinning went through `dock-manager.sh manage`, a
// Rofi menu you had to already know about. The click target now sits on the
// dock itself.
//
// A front-end over dock-manager.sh, which stays the only writer of
// dock-pins.json — it owns the flock, the atomic replace, and the limit. This
// stages a list and commits it once with `set`; nothing here is a second source
// of truth, and applying the same edits as a sequence of add/remove calls would
// take the lock N times and render every intermediate dock on the way.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import ".."
import "../Panel"
import "../Services"

Scope {
    id: root

    property bool open: false

    // The installed-application catalogue, and the ceiling dock-manager.sh will
    // enforce on commit. Both come from `entries` so the number is not written
    // down twice.
    property var entries: []
    property int limit: 10
    property string query: ""
    property string status: ""

    // The staged pin list, as desktop ids in dock order. Toggling a row only
    // stages it; nothing reaches dock-pins.json until Apply, so a misclick in a
    // list of several hundred apps costs a second click rather than a dock.
    property var staged: []
    // Pins whose desktop entry could not be resolved. They cannot be rendered
    // as rows and `set` cannot name them, so Apply would drop them silently —
    // which is exactly the kind of thing that has to be said out loud.
    property int unresolved: 0

    readonly property bool full: staged.length >= limit

    readonly property var visibleEntries: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return entries;
        return entries.filter(e => e.name.toLowerCase().includes(q)
                                || e.desktop_id.toLowerCase().includes(q));
    }

    // Staged ids resolved back to catalogue records, so the order strip can draw
    // names and icons. Anything that vanished from the catalogue between opening
    // and now simply does not appear.
    readonly property var stagedEntries:
        staged.map(id => entries.find(e => e.desktop_id === id)).filter(e => e !== undefined)

    function isStaged(id) {
        return staged.indexOf(id) !== -1;
    }

    // Assigning a new array rather than mutating: `staged` is a var property,
    // and QML only re-evaluates the bindings that read it when the property
    // itself is reassigned. push() would change the contents and update nothing.
    function toggle(id) {
        const next = staged.slice();
        const at = next.indexOf(id);
        if (at !== -1)
            next.splice(at, 1);
        else if (next.length < limit)
            next.push(id);
        else
            return;
        staged = next;
    }

    Process {
        id: lister
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/dock-manager.sh", "entries"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text);
                    root.limit = c.limit ?? 10;
                    const sorted = (c.entries ?? []).slice().sort(
                        (a, b) => a.name.localeCompare(b.name));
                    // Reassigning root.entries always hands the ListView a new
                    // array, even when the catalogue is unchanged from last
                    // opening — the view can't tell it's the same list, so it
                    // tears down and rebuilds every row, IconImage included.
                    // That's a flash of every app icon blanking and redecoding
                    // on an opening that changed nothing. JSON.stringify is a
                    // cheap enough compare for a few hundred plain-object rows
                    // and keeps the old array (and its resolved icons) alive
                    // when nothing actually installed or removed an app.
                    if (JSON.stringify(sorted) !== JSON.stringify(root.entries))
                        root.entries = sorted;
                    root.status = "";
                } catch (e) {
                    root.entries = [];
                    root.status = "Could not read the application list";
                }
                // Staging waits on the catalogue: a pin is only stageable once
                // there is an entry to resolve it against, and `unresolved`
                // cannot be counted before then.
                root.restage();
            }
        }
    }

    function restage() {
        const known = new Set(root.entries.map(e => e.desktop_id.toLowerCase()));
        const next = [];
        let missing = 0;
        for (const pin of Pins.pins) {
            const id = pin.desktop_id ?? "";
            // Matched case-insensitively, like dock-manager.sh does, then
            // stored in the catalogue's spelling so `set` resolves it.
            const match = id !== ""
                ? root.entries.find(e => e.desktop_id.toLowerCase() === id.toLowerCase())
                : undefined;
            if (match)
                next.push(match.desktop_id);
            else
                missing++;
        }
        // Same reasoning as the entries compare above: the staged chips carry
        // their own IconImage row (the Flow near the top of the dialog), and
        // reassigning root.staged on every opening flashed those too even
        // when the pin set hadn't moved. Order matters here, so this compares
        // position by position rather than by set membership.
        const same = next.length === root.staged.length
            && next.every((id, i) => id === root.staged[i]);
        if (!same)
            root.staged = next;
        root.unresolved = missing;
    }

    // Detached rather than a Process for the same reason the dock's unpin is:
    // there is no result to wait for. dock-manager.sh reports a rejected id
    // through notify-send, which lands in the same history as everything else,
    // and the shell picks up the new order from the watched state file.
    function apply() {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/hypr/scripts/dock-manager.sh", "set"
        ].concat(root.staged));
        root.open = false;
    }

    onOpenChanged: {
        if (open) {
            root.query = "";
            root.status = "";
            // The Scope outlives a closing, so the list keeps whatever scroll
            // offset it was left at — which lands a reopening somewhere random
            // in the alphabet with no indication that it is not the top.
            appList.positionViewAtBeginning();
            // Re-listed on every opening: apps are installed and removed while
            // the shell runs, and a stale catalogue would let Apply commit an id
            // that no longer exists.
            lister.running = true;
        }
    }

    // A modal, not a panel, for the same reason the wallpaper picker is one:
    // this is a committed choice with a confirm step, so the desktop behind it
    // should read as unavailable rather than as something to keep working in.
    PanelWindow {
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        // Covering the screen must not push the bar and dock out of their own
        // space — the modal is transient, the reserved layout is not.
        exclusionMode: ExclusionMode.Ignore

        color: "transparent"
        WlrLayershell.namespace: "hyprveil-dock-pins"
        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusive: the search field is the primary control, so the modal has
        // to hold the keyboard from the moment it opens rather than once it has
        // been clicked.
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

            // Matches the wallpaper picker's entrance; see Panel/Wallpapers.qml
            // for why the motion is on the dialog and not on the layer.
            transform: Translate {
                y: root.open ? 0 : -Tokens.spacing6

                Behavior on y {
                    NumberAnimation {
                        duration: Motion.duration(Tokens.dur2h)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.easeOut
                    }
                }
            }

            implicitWidth: Math.max(0, Math.min(560, parent.width - Tokens.spacing4 * 2))
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

                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: "Dock pins"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textLg
                        font.weight: Tokens.weightBold
                        color: Tokens.text
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
                        Accessible.name: "Close dock pins"

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

                // The staged order, drawn as the dock draws it. The list below
                // says WHICH apps are pinned but not in what order, and order is
                // half of what a dock is.
                Flow {
                    Layout.fillWidth: true
                    visible: root.stagedEntries.length > 0
                    spacing: Tokens.spacing2

                    Repeater {
                        model: root.stagedEntries

                        Rectangle {
                            required property var modelData

                            width: 36
                            height: 36
                            radius: Tokens.radiusSm
                            activeFocusOnTab: true
                            color: chipMouse.containsMouse || activeFocus ? "#23262e" : "#1c1f26"
                            border.width: activeFocus ? 1 : 0
                            border.color: Accent.accent
                            Accessible.role: Accessible.Button
                            Accessible.name: "Unpin " + modelData.name

                            Keys.onReturnPressed: root.toggle(modelData.desktop_id)
                            Keys.onSpacePressed: root.toggle(modelData.desktop_id)

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: Tokens.iconMd
                                source: Icons.resolve(undefined, modelData.desktop_id,
                                                      modelData.app_id, true)
                            }

                            // The whole chip is the unpin target — it is already
                            // a "pinned" affordance, so a separate × inside 36px
                            // would be two hit areas fighting over one tile.
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                visible: chipMouse.containsMouse
                                color: Qt.rgba(0, 0, 0, 0.55)

                                Glyph {
                                    anchors.centerIn: parent
                                    text: "\u{f0156}"
                                    size: Tokens.iconSm
                                    color: Tokens.text
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggle(modelData.desktop_id)
                            }
                        }
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    visible: root.stagedEntries.length > 1
                    text: "Drag a tile on the dock to reorder it."
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.text2xs
                    color: Tokens.dim
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
                            Accessible.name: "Search applications to pin"
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
                                text: "Search applications"
                                font: search.font
                                color: Tokens.dim
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                ListView {
                    id: appList
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 320)
                    visible: root.visibleEntries.length > 0
                    clip: true
                    model: root.visibleEntries
                    spacing: Tokens.spacingHair

                    delegate: Rectangle {
                        id: appRow
                        required property var modelData

                        readonly property bool pinned: root.isStaged(modelData.desktop_id)
                        // At capacity the unpinned rows stop responding, but are
                        // still drawn: a list that hides everything you cannot
                        // add gives no clue that capacity is why.
                        readonly property bool available: pinned || !root.full

                        width: ListView.view.width
                        height: 44
                        radius: Tokens.radiusSm
                        activeFocusOnTab: available
                        color: (rowMouse.containsMouse || activeFocus) && available
                             ? "#23262e" : "transparent"
                        border.width: activeFocus ? 1 : 0
                        border.color: Accent.accent
                        opacity: available ? 1.0 : 0.4
                        Accessible.role: Accessible.Button
                        Accessible.name: (pinned ? "Unpin " : "Pin ") + modelData.name

                        Keys.onReturnPressed: if (available) root.toggle(modelData.desktop_id)
                        Keys.onSpacePressed: if (available) root.toggle(modelData.desktop_id)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.spacing2
                            anchors.rightMargin: Tokens.spacing2
                            spacing: Tokens.spacing2

                            IconImage {
                                implicitSize: Tokens.iconLg
                                source: Icons.resolve(undefined, modelData.desktop_id,
                                                      modelData.app_id, true)
                            }

                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                text: modelData.name
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textSm
                                color: Tokens.text
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                implicitWidth: Tokens.spacing5
                                implicitHeight: Tokens.spacing5
                                radius: Tokens.radiusPill
                                color: appRow.pinned
                                     ? Accent.accent : Qt.rgba(1, 1, 1, 0.08)

                                // A check on an unpinned row reads as "pinned,
                                // just quieter" — the two states have to differ
                                // in shape, not only in fill.
                                Glyph {
                                    anchors.centerIn: parent
                                    text: appRow.pinned ? "\u{f012c}" : "\u{f0415}"
                                    size: Tokens.iconSm
                                    color: appRow.pinned ? Tokens.base : Tokens.dim
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: appRow.available
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggle(modelData.desktop_id)
                        }
                    }
                }

                Text {
                    renderType: Text.NativeRendering
                    Layout.fillWidth: true
                    visible: root.visibleEntries.length === 0
                    text: root.entries.length === 0
                        ? "No installed applications were found"
                        : "No application matches “" + root.query + "”"
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.textXs
                    color: Tokens.dim
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing2

                    // One status line in the footer, so the dialog does not
                    // change height as a message appears and clears.
                    Text {
                        renderType: Text.NativeRendering
                        Layout.fillWidth: true
                        text: root.status !== "" ? root.status
                            : root.unresolved > 0
                                ? root.unresolved + " pin(s) have no desktop entry and will be dropped"
                            : root.full ? "Dock is full (" + root.limit + " pins)"
                            : root.staged.length + " of " + root.limit + " pinned"
                        font.family: Tokens.fontUi
                        font.pixelSize: Tokens.textXs
                        color: root.status !== "" || root.unresolved > 0
                             ? Tokens.warning : Tokens.dim
                        elide: Text.ElideRight
                    }

                    Button {
                        text: "Cancel"
                        onClicked: root.open = false
                    }

                    Button {
                        text: "Apply"
                        primary: true
                        onClicked: root.apply()
                    }
                }
            }
        }
    }

    // Same shape the wallpaper picker exposes, so the dock's pins are
    // scriptable from outside the shell without going through Rofi.
    IpcHandler {
        target: "dockpins"

        function toggle(): string {
            root.open = !root.open;
            return root.open ? "open" : "closed";
        }
        function open(): string { root.open = true; return "open"; }
        function close(): string { root.open = false; return "closed"; }
    }
}
