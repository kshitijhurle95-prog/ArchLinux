pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * The live palette, mirrored for the overview surface the same way the
 * pill and launcher mirror it (each qs config has its own singleton root).
 */
Singleton {
    readonly property color base:     shade(adapter.background)
    readonly property color elevated: tone(base, 0.05)
    readonly property color deep:     tone(base, -0.03)
    readonly property color line:     tone(base, 0.14)
    readonly property color accent:   legible(vivid(adapter.color4), elevated, 3.0)
    readonly property color accent2:  "#39FF14"
    readonly property color onSurface: Qt.rgba(1, 1, 1, 0.95)
    readonly property color onSurfaceVariant: Qt.rgba(1, 1, 1, 0.70)

    function shade(c) {
        if (!c) return Qt.rgba(0.08, 0.08, 0.10, 1);
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var s = Math.min(c.hsvSaturation, 0.55);
        var v = c.hsvValue;
        if (v < 0.08)      v = 0.08;
        else if (v > 0.26) v = 0.26 + (v - 0.26) * 0.06;
        return Qt.hsva(hue, s, v, 1);
    }

    function relLum(c) {
        function lin(u) { return u <= 0.04045 ? u / 12.92 : Math.pow((u + 0.055) / 1.055, 2.4); }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }
    function contrast(a, b) {
        var la = relLum(a), lb = relLum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    function legible(fg, bg, target) {
        if (!fg) return Qt.rgba(1, 1, 1, 1);
        var r = fg.r, g = fg.g, b = fg.b;
        for (var i = 0; i < 8; i++) {
            var c = Qt.rgba(r, g, b, 1);
            if (contrast(c, bg) >= target) return c;
            r += (1 - r) * 0.18;
            g += (1 - g) * 0.18;
            b += (1 - b) * 0.18;
        }
        return Qt.rgba(r, g, b, 1);
    }

    function tone(c, dv) {
        if (!c) return Qt.rgba(0.12, 0.12, 0.14, 1);
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        return Qt.hsva(hue, c.hsvSaturation, Math.max(0, Math.min(1, c.hsvValue + dv)), 1);
    }

    function vivid(c) {
        if (!c) return Qt.rgba(0.9, 0.3, 0.2, 1);
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var sat = c.hsvSaturation < 0.06 ? 0 : Math.min(1, c.hsvSaturation * 1.2 + 0.06);
        return Qt.hsva(hue, sat, Math.max(c.hsvValue, 0.74), 1);
    }

    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: adapter
            property color background: "#16110b"
            property color color4: "#e2342a"
        }
    }
}
