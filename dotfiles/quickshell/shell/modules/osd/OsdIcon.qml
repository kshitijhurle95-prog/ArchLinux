pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import shell.services

// Animated vector icon for the glass HUD (volume, microphone, brightness).
// Renders crisp white vector shapes with fluid transitions between states:
// - Volume: dynamic sound-wave arcs with volume-change ripple & animated mute slash.
// - Microphone: subtle breathing pulse while active & animated slash when muted.
// - Brightness: 8-point sun with responsive scaling.
Item {
    id: root

    property string kind: "volume"          // "volume" | "mic" | "brightness"
    property real value: 0.0                // 0.0 .. 1.0 (or boosted)
    property bool muted: false
    property bool active: true              // OSD visibility/flashing state
    property real size: 28
    property color color: "#FFFFFF"

    implicitWidth: size
    implicitHeight: size

    readonly property real u: Math.min(width, height) / 24

    readonly property bool isVolume: kind === "volume"
    readonly property bool isMic: kind === "mic"
    readonly property bool isBrightness: kind === "brightness"

    // Volume change ripple animation on active sound waves
    property real rippleFactor: 1.0
    onValueChanged: {
        if (root.active && !root.muted && !Motion.reduce) {
            rippleAnim.restart();
        }
    }

    SequentialAnimation {
        id: rippleAnim
        NumberAnimation {
            target: root
            property: "rippleFactor"
            to: 1.12
            duration: 90
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "rippleFactor"
            to: 1.0
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    // =========================================================================
    // 1. VOLUME SPEAKER ICON
    // =========================================================================
    Item {
        id: volumeContainer
        anchors.fill: parent
        visible: root.isVolume

        property real slashProg: (root.muted || root.value <= 0.005) ? 1.0 : 0.0
        Behavior on slashProg {
            NumberAnimation {
                duration: Motion.reduce ? 0 : 200
                easing.type: Easing.OutCubic
            }
        }

        // Speaker cone body (dims slightly when muted)
        Shape {
            anchors.fill: parent
            scale: root.u
            transformOrigin: Item.TopLeft
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            opacity: root.muted ? 0.75 : 1.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.reduce ? 0 : 180
                    easing.type: Easing.OutCubic
                }
            }

            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                strokeWidth: 0
                PathSvg {
                    path: "M 4 9 V 15 H 8 L 13 19.5 V 4.5 L 8 9 H 4 Z"
                }
            }
        }

        // Sound Waves container (smoothly scales & fades)
        Item {
            anchors.fill: parent
            scale: root.rippleFactor
            transformOrigin: Item.Center

            // Wave 1: Low volume (> 0%)
            Shape {
                id: wave1
                anchors.fill: parent
                scale: root.u * (w1Active ? 1.0 : 0.65)
                transformOrigin: Item.TopLeft
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                opacity: w1Active ? 1.0 : 0.0

                readonly property bool w1Active: !root.muted && root.value > 0.005

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.reduce ? 0 : 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.reduce ? 0 : 180
                        easing.type: Easing.OutCubic
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.color
                    strokeWidth: 2.2
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg {
                        path: "M 15.5 9.5 C 17.2 10.8 17.2 13.2 15.5 14.5"
                    }
                }
            }

            // Wave 2: Medium volume (> 33%)
            Shape {
                id: wave2
                anchors.fill: parent
                scale: root.u * (w2Active ? 1.0 : 0.65)
                transformOrigin: Item.TopLeft
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                opacity: w2Active ? 1.0 : 0.0

                readonly property bool w2Active: !root.muted && root.value > 0.33

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.reduce ? 0 : 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.reduce ? 0 : 180
                        easing.type: Easing.OutCubic
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.color
                    strokeWidth: 2.2
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg {
                        path: "M 18.5 7.5 C 21.2 9.5 21.2 14.5 18.5 16.5"
                    }
                }
            }

            // Wave 3: High volume (> 66%)
            Shape {
                id: wave3
                anchors.fill: parent
                scale: root.u * (w3Active ? 1.0 : 0.65)
                transformOrigin: Item.TopLeft
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                opacity: w3Active ? 1.0 : 0.0

                readonly property bool w3Active: !root.muted && root.value > 0.66

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.reduce ? 0 : 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.reduce ? 0 : 180
                        easing.type: Easing.OutCubic
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.color
                    strokeWidth: 2.2
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg {
                        path: "M 21.5 5.5 C 25.2 8.5 25.2 15.5 21.5 18.5"
                    }
                }
            }
        }

        // Animated Mute Slash for Volume
        Shape {
            anchors.fill: parent
            scale: root.u
            transformOrigin: Item.TopLeft
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            visible: volumeContainer.slashProg > 0.01
            opacity: volumeContainer.slashProg

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                startX: 4.0
                startY: 4.0
                PathLine {
                    x: 4.0 + 16.0 * volumeContainer.slashProg
                    y: 4.0 + 16.0 * volumeContainer.slashProg
                }
            }
        }
    }

    // =========================================================================
    // 2. MICROPHONE ICON
    // =========================================================================
    Item {
        id: micContainer
        anchors.fill: parent
        visible: root.isMic

        property real slashProg: root.muted ? 1.0 : 0.0
        Behavior on slashProg {
            NumberAnimation {
                duration: Motion.reduce ? 0 : 200
                easing.type: Easing.OutCubic
            }
        }

        // Active breathing pulse animation
        property real breathScale: 1.0
        SequentialAnimation {
            id: breathAnim
            running: !root.muted && root.active && !Motion.reduce
            loops: Animation.Infinite
            NumberAnimation {
                target: micContainer
                property: "breathScale"
                to: 1.05
                duration: 950
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: micContainer
                property: "breathScale"
                to: 1.00
                duration: 950
                easing.type: Easing.InOutSine
            }
        }

        onSlashProgChanged: {
            if (root.muted) {
                breathAnim.stop();
                micContainer.breathScale = 1.0;
            }
        }

        // Mic capsule & stand container (scales with breathing & dims on mute)
        Item {
            anchors.fill: parent
            scale: micContainer.breathScale
            transformOrigin: Item.Center
            opacity: root.muted ? 0.75 : 1.0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.reduce ? 0 : 180
                    easing.type: Easing.OutCubic
                }
            }

            Shape {
                anchors.fill: parent
                scale: root.u
                transformOrigin: Item.TopLeft
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.color
                    strokeColor: "transparent"
                    strokeWidth: 0
                    PathSvg {
                        path: "M 12 2.5 A 3 3 0 0 0 9 5.5 V 11.5 A 3 3 0 0 0 15 11.5 V 5.5 A 3 3 0 0 0 12 2.5 Z M 18 11.5 C 18 14.4 15.6 16.8 12.5 17.1 V 19.5 H 15 V 21.5 H 9 V 19.5 H 11.5 V 17.1 C 8.4 16.8 6 14.4 6 11.5 H 8 C 8 13.7 9.8 15.5 12 15.5 C 14.2 15.5 16 13.7 16 11.5 H 18 Z"
                    }
                }
            }
        }

        // Animated Mute Slash for Microphone
        Shape {
            anchors.fill: parent
            scale: root.u
            transformOrigin: Item.TopLeft
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            visible: micContainer.slashProg > 0.01
            opacity: micContainer.slashProg

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                startX: 4.0
                startY: 4.0
                PathLine {
                    x: 4.0 + 16.0 * micContainer.slashProg
                    y: 4.0 + 16.0 * micContainer.slashProg
                }
            }
        }
    }

    // =========================================================================
    // 3. BRIGHTNESS ICON (Sun)
    // =========================================================================
    Item {
        id: brightnessContainer
        anchors.fill: parent
        visible: root.isBrightness
        scale: root.rippleFactor
        transformOrigin: Item.Center

        Shape {
            anchors.fill: parent
            scale: root.u
            transformOrigin: Item.TopLeft
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.color
                strokeColor: "transparent"
                strokeWidth: 0
                // 8-point sun star with circular hole matching reference
                PathSvg {
                    path: "M 12 2 L 14.5 5.5 L 19 4.5 L 18 9 L 22 12 L 18 15 L 19 19.5 L 14.5 18.5 L 12 22 L 9.5 18.5 L 5 19.5 L 6 15 L 2 12 L 6 9 L 5 4.5 L 9.5 5.5 Z M 12 7.2 A 4.8 4.8 0 1 0 12 16.8 A 4.8 4.8 0 1 0 12 7.2 Z"
                }
            }
        }
    }
}
