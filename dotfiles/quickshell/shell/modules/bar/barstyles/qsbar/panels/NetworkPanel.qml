import QtQuick
import "../modules"
import "../components"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Ryoku.Ui.Singletons
import "../IconMap.js" as IconMap
import shell.services

PanelWindow {
    id: netPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-network"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property string mode:  "none"   // wifi | ethernet | none
    property string ssid:  ""
    property int    signal: 0
    property string iface: ""
    property string ipAddr: ""
    property string freq:  ""

    property string wdev:   ""      // wifi device name (e.g. wlan0)
    property bool   hasWifi: false
    property bool   scanning: false
    property var    networks: []    // [{conn, ssid, sec, sig}]
    property var    known:   []     // known ssids
    property bool   savedOnly: false
    property string selectedNetworkKey: ""
    property string pendingForgetKey: ""
    property int    keyboardIndex: -1
    property bool   heroContextMenuOpen: false
    property bool   heroConfirmForget: false
    readonly property var shownNetworks: networks.filter(function(entry) {
        if (!entry || entry.visible === false) return false
        if (entry.conn || (netPanel.mode === "wifi" && netPanel.ssid !== "" && entry.ssid === netPanel.ssid)) return false
        return true
    })
    readonly property int savedCount: {
        var count = 0
        for (var i = 0; i < networks.length; i++)
            if (networks[i].known === true) count++
        return count
    }

    function networkKey(entry) {
        if (!entry)
            return ""
        return entry.entryKey || "ssid:" + (entry.ssid || "")
    }

    property string nmPasswordSsid: ""
    property string nmPasswordText: ""
    property var    nmPasswordNetwork: null
    property string nmConnectionError: ""
    property bool   nmConnecting: false
    property string networkActionError: ""
    property bool   nmProfilesLoaded: false

    // ── wifi radio ──
    property bool   wifiBlocked: false

    // ── link speed (negotiated connection rate) ──
    property string linkSpeed:   ""

    readonly property bool nmAdapterReady: root.useNM
        && nmAdapter.status === Loader.Ready
        && nmAdapter.item !== null
        && nmAdapter.item.available

    function flagForCountry(code) {
        var value = (code || "").toUpperCase()
        if (!/^[A-Z]{2}$/.test(value)) return ""
        return String.fromCharCode(
            0xD83C, 0xDDE6 + value.charCodeAt(0) - 65,
            0xD83C, 0xDDE6 + value.charCodeAt(1) - 65)
    }

    function formatMbps(value) {
        if (!(value > 0)) return "-"
        return (value >= 100 ? value.toFixed(0) : value.toFixed(1)) + " Mbps"
    }

    function formatPing(value) {
        if (!(value > 0)) return "-"
        return (value < 10 ? value.toFixed(1) : value.toFixed(0)) + " ms"
    }

    function edgeText() {
        if (speedTest.phase === "idle" || speedTest.phase === "cancelled") return "Not tested"
        if (speedTest.phase === "offline") return "Offline"
        if (speedTest.phase === "error" || speedTest.phase === "timeout") return "Unavailable"
        if (speedTest.phase === "latency") return "Locating…"
        var edge = speedTest.edgeCode !== "" ? "Cloudflare · " + speedTest.edgeCode : "Cloudflare Edge"
        var flag = flagForCountry(speedTest.countryCode)
        return edge + (flag !== "" ? " " + flag : "")
    }

    // timestamp captured when a run completes - shown in the green "done" footer
    property string lastTestStamp: ""
    property bool speedTestAttempted: false

    CloudflareSpeedTest {
        id: speedTest
        // live, 2 s-polled source (NetworkWidget → root.networkMode mirror) so a mid-test
        // disconnect flips online→false at once and onOnlineChanged shows "Offline",
        // instead of surfacing later as an XHR error/timeout. netPanel.mode (open-only) stays
        // the source for the panel's detail rows.
        online: root.networkMode !== "none"
    }

    Connections {
        target: speedTest
        function onPhaseChanged() {
            if (speedTest.phase === "success")
                netPanel.lastTestStamp = new Date().toLocaleString(Qt.locale("en_US"), "HH:mm · d MMM")
        }
    }

    // ✓ marks show only on a healthy run (in progress or finished ok) - never on error/cancel/offline
    readonly property bool speedRunOk: speedTest.running || speedTest.phase === "success"
    readonly property bool speedDetailsVisible: speedTestAttempted
        && speedTest.phase !== "idle"
        && speedTest.phase !== "cancelled"

    function toggleWifi() {
        if (nmAdapterReady) {
            nmAdapter.item.toggleWifi()
            return
        }
        if (root.useNM) {
            root.networkVisible = false
            openWifiSettings()
            return
        }

        var wasBlocked = netPanel.wifiBlocked
        rfkillToggle.command = ["bash", "-c", wasBlocked ? "rfkill unblock wifi" : "rfkill block wifi"]
        rfkillToggle.running = false; rfkillToggle.running = true
        netPanel.wifiBlocked = !wasBlocked      // optimistic; rfkillState corrects
        Qt.callLater(function() {
            rfkillState.running = false; rfkillState.running = true
            netData.running = false; netData.running = true
            if (wasBlocked) netPanel.scan()     // just turned ON → look for networks
        })
    }

    function scan() {
        if (nmAdapterReady) {
            nmAdapter.item.scan()
            return
        }
        if (scanning || wifiBlocked || root.useNM) return   // NM fallback: no iwctl scan
        scanning = true
        scanProc.running = false
        scanProc.running = true
        scanWatchdog.restart()        // never stay stuck in "scanning"
    }

    function connectTo(entryOrSsid, sec) {
        if (nmAdapterReady) {
            nmAdapter.item.connectTo(entryOrSsid)
            return
        }

        var ssid = typeof entryOrSsid === "object" && entryOrSsid !== null ? entryOrSsid.ssid : entryOrSsid
        var isKnown = known.indexOf(ssid) >= 0
        if (sec === "open" || isKnown) {
            if (!netPanel.wdev) return
            // argv form (no shell) → a crafted SSID cannot inject commands
            connectProc.command = ["iwctl", "station", netPanel.wdev, "connect", ssid]
            connectProc.running = false
            connectProc.running = true
            // re-scan shortly to reflect new connection
            rescanTimer.restart()
        } else {
            // unknown secured network - needs passphrase → open impala
            root.networkVisible = false
            wifiRunner.running = false
            wifiRunner.running = true
        }
    }

    function activateNetwork(entry) {
        if (!entry)
            return

        networkActionError = ""

        if (entry.conn) {
            if (nmAdapterReady && entry.network)
                entry.network.disconnect()
            else if (wdev !== "") {
                connectProc.command = ["iwctl", "station", wdev, "disconnect"]
                connectProc.running = false
                connectProc.running = true
            }
            rescanTimer.restart()
            return
        }

        connectTo(entry, entry.sec)
    }

    function forgetNetwork(entry) {
        if (!entry || !entry.known)
            return

        cancelForget()
        selectedNetworkKey = ""
        if (nmAdapterReady) {
            nmAdapter.item.forgetNetwork(entry)
            refreshNmNetworks()
        } else {
            forgetProc.command = ["iwctl", "known-networks", entry.ssid, "forget"]
            forgetProc.running = false
            forgetProc.running = true
        }
    }

    function selectNetwork(entry) {
        if (!entry)
            return
        cancelForget()
        var key = networkKey(entry)
        selectedNetworkKey = selectedNetworkKey === key ? "" : key
    }

    function isNeverConnected(entry) {
        return root.useNM && nmProfilesLoaded && entry && entry.known
            && !(Number(entry.lastSuccessful || 0) > 0)
    }

    function protectionLabel(entry) {
        if (!entry)
            return "Unknown"
        if (entry.securityLabel)
            return entry.securityLabel
        switch (entry.sec || "") {
        case "open": return "Open"
        case "psk": return "PSK"
        case "8021x": return "802.1X"
        case "wep": return "WEP"
        case "saved": return "Saved Wi-Fi profile"
        default: return "Unknown"
        }
    }

    function cancelForget() {
        pendingForgetKey = ""
        forgetConfirmTimer.stop()
    }

    function requestForget(entry) {
        if (!entry || !entry.known)
            return
        var key = networkKey(entry)
        if (pendingForgetKey === key) {
            cancelForget()
            forgetNetwork(entry)
            return
        }
        pendingForgetKey = key
        forgetConfirmTimer.restart()
    }

    function resetNetworkSelection() {
        cancelForget()
        selectedNetworkKey = ""
        keyboardIndex = -1
    }

    function ensureKeyboardNetworkVisible() {
        if (keyboardIndex < 0 || keyboardIndex >= networkRepeater.count)
            return
        var item = networkRepeater.itemAt(keyboardIndex)
        if (!item)
            return
        var top = item.y
        var bottom = top + item.height
        if (top < networkFlick.contentY)
            networkFlick.contentY = top
        else if (bottom > networkFlick.contentY + networkFlick.height)
            networkFlick.contentY = Math.min(networkFlick.contentHeight - networkFlick.height,
                                            bottom - networkFlick.height)
    }

    onSavedOnlyChanged: resetNetworkSelection()

    function openWifiSettings() {
        wifiRunner.running = false
        wifiRunner.running = true
    }

    function refreshNmNetworks() {
        if (nmAdapterReady)
            nmAdapter.item.syncNetworks()
    }

    function beginNmPassword(entry) {
        if (!entry || !entry.network)
            return

        nmPasswordSsid = entry.ssid || ""
        nmPasswordNetwork = entry.network
        nmPasswordText = ""
        nmConnectionError = ""
        nmConnecting = false
        nmConnectTimeout.stop()
        Qt.callLater(function() {
            if (nmPasswordInput.visible)
                nmPasswordInput.forceActiveFocus()
        })
    }

    function clearNmPassword() {
        nmPasswordSsid = ""
        nmPasswordText = ""
        nmPasswordNetwork = null
        nmConnectionError = ""
        nmConnecting = false
        nmConnectTimeout.stop()
    }

    function submitNmPassword() {
        if (!nmAdapterReady || !nmPasswordNetwork || nmPasswordText === "" || nmConnecting)
            return

        nmConnectionError = ""
        nmConnecting = true
        nmConnectTimeout.restart()
        nmAdapter.item.connectWithPsk(nmPasswordNetwork, nmPasswordText)
    }

    function handleNmConnected(network) {
        if (!network)
            return

        var name = network.name || ""
        if (name === nmPasswordSsid)
            clearNmPassword()
    }

    function handleNmConnectionFailed(network, reason) {
        if (!network)
            return

        var name = network.name || ""
        if (name !== nmPasswordSsid)
            return

        nmConnecting = false
        nmConnectTimeout.stop()
        nmConnectionError = "Connection failed"
        Qt.callLater(function() {
            if (nmPasswordInput.visible)
                nmPasswordInput.forceActiveFocus()
        })
    }

    property real reveal: root.networkVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.networkVisible ? 160 : 120
            easing.type: root.networkVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.networkVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.networkVisible = false }

    Rectangle {
        id: card
        width: 312
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: netPanel.root
            ownerActive: netPanel.root.networkVisible
            targetX: netPanel.root.networkBarX
            reveal: netPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.networkBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - netPanel.reveal)
            : (barBottom + gap) - 2 * (1 - netPanel.reveal)
        opacity: netPanel.reveal
        focus: root.networkVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (netPanel.heroContextMenuOpen)
                    netPanel.heroContextMenuOpen = false
                else if (netPanel.pendingForgetKey !== "")
                    netPanel.cancelForget()
                else if (netPanel.selectedNetworkKey !== "")
                    netPanel.selectedNetworkKey = ""
                else
                    root.networkVisible = false
                event.accepted = true
                return
            }

            if (netPanel.nmPasswordSsid !== "")
                return

            var entries = netPanel.shownNetworks
            if (entries.length === 0)
                return

            if (event.key === Qt.Key_Down) {
                netPanel.keyboardIndex = (netPanel.keyboardIndex + 1) % entries.length
                Qt.callLater(netPanel.ensureKeyboardNetworkVisible)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                netPanel.keyboardIndex = netPanel.keyboardIndex <= 0
                    ? entries.length - 1 : netPanel.keyboardIndex - 1
                Qt.callLater(netPanel.ensureKeyboardNetworkVisible)
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                if (netPanel.keyboardIndex >= 0)
                    netPanel.selectedNetworkKey = netPanel.networkKey(entries[netPanel.keyboardIndex])
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                netPanel.cancelForget()
                netPanel.selectedNetworkKey = ""
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (netPanel.keyboardIndex >= 0)
                    netPanel.activateNetwork(entries[netPanel.keyboardIndex])
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── 1. HERO / HEADER ──
            Item {
                width: parent.width
                height: 46

                // Glowing Wi-Fi circle glyph on left
                Item {
                    id: heroIconBox
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38

                    Rectangle {
                        anchors.fill: parent
                        radius: 19
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                        border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.28)
                        border.width: 1
                    }

                    IconText {
                        anchors.centerIn: parent
                        text: netPanel.mode === "ethernet" ? IconMap.icon("lan") : IconMap.icon("signal_wifi_4_bar")
                        color: root.seal
                        font.pixelSize: 22
                    }
                }

                // Middle: Network title, SSID, status
                Column {
                    anchors.left: heroIconBox.right
                    anchors.leftMargin: 10
                    anchors.right: heroRightBox.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    UiText {
                        text: I18n.tr("Network")
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }

                    UiText {
                        width: parent.width
                        text: {
                            if (netPanel.mode === "wifi")
                                return netPanel.ssid !== "" ? netPanel.ssid : I18n.tr("Wi-Fi")
                            if (netPanel.mode === "ethernet")
                                return I18n.tr("Wired")
                            return I18n.tr("Not connected")
                        }
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    UiText {
                        text: {
                            if (netPanel.mode === "wifi" || netPanel.mode === "ethernet")
                                return I18n.tr("Connected")
                            return netPanel.hasWifi
                                ? (netPanel.scanning ? I18n.tr("Scanning…") : I18n.tr("Disconnected"))
                                : I18n.tr("No Wi-Fi")
                        }
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                }

                // Right controls: close ✕ at top-right, 5 vertical signal bars at bottom-right
                Item {
                    id: heroRightBox
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 36

                    // Close ✕ button
                    Item {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: -2
                        width: 20
                        height: 20

                        UiText {
                            anchors.centerIn: parent
                            text: "✕"
                            color: closeMa.containsMouse ? root.seal : root.sumi
                            font.pixelSize: 12
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.networkVisible = false
                        }
                    }

                    // 5-bar signal strength indicator
                    Row {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        spacing: 2.5

                        readonly property int activeBars: {
                            if (netPanel.mode === "ethernet") return 5
                            if (netPanel.mode !== "wifi") return 0
                            var sig = netPanel.signal
                            if (sig >= 80) return 5
                            if (sig >= 60) return 4
                            if (sig >= 40) return 3
                            if (sig >= 20) return 2
                            if (sig > 0) return 1
                            return 0
                        }

                        Repeater {
                            model: 5
                            delegate: Rectangle {
                                required property int index
                                width: 3.2
                                height: 6 + index * 3.8
                                radius: 1.6
                                anchors.bottom: parent.bottom
                                color: index < parent.activeBars
                                    ? root.seal
                                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }
                    }
                }

                // Click hero to toggle contextual menu for active connected network
                MouseArea {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: heroRightBox.left
                    enabled: netPanel.mode === "wifi" && netPanel.ssid !== ""
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        netPanel.heroConfirmForget = false
                        netPanel.heroContextMenuOpen = !netPanel.heroContextMenuOpen
                    }
                }
            }

            // ── Connected Wi-Fi Context Menu ──
            Rectangle {
                width: parent.width
                height: netPanel.heroContextMenuOpen ? heroMenuCol.implicitHeight + 12 : 0
                visible: height > 0
                clip: true
                radius: 8
                color: Qt.rgba(0.06, 0.05, 0.10, 0.90)
                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)
                border.width: 1
                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Column {
                    id: heroMenuCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    spacing: 4

                    Row {
                        width: parent.width
                        height: 26
                        spacing: 6

                        // Disconnect
                        Rectangle {
                            width: (parent.width - 6) / 2
                            height: parent.height
                            radius: 6
                            color: discMa.containsMouse ? root.fillHover : root.fillIdle
                            border.color: discMa.containsMouse ? root.seal : root.sep
                            border.width: 1

                            UiText {
                                anchors.centerIn: parent
                                text: I18n.tr("Disconnect")
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: discMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    netPanel.heroContextMenuOpen = false
                                    if (nmAdapterReady && nmAdapter.item.activeNetwork)
                                        nmAdapter.item.activeNetwork.disconnect()
                                    else if (wdev !== "") {
                                        connectProc.command = ["iwctl", "station", wdev, "disconnect"]
                                        connectProc.running = false
                                        connectProc.running = true
                                    }
                                    rescanTimer.restart()
                                }
                            }
                        }

                        // Forget
                        Rectangle {
                            width: (parent.width - 6) / 2
                            height: parent.height
                            radius: 6
                            color: forgetHeroMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : root.fillIdle
                            border.color: forgetHeroMa.containsMouse ? root.seal : root.sep
                            border.width: 1

                            UiText {
                                anchors.centerIn: parent
                                text: netPanel.heroConfirmForget ? I18n.tr("Confirm Forget") : I18n.tr("Forget")
                                color: netPanel.heroConfirmForget ? root.seal : root.ink
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: forgetHeroMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!netPanel.heroConfirmForget) {
                                        netPanel.heroConfirmForget = true
                                        heroForgetTimer.restart()
                                    } else {
                                        netPanel.heroConfirmForget = false
                                        heroForgetTimer.stop()
                                        netPanel.heroContextMenuOpen = false
                                        var curEntry = null
                                        for (var i = 0; i < netPanel.networks.length; i++) {
                                            if (netPanel.networks[i].conn || netPanel.networks[i].ssid === netPanel.ssid) {
                                                curEntry = netPanel.networks[i]
                                                break
                                            }
                                        }
                                        if (curEntry)
                                            netPanel.forgetNetwork(curEntry)
                                        else {
                                            forgetProc.command = ["iwctl", "known-networks", netPanel.ssid, "forget"]
                                            forgetProc.running = false
                                            forgetProc.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) }

            // ── 2. SPEED TEST ──
            Column {
                width: parent.width
                spacing: 4

                Item {
                    width: parent.width
                    height: 24

                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("SPEED TEST")
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        font.weight: Font.Medium
                    }

                    // Start pill button
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: speedBtnRow.implicitWidth + 18
                        height: 22
                        radius: 11
                        color: speedTestMa.containsMouse ? root.fillHover : root.fillIdle
                        border.color: speedTest.running ? root.seal : (speedTestMa.containsMouse ? root.seal : root.sep)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            id: speedBtnRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: IconMap.icon("speed")
                                color: speedTest.running ? root.seal : root.ink
                                font.pixelSize: 11
                            }

                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: speedTest.running ? I18n.tr("Stop") : (speedTest.phase === "success" ? I18n.tr("Retest") : I18n.tr("Start"))
                                color: speedTest.running ? root.seal : root.ink
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: speedTestMa
                            anchors.fill: parent
                            enabled: speedTest.running || netPanel.mode !== "none"
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (speedTest.running) {
                                    speedTest.cancel()
                                    netPanel.speedTestAttempted = false
                                } else {
                                    netPanel.speedTestAttempted = true
                                    speedTest.start()
                                }
                            }
                        }
                    }
                }

                // Inline results row (compact)
                Item {
                    width: parent.width
                    height: netPanel.speedDetailsVisible ? 18 : 0
                    visible: height > 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.fill: parent
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: speedTest.pingMs > 0
                            text: "Ping: " + netPanel.formatPing(speedTest.pingMs)
                            color: root.sumiHi
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: speedTest.downloadMbps > 0
                            text: "↓ " + netPanel.formatMbps(speedTest.downloadMbps)
                            color: root.seal
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: speedTest.uploadMbps > 0
                            text: "↑ " + netPanel.formatMbps(speedTest.uploadMbps)
                            color: root.indigo
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: speedTest.running && speedTest.phase === "latency"
                            text: I18n.tr("Locating…")
                            color: root.sumi
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) }

            // ── 3. DNS PROVIDER ──
            Column {
                id: dnsSection
                width: parent.width
                spacing: 4

                property string pendingProvider: ""
                property int pendingCallId: 0
                property bool customOpen: false
                property string customText: ""
                property string errorText: ""

                readonly property bool busy: pendingCallId !== 0
                readonly property string shownProvider: pendingProvider !== ""
                    ? pendingProvider : Network.dnsProvider

                function customServers() {
                    var text = customText.trim()
                    return text === "" ? [] : text.split(/[\s,]+/).filter(function(value) {
                        return value !== ""
                    })
                }

                function submitProvider(provider, servers) {
                    if (busy) return
                    errorText = ""
                    pendingProvider = provider
                    pendingCallId = Network.setDnsProvider(provider, servers)
                    dnsTimeout.restart()
                }

                function chooseProvider(provider) {
                    if (provider === "custom") {
                        customOpen = !customOpen
                        if (customOpen && customText === "" && Network.dnsProvider === "custom")
                            customText = Network.dnsServers.join(", ")
                        if (customOpen)
                            Qt.callLater(dnsCustomInput.forceActiveFocus)
                        return
                    }
                    customOpen = false
                    submitProvider(provider, [])
                }

                Connections {
                    target: Network
                    function onReplied(id, ok, error) {
                        if (id !== dnsSection.pendingCallId) return
                        dnsTimeout.stop()
                        dnsSection.pendingCallId = 0
                        dnsSection.pendingProvider = ""
                        if (ok) {
                            dnsSection.customOpen = false
                            dnsSection.errorText = ""
                        } else {
                            dnsSection.errorText = error || qsTr("Could not change DNS provider")
                        }
                    }
                }

                Timer {
                    id: dnsTimeout
                    interval: 60000
                    onTriggered: {
                        if (!dnsSection.busy) return
                        dnsSection.pendingCallId = 0
                        dnsSection.pendingProvider = ""
                        dnsSection.errorText = qsTr("DNS change timed out")
                    }
                }

                Item {
                    width: parent.width
                    height: 24

                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("DNS PROVIDER")
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 1
                        font.weight: Font.Medium
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Repeater {
                            model: [
                                { label: "DHCP", value: "dhcp" },
                                { label: "Cloudflare", value: "cloudflare" },
                                { label: "Google", value: "google" },
                                { label: "Custom", value: "custom" }
                            ]

                            delegate: Rectangle {
                                id: dnsChip
                                required property var modelData
                                width: dnsChipTxt.implicitWidth + 12
                                height: 22
                                radius: 11
                                enabled: !dnsSection.busy
                                readonly property bool active: dnsSection.shownProvider === modelData.value
                                color: active ? root.fillActive : (dnsChipMa.containsMouse ? root.fillHover : root.fillIdle)
                                border.color: active ? root.seal : (dnsChipMa.containsMouse ? root.seal : root.sep)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                UiText {
                                    id: dnsChipTxt
                                    anchors.centerIn: parent
                                    text: dnsChip.modelData.label
                                    color: dnsChip.active ? root.seal : root.ink
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    font.weight: dnsChip.active ? Font.Bold : Font.Normal
                                }

                                MouseArea {
                                    id: dnsChipMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: dnsSection.chooseProvider(dnsChip.modelData.value)
                                }
                            }
                        }
                    }
                }

                // Custom DNS input expansion
                Item {
                    width: parent.width
                    height: dnsSection.customOpen ? 28 : 0
                    visible: height > 0
                    clip: true
                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: dnsApplyBtn.left
                        anchors.rightMargin: 4
                        height: 24
                        radius: 6
                        color: root.fillIdle
                        border.color: dnsCustomInput.activeFocus ? root.seal : root.sep
                        border.width: 1

                        TextInput {
                            id: dnsCustomInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            text: dnsSection.customText
                            color: root.ink
                            selectionColor: root.seal
                            selectedTextColor: root.paper
                            font.family: root.mono
                            font.pixelSize: 10
                            clip: true
                            onTextEdited: dnsSection.customText = text
                            onAccepted: dnsSection.submitProvider("custom", dnsSection.customServers())
                        }
                    }

                    Rectangle {
                        id: dnsApplyBtn
                        anchors.right: parent.right
                        width: 44
                        height: 24
                        radius: 6
                        color: dnsApplyMa.containsMouse ? root.fillPrimaryHover : root.seal
                        enabled: !dnsSection.busy && dnsSection.customServers().length > 0

                        UiText {
                            anchors.centerIn: parent
                            text: qsTr("Apply")
                            color: root.paper
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                        MouseArea {
                            id: dnsApplyMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: dnsSection.submitProvider("custom", dnsSection.customServers())
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) }

            // ── Wi-Fi Disabled Alert (if rfkill blocked) ──
            Item {
                width: parent.width
                height: netPanel.wifiBlocked ? 30 : 0
                visible: height > 0
                clip: true

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Wi-Fi is off")
                        color: root.sumi
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                    height: 22
                    radius: 11
                    color: wifiTurnOnMa.containsMouse ? root.fillPrimaryHover : root.seal

                    UiText {
                        anchors.centerIn: parent
                        text: I18n.tr("Turn on")
                        color: root.paper
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: wifiTurnOnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: netPanel.toggleWifi()
                    }
                }
            }

            // ── 4. AVAILABLE NETWORKS HEADER ──
            Item {
                width: parent.width
                height: 24
                visible: !netPanel.wifiBlocked

                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("AVAILABLE NETWORKS")
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    font.weight: Font.Medium
                }

                // Scan pill button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: scanBtnRow.implicitWidth + 16
                    height: 22
                    radius: 11
                    color: scanMa.containsMouse ? root.fillHover : root.fillIdle
                    border.color: scanMa.containsMouse ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        id: scanBtnRow
                        anchors.centerIn: parent
                        spacing: 4

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uE5D5"
                            color: netPanel.scanning ? root.seal : root.ink
                            font.pixelSize: 12
                            RotationAnimator on rotation {
                                running: netPanel.scanning
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1200
                            }
                        }

                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: netPanel.scanning ? I18n.tr("Scanning…") : I18n.tr("Scan")
                            color: netPanel.scanning ? root.seal : root.ink
                            font.family: root.mono
                            font.pixelSize: 10
                        }
                    }

                    MouseArea {
                        id: scanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: netPanel.scan()
                    }
                }
            }

            // ── 5. AVAILABLE NETWORKS LIST ──
            Flickable {
                id: networkFlick
                width: parent.width
                height: Math.min(netList.implicitHeight, 160)
                contentHeight: netList.implicitHeight
                clip: true
                visible: !netPanel.wifiBlocked && (!root.useNM || netPanel.nmAdapterReady)
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: netList
                    width: parent.width
                    spacing: 4

                    Repeater {
                        id: networkRepeater
                        model: netPanel.shownNetworks
                        delegate: Column {
                            id: netTile
                            required property var modelData
                            required property int index
                            width: netList.width
                            spacing: 4
                            readonly property bool expanded: netPanel.selectedNetworkKey === netPanel.networkKey(modelData)
                            readonly property bool keyboardSelected: netPanel.keyboardIndex === index
                            readonly property bool confirmingForget: netPanel.pendingForgetKey === netPanel.networkKey(modelData)

                            Connections {
                                target: root.useNM && modelData.network ? modelData.network : null
                                function onConnectedChanged() {
                                    if (modelData.network && modelData.network.connected)
                                        netPanel.handleNmConnected(modelData.network)
                                    netPanel.refreshNmNetworks()
                                }
                                function onKnownChanged() { netPanel.refreshNmNetworks() }
                                function onStateChangingChanged() { netPanel.refreshNmNetworks() }
                                function onSignalStrengthChanged() { netPanel.refreshNmNetworks() }
                                function onConnectionFailed(reason) {
                                    netPanel.handleNmConnectionFailed(modelData.network, reason)
                                    netPanel.refreshNmNetworks()
                                }
                            }

                            // Clean minimal network row
                            Rectangle {
                                id: netRowCard
                                width: parent.width
                                height: 32
                                radius: 8
                                color: (nma.containsMouse || netTile.expanded || netTile.keyboardSelected)
                                    ? root.fillHover : root.fillIdle
                                border.color: (nma.containsMouse || netTile.expanded || netTile.keyboardSelected)
                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35) : root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: netRowRight.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.sec === "open" ? "\uE898" : "\uE897"
                                        color: root.sumiHi
                                        font.pixelSize: 12
                                    }

                                    UiText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.ssid
                                        color: nma.containsMouse ? root.seal : root.ink
                                        font.family: root.mono
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        width: parent.width - 24
                                    }
                                }

                                Row {
                                    id: netRowRight
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    // 4 signal bars
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Repeater {
                                            model: 4
                                            delegate: Rectangle {
                                                required property int index
                                                width: 2.5
                                                height: 4 + index * 2.8
                                                radius: 1.2
                                                anchors.bottom: parent.bottom
                                                color: index < modelData.sig
                                                    ? (nma.containsMouse ? root.seal : root.ink)
                                                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
                                            }
                                        }
                                    }

                                    // Chevron ›
                                    UiText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "›"
                                        color: nma.containsMouse ? root.seal : root.sumiHi
                                        font.family: root.mono
                                        font.pixelSize: 13
                                    }
                                }

                                MouseArea {
                                    id: nma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: netPanel.keyboardIndex = netTile.index
                                    onClicked: {
                                        if (root.useNM && nmAdapterReady && modelData.sec !== "open" && !modelData.known) {
                                            netPanel.beginNmPassword(modelData)
                                        } else {
                                            netPanel.selectNetwork(modelData)
                                        }
                                    }
                                }
                            }

                            // Contextual Action Drawer on row click
                            Rectangle {
                                width: parent.width
                                height: netTile.expanded ? netActionCol.implicitHeight + 12 : 0
                                visible: height > 0
                                clip: true
                                radius: 8
                                color: Qt.rgba(0.06, 0.05, 0.10, 0.85)
                                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)
                                border.width: 1
                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                Column {
                                    id: netActionCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 6
                                    spacing: 4

                                    Row {
                                        width: parent.width
                                        height: 26
                                        spacing: 6

                                        // Connect button
                                        Rectangle {
                                            width: modelData.known ? (parent.width - 6) / 2 : parent.width
                                            height: parent.height
                                            radius: 6
                                            color: availConnMa.containsMouse ? root.fillHover : root.fillIdle
                                            border.color: availConnMa.containsMouse ? root.seal : root.sep
                                            border.width: 1

                                            UiText {
                                                anchors.centerIn: parent
                                                text: netTile.confirmingForget ? I18n.tr("Cancel") : I18n.tr("Connect")
                                                color: root.ink
                                                font.family: root.mono
                                                font.pixelSize: 10
                                            }
                                            MouseArea {
                                                id: availConnMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (netTile.confirmingForget)
                                                        netPanel.cancelForget()
                                                    else {
                                                        netPanel.selectedNetworkKey = ""
                                                        netPanel.activateNetwork(modelData)
                                                    }
                                                }
                                            }
                                        }

                                        // Forget button (if saved)
                                        Rectangle {
                                            visible: modelData.known
                                            width: (parent.width - 6) / 2
                                            height: parent.height
                                            radius: 6
                                            color: availForgetMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : root.fillIdle
                                            border.color: availForgetMa.containsMouse ? root.seal : root.sep
                                            border.width: 1

                                            UiText {
                                                anchors.centerIn: parent
                                                text: netTile.confirmingForget ? I18n.tr("Confirm") : I18n.tr("Forget")
                                                color: netTile.confirmingForget ? root.seal : root.ink
                                                font.family: root.mono
                                                font.pixelSize: 10
                                            }
                                            MouseArea {
                                                id: availForgetMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: netPanel.requestForget(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    UiText {
                        visible: !netPanel.scanning && netPanel.shownNetworks.length === 0
                        width: netList.width
                        horizontalAlignment: Text.AlignHCenter
                        text: I18n.tr("No networks found")
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                        font.family: root.mono
                        font.pixelSize: 11
                        topPadding: 4
                    }
                    UiText {
                        visible: netPanel.networkActionError !== ""
                        width: netList.width
                        text: netPanel.networkActionError
                        color: root.seal
                        wrapMode: Text.Wrap
                        font.family: root.mono
                        font.pixelSize: 10
                    }
                }
            }

            // ── Inline NM Password Input Prompt ──
            Rectangle {
                width: parent.width
                height: visible ? 88 : 0
                visible: root.useNM && netPanel.nmAdapterReady && netPanel.nmPasswordSsid !== ""
                radius: 8
                color: Qt.rgba(0.06, 0.05, 0.10, 0.85)
                border.color: netPanel.nmConnectionError !== "" ? root.sealRaw : root.seal
                border.width: 1
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    UiText {
                        width: parent.width
                        text: netPanel.nmConnectionError !== ""
                            ? netPanel.nmConnectionError
                            : I18n.tr("Password for ") + netPanel.nmPasswordSsid
                        color: netPanel.nmConnectionError !== "" ? root.sealRaw : root.ink
                        font.family: root.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        width: parent.width
                        height: 24
                        radius: 6
                        color: root.bg
                        border.color: nmPasswordInput.activeFocus ? root.seal : root.sep
                        border.width: 1

                        TextInput {
                            id: nmPasswordInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: netPanel.nmPasswordText
                            echoMode: TextInput.Password
                            color: root.ink
                            selectionColor: root.seal
                            selectedTextColor: root.paper
                            font.family: root.mono
                            font.pixelSize: 11
                            clip: true
                            enabled: !netPanel.nmConnecting
                            onTextChanged: netPanel.nmPasswordText = text
                            Keys.onPressed: function(event) {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    netPanel.submitNmPassword()
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    netPanel.clearNmPassword()
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 22
                        spacing: 6

                        Rectangle {
                            width: (parent.width - 6) / 2
                            height: parent.height
                            radius: 6
                            color: passwordSubmitMa.enabled
                                ? (passwordSubmitMa.containsMouse ? root.fillPrimaryHover : root.seal)
                                : root.fillIdle
                            border.color: passwordSubmitMa.enabled ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: netPanel.nmConnecting ? I18n.tr("connecting…") : I18n.tr("connect")
                                color: passwordSubmitMa.enabled ? root.paper : root.sumi
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: passwordSubmitMa
                                anchors.fill: parent
                                enabled: netPanel.nmPasswordText !== "" && !netPanel.nmConnecting
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: netPanel.submitNmPassword()
                            }
                        }

                        Rectangle {
                            width: (parent.width - 6) / 2
                            height: parent.height
                            radius: 6
                            color: passwordCancelMa.containsMouse ? root.fillHover : root.fillIdle
                            border.color: passwordCancelMa.containsMouse ? root.seal : root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: I18n.tr("cancel")
                                color: passwordCancelMa.containsMouse ? root.seal : root.sumi
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                            MouseArea {
                                id: passwordCancelMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: netPanel.clearNmPassword()
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) }

            // ── 6. NETWORK SETTINGS BUTTON (VIOLET/PURPLE GRADIENT) ──
            Rectangle {
                width: parent.width
                height: 32
                radius: 8
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, netSetMa.containsMouse ? 0.85 : 0.65) }
                    GradientStop { position: 1.0; color: Qt.rgba(root.seal.r * 0.7, root.seal.g * 0.7, root.seal.b * 0.9, netSetMa.containsMouse ? 0.75 : 0.50) }
                }
                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.65)
                border.width: 1
                Behavior on opacity { NumberAnimation { duration: 120 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uE8B8" // settings gear
                        color: "#ffffff"
                        font.pixelSize: 14
                    }

                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Network settings")
                        color: "#ffffff"
                        font.family: root.mono
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: netSetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.networkVisible = false
                        netPanel.openWifiSettings()
                    }
                }
            }
        }
    }

    Loader {
        id: nmAdapter
        active: root.useNM
        source: "NetworkManagerAdapter.qml"
        onLoaded: {
            item.panel = netPanel
            item.panelOpen = Qt.binding(function() { return root.networkVisible })
            item.refresh()
        }
    }

    Process {
        id: netData
        command: ["bash", "-c",
            "IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1); exit}}'); " +
            "if [ -z \"$IFACE\" ]; then echo NONE; exit; fi; " +
            "IPADDR=$(ip -o -4 addr show dev \"$IFACE\" 2>/dev/null | awk '{split($4,a,\"/\"); print a[1]; exit}'); " +
            "if [ -d \"/sys/class/net/$IFACE/wireless\" ]; then " +
            "  LINK=$(iw dev \"$IFACE\" link 2>/dev/null); " +
            "  SSID=$(printf '%s\\n' \"$LINK\" | sed -n 's/^\\s*SSID: //p' | head -1); " +
            "  if [[ \"$SSID\" =~ \\\\(x[0-9A-Fa-f]{2}|[0-7]{3}) ]]; then SSID=$(printf '%b' \"$SSID\"); fi; " +
            "  SIG=$(printf '%s\\n' \"$LINK\" | awk '/signal:/ {print int($2); exit}'); " +
            "  FRQ=$(printf '%s\\n' \"$LINK\" | awk '/freq:/ {print $2 \" MHz\"; exit}'); " +
            "  QUAL=$(awk -v s=\"$SIG\" 'BEGIN{q=int((s+110)*100/70);if(q<0)q=0;if(q>100)q=100;print q}'); " +
            "  printf 'WIFI\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$SSID\" \"$QUAL\" \"$IFACE\" \"$IPADDR\" \"$FRQ\"; " +
            "else printf 'ETHERNET\\t%s\\t%s\\n' \"$IFACE\" \"$IPADDR\"; fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                if (parts[0] === "WIFI") {
                    netPanel.mode = "wifi"; netPanel.ssid = parts[1] || ""
                    netPanel.signal = parseInt(parts[2]) || 0; netPanel.iface = parts[3] || ""
                    netPanel.ipAddr = parts[4] || ""; netPanel.freq = parts[5] || ""
                } else if (parts[0] === "ETHERNET") {
                    netPanel.mode = "ethernet"; netPanel.iface = parts[1] || ""; netPanel.ipAddr = parts[2] || ""
                    netPanel.ssid = ""; netPanel.freq = ""
                } else {
                    netPanel.mode = "none"; netPanel.iface = ""; netPanel.ipAddr = ""; netPanel.ssid = ""
                }
            }
        }
    }

    Process { id: wifiRunner; command: ["bash", "-c", root.launchWifiCmd] }

    // detect wifi device presence
    Process {
        id: devProbe
        command: ["bash", "-c", "for d in /sys/class/net/*/wireless; do [ -e \"$d\" ] || continue; basename \"$(dirname \"$d\")\"; break; done 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var d = this.text.trim()
                netPanel.wdev = d
                netPanel.hasWifi = d !== ""
                if (netPanel.hasWifi) netPanel.scan()
            }
        }
    }

    // scan + list available networks (and known networks)
    Process {
        id: scanProc
        command: ["bash", "-c",
            "DEV=$(for d in /sys/class/net/*/wireless; do [ -e \"$d\" ] || continue; basename \"$(dirname \"$d\")\"; break; done); " +
            "[ -z \"$DEV\" ] && exit; " +
            "iwctl station \"$DEV\" scan >/dev/null 2>&1; sleep 1.5; " +
            "iwctl known-networks list 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g; s/\\r//g' | " +
            "  awk '/^[[:space:]]*-+[[:space:]]*$/ {s++; next} s>=2 && NF>0 { sub(/^[[:space:]]+/,\"\"); sub(/[[:space:]][[:space:]]+.*$/,\"\"); if(length) print \"KNOWN\\t\" $0 }'; " +
            "iwctl station \"$DEV\" get-networks 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g; s/\\r//g' | " +
            "  awk '" +
            "    /^[[:space:]]*-+[[:space:]]*$/ { seps++; next } " +
            "    seps>=2 && NF>0 { " +
            "      line=$0; conn=0; " +
            "      if (line ~ /^[[:space:]]*>/) conn=1; " +
            "      sub(/^[[:space:]]*>?[[:space:]]*/, \"\", line); " +
            "      if (match(line, /[[:space:]]+(open|psk|8021x|wep)[[:space:]]+\\*+[[:space:]]*$/)) { " +
            "        tail=substr(line, RSTART); ssid=substr(line, 1, RSTART-1); " +
            "        gsub(/[[:space:]]+$/, \"\", ssid); " +
            "        n=split(tail, a, /[[:space:]]+/); sec=\"\"; sig=0; " +
            "        for(i=1;i<=n;i++){ if(a[i] ~ /^(open|psk|8021x|wep)$/) sec=a[i]; if(a[i] ~ /^\\*+$/) sig=length(a[i]) } " +
            "        print \"NET\\t\" conn \"\\t\" ssid \"\\t\" sec \"\\t\" sig " +
            "      } " +
            "    }'"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                var nets = [], kn = []
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t")
                    if (p[0] === "KNOWN" && p[1]) {
                        kn.push(p[1].trim())
                    } else if (p[0] === "NET" && p.length >= 5) {
                        nets.push({ conn: p[1] === "1", ssid: p[2], sec: p[3], sig: parseInt(p[4]) || 0, known: false, visible: true })
                    }
                }
                for (var j = 0; j < nets.length; j++)
                    nets[j].known = kn.indexOf(nets[j].ssid) >= 0
                for (var k = 0; k < kn.length; k++) {
                    var found = false
                    for (var n = 0; n < nets.length; n++) {
                        if (nets[n].ssid === kn[k]) {
                            found = true
                            break
                        }
                    }
                    if (!found)
                        nets.push({ conn: false, ssid: kn[k], sec: "saved", sig: 0, known: true, visible: false })
                }
                // connected first, then by signal
                nets.sort(function(a, b) { return (b.conn - a.conn) || (b.sig - a.sig) })
                netPanel.networks = nets
                netPanel.known = kn
                netPanel.scanning = false
                scanWatchdog.stop()
            }
        }
    }

    Process { id: connectProc; command: ["bash", "-c", "true"] }
    Process {
        id: forgetProc
        command: ["true"]
        running: false
        onExited: rescanTimer.restart()
    }

    Timer { id: rescanTimer; interval: 1500; onTriggered: { netData.running = false; netData.running = true; netPanel.scan() } }
    Timer { id: forgetConfirmTimer; interval: 5000; onTriggered: netPanel.pendingForgetKey = "" }
    // safety: if a scan hangs, don't block future rescans forever
    Timer { id: scanWatchdog; interval: 8000; onTriggered: netPanel.scanning = false }
    Timer {
        id: nmConnectTimeout
        interval: 20000
        onTriggered: {
            if (!netPanel.nmConnecting)
                return

            netPanel.nmConnecting = false
            netPanel.nmConnectionError = "Connection timed out"
            Qt.callLater(function() {
                if (nmPasswordInput.visible)
                    nmPasswordInput.forceActiveFocus()
            })
        }
    }

    // ── wifi radio (rfkill) ──
    Process {
        id: rfkillState
        command: ["bash", "-c", "rfkill list wifi 2>/dev/null | grep -qi 'Soft blocked: yes' && echo BLOCKED || echo OK"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: { netPanel.wifiBlocked = this.text.trim() === "BLOCKED" }
        }
    }
    Process { id: rfkillToggle; command: ["bash", "-c", "true"] }

    // negotiated link speed: ethernet from /sys, wifi from iw bitrate
    Process {
        id: speedProc
        command: ["bash", "-c",
            "IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1); exit}}'); " +
            "[ -z \"$IFACE\" ] && exit; " +
            "if [ -d /sys/class/net/$IFACE/wireless ]; then " +
            "  R=$(iw dev \"$IFACE\" link 2>/dev/null | sed -n 's/.*tx bitrate: //p' | awk '{print $1\" \"$2; exit}'); " +
            "  [ -n \"$R\" ] && echo \"W:$R\"; " +
            "else " +
            "  S=$(cat /sys/class/net/$IFACE/speed 2>/dev/null); " +
            "  [ -n \"$S\" ] && echo \"E:$S\"; " +
            "fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()
                if (t.indexOf("E:") === 0) {
                    var mb = parseInt(t.slice(2)) || 0
                    netPanel.linkSpeed = mb >= 1000 ? (mb / 1000).toFixed(1).replace(/\.0$/, "") + " Gbit/s"
                                       : (mb > 0 ? mb + " Mbit/s" : "")
                } else if (t.indexOf("W:") === 0) {
                    netPanel.linkSpeed = t.slice(2)   // already e.g. "866.7 MBit/s"
                } else {
                    netPanel.linkSpeed = ""
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (!root.useNM) {
                rfkillState.running = false; rfkillState.running = true
            } else if (nmAdapterReady) {
                nmAdapter.item.refresh()
            }
            netData.running = false; netData.running = true
            devProbe.running = false; devProbe.running = true
            speedProc.running = false; speedProc.running = true
        } else {
            if (speedTest.running)
                speedTest.cancel()
            speedTestAttempted = false
            clearNmPassword()
            resetNetworkSelection()
        }
    }
}
