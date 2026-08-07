// Feature-local facade. Provider registry I/O and file search live in the
// service/adapter layers; Launcher.qml keeps the small API it already used.
import QtQuick
import "../Services"

Item {
    readonly property var fileResults: LauncherProviders.fileResults
    readonly property bool available: LauncherProviders.available
    readonly property bool busy: LauncherProviders.busy
    readonly property string error: LauncherProviders.error

    function refresh(): void { LauncherProviders.refresh(); }
    function search(query: string): void { LauncherProviders.search(query); }
    function calculatorResult(query: string): var { return LauncherProviders.calculatorResult(query); }
    function emojiResults(query: string): var { return LauncherProviders.emojiResults(query); }
}
