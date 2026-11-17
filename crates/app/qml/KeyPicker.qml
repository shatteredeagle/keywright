import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Pick a keycode for the selected key. `catalog` is [{group, code, label}].
ColumnLayout {
    id: root
    property var catalog: []
    property string title: ""
    property string subtitle: ""
    signal picked(int code)
    signal cleared()

    readonly property var groups: {
        const seen = [];
        for (const c of catalog) if (seen.indexOf(c.group) < 0) seen.push(c.group);
        return seen;
    }
    property string group: groups.length ? groups[0] : ""
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: root.title; color: Theme.text; font.pixelSize: 17; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
            Text { text: root.subtitle; color: Theme.dim; font.pixelSize: 12; visible: root.subtitle !== ""; Layout.fillWidth: true; elide: Text.ElideRight }
        }
        KButton { text: "Clear key"; iconName: "x"; variant: "ghost"; onClicked: root.cleared() }
    }

    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: root.groups
            delegate: KButton {
                required property string modelData
                text: modelData
                chip: true
                selected: root.group === modelData
                onClicked: root.group = modelData
            }
        }
    }

    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: root.catalog.filter(c => c.group === root.group)
            delegate: Rectangle {
                id: keyChip
                required property var modelData
                width: Math.max(54, lbl.implicitWidth + 24)
                height: 38
                radius: 8
                color: hov.hovered ? Theme.accentSoft : Theme.panelHi
                border.color: hov.hovered ? Theme.accent : Theme.line
                Behavior on color { ColorAnimation { duration: 90 } }
                Text { id: lbl; anchors.centerIn: parent; text: keyChip.modelData.label; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.picked(keyChip.modelData.code) }
            }
        }
    }

    Item { Layout.fillHeight: true }
}
