import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Paint a colour onto individual keys. Shown by the keyboard when the effect is "Per-key RGB".
Item {
    id: root
    property var backend
    property var pal
    property var keys: []
    property real kbWidth: 22.5
    property real kbHeight: 6.25
    property var kc: null          // state from backend.kc_state()
    property int h: 0
    property int s: 255
    property int v: 255
    property bool dirty: false
    property int effectId: -1        // current backlight effect, so painting can switch to Per-key RGB
    signal showEffect()            // ask the Lighting page to switch the keyboard to Per-key RGB

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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        RowLayout {
            spacing: 14
            Label { text: "Mode"; opacity: 0.8 }
            ComboBox {
                model: ["Solid", "Breathing", "Reactive (simple)", "Reactive (wide)", "Reactive (splash)"]
                currentIndex: root.kc ? root.kc.perKeyType : 0
                onActivated: i => { if (root.backend.kc_apply("perKeyType", JSON.stringify({ kind: i }))) { root.kc = Object.assign({}, root.kc, { perKeyType: i }); root.dirty = true; } }
            }
            Button { text: "Show on keyboard"; onClicked: root.showEffect() }
            Item { Layout.fillWidth: true }
            Button {
                text: "Save to keyboard"
                highlighted: root.dirty
                enabled: root.dirty
                onClicked: if (root.backend.kc_apply("save", "{}")) root.dirty = false
            }
        }

        Label { text: "Pick a colour, then click keys to paint them."; opacity: 0.7 }
        HsvPicker {
            Layout.fillWidth: true
            h: root.h; s: root.s; v: root.v
            onEdited: (nh, ns, nv) => { root.h = nh; root.s = ns; root.v = nv; }
        }
        Button { text: "Fill every key with this colour"; onClicked: root.fillAll() }

        KeyboardView {
            Layout.fillWidth: true
            Layout.preferredHeight: width / root.kbWidth * root.kbHeight
            pal: root.pal
            keys: root.keys
            kbWidth: root.kbWidth
            kbHeight: root.kbHeight
            fills: root.fills
            showLabels: false
            paintMode: true
            onKeyClicked: i => root.paint(i)
        }
        Item { Layout.fillHeight: true }
    }
}
