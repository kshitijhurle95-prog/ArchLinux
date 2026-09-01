pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import Ryoku.Ui.Singletons

// Segmented choice row: equal-width options in one bordered track, the active
// one filled with the primary tint. Used for power profiles.
Rectangle {
    id: root

    property var options: []      // [{ id, label }]
    property string current: ""

    signal chose(string id)

    implicitHeight: 38
    radius: Theme.radiusWidget
    color: Qt.rgba(24/255, 18/255, 40/255, 0.60)
    border.width: 1
    border.color: Qt.rgba(95/255, 75/255, 150/255, 0.25)

    Row {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            model: root.options
            delegate: Rectangle {
                id: seg
                required property var modelData
                readonly property bool active: seg.modelData.id === root.current
                width: (parent.width - (root.options.length - 1) * 4) / Math.max(1, root.options.length)
                height: parent.height
                radius: Theme.radiusWidget - 4
                color: seg.active ? Qt.rgba(130/255, 85/255, 235/255, 0.85)
                    : segTap.containsMouse
                        ? Qt.rgba(130/255, 90/255, 230/255, 0.25)
                        : "transparent"
                border.width: seg.active ? 1 : 0
                border.color: Qt.rgba(175/255, 135/255, 255/255, 0.70)
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent
                    text: I18n.tr(seg.modelData.label)
                    color: seg.active ? "#ffffff" : (segTap.containsMouse ? "#d8c4ff" : Qt.rgba(180/255, 170/255, 210/255, 0.65))
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm - 1
                    font.weight: seg.active ? Font.Bold : Font.Medium
                }
                MouseArea {
                    id: segTap
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chose(seg.modelData.id)
                }
            }
        }
    }
}
