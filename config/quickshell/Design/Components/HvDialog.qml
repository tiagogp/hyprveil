import QtQuick
import "../.."

HvPanel {
    property string accessibleName: "Dialog"
    implicitWidth: 420
    Accessible.role: Accessible.Dialog
    Accessible.name: accessibleName
}
