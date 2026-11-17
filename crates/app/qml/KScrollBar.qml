import QtQuick
import QtQuick.Controls

// Always-visible scroll bar (while there is something to scroll), so overflowing pages are obvious.
ScrollBar {
    id: bar
    policy: ScrollBar.AlwaysOn
    visible: size < 1.0
    minimumSize: 0.1
    padding: 3
    implicitWidth: 14
    hoverEnabled: true
    // ScrollView leaves a custom bar at the origin, so pin it to the right edge ourselves.
    anchors.top: parent ? parent.top : undefined
    anchors.bottom: parent ? parent.bottom : undefined
    anchors.right: parent ? parent.right : undefined
    contentItem: Rectangle {
        implicitWidth: 8
        radius: 4
        color: bar.pressed ? Theme.accent : bar.hovered ? Theme.faint : Theme.lineStrong
        Behavior on color { ColorAnimation { duration: 100 } }
    }
    background: Rectangle {
        radius: 7
        color: bar.size < 1 ? Theme.field : "transparent"
        opacity: 0.6
    }
}
