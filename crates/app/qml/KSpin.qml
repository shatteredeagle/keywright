import QtQuick
import QtQuick.Controls

SpinBox {
    id: s
    implicitHeight: 36
    implicitWidth: 140
    editable: true
    font.pixelSize: 13
    leftPadding: 34
    rightPadding: 34
    contentItem: TextInput {
        z: 2
        text: s.textFromValue(s.value, s.locale)
        font: s.font
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !s.editable
        validator: s.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }
    component Step: Rectangle {
        property string icon
        property bool hot
        width: 30; height: parent.height
        color: hot ? Theme.panelHi : "transparent"
        Icon { anchors.centerIn: parent; name: parent.icon; size: 15; color: Theme.dim }
    }
    up.indicator: Step { x: s.width - width; icon: "plus"; hot: s.up.pressed; radius: Theme.radiusSmall }
    down.indicator: Step { x: 0; icon: "minus"; hot: s.down.pressed; radius: Theme.radiusSmall }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.field
        border.color: s.activeFocus ? Theme.accent : Theme.line
    }
}
