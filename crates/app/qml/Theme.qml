pragma Singleton
import QtQuick

// Design tokens shared by every page. `mode` is "system", "light" or "dark".
QtObject {
    id: root
    property string mode: "system"
    property SystemPalette sys: SystemPalette {}
    readonly property bool dark: mode === "dark" || (mode === "system" && sys.window.hslLightness < 0.5)

    // Surfaces
    readonly property color bg:        dark ? "#12141b" : "#eef0f5"
    readonly property color sidebar:   dark ? "#0d0f15" : "#e3e6ee"
    readonly property color panel:     dark ? "#1a1d27" : "#ffffff"
    readonly property color panelHi:   dark ? "#232735" : "#f1f3f9"
    readonly property color field:     dark ? "#0f1118" : "#f6f7fb"
    readonly property color line:      dark ? "#2a2f3f" : "#dadee9"
    readonly property color lineStrong: dark ? "#3b4156" : "#bcc3d5"

    // Text
    readonly property color text:      dark ? "#e9ebf3" : "#1b1e2a"
    readonly property color dim:       dark ? "#9aa1b8" : "#5f677f"
    readonly property color faint:     dark ? "#6a728a" : "#8a91a7"

    // Accent and states
    readonly property color accent:     dark ? "#7b8cff" : "#4651e6"
    readonly property color accentHi:   dark ? "#9aa8ff" : "#3640cc"
    readonly property color accentSoft: dark ? Qt.rgba(0.48, 0.55, 1, 0.16) : Qt.rgba(0.27, 0.32, 0.9, 0.10)
    readonly property color accentText:   dark ? "#0c1022" : "#ffffff"
    readonly property color ok:         dark ? "#3fd9a0" : "#119e6c"
    readonly property color warn:       dark ? "#f5b94a" : "#b9800f"

    // Keycaps
    readonly property color capAlpha:   dark ? "#363c52" : "#ffffff"
    readonly property color capMod:     dark ? "#2a2f44" : "#dde1ee"
    readonly property color capEdge:    dark ? "#171a26" : "#b4bbd0"
    readonly property color capText:    dark ? "#e6e9f4" : "#252a3a"

    // Metrics
    readonly property int radius: 12
    readonly property int radiusSmall: 8
    readonly property int gap: 16
    readonly property int pad: 20
}
