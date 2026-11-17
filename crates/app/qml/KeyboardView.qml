import QtQuick

// Draws one layer of keys as tactile caps. `keys` is an array of {x,y,w,h,label,color,encoder,knobLabel}.
Item {
    id: root
    property var keys: []
    property real kbWidth: 22.5
    property real kbHeight: 6.25
    property int selected: -1
    property bool interactive: true
    // Optional per-key cap colours (index-aligned with `keys`); null entries use the theme cap.
    property var fills: []
    property bool showLabels: true
    // Paint mode: press and drag across keys; each key entered reports keyClicked once per stroke.
    property bool paintMode: false
    signal keyClicked(int index)

    readonly property real unit: Math.min(width / kbWidth, height / kbHeight)
    readonly property real gap: Math.max(2, unit * 0.07)
    implicitHeight: width / kbWidth * kbHeight

    Repeater {
        model: root.keys
        delegate: Item {
            id: cap
            required property var modelData
            required property int index
            readonly property bool alpha: modelData.color === "#aaaaaa"
            readonly property bool isKnob: modelData.encoder !== null && modelData.encoder !== undefined
            readonly property var fill: root.fills.length > index ? root.fills[index] : null
            readonly property bool isSel: index === root.selected
            readonly property bool hot: mouse.containsMouse && root.interactive && !root.paintMode
            readonly property color base: fill ? fill : (alpha ? Theme.capAlpha : Theme.capMod)
            readonly property real lift: fill ? 2 : 3
            x: modelData.x * root.unit
            y: modelData.y * root.unit
            width: modelData.w * root.unit - root.gap
            height: modelData.h * root.unit - root.gap

            // Soft glow under lit caps
            Rectangle {
                visible: cap.fill !== null
                anchors.fill: face
                anchors.margins: -3
                radius: face.radius + 3
                color: cap.base
                opacity: 0.22
            }
            Rectangle {
                id: edge
                anchors.fill: parent
                radius: Math.max(4, root.unit * 0.13)
                color: cap.fill ? Qt.darker(cap.base, 1.45) : Theme.capEdge
            }
            Rectangle {
                id: face
                x: 0
                y: cap.isSel || cap.hot ? 0 : 0
                width: parent.width
                height: parent.height - (mouse.pressed ? 1 : cap.lift)
                radius: edge.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(cap.base, cap.fill ? 1.15 : (Theme.dark ? 1.18 : 1.02)) }
                    GradientStop { position: 1.0; color: cap.hot ? Qt.lighter(cap.base, 1.08) : cap.base }
                }
                border.width: cap.isSel ? 2 : 1
                border.color: cap.isSel ? Theme.accent : (Theme.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.08))
                Behavior on height { NumberAnimation { duration: 70 } }

                Text {
                    anchors.fill: parent
                    anchors.margins: 3
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: cap.isKnob ? (cap.modelData.knobLabel || "⟳") : cap.modelData.label
                    elide: Text.ElideRight
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 7
                    font.pixelSize: Math.max(9, root.unit * 0.27)
                    font.weight: Font.Medium
                    lineHeight: 0.95
                    color: cap.fill ? (cap.fill.hslLightness > 0.55 ? "#111111" : "#ffffff") : Theme.capText
                    opacity: !root.showLabels || (cap.modelData.label === "" && !cap.isKnob) ? 0 : 0.92
                }
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
                if (px >= k.x * root.unit && px < (k.x + k.w) * root.unit - root.gap
                    && py >= k.y * root.unit && py < (k.y + k.h) * root.unit - root.gap) return i;
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
