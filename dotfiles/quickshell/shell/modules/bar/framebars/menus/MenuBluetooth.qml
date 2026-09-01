pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import shell.services
import "../../../../components"
import Ryoku.Ui.Singletons

Item {
    id: root

    property real s: 1
    required property bool open
    property bool pageMode: false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: root.adapter !== null
    readonly property bool adapterEnabled: root.hasAdapter && root.adapter.enabled

    readonly property var devices: (root.open && Bluetooth.devices) ? Bluetooth.devices.values : []
    readonly property var connectedDevice: {
        for (var i = 0; i < root.devices.length; i++) {
            if (root.devices[i] && root.devices[i].connected)
                return root.devices[i];
        }
        return null;
    }
    readonly property var availableDevices: {
        var out = [];
        for (var i = 0; i < root.devices.length; i++) {
            var d = root.devices[i];
            if (!d) continue;
            // Exclude the connected device so it is never duplicated
            if (root.connectedDevice && d.address === root.connectedDevice.address)
                continue;
            out.push(d);
        }
        return out;
    }

    property string selectedDeviceAddress: ""
    property bool connectedMenuOpen: false
    property bool confirmingForget: false

    readonly property bool discovering: root.hasAdapter && root.adapter.discovering

    implicitHeight: mainCol.implicitHeight + 20

    function forceReveal() {
        if (root.hasAdapter)
            BluetoothDiscovery.setDiscovering(root, root.adapter, true);
    }

    onOpenChanged: {
        if (!root.open) {
            BluetoothDiscovery.setDiscovering(root, root.adapter, false);
            root.selectedDeviceAddress = "";
            root.connectedMenuOpen = false;
            root.confirmingForget = false;
        } else {
            root.forceReveal();
        }
    }

    Component.onDestruction: BluetoothDiscovery.setDiscovering(root, root.adapter, false)

    function deviceIcon(d) {
        var hint = (d && d.icon ? d.icon : "").toLowerCase();
        if (hint.indexOf("headset") >= 0 || hint.indexOf("headphone") >= 0 || hint.indexOf("audio") >= 0)
            return "headphones";
        if (hint.indexOf("speaker") >= 0)
            return "speaker";
        if (hint.indexOf("mouse") >= 0)
            return "mouse";
        if (hint.indexOf("keyboard") >= 0)
            return "keyboard";
        if (hint.indexOf("gaming") >= 0 || hint.indexOf("joypad") >= 0)
            return "sports_esports";
        if (hint.indexOf("phone") >= 0)
            return "smartphone";
        if (hint.indexOf("computer") >= 0 || hint.indexOf("laptop") >= 0)
            return "computer";
        if (hint.indexOf("watch") >= 0)
            return "watch";
        return "bluetooth";
    }

    function runDeviceAction(d, act) {
        if (!d)
            return;
        switch (act) {
        case "connect": d.connect(); break;
        case "disconnect": d.disconnect(); break;
        case "trust": d.trusted = true; break;
        case "untrust": d.trusted = false; break;
        case "pair": d.pair(); break;
        case "forget": d.forget(); break;
        }
    }

    function openBtSettings() {
        Quickshell.execDetached(["bash", "-c", "command -v blueman-manager >/dev/null && blueman-manager || command -v blueberry >/dev/null && blueberry || command -v gnome-control-center >/dev/null && gnome-control-center bluetooth || ryoku-app settings bluetooth || true"]);
    }

    Column {
        id: mainCol
        width: parent.width - 24
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        // ── 1. Top Sub-Header / Toggle Status Row ──
        Item {
            width: parent.width
            height: 40

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // Purple glowing Bluetooth badge
                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(130/255, 90/255, 230/255, 0.25)
                    border.width: 1
                    border.color: Qt.rgba(160/255, 120/255, 245/255, 0.50)

                    MaterialIcon {
                        anchors.centerIn: parent
                        font.pixelSize: 18
                        text: "bluetooth"
                        color: "#c4a8ff"
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Bluetooth")
                    color: "#ffffff"
                    font.family: Theme.fontPrimary
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            // Dropdown / toggle chevron
            MaterialIcon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 20
                text: root.adapterEnabled ? "keyboard_arrow_down" : "bluetooth_disabled"
                color: root.adapterEnabled ? "#c4a8ff" : Qt.rgba(180/255, 180/255, 200/255, 0.40)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.hasAdapter)
                        root.adapter.enabled = !root.adapter.enabled;
                }
            }
        }

        // ── 2. Hero Connected Device Card ──
        Item {
            width: parent.width
            height: root.connectedDevice !== null
                ? (connectedCard.height + (root.connectedMenuOpen ? connectedDrawer.implicitHeight + 8 : 0))
                : 0
            visible: height > 0
            clip: true
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Column {
                width: parent.width
                spacing: 6

                Rectangle {
                    id: connectedCard
                    width: parent.width
                    height: 68
                    radius: 14
                    color: connectedMa.containsMouse
                        ? Qt.rgba(36/255, 28/255, 56/255, 0.85)
                        : Qt.rgba(28/255, 22/255, 46/255, 0.70)
                    border.width: 1
                    border.color: Qt.rgba(145/255, 105/255, 240/255, 0.50)
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: checkBadge.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        // Glowing circular device icon
                        Rectangle {
                            width: 42
                            height: 42
                            radius: 21
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(125/255, 80/255, 225/255, 0.35)
                            border.width: 1
                            border.color: Qt.rgba(165/255, 125/255, 250/255, 0.65)

                            MaterialIcon {
                                anchors.centerIn: parent
                                font.pixelSize: 22
                                text: root.deviceIcon(root.connectedDevice)
                                color: "#d8c4ff"
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 54
                            spacing: 2

                            Text {
                                width: parent.width
                                text: (root.connectedDevice && root.connectedDevice.name && root.connectedDevice.name.length > 0)
                                    ? root.connectedDevice.name
                                    : (root.connectedDevice ? root.connectedDevice.address : "")
                                color: "#ffffff"
                                font.family: Theme.fontPrimary
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }

                            Text {
                                text: qsTr("Connected")
                                color: "#bda0ff"
                                font.family: Theme.fontPrimary
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // Checkmark purple badge on right
                    Rectangle {
                        id: checkBadge
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        radius: 12
                        color: Qt.rgba(140/255, 95/255, 240/255, 0.40)
                        border.width: 1
                        border.color: Qt.rgba(175/255, 135/255, 255/255, 0.70)

                        MaterialIcon {
                            anchors.centerIn: parent
                            font.pixelSize: 15
                            text: "check"
                            color: "#ffffff"
                        }
                    }

                    MouseArea {
                        id: connectedMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.confirmingForget = false;
                            root.connectedMenuOpen = !root.connectedMenuOpen;
                        }
                    }
                }

                // Connected device action drawer
                Column {
                    id: connectedDrawer
                    width: parent.width
                    spacing: 6
                    visible: root.connectedMenuOpen

                    Row {
                        width: parent.width
                        height: 32
                        spacing: 8

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 8
                            color: disMa.containsMouse ? Qt.rgba(140/255, 95/255, 240/255, 0.35) : Qt.rgba(36/255, 28/255, 56/255, 0.70)
                            border.width: 1
                            border.color: Qt.rgba(145/255, 105/255, 240/255, 0.40)

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Disconnect")
                                color: "#ffffff"
                                font.family: Theme.fontPrimary
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: disMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.connectedDevice)
                                        root.connectedDevice.disconnect();
                                    root.connectedMenuOpen = false;
                                }
                            }
                        }

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 8
                            color: root.confirmingForget
                                ? Qt.rgba(220/255, 60/255, 80/255, 0.45)
                                : (forgMa.containsMouse ? Qt.rgba(140/255, 95/255, 240/255, 0.35) : Qt.rgba(36/255, 28/255, 56/255, 0.70))
                            border.width: 1
                            border.color: root.confirmingForget ? "#ff6b81" : Qt.rgba(145/255, 105/255, 240/255, 0.40)

                            Text {
                                anchors.centerIn: parent
                                text: root.confirmingForget ? qsTr("Confirm Forget?") : qsTr("Forget")
                                color: root.confirmingForget ? "#ffb3be" : "#ffffff"
                                font.family: Theme.fontPrimary
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: forgMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.confirmingForget) {
                                        if (root.connectedDevice)
                                            root.connectedDevice.forget();
                                        root.connectedMenuOpen = false;
                                        root.confirmingForget = false;
                                    } else {
                                        root.confirmingForget = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 3. Available Devices Section Header ──
        Item {
            width: parent.width
            height: 32
            visible: root.hasAdapter

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Available Devices")
                color: "#ffffff"
                font.family: Theme.fontPrimary
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            // [ ⟳ Scan ] pill button
            Rectangle {
                id: scanPill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: scanRow.implicitWidth + 18
                height: 26
                radius: 13
                color: scanMa.containsMouse
                    ? Qt.rgba(130/255, 90/255, 230/255, 0.35)
                    : Qt.rgba(28/255, 22/255, 46/255, 0.65)
                border.width: 1
                border.color: scanMa.containsMouse
                    ? Qt.rgba(165/255, 125/255, 250/255, 0.65)
                    : Qt.rgba(120/255, 90/255, 190/255, 0.30)
                Behavior on color { ColorAnimation { duration: 120 } }

                Row {
                    id: scanRow
                    anchors.centerIn: parent
                    spacing: 5

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 13
                        text: "refresh"
                        color: root.discovering ? "#c4a8ff" : "#ffffff"
                        RotationAnimator on rotation {
                            running: root.discovering
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 1100
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.discovering ? qsTr("Scanning…") : qsTr("Scan")
                        color: root.discovering ? "#c4a8ff" : "#ffffff"
                        font.family: Theme.fontPrimary
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: scanMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.forceReveal()
                }
            }
        }

        // ── 4. Available Devices List ──
        Column {
            width: parent.width
            spacing: 6
            visible: root.hasAdapter

            Text {
                width: parent.width
                visible: root.availableDevices.length === 0 && !root.discovering
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("No Devices Found")
                color: Qt.rgba(180/255, 180/255, 210/255, 0.60)
                font.family: Theme.fontPrimary
                font.pixelSize: 12
                topPadding: 10
                bottomPadding: 10
            }

            Repeater {
                model: root.availableDevices
                delegate: Column {
                    id: devDelegate
                    required property var modelData
                    required property int index
                    readonly property var dev: modelData
                    readonly property bool isSelected: root.selectedDeviceAddress === dev.address

                    width: parent ? parent.width : 0
                    spacing: 4

                    // Main Device Row Pill
                    Rectangle {
                        id: devRowPill
                        width: parent.width
                        height: 44
                        radius: 12
                        color: (devMa.containsMouse || devDelegate.isSelected)
                            ? Qt.rgba(36/255, 28/255, 56/255, 0.85)
                            : Qt.rgba(24/255, 18/255, 40/255, 0.60)
                        border.width: 1
                        border.color: (devMa.containsMouse || devDelegate.isSelected)
                            ? Qt.rgba(150/255, 110/255, 245/255, 0.55)
                            : Qt.rgba(95/255, 75/255, 150/255, 0.25)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: chevronIcon.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 18
                                text: root.deviceIcon(devDelegate.dev)
                                color: (devMa.containsMouse || devDelegate.isSelected) ? "#d8c4ff" : "#b494f8"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28
                                text: (devDelegate.dev && devDelegate.dev.name && devDelegate.dev.name.length > 0)
                                    ? devDelegate.dev.name
                                    : (devDelegate.dev ? devDelegate.dev.address : "")
                                color: (devMa.containsMouse || devDelegate.isSelected) ? "#ffffff" : "#ece6f6"
                                font.family: Theme.fontPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }

                        // Right Chevron
                        MaterialIcon {
                            id: chevronIcon
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 16
                            text: devDelegate.isSelected ? "keyboard_arrow_down" : "chevron_right"
                            color: (devMa.containsMouse || devDelegate.isSelected) ? "#d8c4ff" : Qt.rgba(190/255, 175/255, 230/255, 0.50)
                        }

                        MouseArea {
                            id: devMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.selectedDeviceAddress === devDelegate.dev.address) {
                                    root.selectedDeviceAddress = "";
                                } else {
                                    root.selectedDeviceAddress = devDelegate.dev.address;
                                }
                            }
                        }
                    }

                    // Expanded action drawer
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: devDelegate.isSelected
                        clip: true

                        Row {
                            width: parent.width
                            height: 32
                            spacing: 8

                            Rectangle {
                                width: (devDelegate.dev.paired ? (parent.width - 8) / 2 : parent.width)
                                height: parent.height
                                radius: 8
                                color: connMa.containsMouse
                                    ? Qt.rgba(150/255, 105/255, 255/255, 0.50)
                                    : Qt.rgba(125/255, 80/255, 225/255, 0.35)
                                border.width: 1
                                border.color: Qt.rgba(165/255, 125/255, 250/255, 0.60)

                                Text {
                                    anchors.centerIn: parent
                                    text: devDelegate.dev.paired ? qsTr("Connect") : qsTr("Pair & Connect")
                                    color: "#ffffff"
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    id: connMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (devDelegate.dev.paired)
                                            devDelegate.dev.connect();
                                        else
                                            devDelegate.dev.pair();
                                    }
                                }
                            }

                            Rectangle {
                                visible: devDelegate.dev.paired
                                width: (parent.width - 8) / 2
                                height: parent.height
                                radius: 8
                                color: forgDevMa.containsMouse ? Qt.rgba(140/255, 95/255, 240/255, 0.35) : Qt.rgba(36/255, 28/255, 56/255, 0.70)
                                border.width: 1
                                border.color: Qt.rgba(145/255, 105/255, 240/255, 0.40)

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Forget")
                                    color: "#ffffff"
                                    font.family: Theme.fontPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: forgDevMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        devDelegate.dev.forget();
                                        root.selectedDeviceAddress = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 5. Bottom Bluetooth Settings Button ──
        Rectangle {
            width: parent.width
            height: 42
            radius: 12
            color: btSetMa.containsMouse
                ? Qt.rgba(42/255, 32/255, 68/255, 0.85)
                : Qt.rgba(28/255, 22/255, 46/255, 0.65)
            border.width: 1
            border.color: btSetMa.containsMouse
                ? Qt.rgba(165/255, 125/255, 250/255, 0.60)
                : Qt.rgba(130/255, 95/255, 210/255, 0.35)
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 8

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 16
                    text: "settings"
                    color: "#c4a8ff"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Bluetooth settings")
                    color: "#c4a8ff"
                    font.family: Theme.fontPrimary
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: btSetMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openBtSettings()
            }
        }
    }
}
