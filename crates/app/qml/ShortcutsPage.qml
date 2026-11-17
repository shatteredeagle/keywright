import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Read-only cheat sheet: every key that does something different on a Fn layer.
Item {
    id: root
    property var layers: []   // [[{label, code, ...}]] same key order per layer

    property var pal

    // Which base-layer key holds a given layer (code 0x5220 + n).
    function holder(n) {
        for (const layer of layers) {
            const k = layer.find(k => k.code === 0x5220 + n);
            if (k) return k.label;
        }
        return "";
    }
    function labelFor(i) { return layers.length ? layers[0][i].label : ""; }

    readonly property var cards: {
        const out = [];
        for (let l = 1; l < layers.length; l++) {
            const rows = [];
            for (let i = 0; i < layers[l].length; i++) {
                const c = layers[l][i].code;
                if (c === 0x0001 || c === layers[0][i].code || layers[l][i].label === "") continue;
                rows.push({ from: labelFor(i) || "·", to: layers[l][i].label });
            }
            if (rows.length) out.push({ name: "Layer " + l, hold: holder(l), rows: rows });
        }
        return out;
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        Flow {
            width: parent.width
            spacing: 16
            Repeater {
                model: root.cards
                delegate: Rectangle {
                    required property var modelData
                    width: 300
                    height: head.height + col.implicitHeight + 28
                    radius: 10
                    color: pal.base
                    border.color: Qt.rgba(pal.windowText.r, pal.windowText.g, pal.windowText.b, 0.15)
                    Column {
                        id: col
                        x: 14; y: head.height + 14
                        width: parent.width - 28
                        spacing: 4
                        Repeater {
                            model: modelData.rows
                            delegate: RowLayout {
                                required property var modelData
                                width: col.width
                                Rectangle {
                                    implicitWidth: kl.implicitWidth + 14; implicitHeight: 24; radius: 5
                                    color: pal.button; border.color: Qt.rgba(0, 0, 0, 0.2)
                                    Label { id: kl; anchors.centerIn: parent; text: modelData.from; font.family: "monospace" }
                                }
                                Label { text: "→"; opacity: 0.5 }
                                Label { text: modelData.to; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                        }
                    }
                    Item {
                        id: head
                        width: parent.width; height: 44
                        Label {
                            x: 14; anchors.verticalCenter: parent.verticalCenter
                            text: (modelData.hold ? "Hold " + modelData.hold : modelData.name)
                            font.bold: true; font.pixelSize: 15
                        }
                        Label {
                            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                            text: modelData.name; opacity: 0.55
                        }
                    }
                }
            }
        }
    }
    Label {
        anchors.centerIn: parent
        visible: root.cards.length === 0
        text: "No Fn-layer shortcuts to show."
        opacity: 0.6
    }
}
