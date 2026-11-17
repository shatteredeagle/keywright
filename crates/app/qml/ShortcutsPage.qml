import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Read-only cheat sheet: every key that does something different on a Fn layer.
Item {
    id: root
    property var layers: []   // [[{label, code, ...}]] same key order per layer

    // Which key holds a given layer (code 0x5220 + n).
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 18
        PageHeader {
            Layout.fillWidth: true
            title: "Shortcuts"
            subtitle: "What each Fn layer does, at a glance. Change them on the Keymap page."
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            GridLayout {
                width: parent.width
                columns: Math.max(1, Math.floor(width / 330))
                columnSpacing: 16
                rowSpacing: 16
                Repeater {
                    model: root.cards
                    delegate: Card {
                        id: card
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        padding: 18
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 8
                            RowLayout {
                                Layout.bottomMargin: 6
                                Text { text: card.modelData.hold ? "Hold " + card.modelData.hold : card.modelData.name; color: Theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                                Item { Layout.fillWidth: true }
                                Text { text: card.modelData.name; color: Theme.faint; font.pixelSize: 12 }
                            }
                            Repeater {
                                model: card.modelData.rows
                                delegate: RowLayout {
                                    id: row
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Rectangle {
                                        implicitWidth: Math.max(34, kl.implicitWidth + 16); implicitHeight: 26; radius: 6
                                        color: Theme.capAlpha
                                        border.color: Theme.capEdge
                                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 2; radius: 1; color: Theme.capEdge }
                                        Text { id: kl; anchors.centerIn: parent; text: row.modelData.from; color: Theme.capText; font.pixelSize: 12; font.weight: Font.Medium }
                                    }
                                    Icon { name: "arrow-down"; size: 12; color: Theme.faint; rotation: -90 }
                                    Text { text: row.modelData.to; color: Theme.text; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: root.cards.length === 0
        text: "No Fn-layer shortcuts to show."
        color: Theme.dim
    }
}
