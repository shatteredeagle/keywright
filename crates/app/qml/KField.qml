import QtQuick
import QtQuick.Controls

TextField {
    id: f
    implicitHeight: 36
    font.pixelSize: 13
    color: Theme.text
    placeholderTextColor: Theme.faint
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentText
    leftPadding: 12; rightPadding: 12
    verticalAlignment: TextInput.AlignVCenter
    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.field
        border.color: f.activeFocus ? Theme.accent : f.hovered ? Theme.lineStrong : Theme.line
        Behavior on border.color { ColorAnimation { duration: 110 } }
    }
}
