import QtQuick
import QtQuick.Layouts

// Hue / saturation / brightness sliders (0-255, as the keyboard stores them) with a swatch.
RowLayout {
    id: root
    property int h: 0
    property int s: 255
    property int v: 255
    property bool withValue: true
    readonly property color swatch: Qt.hsva(h / 255, s / 255, v / 255, 1)
    signal edited(int h, int s, int v)
    spacing: 18

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Text { text: "Hue"; color: Theme.dim; font.pixelSize: 12 }
        KSlider {
            Layout.fillWidth: true
            stops: ["#ff0000", "#ffff00", "#00ff00", "#00ffff", "#0000ff", "#ff00ff", "#ff0000"]
            value: root.h
            onMoved: root.edited(Math.round(value), root.s, root.v)
        }
        Text { text: "Saturation"; color: Theme.dim; font.pixelSize: 12 }
        KSlider {
            Layout.fillWidth: true
            stops: ["#ffffff", Qt.hsva(root.h / 255, 1, 1, 1)]
            value: root.s
            onMoved: root.edited(root.h, Math.round(value), root.v)
        }
        Text { visible: root.withValue; text: "Brightness"; color: Theme.dim; font.pixelSize: 12 }
        KSlider {
            visible: root.withValue
            Layout.fillWidth: true
            stops: ["#000000", Qt.hsva(root.h / 255, root.s / 255, 1, 1)]
            value: root.v
            onMoved: root.edited(root.h, root.s, Math.round(value))
        }
    }
    Rectangle {
        Layout.preferredWidth: 72; Layout.preferredHeight: 72; radius: 16
        Layout.alignment: Qt.AlignTop
        color: root.swatch
        border.color: Qt.rgba(1, 1, 1, Theme.dark ? 0.12 : 0.4)
        border.width: 2
        Rectangle { z: -1; anchors.centerIn: parent; width: parent.width + 14; height: width; radius: 22; color: root.swatch; opacity: 0.18 }
    }
}
