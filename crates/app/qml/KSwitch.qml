import QtQuick
import QtQuick.Controls

Switch {
    id: s
    implicitHeight: 28
    hoverEnabled: true
    indicator: Rectangle {
        x: s.leftPadding; y: (s.height - height) / 2
        width: 42; height: 24; radius: 12
        color: s.checked ? Theme.accent : Theme.field
        border.color: s.checked ? Theme.accent : Theme.lineStrong
        Behavior on color { ColorAnimation { duration: 140 } }
        Rectangle {
            y: 3; width: 18; height: 18; radius: 9
            x: s.checked ? parent.width - width - 3 : 3
            color: s.checked ? Theme.accentText : Theme.dim
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Text {
        leftPadding: s.indicator.width + 10
        text: s.text
        color: Theme.text
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
