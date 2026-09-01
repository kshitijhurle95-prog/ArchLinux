import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property bool active: false

    implicitWidth: active ? 16 : 0
    implicitHeight: 28
    visible: implicitWidth > 0.5
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on opacity       { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!checkProc.running) checkProc.running = true
        }
    }

    Process {
        id: checkProc
        command: ["bash", "-c", "pgrep -f 'wayclick.*runner.py' >/dev/null && echo true || echo false"]
        stdout: SplitParser {
            onRead: data => {
                rootMod.active = (data.trim() === "true")
            }
        }
    }

    IconText {
        id: ico
        anchors.centerIn: parent
        text: "\uE312"   // keyboard icon
        color: "#ffffff"
        font.pixelSize: 11
    }

    TooltipMixin {
        id: tip
        root: rootMod.root
        owner: rootMod
        text: "WayClick Keyboard Sounds: Active (Click to toggle)"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: {
            tip.hide()
            toggleProc.running = true
        }
    }

    Process {
        id: toggleProc
        command: ["bash", "-c", "/home/kshitij/user_scripts/wayclick/dusky_wayclick.sh"]
    }
}
