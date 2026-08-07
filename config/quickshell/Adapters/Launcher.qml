pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Utils"

Singleton {
    id: root

    property bool available: true
    property var registry: []
    property var matches: []
    property bool busy: false
    property string error: ""
    property double lastUpdated: 0
    property string pendingQuery: ""

    function refresh(): void { registryFile.reload(); }

    function searchFiles(query: string): void {
        pendingQuery = query.trim();
        if (pendingQuery === "") {
            matches = [];
            return;
        }
        debounce.restart();
    }

    FileView {
        id: registryFile
        path: Paths.launcherProviders
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                const known = ["calculator", "files", "emoji"];
                root.registry = (parsed.providers ?? []).filter(provider =>
                    provider && typeof provider.id === "string" && known.includes(provider.kind));
                root.available = true;
                root.error = "";
            } catch (e) {
                root.registry = [];
                root.available = false;
                root.error = "Launcher provider registry is malformed";
            }
            root.lastUpdated = Date.now();
        }
        onLoadFailed: {
            root.registry = [];
            root.available = false;
            root.error = "Launcher provider registry is unavailable";
            root.lastUpdated = Date.now();
        }
    }

    Timer {
        id: debounce
        interval: 150
        onTriggered: {
            fileSearch.query = root.pendingQuery;
            fileSearch.running = true;
        }
    }

    Process {
        id: fileSearch
        property string query: ""
        command: ["timeout", "2", "find", Paths.home, "-maxdepth", "6",
            "-iname", "*" + query + "*", "-not", "-path", "*/.*"]
        onRunningChanged: root.busy = running
        stdout: StdioCollector {
            onStreamFinished: {
                root.matches = text.split("\n").filter(line => line !== "").slice(0, 8);
                root.error = "";
                root.lastUpdated = Date.now();
            }
        }
    }
}
