import QtQuick
import QtQuick.Controls

// Slider with a filled track. Set `stops` (2-7 colours) for a gradient track instead.
Slider {
    id: s
    property var stops: null
    from: 0; to: 255; stepSize: 1
    implicitHeight: 28
    hoverEnabled: true

    background: Item {
        x: s.leftPadding; y: s.topPadding + s.availableHeight / 2 - 4
        width: s.availableWidth; height: 8
        Rectangle { anchors.fill: parent; radius: 4; color: Theme.field; border.color: Theme.line; visible: !s.stops }
        Rectangle {
            visible: !s.stops
            width: s.visualPosition * parent.width; height: parent.height; radius: 4; color: Theme.accent
        }
        Rectangle {
            visible: !!s.stops
            anchors.fill: parent; radius: 4
            border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.18)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: s.stops ? s.stops[0] : "black" }
                GradientStop { position: 0.17; color: s.stops && s.stops.length > 2 ? s.stops[1] : (s.stops ? s.stops[0] : "black") }
                GradientStop { position: 0.33; color: s.stops && s.stops.length > 2 ? s.stops[2] : (s.stops ? s.stops[0] : "black") }
                GradientStop { position: 0.5;  color: s.stops && s.stops.length > 3 ? s.stops[3] : (s.stops ? s.stops[s.stops.length - 1] : "black") }
                GradientStop { position: 0.67; color: s.stops && s.stops.length > 4 ? s.stops[4] : (s.stops ? s.stops[s.stops.length - 1] : "black") }
                GradientStop { position: 0.83; color: s.stops && s.stops.length > 5 ? s.stops[5] : (s.stops ? s.stops[s.stops.length - 1] : "black") }
                GradientStop { position: 1.0;  color: s.stops ? s.stops[s.stops.length - 1] : "black" }
            }
        }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 20; height: 20; radius: 10
        color: "#ffffff"
        border.width: 2
        border.color: s.pressed || s.hovered ? Theme.accent : Theme.lineStrong
        scale: s.pressed ? 1.12 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Rectangle { z: -1; anchors.centerIn: parent; width: parent.width + 8; height: width; radius: width / 2; color: Theme.accent; opacity: s.pressed ? 0.25 : 0; Behavior on opacity { NumberAnimation { duration: 120 } } }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
