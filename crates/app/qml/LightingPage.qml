import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Backlight, per-key colours, regions and indicators. Changes apply live; "Save to keyboard"
// makes them survive a power cycle.
Item {
    id: root
    property var backend
    property var state: null           // {brightness, effect, speed, hue, saturation, effects:[{name,id}]}
    property bool dirty: false
    property bool saved: false
    property int effectId: -1
    property int brightVal: 255
    property int speedVal: 127
    property int hueVal: 0
    property int satVal: 0
    property var kc: null              // extended lighting state, null when unsupported
    property var keys: []
    property real kbWidth: 22.5
    property real kbHeight: 6.25

    function refresh() {
        const raw = backend.rgb();
        state = raw === "null" ? null : JSON.parse(raw);
        if (state) {
            effectId = state.effect; brightVal = state.brightness; speedVal = state.speed;
            hueVal = state.hue; satVal = state.saturation;
        }
        const k = backend.kc_state();
        kc = k === "null" ? null : JSON.parse(k);
        dirty = false;
        saved = false;
    }
    onVisibleChanged: if (visible && backend.connected) refresh()
    Component.onCompleted: {
        if (backend.connected) refresh();
        const t = backend.env("KEYWRIGHT_TAB");
        if (t !== "") tabs.currentIndex = parseInt(t);
        const pe = backend.env("KEYWRIGHT_PREVIEW_EFFECT");   // development only: preview an effect without writing it
        if (pe !== "") effectId = parseInt(pe);
    }

    function put(field, value) {
        if (!backend.set_rgb(field, value)) return;
        dirty = true; saved = false;
        if (field === "effect") effectId = value;
        else if (field === "brightness") brightVal = value;
        else if (field === "speed") speedVal = value;
    }
    function putColor(hue, sat) {
        if (backend.set_rgb_color(hue, sat)) { hueVal = hue; satVal = sat; dirty = true; saved = false; }
    }
    function saveBasic() {
        if (backend.save_rgb()) { dirty = false; saved = true; }
    }
    function useEffect(id) { put("effect", id); }

    // Built-in effects, plus the two Keychron ones when the keyboard supports them.
    readonly property var allEffects: state ? (kc ? state.effects.concat([{ name: "Per-key RGB", id: 23 }, { name: "Mixed RGB", id: 24 }]) : state.effects) : []
    readonly property var pages: [basicPage, perKey, regions, indicators]
    readonly property var current: pages[tabs.currentIndex]
    readonly property bool currentDirty: current.dirty === true
    readonly property string effectName: {
        const e = allEffects.find(e => e.id === effectId);
        return e ? e.name : "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 18
        visible: root.state !== null

        PageHeader {
            Layout.fillWidth: true
            title: "Lighting"
            subtitle: "Changes show on the keyboard as you make them."
            KTabs {
                id: tabs
                model: ["Backlight", "Per-key", "Regions", "Indicators"]
                disabled: root.kc ? [] : [1, 2, 3]
            }
            KButton {
                text: root.saved && !root.currentDirty ? "Saved" : "Save to keyboard"
                iconName: root.saved && !root.currentDirty ? "check" : "save"
                variant: "primary"
                enabled: root.currentDirty
                onClicked: { root.current.save(); }
            }
        }

        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            // Backlight ---------------------------------------------------------------------
            Item {
                id: basicPage
                property bool dirty: root.dirty
                function save() { root.saveBasic(); }

                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth
                ScrollBar.vertical: KScrollBar {}
                    clip: true
                    ColumnLayout {
                        width: parent.width
                        spacing: 16

                        Card {
                            Layout.fillWidth: true
                            Layout.preferredHeight: (width - 2 * padding) / root.kbWidth * root.kbHeight + 2 * padding + 34
                            padding: 20
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Live preview"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                                    Text { text: root.effectName; color: Theme.accentHi; font.pixelSize: 13; font.weight: Font.Medium }
                                    Item { Layout.fillWidth: true }
                                    Text { text: "An approximation. Click keys to try the reactive effects."; color: Theme.faint; font.pixelSize: 12 }
                                }
                                LightingPreview {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    running: root.visible && stack.currentIndex === 0
                                    keys: root.keys
                                    kbWidth: root.kbWidth
                                    kbHeight: root.kbHeight
                                    effect: root.effectId
                                    hue: root.hueVal
                                    sat: root.satVal
                                    bright: root.brightVal
                                    speed: root.speedVal
                                    perKey: root.kc ? root.kc.colors : null
                                    perKeyMode: root.kc ? root.kc.perKeyType : 0
                                    mixed: root.kc ? { regions: root.kc.regions, effects: root.kc.regionEffects } : null
                                }
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: width > 900 ? 2 : 1
                            columnSpacing: 16
                            uniformCellWidths: true
                            rowSpacing: 16

                            Card {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 16
                                    Text { text: "Effect"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                                    KCombo {
                                        Layout.fillWidth: true
                                        model: root.allEffects.map(e => e.name)
                                        currentIndex: root.allEffects.findIndex(e => e.id === root.effectId)
                                        onActivated: i => root.put("effect", root.allEffects[i].id)
                                    }
                                    Text {
                                        visible: root.effectId === 23 || root.effectId === 24
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        color: Theme.dim; font.pixelSize: 12
                                        text: root.effectId === 23 ? "Colours come from the Per-key tab." : "Colours and effects come from the Regions tab."
                                    }
                                    Text { text: "Colour"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.topMargin: 4 }
                                    HsvPicker {
                                        Layout.fillWidth: true
                                        withValue: false
                                        h: root.hueVal; s: root.satVal
                                        onEdited: (nh, ns, nv) => root.putColor(nh, ns)
                                    }
                                }
                            }
                            Card {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 14
                                    Text { text: "Intensity"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                                    RowLayout {
                                        Text { text: "Brightness"; color: Theme.dim; font.pixelSize: 13; Layout.fillWidth: true }
                                        Text { text: Math.round(root.brightVal / 255 * 100) + "%"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                                    }
                                    KSlider { Layout.fillWidth: true; value: root.brightVal; onMoved: root.put("brightness", Math.round(value)) }
                                    RowLayout {
                                        Layout.topMargin: 6
                                        Text { text: "Effect speed"; color: Theme.dim; font.pixelSize: 13; Layout.fillWidth: true }
                                        Text { text: Math.round(root.speedVal / 255 * 100) + "%"; color: Theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                                    }
                                    KSlider { Layout.fillWidth: true; value: root.speedVal; onMoved: root.put("speed", Math.round(value)) }
                                    Text {
                                        Layout.topMargin: 6
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        color: Theme.faint; font.pixelSize: 12
                                        text: root.dirty ? "Applied now. Save to keep it after the keyboard powers off." : root.saved ? "Saved to the keyboard." : "Drag a slider and watch the preview and the keyboard."
                                    }
                                }
                            }
                        }
                    }
                }
            }

            PerKeyPage {
                id: perKey
                backend: root.backend; keys: root.keys; kbWidth: root.kbWidth; kbHeight: root.kbHeight
                kc: root.kc; effectId: root.effectId
                onShowEffect: root.useEffect(23)
            }
            RegionsPage {
                id: regions
                backend: root.backend; keys: root.keys; kbWidth: root.kbWidth; kbHeight: root.kbHeight
                kc: root.kc; effectId: root.effectId
                effects: root.state ? root.state.effects : []
                onShowEffect: root.useEffect(24)
            }
            IndicatorsPage { id: indicators; backend: root.backend; kc: root.kc }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.state === null
        text: backend.connected ? "Could not read the lighting settings." : "Connect the keyboard to change lighting."
        color: Theme.dim
        font.pixelSize: 14
    }
}
