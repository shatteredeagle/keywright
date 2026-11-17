import QtQuick

// Draws one layer of keys. `keys` is an array of {x,y,w,h,label,color,encoder}.
Item {
    id: root
    property var keys: []
    property real kbWidth: 22.5
    property real kbHeight: 6.25
    property int selected: -1
    property bool interactive: true
    // Optional per-key cap colours (index-aligned with `keys`); empty entries use the theme colour.
    property var fills: []
    property bool showLabels: true
    // Paint mode: press and drag across keys; each key entered reports keyClicked once per stroke.
    property bool paintMode: false
    signal keyClicked(int index)

    readonly property real unit: Math.min(width / kbWidth, height / kbHeight)
    implicitHeight: width / kbWidth * kbHeight

    property var pal
    readonly property bool dark: pal.window.hslLightness < 0.5

    Repeater {
        model: root.keys
        delegate: Rectangle {
            id: cap
            required property var modelData
            required property int index
            readonly property bool mod: modelData.color !== "#aaaaaa"
            readonly property bool isKnob: modelData.encoder !== null && modelData.encoder !== undefined
            x: modelData.x * root.unit
            y: modelData.y * root.unit
            width: modelData.w * root.unit - 3
            height: modelData.h * root.unit - 3
            radius: Math.max(4, root.unit * 0.12)
            readonly property var fill: root.fills.length > index ? root.fills[index] : null
            readonly property color capColor: fill ? fill : base
            color: fill ? (mouse.containsMouse && root.interactive ? Qt.lighter(capColor, 1.1) : capColor)
                 : index === root.selected ? pal.highlight
                 : mouse.containsMouse && root.interactive ? Qt.lighter(base, 1.12)
                 : base
            readonly property color base: root.dark
                ? (mod ? Qt.rgba(0.20, 0.21, 0.24, 1) : Qt.rgba(0.27, 0.28, 0.32, 1))
                : (mod ? Qt.rgba(0.80, 0.81, 0.84, 1) : Qt.rgba(0.93, 0.94, 0.95, 1))
            border.width: index === root.selected && fill ? 3 : 1
            border.color: index === root.selected && fill ? pal.highlight
                        : root.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.16)
            Behavior on color { ColorAnimation { duration: 90 } }

            Text {
                anchors.fill: parent
                anchors.margins: 3
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: cap.isKnob ? (cap.modelData.knobLabel || "⟳") : cap.modelData.label
                elide: Text.ElideRight
                fontSizeMode: Text.Fit
                minimumPixelSize: 7
                font.pixelSize: Math.max(9, root.unit * 0.3)
                color: cap.fill ? (cap.fill.hslLightness > 0.55 ? "#111111" : "#ffffff")
                     : index === root.selected ? pal.highlightedText : pal.windowText
                opacity: !root.showLabels || (cap.modelData.label === "" && !cap.isKnob) ? 0 : 1
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.interactive && !root.paintMode
                cursorShape: Qt.PointingHandCursor
                onClicked: root.keyClicked(cap.index)
            }
        }
    }

    // Drag painting: hit-test the key under the pointer and report each newly entered key.
    MouseArea {
        id: stroke
        anchors.fill: parent
        enabled: root.interactive && root.paintMode
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property int last: -1
        function keyAt(px, py) {
            for (let i = 0; i < root.keys.length; i++) {
                const k = root.keys[i];
                if (px >= k.x * root.unit && px < (k.x + k.w) * root.unit - 3
                    && py >= k.y * root.unit && py < (k.y + k.h) * root.unit - 3) return i;
            }
            return -1;
        }
        function paintAt(px, py) {
            const i = keyAt(px, py);
            if (i >= 0 && i !== last) { last = i; root.keyClicked(i); }
        }
        onPressed: mouse => { last = -1; paintAt(mouse.x, mouse.y); }
        onPositionChanged: mouse => { if (pressed) paintAt(mouse.x, mouse.y); }
        onReleased: last = -1
    }
}
