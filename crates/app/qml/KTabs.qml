import QtQuick
import QtQuick.Layouts

// Segmented control. `model` is a list of labels; `enabledMask` optionally disables entries.
Rectangle {
    id: t
    property var model: []
    property int currentIndex: 0
    property var disabled: []          // indices that cannot be chosen
    signal activated(int index)
    implicitHeight: 38
    implicitWidth: row.implicitWidth + 8
    radius: Theme.radiusSmall + 2
    color: Theme.field
    border.color: Theme.line

    Rectangle {
        id: knob
        y: 4; height: parent.height - 8; radius: Theme.radiusSmall
        color: Theme.panelHi
        border.color: Theme.lineStrong
        x: 4 + (row.children[t.currentIndex] ? row.children[t.currentIndex].x : 0)
        width: row.children[t.currentIndex] ? row.children[t.currentIndex].width : 0
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    Row {
        id: row
        x: 4; y: 4; height: parent.height - 8
        Repeater {
            model: t.model
            delegate: Item {
                required property int index
                required property var modelData
                readonly property bool off: t.disabled.indexOf(index) >= 0
                width: label.implicitWidth + 28; height: row.height
                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData
                    font.pixelSize: 13
                    font.weight: t.currentIndex === index ? Font.DemiBold : Font.Medium
                    color: off ? Theme.faint : t.currentIndex === index ? Theme.text : Theme.dim
                    opacity: off ? 0.6 : 1
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !off
                    cursorShape: off ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: { t.currentIndex = index; t.activated(index); }
                }
            }
        }
    }
}
