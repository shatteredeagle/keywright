import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Keywright

ApplicationWindow {
    id: win
    width: 1360
    height: 800
    minimumWidth: 1000
    minimumHeight: 600
    visible: true
    title: "Keywright"
    color: Theme.bg

    Backend { id: backend }

    // Appearance: "system" follows the desktop; "light" and "dark" force a palette.
    property string themeMode: "system"
    onThemeModeChanged: Theme.mode = themeMode

    // Qt's own controls (scroll bars, menus) pick up the same palette.
    palette.window: Theme.bg
    palette.windowText: Theme.text
    palette.base: Theme.field
    palette.alternateBase: Theme.panel
    palette.text: Theme.text
    palette.button: Theme.panel
    palette.buttonText: Theme.text
    palette.highlight: Theme.accent
    palette.highlightedText: Theme.accentText
    palette.mid: Theme.lineStrong
    palette.dark: Theme.line
    palette.light: Theme.panelHi
    palette.placeholderText: Theme.faint

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
    readonly property string link: !backend.connected ? "Not connected"
        : backend.status.indexOf("2.4") >= 0 ? "2.4 GHz wireless" : "USB cable"

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
        Theme.mode = themeMode;
        reload();
        const sel = backend.env("KEYWRIGHT_SELECT");
        if (sel !== "") selected = parseInt(sel);
        const pg = backend.env("KEYWRIGHT_PAGE");
        if (pg !== "") pages.currentIndex = parseInt(pg);
        const shot = backend.env("KEYWRIGHT_SHOT");
        if (shot !== "") shotTimer.start();
    }
    Timer {
        id: shotTimer
        interval: parseInt(backend.env("KEYWRIGHT_SHOT_DELAY") || "1200")
        onTriggered: bg.grabToImage(r => { r.saveToFile(backend.env("KEYWRIGHT_SHOT")); Qt.quit(); })
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Theme.bg

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---- Sidebar -------------------------------------------------------------------
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 232
                color: Theme.sidebar
                Rectangle { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 1; color: Theme.line }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 4

                    RowLayout {
                        Layout.bottomMargin: 22
                        Layout.topMargin: 4
                        spacing: 12
                        Rectangle {
                            width: 40; height: 40; radius: 11
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0; color: Theme.dark ? "#8b9bff" : "#6a74f0" }
                                GradientStop { position: 1; color: Theme.dark ? "#5a4fd8" : "#3a37c4" }
                            }
                            Rectangle { x: 9; y: 8; width: 22; height: 20; radius: 5; color: "#ffffff"; opacity: 0.95
                                Text { anchors.centerIn: parent; text: "K"; font.pixelSize: 13; font.weight: Font.Black; color: "#3a37c4" } }
                            Rectangle { x: 9; y: 28; width: 22; height: 4; radius: 2; color: "#ffffff"; opacity: 0.45 }
                        }
                        ColumnLayout {
                            spacing: 0
                            Text { text: "Keywright"; color: Theme.text; font.pixelSize: 18; font.weight: Font.Bold }
                            Text { text: "Keychron configurator"; color: Theme.faint; font.pixelSize: 11 }
                        }
                    }

                    Repeater {
                        model: [
                            { name: "Keymap", icon: "keyboard" },
                            { name: "Lighting", icon: "sun" },
                            { name: "Macros", icon: "macro" },
                            { name: "Shortcuts", icon: "list" }
                        ]
                        delegate: Rectangle {
                            id: nav
                            required property var modelData
                            required property int index
                            readonly property bool active: pages.currentIndex === index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            radius: 10
                            color: active ? Theme.accentSoft : navHover.hovered ? Theme.panelHi : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Rectangle { visible: nav.active; x: 0; y: 11; width: 3; height: 22; radius: 2; color: Theme.accent }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                spacing: 12
                                Icon { name: nav.modelData.icon; size: 20; color: nav.active ? Theme.accentHi : Theme.dim }
                                Text { text: nav.modelData.name; font.pixelSize: 14; font.weight: nav.active ? Font.DemiBold : Font.Medium; color: nav.active ? Theme.text : Theme.dim }
                                Item { Layout.fillWidth: true }
                            }
                            HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: pages.currentIndex = nav.index }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Connection status
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 62
                        radius: 12
                        color: Theme.panel
                        border.color: Theme.line
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            Rectangle {
                                width: 34; height: 34; radius: 17
                                color: backend.connected ? Qt.rgba(Theme.ok.r, Theme.ok.g, Theme.ok.b, 0.16) : Theme.panelHi
                                Icon { anchors.centerIn: parent; name: win.link.indexOf("2.4") >= 0 ? "wifi" : "usb"; size: 18; color: backend.connected ? Theme.ok : Theme.faint }
                            }
                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Text { text: backend.connected ? "Keychron Q6 Max" : "No keyboard"; color: Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: win.link; color: backend.connected ? Theme.ok : Theme.faint; font.pixelSize: 12 }
                            }
                        }
                    }
                    RowLayout {
                        Layout.topMargin: 8
                        spacing: 8
                        KCombo {
                            Layout.fillWidth: true
                            model: ["System", "Light", "Dark"]
                            currentIndex: ["system", "light", "dark"].indexOf(win.themeMode)
                            onActivated: i => {
                                win.themeMode = ["system", "light", "dark"][i];
                                backend.set_theme(win.themeMode);
                            }
                        }
                        KButton { iconName: "refresh"; variant: "secondary"; implicitWidth: 40; leftPadding: 0; rightPadding: 0; onClicked: win.reload()
                            ToolTip.visible: hovered; ToolTip.text: "Look for the keyboard again" }
                    }
                }
            }

            // ---- Pages ---------------------------------------------------------------------
            StackLayout {
                id: pages
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: 0

                // Keymap
                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 28
                        spacing: 18
                        visible: backend.connected

                        PageHeader {
                            Layout.fillWidth: true
                            title: "Keymap"
                            subtitle: "Click a key to change what it does. Changes go to the keyboard instantly."
                            KTabs {
                                model: Array.from({ length: win.keymap.layers.length }, (_, i) => "Layer " + i)
                                currentIndex: win.layer
                                onActivated: i => { win.layer = i; win.selected = -1; }
                            }
                        }

                        Card {
                            Layout.fillWidth: true
                            Layout.preferredHeight: (width - 2 * padding) / win.keymap.width * win.keymap.height + 2 * padding
                            padding: 22
                            KeyboardView {
                                anchors.fill: parent
                                keys: win.displayKeys
                                kbWidth: win.keymap.width
                                kbHeight: win.keymap.height
                                selected: win.selected
                                onKeyClicked: i => win.selected = i
                            }
                        }

                        Card {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: win.selected >= 0
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 12
                                RowLayout {
                                    visible: win.knobSelected
                                    spacing: 10
                                    Icon { name: "knob"; size: 18; color: Theme.dim }
                                    KTabs {
                                        model: ["Turn left", "Turn right"]
                                        currentIndex: win.knobDir
                                        onActivated: i => win.knobDir = i
                                    }
                                    Text {
                                        readonly property var b: win.keymap.encoders && win.keymap.encoders.length > win.layer ? win.keymap.encoders[win.layer][win.knobDir] : null
                                        text: b ? "currently " + (b.label || "nothing") : ""
                                        color: Theme.dim; font.pixelSize: 13
                                    }
                                }
                                KeyPicker {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    catalog: win.catalog
                                    title: win.selected < 0 ? ""
                                         : win.knobSelected ? "Knob " + (win.knobDir === 1 ? "turn right" : "turn left")
                                         : "Remap “" + (win.layerKeys[win.selected].label || "empty") + "”"
                                    subtitle: "Layer " + win.layer
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
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: win.selected < 0
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                Icon { Layout.alignment: Qt.AlignHCenter; name: "keyboard"; size: 34; color: Theme.faint }
                                Text { text: "Pick a key above to remap it"; color: Theme.dim; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter }
                                Text { text: "The knob is a key too: click it to set what turning it does."; color: Theme.faint; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
                            }
                        }
                    }
                }

                LightingPage {
                    backend: backend
                    keys: win.keymap.layers.length ? win.keymap.layers[0] : []
                    kbWidth: win.keymap.width
                    kbHeight: win.keymap.height
                }

                MacrosPage {
                    backend: backend
                    catalog: win.catalog
                }

                ShortcutsPage {
                    layers: win.keymap.layers
                }
            }
        }

        // Shown over the pages when no keyboard answers.
        Rectangle {
            visible: !backend.connected
            x: 232; width: parent.width - 232; height: parent.height
            color: Theme.bg
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14
                width: 380
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 88; height: 88; radius: 44
                    color: Theme.panel; border.color: Theme.line
                    Icon { anchors.centerIn: parent; name: "keyboard"; size: 40; color: Theme.faint }
                }
                Text { text: "No keyboard found"; color: Theme.text; font.pixelSize: 22; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
                Text { text: backend.status; color: Theme.dim; font.pixelSize: 13; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                KButton { text: "Look again"; iconName: "refresh"; variant: "primary"; Layout.alignment: Qt.AlignHCenter; onClicked: win.reload() }
            }
        }
    }
}
