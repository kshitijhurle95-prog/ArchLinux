pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "Singletons"
import Ryoku.Ui.Singletons

/**
 * macOS-Style Mission Control Window Card (Border-free with smooth popup hover):
 * - Clean borderless floating card design
 * - Smooth popup hover animation (elevation lift + scale popup + deep soft shadow)
 * - Tactile press and click-smaller activation
 * - Header with App Icon and interactive close button (✕)
 * - Glassmorphic Right-Click Context Menu ("Move to New Space", Focus, Minimize, Fullscreen, Close)
 * - Drag-and-drop integration with dynamic Space Bar expansion
 * - Smooth non-destructive search dimming
 */
Item {
    id: card

    property real s: 1
    property var ov: null
    property var winData: null
    property int idx: 0
    property bool selected: false
    property bool clickedActivating: false
    property bool menuOpen: false

    readonly property string addr: card.winData ? (card.winData.addr || "") : ""
    readonly property var tl: card.winData ? card.winData.tl : null
    readonly property string cls: card.winData ? (card.winData.cls || "") : ""
    readonly property string title: card.winData ? (card.winData.title || card.winData.cls || "Window") : "Window"
    readonly property int wsId: card.winData ? (card.winData.wsId || 1) : 1
    readonly property bool isMinimized: card.winData ? !!card.winData.isMinimized : false
    readonly property bool isFullscreen: card.winData ? !!card.winData.fullscreen : false
    readonly property bool hasCapture: card.tl && card.tl.wayland

    readonly property bool isInitiallyFocused: !!card.ov && card.ov.initFocusedAddr.length > 0 &&
        (card.ov.normAddr(card.ov.initFocusedAddr) === card.ov.normAddr(card.addr))

    readonly property string appIconPath: {
        var c = card.cls;
        if (!c) return "";
        var e = DesktopEntries.heuristicLookup(c);
        var p = (e && e.icon) ? Quickshell.iconPath(e.icon, true) : "";
        if (!p) p = Quickshell.iconPath(c, true);
        return p || "";
    }

    // Dynamic effective window opacity matching Hyprland running window
    readonly property real effectiveOpacity: {
        if (!card.winData) return 1.0;
        if (card.winData.fullscreen || (card.tl && card.tl.fullscreen)) return 1.0;
        var c = (card.cls || "").toLowerCase();
        if (c.match(/^(mpv|vlc|eog|imv|feh|loupe|celluloid|totem|com\.gabm\.satty|satty|looking-glass-client|steam|gamescope)$/)) {
            return 1.0;
        }
        var base = (card.ov && typeof card.ov.compositorActiveOpacity === "number" && card.ov.compositorActiveOpacity > 0)
            ? card.ov.compositorActiveOpacity : 0.85;
        return base;
    }

    // Search query matching state
    readonly property bool matchesSearch: {
        if (!card.ov || !card.ov.searchQuery || card.ov.searchQuery.trim().length === 0)
            return true;
        var q = card.ov.searchQuery.toLowerCase().trim();
        return (card.title.toLowerCase().indexOf(q) !== -1) || (card.cls.toLowerCase().indexOf(q) !== -1);
    }

    // Hover state
    property bool hovered: cardMa.containsMouse || closeMa.containsMouse || menuOpen
    readonly property bool isDraggingThis: !!card.ov && card.ov.dragging && card.ov.dragAddr === card.addr

    // Staggered entrance animation
    property bool appeared: false
    Timer {
        interval: 15 + Math.min(card.idx * 25, 200)
        running: true
        repeat: false
        onTriggered: card.appeared = true
    }

    opacity: (card.appeared && !card.isDraggingThis) ? (card.matchesSearch ? 1.0 : 0.18) : 0.0
    scale: (card.appeared && !card.isDraggingThis)
        ? (card.clickedActivating ? 0.92
        : (cardMa.pressed ? 0.94
        : (card.hovered ? 1.055
        : (card.selected ? 1.02
        : (card.isInitiallyFocused ? 1.015 : (card.matchesSearch ? 1.0 : 0.94))))))
        : 0.85
    z: card.isDraggingThis ? 200 : (card.menuOpen ? 180 : (card.clickedActivating ? 150 : (card.hovered ? 60 : (card.selected ? 20 : 10))))

    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
    Behavior on scale { NumberAnimation { duration: (card.clickedActivating || cardMa.pressed) ? 120 : Motion.standard; easing.type: Motion.easeExpo } }

    // Floating Popup Lift Animation on Hover
    Item {
        id: cardBody
        anchors.fill: parent
        y: (card.hovered && !card.isDraggingThis && !cardMa.pressed) ? -8 * card.s : 0
        Behavior on y { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

        // No background or shadow underlay - completely transparent preview canvas

        // Outer Card Container Frame (Border-free)
        Rectangle {
            id: face
            anchors.fill: parent
            radius: 12 * card.s
            color: "transparent"
            border.width: 0
            border.color: "transparent"
            z: 1

            // Window Title & App Icon Top Bar
            Rectangle {
                id: topBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 28 * card.s
                radius: 12 * card.s
                color: card.hovered ? Qt.rgba(0.12, 0.12, 0.16, 0.96) : Qt.rgba(0.06, 0.06, 0.09, 0.88)

                Behavior on color { ColorAnimation { duration: Motion.fast } }

                // Flat bottom corners for seamless header
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 8 * card.s
                    color: topBar.color
                }

                // Hairline top inner highlight
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.leftMargin: 12 * card.s
                    anchors.rightMargin: 12 * card.s
                    height: 1
                    radius: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10 * card.s
                    anchors.right: closeBtn.left
                    anchors.rightMargin: 8 * card.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * card.s

                    // App Icon (interactive hover scale)
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16 * card.s
                        height: 16 * card.s

                        IconImage {
                            id: appIconImg
                            anchors.centerIn: parent
                            implicitSize: 16 * card.s
                            source: card.appIconPath
                            scale: iconMa.containsMouse ? 1.20 : 1.0
                            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeExpo } }
                        }

                        MouseArea {
                            id: iconMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    // Window Title
                    Text {
                        id: titleText
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width - 24 * card.s - badgesRow.implicitWidth - 30 * card.s)
                        text: card.title
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: 11 * card.s
                        font.weight: Font.DemiBold
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    Row {
                        id: badgesRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4 * card.s

                        // Desktop Space Indicator Pill
                        Rectangle {
                            id: spaceText
                            anchors.verticalCenter: parent.verticalCenter
                            width: spaceLabel.implicitWidth + 10 * card.s
                            height: 16 * card.s
                            radius: 8 * card.s
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border.width: 0

                            Text {
                                id: spaceLabel
                                anchors.centerIn: parent
                                text: I18n.tr("Space ") + card.wsId
                                color: Qt.rgba(255, 255, 255, 0.65)
                                font.family: Theme.font
                                font.pixelSize: 9 * card.s
                                font.weight: Font.Medium
                            }
                        }

                        // Fullscreen Badge
                        Rectangle {
                            visible: card.isFullscreen
                            anchors.verticalCenter: parent.verticalCenter
                            width: fsLabel.implicitWidth + 10 * card.s
                            height: 16 * card.s
                            radius: 8 * card.s
                            color: Qt.rgba(0.2, 0.5, 0.9, 0.45)
                            border.width: 0

                            Text {
                                id: fsLabel
                                anchors.centerIn: parent
                                text: I18n.tr("Fullscreen")
                                color: "#ffffff"
                                font.family: Theme.font
                                font.pixelSize: 8.5 * card.s
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }

                // Interactive Close Button (✕)
                Rectangle {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * card.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18 * card.s
                    height: 18 * card.s
                    radius: width / 2
                    color: closeMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.90) : Qt.rgba(0, 0, 0, 0.35)
                    opacity: (card.hovered || closeMa.containsMouse) ? 1.0 : 0.40
                    border.width: 0

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#ffffff"
                        font.pixelSize: 8.5 * card.s
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (card.ov) card.ov.closeWindow(card.tl, card.addr)
                    }
                }
            }

            // Window Live Screencopy Preview Container
            Item {
                id: previewContainer
                anchors.top: topBar.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2 * card.s
                clip: true

                Rectangle {
                    anchors.fill: parent
                    radius: 8 * card.s
                    color: "transparent"
                }

                // App Icon + Info when minimized or capture is unmapped
                Column {
                    anchors.centerIn: parent
                    spacing: 8 * card.s
                    opacity: (!card.hasCapture || card.isMinimized) ? 0.95 : 0

                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitSize: Math.max(36 * card.s, Math.min(64 * card.s, Math.min(card.width, card.height) * 0.35))
                        source: card.appIconPath
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: card.title
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: 12 * card.s
                        font.weight: Font.DemiBold
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    Text {
                        visible: card.isMinimized
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("Click to restore")
                        color: "#ff9f43"
                        font.family: Theme.font
                        font.pixelSize: 10 * card.s
                        font.weight: Font.Medium
                    }
                }

                // Live Screencopy View (Only for non-minimized active windows)
                ScreencopyView {
                    anchors.fill: parent
                    captureSource: (card.hasCapture && !card.isMinimized) ? card.tl.wayland : null
                    live: !!card.ov && card.ov.active && !card.isMinimized
                    visible: card.hasCapture && !card.isMinimized
                    opacity: card.effectiveOpacity
                }
            }

            // Main Card Mouse Area (Focus / Drag / Right-Click Menu)
            MouseArea {
                id: cardMa
                anchors.fill: parent
                anchors.topMargin: topBar.height
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor

                property real downX: 0
                property real downY: 0
                property bool armed: false
                property int btn: Qt.LeftButton

                onPressed: (m) => {
                    cardMa.btn = m.button;
                    cardMa.armed = (m.button === Qt.LeftButton);
                    cardMa.downX = m.x;
                    cardMa.downY = m.y;
                    if (m.button === Qt.RightButton) {
                        card.menuOpen = !card.menuOpen;
                    }
                }

                onPositionChanged: (m) => {
                    if (!cardMa.armed || !card.ov || card.menuOpen) return;
                    if (!card.ov.dragging) {
                        if (Math.abs(m.x - cardMa.downX) + Math.abs(m.y - cardMa.downY) < 8 * card.s)
                            return;
                        card.ov.dragging = true;
                        card.ov.dragAddr = card.addr;
                        card.ov.dragSrcWs = card.wsId;
                        card.ov.dragTl = card.tl ? card.tl.wayland : null;
                    }
                    var rp = cardMa.mapToItem(card.ov, m.x, m.y);
                    card.ov.updateDrag(rp.x, rp.y);
                }

                onReleased: {
                    if (card.ov && card.ov.dragging) {
                        card.ov.commitDrop();
                        card.ov.endDrag();
                    } else if (cardMa.armed && card.ov && !card.menuOpen) {
                        card.clickedActivating = true;
                        card.ov.focusWindow(card.tl, card.addr, card.isMinimized, card.wsId);
                    }
                    cardMa.armed = false;
                }

                onCanceled: {
                    if (card.ov) card.ov.endDrag();
                    cardMa.armed = false;
                }
            }
        }

        // ---- Glassmorphic Right-Click Context Menu -------------------------------
        Rectangle {
            id: contextMenu
            visible: card.menuOpen
            x: Math.min(card.width - width - 10 * card.s, Math.max(10 * card.s, 20 * card.s))
            y: 34 * card.s
            width: 190 * card.s
            height: menuCol.implicitHeight + 16 * card.s
            radius: 12 * card.s
            color: Qt.rgba(0.08, 0.08, 0.12, 0.96)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.15)
            z: 220
            opacity: card.menuOpen ? 1.0 : 0.0
            scale: card.menuOpen ? 1.0 : 0.92

            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeExpo } }

            Column {
                id: menuCol
                anchors.centerIn: parent
                width: parent.width - 12 * card.s
                spacing: 2 * card.s

                // Focus
                Rectangle {
                    width: parent.width
                    height: 26 * card.s
                    radius: 6 * card.s
                    color: itemMa1.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * card.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * card.s

                        Text { text: "🔍"; font.pixelSize: 10 * card.s; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: I18n.tr("Focus Window"); color: "#ffffff"; font.family: Theme.font; font.pixelSize: 10.5 * card.s; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: itemMa1
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            card.menuOpen = false;
                            if (card.ov) card.ov.focusWindow(card.tl, card.addr, card.isMinimized, card.wsId);
                        }
                    }
                }

                // Move to New Space
                Rectangle {
                    width: parent.width
                    height: 26 * card.s
                    radius: 6 * card.s
                    color: itemMa2.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * card.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * card.s

                        Text { text: "➕"; font.pixelSize: 10 * card.s; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: I18n.tr("Move to New Space"); color: "#ffffff"; font.family: Theme.font; font.pixelSize: 10.5 * card.s; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: itemMa2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            card.menuOpen = false;
                            if (card.ov) card.ov.moveToNewSpace(card.addr);
                        }
                    }
                }

                // Move to Spaces Row
                Rectangle {
                    width: parent.width
                    height: 30 * card.s
                    color: "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * card.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4 * card.s

                        Text {
                            text: I18n.tr("Move:");
                            color: Qt.rgba(255, 255, 255, 0.50)
                            font.family: Theme.font
                            font.pixelSize: 10 * card.s
                        }

                        Repeater {
                            model: card.ov ? card.ov.deskList.slice(0, 4) : []
                            delegate: Rectangle {
                                required property var modelData
                                readonly property int targetWs: modelData
                                visible: targetWs !== card.wsId
                                width: 22 * card.s
                                height: 20 * card.s
                                radius: 4 * card.s
                                color: wsBtnMa.containsMouse ? Theme.brand : Qt.rgba(1, 1, 1, 0.10)

                                Text {
                                    anchors.centerIn: parent
                                    text: "" + targetWs
                                    color: "#ffffff"
                                    font.family: Theme.font
                                    font.pixelSize: 9.5 * card.s
                                    font.weight: Font.Bold
                                }

                                MouseArea {
                                    id: wsBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        card.menuOpen = false;
                                        if (card.ov) card.ov.moveWindow(card.addr, targetWs);
                                    }
                                }
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // Toggle Fullscreen
                Rectangle {
                    width: parent.width
                    height: 26 * card.s
                    radius: 6 * card.s
                    color: itemMa3.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * card.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * card.s

                        Text { text: "⛶"; font.pixelSize: 10 * card.s; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: card.isFullscreen ? I18n.tr("Exit Fullscreen") : I18n.tr("Fullscreen"); color: "#ffffff"; font.family: Theme.font; font.pixelSize: 10.5 * card.s; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: itemMa3
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            card.menuOpen = false;
                            if (card.ov) Hyprland.dispatch("hl.dsp.fullscreen({ window = \"address:" + card.ov.normAddr(card.addr) + "\" })");
                        }
                    }
                }

                // Close
                Rectangle {
                    width: parent.width
                    height: 26 * card.s
                    radius: 6 * card.s
                    color: itemMa4.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.80) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8 * card.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8 * card.s

                        Text { text: "✕"; font.pixelSize: 10 * card.s; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: I18n.tr("Close Window"); color: "#ffffff"; font.family: Theme.font; font.pixelSize: 10.5 * card.s; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: itemMa4
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            card.menuOpen = false;
                            if (card.ov) card.ov.closeWindow(card.tl, card.addr);
                        }
                    }
                }
            }
        }
    }
}
