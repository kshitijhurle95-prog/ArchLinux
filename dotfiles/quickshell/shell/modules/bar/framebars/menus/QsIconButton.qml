import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// Square icon button for the sidebar header, footer, and page-back rows.
// `danger` warms the hover to the error tint for destructive session actions.
Rectangle {
    id: root

    property string icon: "circle"
    property string tip: ""
    property bool danger: false
    // Top-edge controls open their bubble downward so it never leaves the panel.
    property bool tipBelow: false
    // Bubble edge to pin to: "center" (default), "left" or "right".
    property string tipAlign: "center"

    signal clicked()

    implicitWidth: 38
    implicitHeight: 38
    radius: 10
    color: tap.containsMouse
        ? (root.danger
            ? Qt.rgba(220/255, 60/255, 80/255, 0.40)
            : Qt.rgba(130/255, 90/255, 230/255, 0.35))
        : Qt.rgba(36/255, 28/255, 56/255, 0.65)
    border.width: 1
    border.color: tap.containsMouse
        ? (root.danger ? "#ff6b81" : Qt.rgba(165/255, 125/255, 250/255, 0.65))
        : Qt.rgba(140/255, 100/255, 230/255, 0.35)
    Behavior on color { ColorAnimation { duration: 120 } }

    // Native press feel: the face dips under the pointer and springs back.
    scale: tap.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

    MaterialIcon {
        anchors.centerIn: parent
        font.pixelSize: 18
        text: root.icon
        color: root.danger && tap.containsMouse ? "#ffb3be" : "#ffffff"
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    QsTip {
        text: root.tip
        below: root.tipBelow
        align: root.tipAlign
        hovered: tap.containsMouse && !tap.pressed
    }
}
