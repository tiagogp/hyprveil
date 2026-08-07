import QtQuick

// Canonical low-level pointer primitive for specialised controls such as
// draggable dock tiles, tray items, workspace pills, and swipeable cards.
// Semantic buttons should still use HvButton/HvActionRow.
MouseArea {
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
}
