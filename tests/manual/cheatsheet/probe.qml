// Manual probe for Panel/Cheatsheet.qml and Services/Keybinds.qml.
//
//   quickshell -p tests/manual/cheatsheet/probe.qml
//
// Not part of tests/run.sh: it needs a Wayland display and the quickshell
// binary, neither of which the non-session gate has.
//
// It exists because the cheatsheet is the one surface that cannot be checked by
// reading the code — the whole question is whether keybindings.conf parsed into
// something a person can scan. Opening it through the running shell means
// restarting the shell to see a change, and a restart discards the session's
// notification history (see config/quickshell/shell.qml).
//
// Everything beside this file is a SYMLINK to the real component, so this can
// never drift into probing a stale copy.
//
// The modal takes the keyboard exclusively, so this closes itself rather than
// relying on the reader having a working Escape.
//
// Expected: sections in the order keybindings.conf declares them, two balanced
// columns, per-digit workspace binds collapsed to a single `1 – 0` row, the
// count in the header equal to the file's bind lines (NOT the rows on screen),
// and every row's action legible without its shell quoting.
import QtQuick
import Quickshell
import "Panel"

ShellRoot {
    Cheatsheet {
        id: sheet

        Component.onCompleted: {
            sheet.open = true;
            // Set here rather than typed into the field: the point is to prove
            // the filter narrows sections and groups, not that TextInput works.
            if (Qt.application.arguments.indexOf("--filter") !== -1)
                sheet.query = "workspace";
        }
    }

    Timer {
        interval: 8000
        running: true
        onTriggered: Qt.quit()
    }
}
