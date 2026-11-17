import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Keywright

ApplicationWindow {
    id: win
    width: 1360
    height: 720
    minimumWidth: 900
    minimumHeight: 520
    visible: true
    title: "Keywright"

    Backend { id: backend }
    SystemPalette { id: pal }

    property var keymap: ({ width: 22.5, height: 6.25, layers: [] })
    property var catalog: []
    property int layer: 0
    property int selected: -1
    readonly property var layerKeys: keymap.layers.length > layer ? keymap.layers[layer] : []

    function reload() {
        backend.load();
        if (backend.connected) {
            keymap = JSON.parse(backend.keymap());
            catalog = JSON.parse(backend.catalog());
            selected = -1;
        }
    }
    Component.onCompleted: {
        reload();
        const pg = backend.env("KEYWRIGHT_PAGE");
        if (pg !== "") pages.currentIndex = parseInt(pg);
        const shot = backend.env("KEYWRIGHT_SHOT");
        if (shot !== "") shotTimer.start();
    }
    Timer {
        id: shotTimer
        interval: 900
        onTriggered: bg.grabToImage(r => { r.saveToFile(backend.env("KEYWRIGHT_SHOT")); Qt.quit(); })
    }

    Rectangle {
    id: bg
    anchors.fill: parent
    color: pal.window
    RowLayout {
        id: mainRow
        anchors.fill: parent
        spacing: 0

        // Navigation
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 190
            color: Qt.darker(pal.window, 1.06)
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                Label { text: "Keywright"; font.bold: true; font.pixelSize: 20; Layout.bottomMargin: 14 }
                Repeater {
                    model: ["Keymap", "Lighting", "Shortcuts"]
                    delegate: ItemDelegate {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        text: modelData
                        highlighted: pages.currentIndex === index
                        onClicked: pages.currentIndex = index
                    }
                }
                Item { Layout.fillHeight: true }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: backend.status
                    opacity: 0.7
                    font.pixelSize: 12
                }
                Button { text: "Reconnect"; Layout.fillWidth: true; onClicked: win.reload() }
            }
        }

        StackLayout {
            id: pages
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: 0

            // Keymap
            Item {
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14
                    visible: backend.connected
                    RowLayout {
                        spacing: 8
                        Label { text: "Layer"; opacity: 0.7 }
                        Repeater {
                            model: win.keymap.layers.length
                            delegate: Button {
                                required property int index
                                text: index
                                checkable: true
                                checked: win.layer === index
                                onClicked: { win.layer = index; win.selected = -1; }
                            }
                        }
                    }
                    KeyboardView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width / win.keymap.width * win.keymap.height
                        keys: win.layerKeys
                        kbWidth: win.keymap.width
                        kbHeight: win.keymap.height
                        selected: win.selected
                        onKeyClicked: i => win.selected = i
                    }
                    KeyPicker {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: win.selected >= 0
                        catalog: win.catalog
                        title: win.selected >= 0 ? "Remap “" + (win.layerKeys[win.selected].label || "empty") + "” on layer " + win.layer : ""
                        function apply(code) {
                            const k = win.layerKeys[win.selected];
                            if (backend.set_key(win.layer, k.row, k.col, code)) {
                                win.keymap = JSON.parse(backend.keymap());
                            }
                        }
                        onPicked: code => apply(code)
                        onCleared: apply(0)
                    }
                    Label {
                        visible: win.selected < 0
                        text: "Click a key to remap it."
                        opacity: 0.6
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Item { Layout.fillHeight: win.selected < 0 }
                }
            }

            // Lighting (next step)
            Item {
                Label { anchors.centerIn: parent; text: "Lighting controls arrive in the next step."; opacity: 0.6 }
            }

            // Shortcuts
            ShortcutsPage {
                layers: win.keymap.layers
                Layout.margins: 20
            }
        }
    }
    }

    Label {
        visible: !backend.connected
        anchors.centerIn: parent
        text: backend.status
        font.pixelSize: 16
        opacity: 0.7
    }
}
