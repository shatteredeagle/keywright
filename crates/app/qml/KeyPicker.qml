import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Pick a keycode for the selected key. `catalog` is [{group, code, label}].
Pane {
    id: root
    property var catalog: []
    property string title: ""
    signal picked(int code)
    signal cleared()

    readonly property var groups: {
        const seen = [];
        for (const c of catalog) if (seen.indexOf(c.group) < 0) seen.push(c.group);
        return seen;
    }
    property string group: groups.length ? groups[0] : ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        Label { text: root.title; font.bold: true; font.pixelSize: 15; Layout.fillWidth: true; elide: Text.ElideRight }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.groups
                delegate: Button {
                    required property string modelData
                    text: modelData
                    flat: root.group !== modelData
                    highlighted: root.group === modelData
                    onClicked: root.group = modelData
                }
            }
        }
        Flow {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            clip: true
            Repeater {
                model: root.catalog.filter(c => c.group === root.group)
                delegate: Button {
                    required property var modelData
                    text: modelData.label
                    width: Math.max(52, implicitWidth)
                    onClicked: root.picked(modelData.code)
                }
            }
        }
        Button { text: "Set to none"; onClicked: root.cleared() }
    }
}
