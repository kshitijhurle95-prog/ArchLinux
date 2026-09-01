import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import "../IconMap.js" as IconMap
import Ryoku.Ui.Singletons

PanelWindow {
    id: btPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-bluetooth"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property bool btOn: false
    property bool scanning: false
    property var devices: []   // [{name, mac, connected, paired}]
    readonly property var shownDevices: devices.slice(0, 8)
    readonly property int numConnected: {
        var n = 0
        for (var i = 0; i < devices.length; i++) if (devices[i].connected) n++
        return n
    }
    property string connCmd: ""
    readonly property color deviceActionFill: Qt.rgba(
        root.paper.r * 0.88,
        root.paper.g * 0.88,
        root.paper.b * 0.88,
        1.0)

    function refresh() { btData.running = false; btData.running = true }

    function activateDevice(device) {
        if (!device || connProc.running) return
        var mac = String(device.mac || "")
        if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(mac)) return
        if (device.connected) {
            connCmd = "bluetoothctl disconnect " + mac
        } else if (device.paired) {
            connCmd = "bluetoothctl connect " + mac
        } else {
            connCmd = "bluetoothctl trust " + mac
                + " && bluetoothctl pair " + mac
                + " && bluetoothctl connect " + mac
        }
        connProc.running = true
    }

    function forgetDevice(device) {
        if (!device || connProc.running) return
        var mac = String(device.mac || "")
        if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(mac)) return
        connCmd = "bluetoothctl remove " + mac
        connProc.running = true
    }

    // The bash model carries only {name,mac,connected,paired}; battery/icon/state
    // come live off Quickshell.Bluetooth, matched by MAC.
    function btDeviceFor(mac) {
        if (typeof Bluetooth === "undefined" || !Bluetooth || !Bluetooth.devices) return null
        var m = String(mac || "").toUpperCase()
        if (!m) return null
        var vals = Bluetooth.devices.values
        for (var i = 0; i < vals.length; i++) {
            var d = vals[i]
            if (d && String(d.address || "").toUpperCase() === m) return d
        }
        return null
    }
    // BlueZ phone charge is coarse/stale without provenance; suppress it (mirrors Shibumi).
    function batteryText(dev) {
        if (!dev || !dev.batteryAvailable) return ""
        var ic = String(dev.icon || "").toLowerCase()
        if (ic === "phone" || ic === "smartphone") return ""
        var b = Number(dev.battery)
        if (!isFinite(b) || b < 0 || b > 1) return ""
        return Math.round(b * 100) + "%"
    }
    function typeLabel(dev) {
        var ic = String(dev && dev.icon ? dev.icon : "").toLowerCase()
        if (ic === "input-gaming") return "Controller"
        if (ic === "audio-headphones") return "Headphones"
        if (ic === "audio-headset") return "Headset"
        if (ic === "audio-card") return "Speaker"
        if (ic === "input-mouse") return "Mouse"
        if (ic === "input-keyboard") return "Keyboard"
        if (ic === "phone") return "Phone"
        return ic ? ic : "Device"
    }

    readonly property var connectedDevice: {
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].connected) return devices[i]
        }
        return null
    }
    readonly property var availableDevices: devices.filter(function(d) {
        return !d.connected
    })
    property bool heroContextMenuOpen: false
    property string selectedDeviceMac: ""

    property real reveal: root.bluetoothVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.bluetoothVisible ? 160 : 120
            easing.type: root.bluetoothVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.bluetoothVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.bluetoothVisible = false }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: btPanel.root
            ownerActive: btPanel.root.bluetoothVisible
            targetX: btPanel.root.bluetoothBarX
            reveal: btPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.bluetoothBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - btPanel.reveal)
            : (barBottom + gap) - 2 * (1 - btPanel.reveal)
        opacity: btPanel.reveal
        focus: root.bluetoothVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.bluetoothVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── 1. HEADER ROW ──
            Item {
                width: parent.width
                height: 40

                Item {
                    id: heroIconBox
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36

                    Rectangle {
                        anchors.fill: parent; radius: 18
                        color: Qt.rgba(130/255, 85/255, 235/255, 0.20)
                        border.color: Qt.rgba(145/255, 105/255, 240/255, 0.40)
                        border.width: 1
                    }

                    IconText {
                        anchors.centerIn: parent
                        text: IconMap.icon("bluetooth")
                        color: "#c4a8ff"
                        font.pixelSize: 18
                    }
                }

                Column {
                    anchors.left: heroIconBox.right
                    anchors.leftMargin: 10
                    anchors.right: heroControls.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    UiText {
                        text: I18n.tr("Bluetooth")
                        color: "#ffffff"
                        font.family: root.mono
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    UiText {
                        width: parent.width
                        text: {
                            if (!btPanel.btOn) return I18n.tr("Disabled")
                            if (btPanel.connectedDevice) return btPanel.connectedDevice.name
                            if (btPanel.scanning) return I18n.tr("Scanning…")
                            return I18n.tr("Ready")
                        }
                        color: Qt.rgba(180/255, 170/255, 210/255, 0.70)
                        font.family: root.mono
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: heroControls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Power toggle
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 42; height: 22; radius: 11
                        color: btPanel.btOn ? Qt.rgba(130/255, 85/255, 235/255, 0.85)
                                            : Qt.rgba(40/255, 32/255, 60/255, 0.60)
                        border.color: btPanel.btOn ? Qt.rgba(175/255, 135/255, 255/255, 0.70)
                                                   : Qt.rgba(110/255, 90/255, 160/255, 0.35)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            width: 16; height: 16; radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            x: btPanel.btOn ? parent.width - width - 3 : 3
                            color: "#ffffff"
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { powerProc.running = false; powerProc.running = true }
                        }
                    }

                    // Close button
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: 12
                        color: closeMa.containsMouse ? Qt.rgba(130/255, 90/255, 230/255, 0.25) : "transparent"
                        UiText {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMa.containsMouse ? "#ffffff" : Qt.rgba(180/255, 170/255, 210/255, 0.60)
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bluetoothVisible = false
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(140/255, 120/255, 200/255, 0.15) }

            // ── 2. HERO CONNECTED CARD ──
            Item {
                width: parent.width
                visible: btPanel.btOn && btPanel.connectedDevice !== null
                height: visible ? connectedCardRect.implicitHeight : 0

                Rectangle {
                    id: connectedCardRect
                    width: parent.width
                    implicitHeight: connCol.implicitHeight + (btPanel.heroContextMenuOpen ? connDrawer.implicitHeight + 10 : 0) + 16
                    radius: 12
                    color: Qt.rgba(36/255, 24/255, 60/255, 0.70)
                    border.color: Qt.rgba(145/255, 105/255, 240/255, 0.50)
                    border.width: 1
                    clip: true

                    Column {
                        id: connCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 10

                            // Device icon disc
                            Rectangle {
                                width: 34; height: 34; radius: 17
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(130/255, 85/255, 235/255, 0.35)
                                border.color: Qt.rgba(175/255, 135/255, 255/255, 0.70)
                                border.width: 1

                                IconText {
                                    anchors.centerIn: parent
                                    text: {
                                        var d = btPanel.connectedDevice ? btPanel.btDeviceFor(btPanel.connectedDevice.mac) : null
                                        var lbl = btPanel.typeLabel(d)
                                        if (lbl === "Headphones" || lbl === "Headset") return IconMap.icon("headphones")
                                        if (lbl === "Mouse") return IconMap.icon("mouse")
                                        if (lbl === "Keyboard") return IconMap.icon("keyboard")
                                        if (lbl === "Phone") return IconMap.icon("smartphone")
                                        return IconMap.icon("bluetooth")
                                    }
                                    color: "#ffffff"
                                    font.pixelSize: 17
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 34 - 10 - 28 - 10
                                spacing: 2

                                UiText {
                                    width: parent.width
                                    text: btPanel.connectedDevice ? btPanel.connectedDevice.name : ""
                                    color: "#ffffff"
                                    font.family: root.mono
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: 4
                                    UiText {
                                        text: I18n.tr("Connected")
                                        color: "#c4a8ff"
                                        font.family: root.mono
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                    UiText {
                                        visible: {
                                            var d = btPanel.connectedDevice ? btPanel.btDeviceFor(btPanel.connectedDevice.mac) : null
                                            return btPanel.batteryText(d) !== ""
                                        }
                                        text: {
                                            var d = btPanel.connectedDevice ? btPanel.btDeviceFor(btPanel.connectedDevice.mac) : null
                                            return "· " + btPanel.batteryText(d)
                                        }
                                        color: Qt.rgba(180/255, 170/255, 210/255, 0.75)
                                        font.family: root.mono
                                        font.pixelSize: 10
                                    }
                                }
                            }

                            // Glowing checkmark badge
                            Rectangle {
                                width: 24; height: 24; radius: 12
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(130/255, 85/255, 235/255, 0.85)
                                border.color: Qt.rgba(175/255, 135/255, 255/255, 0.70)
                                border.width: 1

                                UiText {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "#ffffff"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        // Contextual Drawer (Disconnect / Forget)
                        Item {
                            id: connDrawer
                            width: parent.width
                            visible: btPanel.heroContextMenuOpen
                            implicitHeight: visible ? 28 : 0

                            Row {
                                anchors.fill: parent
                                spacing: 6

                                Rectangle {
                                    width: (parent.width - 6) / 2; height: 28; radius: 6
                                    color: discMa.containsMouse ? Qt.rgba(220/255, 60/255, 80/255, 0.35) : Qt.rgba(40/255, 30/255, 60/255, 0.50)
                                    border.color: discMa.containsMouse ? "#ff6b81" : Qt.rgba(110/255, 90/255, 160/255, 0.30)
                                    border.width: 1
                                    UiText { anchors.centerIn: parent; text: I18n.tr("Disconnect"); color: discMa.containsMouse ? "#ffb3be" : "#ffffff"; font.family: root.mono; font.pixelSize: 10; font.weight: Font.Medium }
                                    MouseArea {
                                        id: discMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { btPanel.activateDevice(btPanel.connectedDevice); btPanel.heroContextMenuOpen = false }
                                    }
                                }

                                Rectangle {
                                    width: (parent.width - 6) / 2; height: 28; radius: 6
                                    color: fgtMa.containsMouse ? Qt.rgba(130/255, 90/255, 230/255, 0.35) : Qt.rgba(40/255, 30/255, 60/255, 0.50)
                                    border.color: fgtMa.containsMouse ? "#c4a8ff" : Qt.rgba(110/255, 90/255, 160/255, 0.30)
                                    border.width: 1
                                    UiText { anchors.centerIn: parent; text: I18n.tr("Forget"); color: "#ffffff"; font.family: root.mono; font.pixelSize: 10; font.weight: Font.Medium }
                                    MouseArea {
                                        id: fgtMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { btPanel.forgetDevice(btPanel.connectedDevice); btPanel.heroContextMenuOpen = false }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: btPanel.heroContextMenuOpen = !btPanel.heroContextMenuOpen
                    }
                }
            }

            // ── 3. AVAILABLE DEVICES HEADER + SCAN ──
            Item {
                width: parent.width
                height: 24
                visible: btPanel.btOn

                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Available Devices")
                    color: Qt.rgba(180/255, 170/255, 210/255, 0.65)
                    font.family: root.mono
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: scanLbl.implicitWidth + 16; height: 22; radius: 11
                    color: scanMa.containsMouse ? Qt.rgba(130/255, 90/255, 230/255, 0.30) : Qt.rgba(36/255, 28/255, 56/255, 0.65)
                    border.color: (btPanel.scanning || scanMa.containsMouse) ? Qt.rgba(165/255, 125/255, 250/255, 0.65) : Qt.rgba(140/255, 100/255, 230/255, 0.35)
                    border.width: 1

                    Row {
                        id: scanLbl
                        anchors.centerIn: parent
                        spacing: 4
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⟳"
                            color: btPanel.scanning ? "#c4a8ff" : "#ffffff"
                            font.pixelSize: 12
                            transformOrigin: Item.Center
                            NumberAnimation on rotation {
                                running: btPanel.scanning
                                from: 0; to: 360; duration: 900
                                loops: Animation.Infinite
                            }
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: btPanel.scanning ? I18n.tr("Scanning") : I18n.tr("Scan")
                            color: btPanel.scanning ? "#c4a8ff" : "#ffffff"
                            font.family: root.mono
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: scanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !btPanel.scanning
                        onClicked: { scanProc.running = false; scanProc.running = true }
                    }
                }
            }

            // ── 4. AVAILABLE DEVICES LIST ──
            Column {
                width: parent.width
                spacing: 4
                visible: btPanel.btOn

                Repeater {
                    model: btPanel.availableDevices.slice(0, 7)
                    delegate: Rectangle {
                        id: devTile
                        required property var modelData
                        readonly property bool isSelected: btPanel.selectedDeviceMac === modelData.mac
                        readonly property bool hovered: tileMa.containsMouse
                        readonly property var nativeDev: btPanel.btDeviceFor(modelData.mac)
                        width: parent.width
                        implicitHeight: devCol.implicitHeight + (isSelected ? actDrawer.implicitHeight + 8 : 0) + 12
                        radius: 8
                        color: hovered ? Qt.rgba(130/255, 90/255, 230/255, 0.20) : Qt.rgba(24/255, 18/255, 40/255, 0.50)
                        border.color: isSelected ? Qt.rgba(145/255, 105/255, 240/255, 0.50)
                                      : hovered ? Qt.rgba(130/255, 90/255, 230/255, 0.35)
                                      : Qt.rgba(95/255, 75/255, 150/255, 0.20)
                        border.width: 1
                        clip: true

                        Column {
                            id: devCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 6

                            Row {
                                width: parent.width
                                spacing: 8

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        var lbl = btPanel.typeLabel(devTile.nativeDev)
                                        if (lbl === "Headphones" || lbl === "Headset") return IconMap.icon("headphones")
                                        if (lbl === "Mouse") return IconMap.icon("mouse")
                                        if (lbl === "Keyboard") return IconMap.icon("keyboard")
                                        if (lbl === "Phone") return IconMap.icon("smartphone")
                                        return IconMap.icon("bluetooth")
                                    }
                                    color: "#c4a8ff"
                                    font.pixelSize: 15
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 15 - 8 - 14 - 8
                                    spacing: 1

                                    UiText {
                                        width: parent.width
                                        text: devTile.modelData.name
                                        color: "#ffffff"
                                        font.family: root.mono
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }

                                    UiText {
                                        width: parent.width
                                        text: devTile.modelData.paired ? I18n.tr("Paired") : String(devTile.modelData.mac || "")
                                        color: Qt.rgba(180/255, 170/255, 210/255, 0.50)
                                        font.family: root.mono
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }

                                UiText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "›"
                                    color: Qt.rgba(180/255, 170/255, 210/255, 0.40)
                                    font.pixelSize: 14
                                }
                            }

                            Item {
                                id: actDrawer
                                width: parent.width
                                visible: devTile.isSelected
                                implicitHeight: visible ? 26 : 0

                                Row {
                                    anchors.fill: parent
                                    spacing: 6

                                    Rectangle {
                                        width: devTile.modelData.paired ? (parent.width - 6) / 2 : parent.width; height: 26; radius: 6
                                        color: Qt.rgba(130/255, 85/255, 235/255, 0.85)
                                        border.color: Qt.rgba(175/255, 135/255, 255/255, 0.70)
                                        border.width: 1
                                        UiText { anchors.centerIn: parent; text: devTile.modelData.paired ? I18n.tr("Connect") : I18n.tr("Pair & Connect"); color: "#ffffff"; font.family: root.mono; font.pixelSize: 10; font.weight: Font.DemiBold }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: btPanel.activateDevice(devTile.modelData)
                                        }
                                    }

                                    Rectangle {
                                        visible: devTile.modelData.paired
                                        width: (parent.width - 6) / 2; height: 26; radius: 6
                                        color: Qt.rgba(40/255, 30/255, 60/255, 0.50)
                                        border.color: Qt.rgba(110/255, 90/255, 160/255, 0.30)
                                        border.width: 1
                                        UiText { anchors.centerIn: parent; text: I18n.tr("Forget"); color: "#ffffff"; font.family: root.mono; font.pixelSize: 10 }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: btPanel.forgetDevice(devTile.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: tileMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (btPanel.selectedDeviceMac === devTile.modelData.mac)
                                    btPanel.selectedDeviceMac = ""
                                else
                                    btPanel.selectedDeviceMac = devTile.modelData.mac
                            }
                        }
                    }
                }

                UiText {
                    visible: btPanel.btOn && btPanel.availableDevices.length === 0
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: btPanel.scanning ? I18n.tr("Searching for devices…") : I18n.tr("No nearby devices found")
                    color: Qt.rgba(180/255, 170/255, 210/255, 0.40)
                    font.family: root.mono; font.pixelSize: 11
                    topPadding: 6; bottomPadding: 6
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(140/255, 120/255, 200/255, 0.15) }

            // ── 5. SETTINGS FOOTER ──
            Rectangle {
                width: parent.width
                height: 32; radius: 8
                color: btSetMa.containsMouse ? Qt.rgba(130/255, 90/255, 230/255, 0.30) : Qt.rgba(36/255, 28/255, 56/255, 0.65)
                border.color: btSetMa.containsMouse ? Qt.rgba(165/255, 125/255, 250/255, 0.65) : Qt.rgba(140/255, 100/255, 230/255, 0.35)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText { anchors.verticalCenter: parent.verticalCenter; text: IconMap.icon("settings"); color: "#ffffff"; font.pixelSize: 14 }
                    UiText { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Bluetooth settings"); color: "#ffffff"; font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium }
                }
                MouseArea {
                    id: btSetMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.bluetoothVisible = false; btRunner.running = false; btRunner.running = true }
                }
            }
        }
    }

    // ── data: power state + device list with connected/paired flags ──
    Process {
        id: btData
        command: ["bash", "-c",
            "if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then " +
            "  echo ON; " +
            "  conn=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'); " +
            "  paired=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}'); " +
            "  bluetoothctl devices 2>/dev/null | while read -r _ mac rest; do " +
            "    c=0; p=0; " +
            "    printf '%s\\n' \"$conn\"   | grep -qx \"$mac\" && c=1; " +
            "    printf '%s\\n' \"$paired\" | grep -qx \"$mac\" && p=1; " +
            "    echo \"$c|$p|$mac|$rest\"; " +
            "  done; " +
            "else echo OFF; fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                if (lines[0] !== "ON") { btPanel.btOn = false; btPanel.devices = []; return }
                btPanel.btOn = true
                var devs = []
                for (var i = 1; i < lines.length; i++) {
                    var parts = lines[i].split("|")
                    if (parts.length < 4) continue
                    var name = parts.slice(3).join("|").trim()
                    if (!name || name === parts[2]) name = parts[2]   // fall back to mac
                    devs.push({
                        connected: parts[0] === "1",
                        paired:    parts[1] === "1",
                        mac:       parts[2],
                        name:      name
                    })
                }
                // connected first, then paired, then the rest
                devs.sort(function(a, b) {
                    var ra = a.connected ? 0 : a.paired ? 1 : 2
                    var rb = b.connected ? 0 : b.paired ? 1 : 2
                    return ra - rb
                })
                btPanel.devices = devs
            }
        }
    }

    // ── power on/off ──
    Process {
        id: powerProc
        command: ["bash", "-c", "bluetoothctl power " + (btPanel.btOn ? "off" : "on")]
        running: false
        onExited: btPanel.refresh()
    }

    // ── timed discovery scan ──
    Process {
        id: scanProc
        command: ["bash", "-c", "bluetoothctl --timeout 10 scan on >/dev/null 2>&1"]
        running: false
        onRunningChanged: { btPanel.scanning = running; if (!running) btPanel.refresh() }
    }
    Timer {
        interval: 1500; repeat: true
        running: btPanel.scanning && btPanel.visible
        onTriggered: btPanel.refresh()
    }

    // ── connect / disconnect / pair ──
    Process {
        id: connProc
        command: ["bash", "-c", btPanel.connCmd]
        running: false
        onExited: btPanel.refresh()
    }

    Process { id: btRunner; command: ["bash", "-c", root.launchBtCmd] }

    onVisibleChanged: { if (visible) btPanel.refresh() }
}
