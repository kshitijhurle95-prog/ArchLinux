pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

/**
 * macOS Mission Control Stage Surface:
 * Instantiated per screen on WlrLayer.Overlay.
 * Automatically covers underlying desktop windows with zero delay on launch,
 * and executes smooth spatial fluid physics on both launch and dismiss.
 */
Scope {
    id: root

    // The monitor this overview surface draws on, injected per-screen by shell.qml.
    property var screen: null

    // Reveal input the controller binds to this monitor's ShellState.overviewOpen.
    property bool active: false

    // Direct wallpaper socket subscription
    property string wallpaperPath: ""
    property string wallpaperFit: "Cover"
    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    function applyWallpaper(line) {
        try {
            const f = JSON.parse(line);
            root.wallpaperFit = f.fit || "Cover";
            root.wallpaperPath = f.path || "";
        } catch (e) {
        }
    }

    Socket {
        id: wallSub
        path: root.sockPath
        parser: SplitParser {
            onRead: line => root.applyWallpaper(line)
        }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe wallpaper\n");
                flush();
            } else {
                wallRetry.restart();
            }
        }
    }

    Timer {
        id: wallRetry
        interval: 2000
        onTriggered: if (!wallSub.connected) wallSub.connected = true
    }

    // Close request (Esc / click-out).
    signal requestClose()

    Process {
        id: markOverviewInactiveProc
        command: ["rm", "-f", "/tmp/ryoku_overview_active"]
    }

    onActiveChanged: if (root.active) {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    function hide() {
        markOverviewInactiveProc.running = true;
        root.requestClose();
    }

    readonly property string focusedMon: {
        var m = Hyprland.focusedMonitor;
        return m && m.name ? m.name : "";
    }

    PanelWindow {
        id: win
        readonly property real s: Math.min(1.25, (root.screen ? root.screen.height / 1080 : 1)) * Math.max(0.8, Math.min(1.4, Config.fontScale))
        readonly property bool isFocused: !root.focusedMon || root.focusedMon === (root.screen ? root.screen.name : "")
        readonly property bool shown: root.active

        screen: root.screen
        visible: shown || closing.running
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.namespace: "overview"
        WlrLayershell.layer: WlrLayer.Overlay
        // Only the focused monitor grabs the keyboard, so keys never double-fire.
        WlrLayershell.keyboardFocus: (shown && isFocused) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        // Hold the layer mapped through the smooth closing outro
        Timer { id: closing; interval: Motion.window; repeat: false }
        onShownChanged: {
            if (shown) {
                if (isFocused)
                    kb.forceActiveFocus();
            } else {
                markOverviewInactiveProc.running = true;
                closing.restart();
            }
        }

        // Clean wallpaper background: immediately covers on launch, smoothly fades on dismiss
        Image {
            id: bgWallpaper
            anchors.fill: parent
            source: root.wallpaperPath.length > 0 ? ("file://" + root.wallpaperPath) : ""
            cache: true
            asynchronous: false
            sourceSize.width: (root.screen && root.screen.width > 0) ? root.screen.width : 1920
            sourceSize.height: (root.screen && root.screen.height > 0) ? root.screen.height : 1080
            fillMode: {
                switch (root.wallpaperFit) {
                case "Contain": return Image.PreserveAspectFit;
                case "Fill": return Image.Stretch;
                case "ScaleDown":
                    return (sourceSize.width <= width && sourceSize.height <= height)
                        ? Image.Pad : Image.PreserveAspectFit;
                default: return Image.PreserveAspectCrop;
                }
            }
            opacity: win.shown ? 1 : 0
            visible: win.shown || closing.running

            // Smooth fade-out only when closing
            Behavior on opacity {
                enabled: !win.shown
                NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard }
            }
        }

        // Dark dimming scrim over wallpaper for consistent contrast on any wallpaper
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.40)
            opacity: win.shown ? 1 : 0
            visible: win.shown || closing.running

            Behavior on opacity {
                NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard }
            }
        }

        // Click or swipe/scroll down on bare wallpaper to dismiss Mission Control
        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
            onWheel: (wheel) => {
                if (wheel.angleDelta.y < 0 || wheel.pixelDelta.y < 0) {
                    root.hide();
                }
            }
        }

        Overview {
            id: body
            anchors.fill: parent
            s: win.s
            screenName: root.screen ? root.screen.name : ""
            active: win.shown
            dataReady: true
            focusHere: win.isFocused
            onRequestClose: root.hide()

            // Smooth spatial reveal & dismiss transitions
            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 1.03
            y: win.shown ? 0 : 6 * win.s
            Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeExpo } }
            Behavior on scale { NumberAnimation { duration: Motion.window; easing.type: Motion.easeExpo } }
            Behavior on y { NumberAnimation { duration: Motion.window; easing.type: Motion.easeExpo } }
        }

        // Keyboard: only the focused monitor's window handles keys.
        Item {
            id: kb
            anchors.fill: parent
            focus: win.shown && win.isFocused
            Keys.onPressed: (e) => {
                if (!win.isFocused)
                    return;
                var alt = (e.modifiers & Qt.AltModifier) !== 0;
                var shift = (e.modifiers & Qt.ShiftModifier) !== 0;
                var ctrl = (e.modifiers & Qt.ControlModifier) !== 0;

                if (e.key === Qt.Key_Escape) {
                    if (body.dragging) {
                        body.cancelDrag();
                    } else if (body.searchQuery.length > 0) {
                        body.clearSearch();
                    } else {
                        root.hide();
                    }
                    e.accepted = true;
                } else if (alt && (e.key === Qt.Key_Tab || e.key === Qt.Key_Right || e.key === Qt.Key_Backtab || e.key === Qt.Key_Left)) {
                    body.cycleDesktop((shift || e.key === Qt.Key_Backtab || e.key === Qt.Key_Left) ? -1 : 1);
                    e.accepted = true;
                } else if (!alt && !ctrl && e.key >= Qt.Key_1 && e.key <= Qt.Key_9 && body.searchQuery.length === 0) {
                    body.switchToSpaceNumber(e.key - Qt.Key_0);
                    e.accepted = true;
                } else if (!alt && !ctrl && (e.key === Qt.Key_0 || e.key === Qt.Key_AsciiTilde || e.key === Qt.Key_QuoteLeft) && body.searchQuery.length === 0) {
                    body.setViewAllSpaces(!body.viewAllSpaces);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right) {
                    body.cycle(shift ? -1 : 1); e.accepted = true;
                } else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left) {
                    body.cycle(-1); e.accepted = true;
                } else if (e.key === Qt.Key_Down) {
                    body.cycleVertical(1); e.accepted = true;
                } else if (e.key === Qt.Key_Up) {
                    body.cycleVertical(-1); e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    body.activateSelected(); e.accepted = true;
                } else if (e.key === Qt.Key_Backspace) {
                    body.handleBackspace(); e.accepted = true;
                } else if (e.text && e.text.length === 1 && !alt && !ctrl && ((e.key >= Qt.Key_A && e.key <= Qt.Key_Z) || (e.key >= Qt.Key_0 && e.key <= Qt.Key_9) || e.key === Qt.Key_Space)) {
                    body.handleSearchInput(e.text); e.accepted = true;
                }
            }
        }
    }
}
