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
    SystemPalette { id: sysPal }

    // Appearance: "system" follows the desktop; "light" and "dark" force a palette.
    property string themeMode: "system"
    readonly property bool useDark: themeMode === "dark"
        || (themeMode === "system" && sysPal.window.hslLightness < 0.5)
    readonly property var darkColors: ({
        window: "#1b1c20", windowText: "#e6e7ea", base: "#25262b", alternateBase: "#2b2d33",
        text: "#e6e7ea", button: "#33353c", buttonText: "#e6e7ea", highlight: "#3d8bfd",
        highlightedText: "#ffffff", mid: "#4a4d55", dark: "#121316", light: "#42454d",
        placeholderText: "#8b8e96"
    })
    readonly property var lightColors: ({
        window: "#efeff1", windowText: "#1f2024", base: "#ffffff", alternateBase: "#f5f5f7",
        text: "#1f2024", button: "#e4e5e9", buttonText: "#1f2024", highlight: "#2f7bf0",
        highlightedText: "#ffffff", mid: "#b8bac2", dark: "#8d8f98", light: "#ffffff",
        placeholderText: "#767983"
    })
    function tone(name) {
        return themeMode === "system" ? sysPal[name] : (useDark ? darkColors : lightColors)[name];
    }
    palette.window: tone("window")
    palette.windowText: tone("windowText")
    palette.base: tone("base")
    palette.alternateBase: tone("alternateBase")
    palette.text: tone("text")
    palette.button: tone("button")
    palette.buttonText: tone("buttonText")
    palette.highlight: tone("highlight")
    palette.highlightedText: tone("highlightedText")
    palette.mid: tone("mid")
    palette.dark: tone("dark")
    palette.light: tone("light")
    palette.placeholderText: tone("placeholderText")

    property var keymap: ({ width: 22.5, height: 6.25, layers: [] })
    property var catalog: []
    property int layer: 0
    property int selected: -1
    property int knobDir: 0     // 0 = turn left (counter-clockwise), 1 = turn right
    readonly property var selectedKey: selected >= 0 && selected < layerKeys.length ? layerKeys[selected] : null
    readonly property bool knobSelected: selectedKey !== null && selectedKey.encoder !== null && selectedKey.encoder !== undefined
    // Keys as drawn: the knob shows what turning it does on this layer.
    readonly property var displayKeys: layerKeys.map(k => {
        if (k.encoder === null || k.encoder === undefined || !keymap.encoders || keymap.encoders.length <= layer) return k;
        const e = keymap.encoders[layer];
        return Object.assign({}, k, { knobLabel: "↶ " + (e[0].label || "–") + "\n↷ " + (e[1].label || "–") });
    })
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
        themeMode = backend.theme();
        const forced = backend.env("KEYWRIGHT_THEME");
        if (forced !== "") themeMode = forced;
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
    color: win.palette.window
    RowLayout {
        id: mainRow
        anchors.fill: parent
        spacing: 0

        // Navigation
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 190
            color: Qt.darker(win.palette.window, 1.08)
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
                ComboBox {
                    Layout.fillWidth: true
                    model: ["System theme", "Light", "Dark"]
                    currentIndex: ["system", "light", "dark"].indexOf(win.themeMode)
                    onActivated: i => {
                        win.themeMode = ["system", "light", "dark"][i];
                        backend.set_theme(win.themeMode);
                    }
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
                                highlighted: win.layer === index
                                onClicked: { win.layer = index; win.selected = -1; }
                            }
                        }
                    }
                    KeyboardView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width / win.keymap.width * win.keymap.height
                        pal: win.palette
                        keys: win.displayKeys
                        kbWidth: win.keymap.width
                        kbHeight: win.keymap.height
                        selected: win.selected
                        onKeyClicked: i => win.selected = i
                    }
                    RowLayout {
                        visible: win.knobSelected
                        spacing: 8
                        Label { text: "Knob"; opacity: 0.7 }
                        Repeater {
                            model: [{ dir: 0, name: "Turn left" }, { dir: 1, name: "Turn right" }]
                            delegate: Button {
                                required property var modelData
                                readonly property var bound: win.keymap.encoders && win.keymap.encoders.length > win.layer ? win.keymap.encoders[win.layer][modelData.dir] : null
                                text: modelData.name + (bound ? ": " + (bound.label || "none") : "")
                                highlighted: win.knobDir === modelData.dir
                                onClicked: win.knobDir = modelData.dir
                            }
                        }
                    }
                    KeyPicker {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: win.selected >= 0
                        catalog: win.catalog
                        title: win.selected < 0 ? ""
                             : win.knobSelected ? "Knob " + (win.knobDir === 1 ? "turn right" : "turn left") + " on layer " + win.layer
                             : "Remap “" + (win.layerKeys[win.selected].label || "empty") + "” on layer " + win.layer
                        function apply(code) {
                            if (win.knobSelected) {
                                if (backend.set_encoder(win.layer, win.knobDir === 1, code)) win.keymap = JSON.parse(backend.keymap());
                                return;
                            }
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

            // Lighting
            LightingPage {
                backend: backend
                pal: win.palette
                keys: win.keymap.layers.length ? win.keymap.layers[0] : []
                kbWidth: win.keymap.width
                kbHeight: win.keymap.height
            }

            // Shortcuts
            ShortcutsPage {
                pal: win.palette
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
