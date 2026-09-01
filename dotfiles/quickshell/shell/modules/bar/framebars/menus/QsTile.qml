pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"
import Ryoku.Ui.Singletons

// One quick-settings toggle tile: icon in a state circle, label + live
// sub-state, whole face toggles, the chevron (when a detail page exists)
// navigates. Active tiles fill with the primary tint so state reads at a
// glance; everything else stays quiet surface.
Item {
    id: root

    property string icon: "circle"
    property string label: ""
    property string sub: ""
    property bool on: false
    property bool hasPage: false
    property string pageTip: ""

    // A tile whose action cannot be taken right now. It stays visible and keeps
    // explaining itself through `sub` (the reason belongs there), but reads as
    // inert and swallows the tap, so the user learns before clicking instead of
    // after a notification. Defaults available, so a tile that never sets it
    // behaves exactly as before.
    property bool available: true

    signal toggled()
    signal pageRequested()

    implicitHeight: 64

    // The effective background the tile's ink sits on: the resting tile fill
    // (soft primary tint when on, soft on-surface wash when off) composited
    // over the panel's effective surface, so labels stay legible on the tint.
    readonly property color effBg: Theme.blend(
        root.on ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06),
        Theme.effectiveSurface)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: root.on
            ? (face.containsMouse ? Qt.rgba(44/255, 32/255, 72/255, 0.85) : Qt.rgba(34/255, 24/255, 56/255, 0.70))
            : (face.containsMouse ? Qt.rgba(36/255, 28/255, 56/255, 0.80) : Qt.rgba(24/255, 18/255, 40/255, 0.55))
        border.width: 1
        border.color: root.on
            ? Qt.rgba(160/255, 120/255, 245/255, 0.60)
            : (face.containsMouse ? Qt.rgba(140/255, 100/255, 230/255, 0.40) : Qt.rgba(95/255, 75/255, 150/255, 0.25))
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
        id: face
        anchors.fill: parent
        anchors.rightMargin: root.hasPage ? 34 : 0
        hoverEnabled: true
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.available) root.toggled()
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: root.hasPage ? 34 : 12
        spacing: 10
        opacity: root.available ? 1 : 0.45
        Behavior on opacity { NumberAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }

        Rectangle {
            id: iconDisc
            anchors.verticalCenter: parent.verticalCenter
            scale: face.pressed ? 0.86 : 1
            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
            width: 36
            height: 36
            radius: 18
            color: root.on
                ? Qt.rgba(130/255, 85/255, 235/255, 0.85)
                : Qt.rgba(140/255, 120/255, 190/255, 0.15)
            border.width: 1
            border.color: root.on
                ? Qt.rgba(175/255, 135/255, 255/255, 0.70)
                : Qt.rgba(120/255, 100/255, 170/255, 0.20)
            Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }

            MaterialIcon {
                anchors.centerIn: parent
                font.pixelSize: 18
                fill: root.on ? 1 : 0
                text: root.icon
                color: root.on ? "#ffffff" : "#c4a8ff"
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - iconDisc.width - parent.spacing
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: I18n.tr(root.label)
                color: "#ffffff"
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text.length > 0
                text: root.sub
                color: root.on ? "#c4a8ff" : Qt.rgba(180/255, 170/255, 210/255, 0.65)
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm - 2
            }
        }
    }

    // Detail-page affordance: its own hit region so a chevron tap never toggles.
    Rectangle {
        visible: root.hasPage
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 6
        width: 26
        radius: Theme.radiusWidget - 4
        color: pageTap.containsMouse
            ? Qt.rgba(130/255, 90/255, 230/255, 0.25)
            : "transparent"
        scale: pageTap.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

        MaterialIcon {
            anchors.centerIn: parent
            font.pixelSize: 16
            text: "chevron_right"
            color: pageTap.containsMouse ? "#ffffff" : "#c4a8ff"
        }
        MouseArea {
            id: pageTap
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pageRequested()
        }
        QsTip {
            text: root.pageTip
            align: "right"
            hovered: pageTap.containsMouse && !pageTap.pressed
        }
    }
}
