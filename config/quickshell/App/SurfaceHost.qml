import QtQuick

QtObject {
    property string nature: ""
    property var surfaceNames: []

    function accepts(name: string): bool { return surfaceNames.indexOf(name) >= 0; }
    function open(name: string, screen: var, origin: var): string {
        return accepts(name) ? SurfaceCoordinator.open(name, screen, origin)
                             : "invalid " + nature + " surface: " + name;
    }
}
