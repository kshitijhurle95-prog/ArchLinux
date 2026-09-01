pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"
import Quickshell

Item {
    id: root

    property real s: 1
    property bool open: false
    property bool pageMode: false
    property bool scanning: false

    property string selectedApSsid: ""
    property bool connectedMenuOpen: false
    property bool confirmingForget: false

    implicitHeight: mainCol.implicitHeight + 20

    function forceReveal() {
        root.scanning = true;
        Network.refresh();
        scanClear.restart();
    }

    onOpenChanged: {
        Network.setVpnPolling(root, root.open);
        if (root.open) {
            root.forceReveal();
        } else {
            root.scanning = false;
            scanClear.stop();
            root.selectedApSsid = "";
            root.connectedMenuOpen = false;
            root.confirmingForget = false;
        }
    }

    Component.onCompleted: Network.setVpnPolling(root, root.open)
    Component.onDestruction: Network.setVpnPolling(root, false)

    // Available networks: excludes currently active connected SSID so it is NEVER duplicated
    readonly property var availableNets: {
        var aps = Network.accessPoints;
        var activeBand = "";
        for (var a = 0; a < aps.length; a++) {
            if (aps[a] && aps[a].active) {
                activeBand = aps[a].band || "";
                break;
            }
        }
        var best = ({});
        for (var i = 0; i < aps.length; i++) {
            var ap = aps[i];
            if (!ap || !ap.ssid)
                continue;
            // Exclude connected SSID completely
            if (ap.ssid === Network.activeSsid)
                continue;
            var key = ap.ssid + "\u0000" + (ap.band || "");
            var prev = best[key];
            if (!prev || (ap.strength || 0) > (prev.strength || 0))
                best[key] = ap;
        }
        var out = [];
        for (var k in best)
            out.push(best[k]);
        out.sort(function (x, y) { return (y.strength || 0) - (x.strength || 0); });
        return out;
    }

    readonly property var multiBandSsids: {
        var bands = ({});
        var aps = Network.accessPoints;
        for (var i = 0; i < aps.length; i++) {
            var ap = aps[i];
            if (!ap || !ap.ssid || !ap.band)
                continue;
            if (!bands[ap.ssid])
                bands[ap.ssid] = ({});
            bands[ap.ssid][ap.band] = true;
        }
        var multi = ({});
        for (var s in bands)
            if (Object.keys(bands[s]).length > 1)
                multi[s] = true;
        return multi;
    }

    onAvailableNetsChanged: if (root.availableNets.length > 0) root.scanning = false

    function secured(ap) {
        return ap && ap.security && ap.security !== "None" && ap.security !== "--";
    }

    Timer {
        id: rescan
        interval: 30000
        repeat: true
        running: root.open
        onTriggered: Network.refresh()
    }

    Timer {
        id: scanClear
        interval: 15000
        onTriggered: root.scanning = false
    }

    function openWifiSettings() {
        Quickshell.execDetached(["bash", "-c", "command -v nm-connection-editor >/dev/null && nm-connection-editor || command -v gnome-control-center >/dev/null && gnome-control-center wifi || ryoku-app settings network || true"]);
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

                // Purple glowing Wi-Fi badge
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
                        text: "wifi"
                        color: "#c4a8ff"
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Wi-Fi")
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
                text: Network.wifiRadio ? "keyboard_arrow_down" : "wifi_off"
                color: Network.wifiRadio ? "#c4a8ff" : Qt.rgba(180/255, 180/255, 200/255, 0.40)
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Network.setWifiEnabled(!Network.wifiRadio)
            }
        }

        // ── 2. Hero Connected Network Card ──
        Item {
            width: parent.width
            height: (Network.wifiPresent && Network.activeSsid.length > 0)
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

                        // Glowing Wi-Fi circle
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
                                text: "wifi"
                                color: "#d8c4ff"
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 54
                            spacing: 2

                            Text {
                                width: parent.width
                                text: Network.activeSsid
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

                // Connected network action drawer
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
                                    Network.disconnectWifi();
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
                                        Network.forgetWifi(Network.activeSsid);
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

        // ── 3. Available Networks Section Header ──
        Item {
            width: parent.width
            height: 32
            visible: Network.wifiPresent

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Available Networks")
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
                        color: root.scanning ? "#c4a8ff" : "#ffffff"
                        RotationAnimator on rotation {
                            running: root.scanning
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 1100
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.scanning ? qsTr("Scanning…") : qsTr("Scan")
                        color: root.scanning ? "#c4a8ff" : "#ffffff"
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

        // ── 4. Available Networks List ──
        Column {
            width: parent.width
            spacing: 6
            visible: Network.wifiPresent

            Text {
                width: parent.width
                visible: root.availableNets.length === 0 && !root.scanning
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("No Available Networks")
                color: Qt.rgba(180/255, 180/255, 210/255, 0.60)
                font.family: Theme.fontPrimary
                font.pixelSize: 12
                topPadding: 10
                bottomPadding: 10
            }

            Repeater {
                model: root.availableNets
                delegate: Column {
                    id: apDelegate
                    required property var modelData
                    required property int index
                    readonly property var ap: modelData
                    readonly property bool isSelected: root.selectedApSsid === ap.ssid
                    property bool showPassword: false
                    property bool connecting: false
                    property bool errorShown: false
                    property int pendingId: -1

                    width: parent ? parent.width : 0
                    spacing: 4

                    function doConnect() {
                        apDelegate.errorShown = false;
                        apDelegate.connecting = true;
                        var pw = (root.secured(ap) && !ap.saved) ? pwInput.text : "";
                        apDelegate.pendingId = Network.connectWifi(ap.ssid, pw, ap.bssid);
                    }

                    Connections {
                        target: Network
                        function onReplied(id, ok, error) {
                            if (id !== apDelegate.pendingId)
                                return;
                            apDelegate.connecting = false;
                            apDelegate.pendingId = -1;
                            if (!ok) {
                                apDelegate.errorShown = true;
                                pwInput.text = "";
                            } else {
                                root.selectedApSsid = "";
                            }
                        }
                    }

                    // Main Network Row Pill
                    Rectangle {
                        id: apRowPill
                        width: parent.width
                        height: 44
                        radius: 12
                        color: (apMa.containsMouse || apDelegate.isSelected)
                            ? Qt.rgba(36/255, 28/255, 56/255, 0.85)
                            : Qt.rgba(24/255, 18/255, 40/255, 0.60)
                        border.width: 1
                        border.color: (apMa.containsMouse || apDelegate.isSelected)
                            ? Qt.rgba(150/255, 110/255, 245/255, 0.55)
                            : Qt.rgba(95/255, 75/255, 150/255, 0.25)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: rightIconsRow.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 18
                                text: "wifi"
                                color: (apMa.containsMouse || apDelegate.isSelected) ? "#d8c4ff" : "#b494f8"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28
                                text: apDelegate.ap.ssid
                                color: (apMa.containsMouse || apDelegate.isSelected) ? "#ffffff" : "#ece6f6"
                                font.family: Theme.fontPrimary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }

                        // Right icons: Lock (if secured), 4 signal bars, Chevron
                        Row {
                            id: rightIconsRow
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // Lock icon
                            MaterialIcon {
                                visible: root.secured(apDelegate.ap)
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 14
                                text: "lock"
                                color: Qt.rgba(200/255, 190/255, 220/255, 0.65)
                            }

                            // 4 vertical signal strength bars
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2.2
                                readonly property int activeBars: {
                                    var str = apDelegate.ap.strength || 0;
                                    if (str >= 75) return 4;
                                    if (str >= 50) return 3;
                                    if (str >= 25) return 2;
                                    if (str > 0) return 1;
                                    return 0;
                                }

                                Repeater {
                                    model: 4
                                    delegate: Rectangle {
                                        required property int index
                                        width: 2.8
                                        height: 4 + index * 3.0
                                        radius: 1.4
                                        anchors.bottom: parent.bottom
                                        color: index < parent.activeBars
                                            ? "#b494f8"
                                            : Qt.rgba(140/255, 120/255, 190/255, 0.22)
                                    }
                                }
                            }

                            // Chevron >
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 16
                                text: apDelegate.isSelected ? "keyboard_arrow_down" : "chevron_right"
                                color: (apMa.containsMouse || apDelegate.isSelected) ? "#d8c4ff" : Qt.rgba(190/255, 175/255, 230/255, 0.50)
                            }
                        }

                        MouseArea {
                            id: apMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.selectedApSsid === apDelegate.ap.ssid) {
                                    root.selectedApSsid = "";
                                } else {
                                    root.selectedApSsid = apDelegate.ap.ssid;
                                    apDelegate.errorShown = false;
                                }
                            }
                        }
                    }

                    // Expanded action / password drawer
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: apDelegate.isSelected
                        clip: true

                        // Password input for secured unsaved networks
                        Rectangle {
                            width: parent.width
                            height: 36
                            radius: 8
                            visible: root.secured(apDelegate.ap) && !apDelegate.ap.saved
                            color: Qt.rgba(20/255, 16/255, 34/255, 0.85)
                            border.width: 1
                            border.color: pwInput.activeFocus ? "#b494f8" : Qt.rgba(130/255, 95/255, 210/255, 0.35)

                            TextInput {
                                id: pwInput
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: pwEye.left
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#ffffff"
                                font.family: Theme.fontPrimary
                                font.pixelSize: 12
                                echoMode: apDelegate.showPassword ? TextInput.Normal : TextInput.Password
                                clip: true
                                onAccepted: apDelegate.doConnect()

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: qsTr("Enter password…")
                                    color: Qt.rgba(180/255, 170/255, 210/255, 0.45)
                                    font: pwInput.font
                                    visible: pwInput.text.length === 0 && !pwInput.activeFocus
                                }
                            }

                            MaterialIcon {
                                id: pwEye
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: 16
                                text: apDelegate.showPassword ? "visibility_off" : "visibility"
                                color: "#c4a8ff"
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: apDelegate.showPassword = !apDelegate.showPassword
                                }
                            }
                        }

                        // Error badge if failed
                        Text {
                            width: parent.width
                            visible: apDelegate.errorShown
                            text: qsTr("Connection failed")
                            color: "#ff6b81"
                            font.family: Theme.fontPrimary
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // Connect button
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 8
                            color: apConnectMa.containsMouse
                                ? Qt.rgba(150/255, 105/255, 255/255, 0.50)
                                : Qt.rgba(125/255, 80/255, 225/255, 0.35)
                            border.width: 1
                            border.color: Qt.rgba(165/255, 125/255, 250/255, 0.60)

                            Text {
                                anchors.centerIn: parent
                                text: apDelegate.connecting ? qsTr("Connecting…") : qsTr("Connect")
                                color: "#ffffff"
                                font.family: Theme.fontPrimary
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: apConnectMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !apDelegate.connecting
                                onClicked: apDelegate.doConnect()
                            }
                        }
                    }
                }
            }
        }

        // ── 5. Bottom Network Settings Button ──
        Rectangle {
            width: parent.width
            height: 42
            radius: 12
            color: netSetMa.containsMouse
                ? Qt.rgba(42/255, 32/255, 68/255, 0.85)
                : Qt.rgba(28/255, 22/255, 46/255, 0.65)
            border.width: 1
            border.color: netSetMa.containsMouse
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
                    text: qsTr("Network settings")
                    color: "#c4a8ff"
                    font.family: Theme.fontPrimary
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                id: netSetMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openWifiSettings()
            }
        }
    }
}
