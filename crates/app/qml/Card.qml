import QtQuick

// A raised panel. Children go inside with `padding` around them.
Rectangle {
    id: c
    property int padding: Theme.pad
    default property alias content: inner.data
    color: Theme.panel
    radius: Theme.radius
    border.width: 1
    border.color: Theme.line
    // Size to the first child's implicit size; children that anchor to the card are laid out inside.
    implicitWidth: (inner.children.length ? inner.children[0].implicitWidth : 0) + padding * 2
    implicitHeight: (inner.children.length ? inner.children[0].implicitHeight : 0) + padding * 2
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: c.padding
    }
}
