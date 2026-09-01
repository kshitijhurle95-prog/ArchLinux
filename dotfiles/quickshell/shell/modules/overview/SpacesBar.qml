pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import "Singletons"
import Ryoku.Ui.Singletons

/**
 * macOS-Style Mission Control Spaces Bar (Phase 3 Advanced):
 * - Signature "Grab Window -> Workspace Fan-Out" dynamic expansion during window drag
 * - Shared sliding white glass capsule indicator
 * - Proximity drop-target glow and drop confirmation pulse
 * - Workspace mini-preview popover on hover/linger
 * - Smooth drag-and-drop workspace reordering and hover Space deletion
 */
Item {
    id: root

    property real s: 1
    property var ov: null

    // Signature Fan-Out state
    readonly property bool isExpanded: !!root.ov && root.ov.dragging
    property real cardW: (root.isExpanded ? 164 : 140) * root.s
    property real cardH: (root.isExpanded ? 64 : 56) * root.s
    property real gap: (root.isExpanded ? 16 : 12) * root.s
    property real barHeight: (root.isExpanded ? 70 : 60) * root.s
    readonly property real step: root.cardW + root.gap

    readonly property int deskCount: root.ov ? root.ov.deskList.length : 0
    readonly property real spacesRowWidth: root.deskCount > 0 ? (root.deskCount * root.step - root.gap) : 0

    Behavior on cardW { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
    Behavior on cardH { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
    Behavior on gap { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
    Behavior on barHeight { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

    // Drag-and-Drop state for workspace reordering
    property bool isDraggingWs: false
    property int dragSrcIndex: -1
    property int dragTargetIndex: -1
    property real dragRawX: 0

    implicitWidth: mainRow.implicitWidth
    implicitHeight: root.barHeight

    Item {
        id: mainRow
        anchors.centerIn: parent
        width: allPill.width + root.gap + spacesContainer.width
        height: root.cardH

        Behavior on width { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
        Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

        // ---- Shared Smooth Sliding Active Capsule Indicator ------------------
        readonly property int viewedIndex: {
            if (!root.ov || root.ov.viewAllSpaces) return -1;
            var list = root.ov.deskList;
            for (var i = 0; i < list.length; i++) {
                if (list[i] === root.ov.viewedWsId)
                    return i;
            }
            return -1;
        }

        readonly property real targetIndicatorX: {
            if (!root.ov || root.ov.viewAllSpaces || mainRow.viewedIndex < 0)
                return allPill.x;
            return spacesContainer.x + mainRow.viewedIndex * root.step;
        }

        readonly property real targetIndicatorWidth: {
            if (!root.ov || root.ov.viewAllSpaces || mainRow.viewedIndex < 0)
                return allPill.width;
            return root.cardW;
        }

        Rectangle {
            id: activeSlidingPill
            x: mainRow.targetIndicatorX
            y: 0
            width: mainRow.targetIndicatorWidth
            height: root.cardH
            radius: 28 * root.s
            color: Qt.rgba(1, 1, 1, 0.94)
            z: 2

            Behavior on x { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
            Behavior on width { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

            // Inner top highlight on the active pill
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.leftMargin: 14 * root.s
                anchors.rightMargin: 14 * root.s
                height: 1
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.50)
            }
        }

        // ---- "ALL SPACES" Pill Button ---------------------------------------
        Item {
            id: allPill
            x: 0
            y: 0
            width: (root.isExpanded ? 150 : 140) * root.s
            height: root.cardH
            z: 10

            Behavior on width { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

            readonly property bool isSelected: !!root.ov && root.ov.viewAllSpaces
            readonly property bool isHovered: allPillMa.containsMouse
            readonly property bool dropHot: !!root.ov && root.ov.dragging && root.ov.dragTargetWs === (root.ov.viewedWsId || 1)

            scale: allPillMa.pressed ? 0.97 : ((allPill.dropHot || allPill.isHovered) ? 1.03 : 1.0)
            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeExpo } }

            Rectangle {
                id: allPillGlass
                anchors.fill: parent
                radius: 28 * root.s
                color: allPill.isSelected ? "transparent"
                    : ((allPill.dropHot || allPill.isHovered) ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(0, 0, 0, 0.10))
                border.width: allPill.dropHot ? 2 : 0
                border.color: allPill.dropHot ? Theme.brand : "transparent"

                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Rectangle {
                    visible: !allPill.isSelected
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.leftMargin: 12 * root.s
                    anchors.rightMargin: 12 * root.s
                    height: 1
                    radius: 1
                    color: Qt.rgba(1, 1, 1, 0.05)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2 * root.s

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("ALL SPACES")
                        color: allPill.isSelected ? "#000000" : "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8 * root.s
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            var n = root.ov ? root.ov.totalWindowCount : 0;
                            return n + " " + (n === 1 ? I18n.tr("Window") : I18n.tr("Windows"));
                        }
                        color: allPill.isSelected ? Qt.rgba(0, 0, 0, 0.65) : Qt.rgba(255, 255, 255, 0.55)
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Normal
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }
                }
            }

            MouseArea {
                id: allPillMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.ov) root.ov.setViewAllSpaces(true)
            }
        }

        // ---- Desktop Spaces Container ----------------------------------------
        Item {
            id: spacesContainer
            x: allPill.width + root.gap
            y: 0
            width: root.spacesRowWidth
            height: root.cardH
            z: 10

            Behavior on x { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
            Behavior on width { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
            Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

            Repeater {
                model: root.ov ? root.ov.deskList : []
                delegate: Item {
                    id: dcard
                    required property var modelData
                    required property int index
                    readonly property int wsId: dcard.modelData
                    readonly property int winCount: root.ov ? root.ov.deskWinCount(dcard.wsId) : 0
                    readonly property bool isViewed: !root.ov.viewAllSpaces && root.ov.viewedWsId === dcard.wsId
                    readonly property bool activeD: !!root.ov && root.ov.activeWsId === dcard.wsId
                    readonly property bool dropHot: !!root.ov && root.ov.dragging && root.ov.dragTargetWs === dcard.wsId
                    readonly property bool isThisDragging: root.isDraggingWs && root.dragSrcIndex === dcard.index
                    property bool hovered: false
                    property bool dropPulse: false

                    // Connections for drop pulse animation
                    Connections {
                        target: root.ov
                        ignoreUnknownSignals: true
                        function onDropConfirmed(targetWs) {
                            if (targetWs === dcard.wsId) {
                                dcard.dropPulse = true;
                                pulseTimer.restart();
                            }
                        }
                    }

                    Timer {
                        id: pulseTimer
                        interval: 260
                        onTriggered: dcard.dropPulse = false
                    }

                    readonly property real baseX: dcard.index * root.step
                    readonly property real computedX: {
                        if (!root.isDraggingWs)
                            return dcard.baseX;
                        if (dcard.isThisDragging)
                            return root.dragRawX;
                        if (root.dragSrcIndex < root.dragTargetIndex) {
                            if (dcard.index > root.dragSrcIndex && dcard.index <= root.dragTargetIndex)
                                return dcard.baseX - root.step;
                        } else if (root.dragSrcIndex > root.dragTargetIndex) {
                            if (dcard.index >= root.dragTargetIndex && dcard.index < root.dragSrcIndex)
                                return dcard.baseX + root.step;
                        }
                        return dcard.baseX;
                    }

                    x: dcard.computedX
                    y: dcard.dropHot ? -3 * root.s : 0
                    width: root.cardW
                    height: root.cardH
                    z: dcard.isThisDragging ? 100 : (dcard.dropHot ? 60 : (10 - dcard.index))
                    scale: dcard.isThisDragging ? 1.08 : (dcard.dropPulse ? 1.08 : (cardMa.pressed ? 0.97 : ((dcard.dropHot || dcard.hovered) ? 1.04 : 1.0)))
                    opacity: (root.isDraggingWs && !dcard.isThisDragging) ? 0.92 : 1.0

                    Behavior on x {
                        enabled: !dcard.isThisDragging
                        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo }
                    }
                    Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeExpo } }
                    Behavior on width { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
                    Behavior on height { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
                    Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeExpo } }
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                    Rectangle {
                        id: cardFace
                        anchors.fill: parent
                        radius: 28 * root.s

                        color: dcard.isViewed ? "transparent"
                            : (dcard.isThisDragging ? Qt.rgba(1, 1, 1, 0.92)
                            : (dcard.dropHot ? Qt.rgba(226/255, 52/255, 42/255, 0.22)
                            : (dcard.hovered ? Qt.rgba(0, 0, 0, 0.20)
                            : Qt.rgba(0, 0, 0, 0.10))))

                        border.width: dcard.dropHot ? 2 : (dcard.hovered ? 1 : 0)
                        border.color: dcard.dropHot ? Theme.brand : (dcard.hovered ? Qt.rgba(1, 1, 1, 0.20) : "transparent")

                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                        Rectangle {
                            visible: !dcard.isViewed && !dcard.isThisDragging
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.topMargin: 1
                            anchors.leftMargin: 12 * root.s
                            anchors.rightMargin: 12 * root.s
                            height: 1
                            radius: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 2 * root.s

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4 * root.s

                                Text {
                                    text: I18n.tr("SPACE ") + dcard.wsId
                                    color: (dcard.isViewed || dcard.isThisDragging) ? "#000000" : "#ffffff"
                                    font.family: Theme.font
                                    font.pixelSize: 12 * root.s
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.8 * root.s
                                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                                }

                                // Active workspace green dot indicator
                                Rectangle {
                                    visible: dcard.activeD
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 7 * root.s
                                    height: 7 * root.s
                                    radius: width / 2
                                    color: (dcard.isViewed || dcard.isThisDragging) ? "#009900" : "#39FF14"
                                }
                            }

                            // Window count / Drop hint
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: dcard.dropHot ? I18n.tr("Drop Here")
                                    : (dcard.winCount > 0 ? (dcard.winCount + " " + (dcard.winCount === 1 ? I18n.tr("Window") : I18n.tr("Windows"))) : I18n.tr("Empty"))
                                color: (dcard.isViewed || dcard.isThisDragging) ? Qt.rgba(0, 0, 0, 0.65)
                                    : (dcard.dropHot ? Theme.brand : (dcard.winCount > 0 ? Qt.rgba(255, 255, 255, 0.65) : Qt.rgba(255, 255, 255, 0.30)))
                                font.family: Theme.font
                                font.pixelSize: 10 * root.s
                                font.weight: dcard.dropHot ? Font.Bold : Font.Normal
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                        }

                        // Remove Space Close Button (✕) on hover
                        Rectangle {
                            id: removeSpaceBtn
                            visible: (dcard.hovered || removeMa.containsMouse) && root.deskCount > 1 && !root.isDraggingWs && !root.ov.dragging
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: 5 * root.s
                            anchors.rightMargin: 7 * root.s
                            width: 17 * root.s
                            height: 17 * root.s
                            radius: width / 2
                            z: 60
                            color: removeMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.90) : (dcard.isViewed ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(0, 0, 0, 0.45))
                            border.width: 0

                            Behavior on color { ColorAnimation { duration: Motion.fast } }

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: (removeMa.containsMouse || !dcard.isViewed) ? "#ffffff" : "#000000"
                                font.family: Theme.font
                                font.pixelSize: 8.5 * root.s
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                id: removeMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: {
                                    if (root.ov) {
                                        root.ov.removeSpace(dcard.wsId);
                                    }
                                }
                            }
                        }

                        // Workspace Mini App Preview Popover (Appears on hover or linger during drag)
                        Rectangle {
                            id: miniPreviewPopover
                            readonly property var iconList: root.ov ? root.ov.deskWinIcons(dcard.wsId) : []
                            visible: !root.isDraggingWs && (dcard.hovered || dcard.dropHot) && iconList.length > 0 && !dcard.isViewed
                            anchors.top: parent.bottom
                            anchors.topMargin: 8 * root.s
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.max(60 * root.s, miniRow.implicitWidth + 16 * root.s)
                            height: 28 * root.s
                            radius: 14 * root.s
                            color: Qt.rgba(0.08, 0.08, 0.12, 0.94)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.15)
                            z: 90
                            opacity: visible ? 1.0 : 0.0
                            scale: visible ? 1.0 : 0.90

                            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeExpo } }

                            Row {
                                id: miniRow
                                anchors.centerIn: parent
                                spacing: 6 * root.s

                                Repeater {
                                    model: miniPreviewPopover.iconList.slice(0, 5)
                                    delegate: IconImage {
                                        required property var modelData
                                        implicitSize: 15 * root.s
                                        source: modelData
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cardMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onEntered: dcard.hovered = true
                            onExited: dcard.hovered = false

                            property real startX: 0
                            property bool pressedDown: false

                            onPressed: (m) => {
                                if (m.button === Qt.LeftButton) {
                                    cardMa.pressedDown = true;
                                    cardMa.startX = m.x;
                                }
                            }

                            onPositionChanged: (m) => {
                                if (!cardMa.pressedDown || (root.ov && root.ov.dragging)) return;
                                if (!root.isDraggingWs) {
                                    if (Math.abs(m.x - cardMa.startX) < 6 * root.s)
                                        return;
                                    root.isDraggingWs = true;
                                    root.dragSrcIndex = dcard.index;
                                    root.dragTargetIndex = dcard.index;
                                }
                                var mapped = cardMa.mapToItem(spacesContainer, m.x, m.y);
                                var targetX = mapped.x - cardMa.startX;
                                root.dragRawX = Math.max(0, Math.min(root.spacesRowWidth - root.cardW, targetX));

                                var cardCenterX = root.dragRawX + root.cardW / 2;
                                var targetSlot = Math.max(0, Math.min(root.deskCount - 1, Math.floor(cardCenterX / root.step)));
                                root.dragTargetIndex = targetSlot;
                            }

                            onReleased: {
                                if (root.isDraggingWs) {
                                    if (root.dragTargetIndex !== -1 && root.dragTargetIndex !== root.dragSrcIndex && root.ov) {
                                        var list = root.ov.deskList.slice();
                                        var movedItem = list.splice(root.dragSrcIndex, 1)[0];
                                        list.splice(root.dragTargetIndex, 0, movedItem);
                                        root.ov.reorderWorkspaces(list);
                                    }
                                    root.isDraggingWs = false;
                                    root.dragSrcIndex = -1;
                                    root.dragTargetIndex = -1;
                                } else if (cardMa.pressedDown && !(root.ov && root.ov.dragging)) {
                                    if (root.ov) {
                                        root.ov.setViewAllSpaces(false);
                                        root.ov.switchToWs(dcard.wsId);
                                    }
                                }
                                cardMa.pressedDown = false;
                            }

                            onCanceled: {
                                root.isDraggingWs = false;
                                root.dragSrcIndex = -1;
                                root.dragTargetIndex = -1;
                                cardMa.pressedDown = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
