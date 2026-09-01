pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import shell.services
import "../../components"

// Minimal Borderless Glass HUD OSD (volume, mic, brightness).
// Borderless, translucent glass slider with softly glowing white fill,
// responsive animated vector icon, and clean bright white percentage.
Item {
    id: root

    property string kind: "volume"          // volume | mic | brightness
    property bool suppressed: false
    // Per-monitor UI scale, threaded from the hosting OsdWindow (default 1 = no-op).
    property real us: 1

    readonly property bool isVolume: kind === "volume"
    readonly property bool isMic: kind === "mic"
    readonly property bool isBrightness: kind === "brightness"

    // --- value and mute per kind -------------------------------------------
    readonly property var device: isVolume ? Pipewire.defaultAudioSink
        : isMic ? Pipewire.defaultAudioSource : null
    readonly property var audio: (device && device.audio) ? device.audio : null
    readonly property bool muted: audio ? audio.muted : false

    // With BOOST on, the sink legitimately runs past unity (up to 150%)
    readonly property real maxValue: (isVolume && Config.qsbar
        && Config.qsbar.audioBoost === true) ? 1.5 : 1.0
    readonly property real value: isBrightness
        ? OsdFeed.brightness
        : (audio ? Math.max(0, Math.min(root.maxValue, audio.volume)) : 0)
    readonly property bool over: root.value > 1.005

    // Smoothly interpolate slider fill and percentage readout on value changes
    property real animatedValue: root.value
    Behavior on animatedValue {
        NumberAnimation {
            duration: Motion.reduce ? 0 : 180
            easing.type: Easing.OutCubic
        }
    }

    // --- flash state machine ------------------------------------------------
    property bool flashing: false

    // Startup grace: swallow flashes until a short settle after the source first appears
    property bool armed: false
    readonly property var gateSource: root.isBrightness ? OsdFeed : root.audio
    onGateSourceChanged: if (root.gateSource && !root.armed && !armTimer.running) armTimer.restart()
    Component.onCompleted: if (root.gateSource && !armTimer.running) armTimer.restart()
    Timer { id: armTimer; interval: 700; onTriggered: root.armed = true }

    function flash() {
        if (suppressed || !root.armed)
            return;
        flashing = true;
        hideTimer.restart();
    }

    onSuppressedChanged: if (suppressed) {
        hideTimer.stop();
        flashing = false;
    }

    // The 1000 ms auto-hide hold, restarted on every value change.
    Timer {
        id: hideTimer
        interval: Motion.osdHide
        onTriggered: root.flashing = false
    }

    // Audio triggers: any volume or mute change on the tracked default device.
    PwObjectTracker { objects: root.device ? [root.device] : [] }
    Connections {
        target: root.audio
        function onVolumesChanged() { root.flash(); }
        function onMutedChanged() { root.flash(); }
    }
    // Brightness trigger: the daemon feed bumps its sequence on each change.
    Connections {
        target: root.isBrightness ? OsdFeed : null
        function onBrightnessSeqChanged() { root.flash(); }
    }

    // --- content: animated icon + glass slider + percentage -----------------
    implicitWidth: 280 * root.us
    implicitHeight: 32 * root.us

    // Animated Vector Icon
    OsdIcon {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        kind: root.kind
        value: root.value
        muted: root.muted
        active: root.flashing
        size: 28 * root.us
        color: "#FFFFFF"
    }

    // Glass-like Slider
    Item {
        id: slider
        anchors.left: glyph.right
        anchors.leftMargin: 18 * root.us
        anchors.right: pct.left
        anchors.rightMargin: 18 * root.us
        anchors.verticalCenter: parent.verticalCenter
        height: 6.5 * root.us

        // Background trough: translucent white glass effect with smooth rounded edges
        Rectangle {
            id: track
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.22)
            antialiasing: true
        }

        // Filled section: smoothly interpolates fill width with softly glowing white fill
        Item {
            id: fillSection
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.min(1, root.animatedValue / root.maxValue)) * parent.width
            clip: false
            visible: width > 0.5

            // Soft glowing aura behind filled section
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1.5 * root.us
                radius: (height + 3 * root.us) / 2
                color: Qt.rgba(1, 1, 1, 0.30)
                antialiasing: true
                visible: root.animatedValue > 0.01
            }

            // Crisp solid white fill with rounded ends
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: (root.isVolume && root.over) ? "#ff7b7b" : "#FFFFFF"
                antialiasing: true
            }
        }

        // Over-unity / boost indicator when volume exceeds 100%
        Rectangle {
            x: Math.round(parent.width / root.maxValue) - root.us
            anchors.verticalCenter: parent.verticalCenter
            width: 2 * root.us
            height: parent.height + 4 * root.us
            radius: 1 * root.us
            color: "#FFFFFF"
            opacity: 0.6
            visible: root.maxValue > 1.005
        }
    }

    // Clean, thin, bright white percentage readout
    Text {
        id: pct
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 48 * root.us
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.animatedValue * 100) + "%"
        color: (root.isVolume && root.over) ? "#ff7b7b" : "#FFFFFF"
        font.family: Theme.fontPrimary
        font.weight: Font.Normal
        font.pixelSize: 16 * root.us
        antialiasing: true
    }
}
