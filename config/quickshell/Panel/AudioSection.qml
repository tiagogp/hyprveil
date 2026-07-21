// PipeWire audio controls.
//
// The bar already reads PipeWire for its volume glyph; this panel keeps the
// same source of truth and only shells out when the user asks for the full sound
// settings page.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import ".."
import "../Services"

Section {
    id: root

    glyph: "\u{f057e}"
    title: "Audio"

    function hasType(node, flag) {
        return node !== null && (node.type & flag) === flag;
    }

    function nodeTitle(node) {
        if (!node) return "";
        return node.description || node.nickname || node.name;
    }

    function sortByTitle(items) {
        return items.sort((a, b) => root.nodeTitle(a).localeCompare(root.nodeTitle(b)));
    }

    readonly property var outputDevices: sortByTitle(Pipewire.nodes.values
        .filter(n => n.audio && !n.isStream && root.hasType(n, PwNodeType.AudioSink)))
    readonly property var inputDevices: sortByTitle(Pipewire.nodes.values
        .filter(n => n.audio && !n.isStream && root.hasType(n, PwNodeType.AudioSource)))
    readonly property var streams: sortByTitle(Pipewire.nodes.values
        .filter(n => n.audio && n.isStream
            && (root.hasType(n, PwNodeType.AudioOutStream)
                || root.hasType(n, PwNodeType.AudioInStream))))

    Text {
        renderType: Text.NativeRendering
        Layout.fillWidth: true
        visible: !Pipewire.ready
        text: "Audio service unavailable"
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.textXs
        color: Tokens.dim
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: Pipewire.ready
        spacing: Tokens.spacing2

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing1

            Text {
                renderType: Text.NativeRendering
                text: "Output"
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.text2xs
                font.weight: Tokens.weightSemibold
                color: Tokens.dim
            }

            Repeater {
                model: root.outputDevices

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: outputLayout.implicitHeight + Tokens.spacing2
                    radius: Tokens.radiusSm
                    activeFocusOnTab: true
                    color: outputMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    border.width: activeFocus ? 1 : 0
                    border.color: Accent.accent
                    Accessible.role: Accessible.Button
                    Accessible.name: "Select audio output " + root.nodeTitle(modelData)

                    Keys.onReturnPressed: Pipewire.preferredDefaultAudioSink = modelData
                    Keys.onSpacePressed: Pipewire.preferredDefaultAudioSink = modelData
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_M && modelData.audio) {
                            modelData.audio.muted = !modelData.audio.muted;
                            event.accepted = true;
                        }
                    }

                    ColumnLayout {
                        id: outputLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: Tokens.spacing2
                            rightMargin: Tokens.spacing2
                        }
                        spacing: Tokens.spacing1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing2

                            Glyph {
                                text: "\u{f057e}"
                                size: Tokens.iconSm
                                color: modelData === Pipewire.defaultAudioSink
                                    ? Accent.accent : Tokens.muted
                            }

                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                text: root.nodeTitle(modelData)
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textXs
                                color: modelData === Pipewire.defaultAudioSink
                                    ? Tokens.text : Tokens.muted
                                elide: Text.ElideRight
                            }

                            Text {
                                renderType: Text.NativeRendering
                                text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.text2xs
                                color: Tokens.dim
                            }

                            Glyph {
                                text: modelData.audio?.muted ? "\u{f075f}" : "\u{f057e}"
                                size: Tokens.iconSm
                                color: modelData.audio?.muted ? Tokens.warning : Tokens.dim
                            }
                        }

                        AudioSlider {
                            Layout.fillWidth: true
                            node: modelData
                        }
                    }

                    MouseArea {
                        id: outputMouse
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                        }
                        height: Tokens.spacing8
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: event => {
                            if (event.button === Qt.MiddleButton) {
                                modelData.audio.muted = !modelData.audio.muted;
                            } else {
                                Pipewire.preferredDefaultAudioSink = modelData;
                            }
                        }
                    }
                }
            }

            Text {
                renderType: Text.NativeRendering
                Layout.fillWidth: true
                visible: root.outputDevices.length === 0
                text: "No output devices"
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textXs
                color: Tokens.dim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing1

            Text {
                renderType: Text.NativeRendering
                text: "Input"
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.text2xs
                font.weight: Tokens.weightSemibold
                color: Tokens.dim
            }

            Repeater {
                model: root.inputDevices

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: inputLayout.implicitHeight + Tokens.spacing2
                    radius: Tokens.radiusSm
                    activeFocusOnTab: true
                    color: inputMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    border.width: activeFocus ? 1 : 0
                    border.color: Accent.accent
                    Accessible.role: Accessible.Button
                    Accessible.name: "Select audio input " + root.nodeTitle(modelData)

                    Keys.onReturnPressed: Pipewire.preferredDefaultAudioSource = modelData
                    Keys.onSpacePressed: Pipewire.preferredDefaultAudioSource = modelData
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_M && modelData.audio) {
                            modelData.audio.muted = !modelData.audio.muted;
                            event.accepted = true;
                        }
                    }

                    ColumnLayout {
                        id: inputLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: Tokens.spacing2
                            rightMargin: Tokens.spacing2
                        }
                        spacing: Tokens.spacing1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing2

                            Glyph {
                                text: "\u{f036c}"
                                size: Tokens.iconSm
                                color: modelData === Pipewire.defaultAudioSource
                                    ? Accent.accent : Tokens.muted
                            }

                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                text: root.nodeTitle(modelData)
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textXs
                                color: modelData === Pipewire.defaultAudioSource
                                    ? Tokens.text : Tokens.muted
                                elide: Text.ElideRight
                            }

                            Text {
                                renderType: Text.NativeRendering
                                text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.text2xs
                                color: Tokens.dim
                            }

                            Glyph {
                                text: modelData.audio?.muted ? "\u{f036d}" : "\u{f036c}"
                                size: Tokens.iconSm
                                color: modelData.audio?.muted ? Tokens.warning : Tokens.dim
                            }
                        }

                        AudioSlider {
                            Layout.fillWidth: true
                            node: modelData
                        }
                    }

                    MouseArea {
                        id: inputMouse
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                        }
                        height: Tokens.spacing8
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: event => {
                            if (event.button === Qt.MiddleButton) {
                                modelData.audio.muted = !modelData.audio.muted;
                            } else {
                                Pipewire.preferredDefaultAudioSource = modelData;
                            }
                        }
                    }
                }
            }

            Text {
                renderType: Text.NativeRendering
                Layout.fillWidth: true
                visible: root.inputDevices.length === 0
                text: "No input devices"
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textXs
                color: Tokens.dim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.streams.length > 0
            spacing: Tokens.spacing1

            Text {
                renderType: Text.NativeRendering
                text: "Streams"
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.text2xs
                font.weight: Tokens.weightSemibold
                color: Tokens.dim
            }

            Repeater {
                model: root.streams

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: streamLayout.implicitHeight + Tokens.spacing2
                    radius: Tokens.radiusSm
                    activeFocusOnTab: true
                    color: streamMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    border.width: activeFocus ? 1 : 0
                    border.color: Accent.accent
                    Accessible.role: Accessible.Button
                    Accessible.name: "Mute audio stream " + root.nodeTitle(modelData)

                    Keys.onReturnPressed: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted
                    Keys.onSpacePressed: if (modelData.audio) modelData.audio.muted = !modelData.audio.muted

                    ColumnLayout {
                        id: streamLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: Tokens.spacing2
                            rightMargin: Tokens.spacing2
                        }
                        spacing: Tokens.spacing1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing2

                            Glyph {
                                text: root.hasType(modelData, PwNodeType.AudioInStream)
                                    ? "\u{f036c}" : "\u{f04db}"
                                size: Tokens.iconSm
                                color: Tokens.muted
                            }

                            Text {
                                renderType: Text.NativeRendering
                                Layout.fillWidth: true
                                text: root.nodeTitle(modelData)
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.textXs
                                color: Tokens.muted
                                elide: Text.ElideRight
                            }

                            Text {
                                renderType: Text.NativeRendering
                                text: Math.round((modelData.audio?.volume ?? 0) * 100) + "%"
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.text2xs
                                color: Tokens.dim
                            }

                            Glyph {
                                text: modelData.audio?.muted ? "\u{f075f}" : "\u{f057e}"
                                size: Tokens.iconSm
                                color: modelData.audio?.muted ? Tokens.warning : Tokens.dim
                            }
                        }

                        AudioSlider {
                            Layout.fillWidth: true
                            node: modelData
                        }
                    }

                    MouseArea {
                        id: streamMouse
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                        }
                        height: Tokens.spacing8
                        hoverEnabled: true
                        acceptedButtons: Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (modelData.audio)
                            modelData.audio.muted = !modelData.audio.muted
                    }
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignRight
            text: "Sound settings"
            onClicked: Quickshell.execDetached(
                ["env", "XDG_CURRENT_DESKTOP=GNOME",
                 "gnome-control-center", "sound"])
        }
    }
}
