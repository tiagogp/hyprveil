import QtQuick
import QtQuick.Layouts
import ".."
import "../Design/Components"
import "../Services"

HvSection {
    id: root
    glyph: "\u{f0241}"
    title: "Power"
    readonly property var orderedProfiles: {
        const preferred = ["performance", "balanced", "power-saver"];
        return preferred.filter(p => PowerProfiles.state.profiles.includes(p))
            .concat(PowerProfiles.state.profiles.filter(p => !preferred.includes(p)).sort());
    }
    readonly property var labels: orderedProfiles.map(profile => profile === "power-saver"
        ? "Saver" : profile.charAt(0).toUpperCase() + profile.slice(1))
    Text {
        Layout.fillWidth: true
        visible: !PowerProfiles.available
        text: PowerProfiles.error
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }
    Segmented {
        Layout.fillWidth: true
        visible: PowerProfiles.available
        options: root.labels
        values: root.orderedProfiles
        current: PowerProfiles.state.current
        accessibleName: "Power profile"
        onPicked: value => PowerProfiles.setProfile(value)
    }
}
