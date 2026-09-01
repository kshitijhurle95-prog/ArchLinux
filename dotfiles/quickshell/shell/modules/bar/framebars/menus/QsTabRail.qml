pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../.." as Pill
import Ryoku.FrameBars
import shell.services
import "../../../../components"

// Icon rail for the configured quick-settings modules. Module metadata comes
// from the shared frame catalog, so the rail and loader cannot drift.
Item {
    id: root

    property var modules: []
    property string activeModule: ""
    signal moduleActivated(string moduleId)
    signal requestClose()

    readonly property int notifCount: Notifs.history.length

    implicitWidth: 44

    // Right-edge hairline only - no fill rect, no seam
    Rectangle {
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
        width: 1
        color: Qt.rgba(140/255, 120/255, 200/255, 0.15)
    }

    Column {
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Repeater {
            model: root.modules

            delegate: RailTab {
                required property string modelData
                readonly property var metadata: MenuCatalog.quickSettingsModule(modelData)

                icon: metadata ? metadata.icon : ""
                tipText: metadata ? qsTr(metadata.label) : ""
                active: root.activeModule === modelData
                badge: modelData === "notifications" ? root.notifCount : 0
                onActivated: root.moduleActivated(modelData)
            }
        }
    }

    // ---- bottom utility buttons ---------------------------------------------
    Column {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        RailIconBtn {
            icon: "search"; tipText: qsTr("Lens search")
            onClicked: { Quickshell.execDetached(["ryoku-cmd-google-lens"]); root.requestClose(); }
        }
        RailIconBtn {
            icon: "document_scanner"; tipText: qsTr("Copy text on screen")
            onClicked: { Quickshell.execDetached(["ryoku-cmd-ocr"]); root.requestClose(); }
        }
        RailIconBtn {
            icon: "qr_code_scanner"; tipText: qsTr("Scan a QR code")
            onClicked: { Quickshell.execDetached(["ryoku-cmd-qr-scan"]); root.requestClose(); }
        }
        RailIconBtn {
            icon: "settings"; tipText: qsTr("Ryoku Hub")
            onClicked: { Quickshell.execDetached(["ryoku-shell", "hub", "open"]); root.requestClose(); }
        }
        RailIconBtn {
            icon: "colorize"; tipText: qsTr("Pick a color")
            onClicked: { Quickshell.execDetached(["ryoku-cmd-color-picker"]); root.requestClose(); }
        }
    }

    // ---- inline components --------------------------------------------------

    // Icon tab: solid primary disc when active, transparent when not.
    // Disc = filled circle in Theme.primary. Icon = Theme.onPrimary when active.
    component RailTab: Item {
        id: rt
        property string moduleId: ""
        property string icon: ""
        property string tipText: ""
        property bool active: false
        property int badge: 0
        signal activated()

        width: 36; height: 36

        // Hover wash underneath disc so the hover shows even when disc is hidden
        Rectangle {
            id: hoverWash
            anchors.fill: parent; radius: width / 2
            color: rtTap.containsMouse && !rt.active
                ? Qt.rgba(130/255, 90/255, 230/255, 0.25)
                : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        // Active disc: purple glowing circle
        Rectangle {
            id: disc
            anchors.fill: parent; radius: width / 2
            visible: rt.active
            color: Qt.rgba(130/255, 85/255, 235/255, 0.85)
            border.width: 1
            border.color: Qt.rgba(175/255, 135/255, 255/255, 0.70)

            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        // Icon: white on active disc, #c4a8ff otherwise.
        MaterialIcon {
            anchors.centerIn: parent; font.pixelSize: 20
            text: rt.icon
            fill: rt.active ? 1 : 0
            color: rt.active ? "#ffffff" : (rtTap.containsMouse ? "#ffffff" : "#c4a8ff")
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        // Press dip
        scale: rtTap.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

        // Unread badge (notifications tab; hidden at zero)
        Rectangle {
            visible: rt.badge > 0
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: -2; anchors.rightMargin: -2
            width: Math.max(16, badgeTxt.implicitWidth + 6); height: 16; radius: 8
            color: Qt.rgba(130/255, 85/255, 235/255, 0.95)
            Text {
                id: badgeTxt; anchors.centerIn: parent
                text: rt.badge > 99 ? "99+" : String(rt.badge)
                color: "#ffffff"
                font.family: Theme.fontPrimary; font.pixelSize: 9; font.weight: Font.Bold
            }
        }

        MouseArea {
            id: rtTap; anchors.fill: parent
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: rt.activated()
        }

        // side: true => bubble opens to the RIGHT (stays inside panel body)
        QsTip { text: rt.tipText; side: true; hovered: rtTap.containsMouse && !rtTap.pressed }
    }

    // Utility icon button (Hub, colour picker) - same side tip.
    component RailIconBtn: Item {
        id: rib
        property string icon: ""
        property string tipText: ""
        signal clicked()

        width: 34; height: 34

        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: ribTap.containsMouse
                ? Qt.rgba(130/255, 90/255, 230/255, 0.25)
                : "transparent"
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        MaterialIcon {
            anchors.centerIn: parent; font.pixelSize: 17; text: rib.icon
            color: ribTap.containsMouse ? "#ffffff" : "#c4a8ff"
        }
        scale: ribTap.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
        MouseArea {
            id: ribTap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: rib.clicked()
        }
        QsTip { text: rib.tipText; side: true; hovered: ribTap.containsMouse && !ribTap.pressed }
    }
}
