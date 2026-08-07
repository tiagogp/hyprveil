import QtQuick

QtObject {
    id: root
    default property list<QtObject> content
    property string nature: ""
    property var surfaceNames: []

    function accepts(name: string): bool { return surfaceNames.indexOf(name) >= 0; }
    function registerSurface(name: string, controller: var): void {
        if (!accepts(name)) throw new Error("invalid " + nature + " surface: " + name);
        SurfaceCoordinator.registerSurface(name, controller, nature);
    }
    function reportState(name: string, open: bool): void {
        if (accepts(name)) SurfaceCoordinator.reportState(name, open);
    }
    function open(name: string, screen: var, origin: var): string {
        return accepts(name) ? SurfaceCoordinator.open(name, screen, origin)
                             : "invalid " + nature + " surface: " + name;
    }
}
