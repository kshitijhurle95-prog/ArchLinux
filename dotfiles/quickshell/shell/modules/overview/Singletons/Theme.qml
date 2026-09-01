pragma Singleton
import QtQuick
import Quickshell

/**
 * Overview palette + typography singleton.
 */
Singleton {
    readonly property color brand:    (typeof Scheme !== "undefined" && Scheme.accent) ? Scheme.accent : "#e2342a"
    readonly property color vermLit:  Qt.lighter(brand, 1.22)
    readonly property color vermDeep: Qt.darker(brand, 1.3)
    readonly property color gold:     "#39FF14"

    // warm-white text ramp
    readonly property color bright:   "#ffffff"
    readonly property color cream:    Qt.rgba(1, 1, 1, 0.90)
    readonly property color subtle:   Qt.rgba(1, 1, 1, 0.70)
    readonly property color dim:      Qt.rgba(1, 1, 1, 0.50)
    readonly property color faint:    Qt.rgba(1, 1, 1, 0.35)

    // near-black canvas
    readonly property color cardTop:  Qt.rgba(0.08, 0.08, 0.10, 0.90)
    readonly property color cardBot:  Qt.rgba(0.04, 0.04, 0.06, 0.85)
    readonly property color tileBg:   Qt.rgba(0.12, 0.12, 0.16, 0.90)
    readonly property color border:   Qt.rgba(1, 1, 1, 0.10)
    readonly property color hair:     Qt.rgba(1, 1, 1, 0.06)
    readonly property color sheen:    Qt.rgba(1, 1, 1, 0.05)
    readonly property color shadow:   "#000000"

    // accent tints for cell fills / drop targets
    readonly property color frameBg:     Qt.rgba(226/255, 52/255, 42/255, 0.10)
    readonly property color frameBorder: Qt.rgba(243/255, 237/255, 225/255, 0.18)
    readonly property color threadBg:    Qt.rgba(226/255, 52/255, 42/255, 0.13)

    // typography stack
    readonly property string display: "Fraunces"
    readonly property string font:    Config.fontFamily.length > 0 ? Config.fontFamily : "Space Grotesk"
    readonly property string fontJp:  "Noto Sans CJK JP"
    readonly property string mono:    "JetBrainsMono Nerd Font"

    readonly property string mark: Config.markText.length > 0 ? Config.markText : "力"
    readonly property string markSource: Config.markImage
    readonly property bool markTint: Config.markTint
    readonly property string brandName: Config.brandName.length > 0 ? Config.brandName : "Ryoku"
    readonly property int    radius:  0
    readonly property int    shadowStep: 6
}
