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
    // Tracked by toggle rather than read from the keyboard: Qt exposes no
    // modifier-state query without a key event, so this can only follow presses
    // seen while the field has focus. It starts false, which is the common case
    // at a login prompt.
    property bool capsLock: false

    Rectangle {
        anchors.fill: parent
        radius: 23
        color: colors.inputBg
        border.width: 1
        border.color: root.showError ? colors.error
                    : input.activeFocus ? colors.inputFocus
                    : colors.inputBorder

        Behavior on border.color { ColorAnimation { duration: 140 } }
    }

    // Shaken rather than only recoloured: on a failed login the placeholder is
    // the only thing that changes, and a colour swap alone is easy to miss on
    // the frame where focus returns to an already-empty field.
    //
    // Driven through anchors.horizontalCenterOffset, not `x`. The parent
    // centres this item by anchor, so an animation on `x` is overridden by the
    // anchor on the next layout pass — and reading root.x for the return keyframe
    // would sample a value the animation is itself mid-way through changing.
    SequentialAnimation {
        id: shake
        running: false
        NumberAnimation { target: root.anchors; property: "horizontalCenterOffset"; to: -8; duration: 45 }
        NumberAnimation { target: root.anchors; property: "horizontalCenterOffset"; to: 8; duration: 90 }
        NumberAnimation { target: root.anchors; property: "horizontalCenterOffset"; to: 0; duration: 45 }
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

        // Caps Lock is the single most common cause of a "wrong password" that
        // is not a wrong password, and it is invisible in a masked field.
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_CapsLock)
                root.capsLock = !root.capsLock
        }
    }

    // Sits under the pill; reserves no layout height so the column above does
    // not shift when it appears.
    Text {
        anchors.top: parent.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        text: qsTr("Caps Lock is on")
        font.family: geistRegular ? geistRegular.name : "sans-serif"
        font.pixelSize: 12
        color: colors.warning
        opacity: root.capsLock ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
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
            shake.restart()
            root.focusInput()
        }
        function onLoginSucceeded() {
            root.showError = false
        }
    }
}
