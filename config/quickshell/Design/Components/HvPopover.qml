import QtQuick
import "../.."

HvPanel {
    property point origin: Qt.point(width / 2, 0)
    transformOrigin: Item.Top
    Accessible.role: Accessible.PopupMenu
}
