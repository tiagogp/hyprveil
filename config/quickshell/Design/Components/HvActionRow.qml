import QtQuick
import "../.."

HvListRow {
    id: root
    property bool busy: false
    property string text: ""
    signal clicked()
    onTextChanged: if (text.length > 0) title = text
    activeFocusOnTab: enabled && !busy
    Accessible.role: Accessible.Button
    Accessible.focusable: activeFocusOnTab
    opacity: enabled ? 1 : 0.42

    function activate(): void { if (enabled && !busy) clicked(); }
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()
    Keys.onSpacePressed: activate()
    TapHandler { parent: root; enabled: root.enabled && !root.busy; onTapped: root.activate() }
}
