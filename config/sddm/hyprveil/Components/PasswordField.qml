import QtQuick
import QtQuick.Controls.Basic

// Pill password field — 280x46, radius 23, translucent fill/border, matches
// hypr/hyprlock.conf's input-field block (rounding 23, outer/inner alpha
// white, check_color/fail_color mirrored below).
Item {
    id: root
    required property var colors
    property var geistRegular
    property string userName
    property int sessionIndex: 0

    width: 280
    height: 46

    property bool showError: false

    Rectangle {
        anchors.fill: parent
        radius: 23
        color: colors.inputBg
        border.width: 1
        border.color: root.showError ? colors.error : colors.inputBorder
    }

    TextField {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        background: null
        color: colors.textPrimary
        font.family: geistRegular ? geistRegular.name : "sans-serif"
        font.pixelSize: 13
        placeholderText: root.showError ? qsTr("Wrong password") : qsTr("Enter password")
        placeholderTextColor: root.showError ? colors.error : colors.textSubtle
        selectByMouse: true

        onTextEdited: root.showError = false
        onAccepted: root.submit()
    }

    function submit() {
        if (input.text.length === 0 || !root.userName) return
        sddm.login(root.userName, input.text, root.sessionIndex)
    }

    function focusInput() { input.forceActiveFocus() }

    Connections {
        target: sddm
        function onLoginFailed() {
            input.text = ""
            root.showError = true
            root.focusInput()
        }
        function onLoginSucceeded() {
            root.showError = false
        }
    }
}
