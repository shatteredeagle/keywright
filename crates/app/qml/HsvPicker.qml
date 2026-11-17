import QtQuick
import QtQuick.Controls
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
    spacing: 16

    component Track: Slider {
        id: sl
        property var stops: []
        Layout.fillWidth: true
        from: 0; to: 255; stepSize: 1
        background: Rectangle {
            y: sl.height / 2 - 5; height: 10; radius: 5; width: sl.availableWidth; x: sl.leftPadding
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: sl.stops[0] }
                GradientStop { position: 0.17; color: sl.stops.length > 2 ? sl.stops[1] : sl.stops[0] }
                GradientStop { position: 0.33; color: sl.stops.length > 2 ? sl.stops[2] : sl.stops[0] }
                GradientStop { position: 0.5; color: sl.stops.length > 3 ? sl.stops[3] : sl.stops[sl.stops.length - 1] }
                GradientStop { position: 0.67; color: sl.stops.length > 4 ? sl.stops[4] : sl.stops[sl.stops.length - 1] }
                GradientStop { position: 0.83; color: sl.stops.length > 5 ? sl.stops[5] : sl.stops[sl.stops.length - 1] }
                GradientStop { position: 1.0; color: sl.stops[sl.stops.length - 1] }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        Track {
            stops: ["#ff0000", "#ffff00", "#00ff00", "#00ffff", "#0000ff", "#ff00ff", "#ff0000"]
            value: root.h
            onMoved: root.edited(Math.round(value), root.s, root.v)
        }
        Track {
            stops: ["#ffffff", Qt.hsva(root.h / 255, 1, 1, 1)]
            value: root.s
            onMoved: root.edited(root.h, Math.round(value), root.v)
        }
        Track {
            visible: root.withValue
            stops: ["#000000", Qt.hsva(root.h / 255, root.s / 255, 1, 1)]
            value: root.v
            onMoved: root.edited(root.h, root.s, Math.round(value))
        }
    }
    Rectangle {
        Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: 12
        Layout.alignment: Qt.AlignTop
        color: root.swatch
        border.color: Qt.rgba(0, 0, 0, 0.25)
    }
}
