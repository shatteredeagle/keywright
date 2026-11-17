import QtQuick
import QtQuick.Layouts

// Title, one-line explanation, and a slot for actions on the right.
RowLayout {
    id: h
    property string title: ""
    property string subtitle: ""
    default property alias actions: actionRow.data
    spacing: 16
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text { text: h.title; color: Theme.text; font.pixelSize: 26; font.weight: Font.Bold }
        Text { text: h.subtitle; color: Theme.dim; font.pixelSize: 13; visible: h.subtitle !== ""; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
    RowLayout { id: actionRow; spacing: 10; Layout.alignment: Qt.AlignVCenter }
}
