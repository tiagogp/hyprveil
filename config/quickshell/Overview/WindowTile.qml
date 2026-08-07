// One window in the overview.
//
// The preview is a live ScreencopyView bound to the toplevel's wayland handle —
// Hyprland's toplevel-export protocol streams the real window, so this is the
// actual contents, not a stale screenshot. The tile carries the app icon, its
// title, and the workspace it lives on, because the overview's whole job is to
// let you pick a window you cannot currently see.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Services"
import ".."
import "../Design/Components"

Surface {
    id: root

    // The HyprlandToplevel this tile stands for, set by the delegate.
    property var toplevel: null
    signal activated()

    readonly property string appClass: root.toplevel?.lastIpcObject?.class ?? ""
    readonly property string titleText: Compositor.displayTitle(root.toplevel?.title ?? "")
    readonly property int wsId: root.toplevel?.workspace?.id ?? 0
    readonly property string iconSource:
        Icons.resolve(undefined, undefined, root.appClass, true)

    implicitWidth: 264
    implicitHeight: 200
    elevation: mouse.containsMouse ? 3 : 2
    radius: Tokens.radiusMd

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.spacing2h
        spacing: Tokens.spacing2

        // The preview area. Clipped so a capture that fills more than the tile
        // never spills over the rounded corners, and centred so the aspect-fit
        // ScreencopyView sits in the middle of whatever letterboxing is left.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ScreencopyView {
                id: preview
                anchors.centerIn: parent
                captureSource: root.toplevel?.wayland ?? null
                live: true
                // Constrains the implicit size to the tile while keeping the
                // window's own aspect ratio — the view letterboxes itself rather
                // than stretching the desktop.
                constraintSize: Qt.size(parent.width, parent.height)
            }

            // Until the first frame arrives the tile would be an empty well;
            // the app's own icon stands in so the tile is identifiable the
            // instant the overview opens.
            Image {
                anchors.centerIn: parent
                visible: !preview.hasContent && root.iconSource !== ""
                source: root.iconSource
                width: Tokens.iconXl
                height: Tokens.iconXl
                sourceSize.width: Tokens.iconXl * 2
                sourceSize.height: Tokens.iconXl * 2
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        // Footer: icon, title, and the workspace the window is on.
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing2

            Image {
                visible: root.iconSource !== ""
                source: root.iconSource
                Layout.preferredWidth: Tokens.iconMd
                Layout.preferredHeight: Tokens.iconMd
                sourceSize.width: Tokens.iconMd * 2
                sourceSize.height: Tokens.iconMd * 2
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                renderType: Text.NativeRendering
                Layout.fillWidth: true
                text: root.titleText
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.textXs
                color: Tokens.text
                elide: Text.ElideRight
            }

            // The workspace pill, so a window on 3 reads as "on 3" without
            // having to switch there to find out.
            Rectangle {
                implicitWidth: Math.max(Tokens.spacing4, wsLabel.implicitWidth + Tokens.spacing2)
                implicitHeight: Tokens.spacing4
                radius: Tokens.radiusPill
                color: Accent.accentSoft

                Text {
                    id: wsLabel
                    anchors.centerIn: parent
                    renderType: Text.NativeRendering
                    text: String(root.wsId)
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.text2xs
                    font.weight: Tokens.weightSemibold
                    color: Accent.accent
                }
            }
        }
    }

    // Accent ring on hover, over the tier border rather than instead of it, so
    // the hovered tile reads as picked without the border colour jumping on
    // every neighbour.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 1
        border.color: Accent.accent
        opacity: mouse.containsMouse ? 1 : 0
        antialiasing: true

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.duration(Tokens.dur1)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.easeStandard
            }
        }
    }

    HvPointerArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
