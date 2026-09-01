pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import shell.services
import Ryoku.Ui.Singletons

// One OSD window: a minimal borderless floating glass HUD overlay anchored
// to the bottom centre, shown on every monitor. `kind` selects volume, mic,
// or brightness. Click-through, never takes focus.
//
// Antigravity-like fluid floating motion:
// - On appearance: smooth fade in (0 -> 1), scale (96% -> 100%), float upward.
// - On value change: smooth slider & percentage interpolation in place.
// - On exit: gentle float upward, fade out (1 -> 0), slight shrink (100% -> 96%).
PanelWindow {
    id: win

    required property var modelData
    required property string kind
    // Per-monitor UI scale (shell.json displays.ui_scale)
    readonly property real us: Tokens.uiScaleFor(modelData ? modelData.name : "")
    readonly property real osdScale: Config.barStyle === "nacre"
        ? Config.normalizedNacre.osdScale : 1

    // Mon fullscreen detection: suppress OSD when fullscreen app is active
    readonly property bool monFullscreen: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === (modelData ? modelData.name : ""))
                return mons[i].activeWorkspace ? (Fullscreen.byWs[mons[i].activeWorkspace.id] === true) : false;
        return false;
    }

    readonly property bool active: osd.flashing

    screen: modelData
    visible: hud.opacity > 0.001 || osd.flashing
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-osd"

    // Anchored at bottom center with comfortable clearance
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    margins.bottom: 38 * win.osdScale * win.us

    implicitHeight: 64 * win.osdScale * win.us

    // Floating borderless HUD container with fluid physics
    Item {
        id: hud
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: osd.implicitWidth
        height: osd.implicitHeight
        scale: 1.0
        opacity: 0.0

        property real yOffset: 8 * win.us

        transform: [
            Scale {
                origin.x: hud.width / 2
                origin.y: hud.height / 2
                xScale: win.osdScale
                yScale: win.osdScale
            },
            Translate {
                y: hud.yOffset * win.osdScale
            }
        ]

        states: [
            State {
                name: "shown"
                when: win.active
                PropertyChanges {
                    target: hud
                    opacity: 1.0
                    scale: 1.0
                    yOffset: 0.0
                }
            },
            State {
                name: "hidden"
                when: !win.active
                PropertyChanges {
                    target: hud
                    opacity: 0.0
                    scale: 0.96
                    yOffset: -8 * win.us
                }
            }
        ]

        transitions: [
            Transition {
                from: "hidden"
                to: "shown"
                SequentialAnimation {
                    PropertyAction { target: hud; property: "yOffset"; value: 8 * win.us }
                    PropertyAction { target: hud; property: "scale"; value: 0.96 }
                    PropertyAction { target: hud; property: "opacity"; value: 0.0 }
                    ParallelAnimation {
                        NumberAnimation {
                            target: hud
                            properties: "opacity,scale,yOffset"
                            duration: Motion.reduce ? 0 : 200
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            },
            Transition {
                from: "shown"
                to: "hidden"
                ParallelAnimation {
                    NumberAnimation {
                        target: hud
                        property: "opacity"
                        to: 0.0
                        duration: Motion.reduce ? 0 : 200
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: hud
                        property: "scale"
                        to: 0.96
                        duration: Motion.reduce ? 0 : 200
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: hud
                        property: "yOffset"
                        to: -8 * win.us
                        duration: Motion.reduce ? 0 : 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
        ]

        Osd {
            id: osd
            anchors.fill: parent
            kind: win.kind
            us: win.us
            suppressed: false
        }
    }

    // Click-through: OSD is a passive HUD readout, never eats clicks
    mask: Region {}
}
