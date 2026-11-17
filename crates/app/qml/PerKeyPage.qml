import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Paint a colour onto individual keys. Shown by the keyboard when the effect is "Per-key RGB".
Item {
    id: root
    property var backend
    property var keys: []
    property real kbWidth: 22.5
    property real kbHeight: 6.25
    property var kc: null          // state from backend.kc_state()
    property int h: 0
    property int s: 255
    property int v: 255
    property bool dirty: false
    property int effectId: -1      // current backlight effect, so painting can switch to Per-key RGB
    signal showEffect()

    function save() { if (backend.kc_apply("save", "{}")) dirty = false; }

    readonly property var fills: {
        if (!kc) return [];
        return keys.map(k => k.led === null || k.led === undefined ? null
            : Qt.hsva(kc.colors[k.led].h / 255, kc.colors[k.led].s / 255, kc.colors[k.led].v / 255, 1));
    }

    function paint(i) {
        const led = keys[i].led;
        if (led === null || led === undefined) return;
        if (backend.kc_apply("color", JSON.stringify({ led: led, h: h, s: s, v: v }))) {
            const colors = kc.colors.slice();
            colors[led] = { h: h, s: s, v: v };
            kc = Object.assign({}, kc, { colors: colors });
            dirty = true;
            if (effectId !== 23) showEffect();
        }
    }
    function fillAll() {
        if (backend.kc_apply("fill", JSON.stringify({ h: h, s: s, v: v }))) {
            kc = Object.assign({}, kc, { colors: kc.colors.map(() => ({ h: h, s: s, v: v })) });
            dirty = true;
            if (effectId !== 23) showEffect();
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
                ScrollBar.vertical: KScrollBar {}
        clip: true
        ColumnLayout {
            width: parent.width
            spacing: 16

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
                        spacing: 14
                        Text { text: "Brush colour"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                        HsvPicker {
                            Layout.fillWidth: true
                            h: root.h; s: root.s; v: root.v
                            onEdited: (nh, ns, nv) => { root.h = nh; root.s = ns; root.v = nv; }
                        }
                    }
                }
                Card {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 14
                        Text { text: "How the colours behave"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                        KCombo {
                            Layout.fillWidth: true
                            model: ["Solid", "Breathing", "Reactive (simple)", "Reactive (wide)", "Reactive (splash)"]
                            currentIndex: root.kc ? root.kc.perKeyType : 0
                            onActivated: i => { if (root.backend.kc_apply("perKeyType", JSON.stringify({ kind: i }))) { root.kc = Object.assign({}, root.kc, { perKeyType: i }); root.dirty = true; } }
                        }
                        RowLayout {
                            spacing: 10
                            KButton { text: "Fill every key"; iconName: "palette"; onClicked: root.fillAll() }
                            KButton { text: "Show on keyboard"; variant: "ghost"; iconName: "bolt"; onClicked: root.showEffect() }
                        }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                            color: Theme.faint; font.pixelSize: 12
                            text: "Pick a colour, then click or drag across the keys below. The first stroke switches the keyboard to Per-key RGB."
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.preferredHeight: (width - 2 * padding) / root.kbWidth * root.kbHeight + 2 * padding
                padding: 22
                KeyboardView {
                    anchors.fill: parent
                    keys: root.keys
                    kbWidth: root.kbWidth
                    kbHeight: root.kbHeight
                    fills: root.fills
                    showLabels: false
                    paintMode: true
                    onKeyClicked: i => root.paint(i)
                }
            }
        }
    }
}
