import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Split the keys into regions and give each region its own effect playlist ("Mixed RGB").
Item {
    id: root
    property var backend
    property var pal
    property var keys: []
    property real kbWidth: 22.5
    property real kbHeight: 6.25
    property var kc: null
    property var effects: []       // [{name, id}] built-in effects
    property int brush: 0
    property bool dirty: false
    property int effectId: -1
    signal showEffect()

    readonly property var regionColors: ["#3d8bfd", "#f08c2e", "#3cb371", "#c45ab3"]
    readonly property var fills: kc ? keys.map(k => k.led === null || k.led === undefined ? null
            : root.regionColors[kc.regions[k.led] % root.regionColors.length]) : []

    function assign(i) {
        const led = keys[i].led;
        if (led === null || led === undefined) return;
        if (backend.kc_apply("region", JSON.stringify({ leds: [led], region: brush }))) {
            const regions = kc.regions.slice();
            regions[led] = brush;
            kc = Object.assign({}, kc, { regions: regions });
            dirty = true;
            if (effectId !== 24) showEffect();
        }
    }
    function step(region, index, patch) {
        const cur = Object.assign({}, kc.regionEffects[region][index], patch);
        const ok = backend.kc_apply("regionEffect", JSON.stringify({
            region: region, index: index, effect: cur.effect, hue: cur.hue, sat: cur.sat, speed: cur.speed, time: cur.time }));
        if (ok) {
            const all = kc.regionEffects.map(r => r.slice());
            all[region][index] = cur;
            kc = Object.assign({}, kc, { regionEffects: all });
            dirty = true;
            if (effectId !== 24) showEffect();
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width - 40
            x: 20
            spacing: 16

            RowLayout {
                Layout.topMargin: 20
                spacing: 12
                Label { text: "Paint region"; opacity: 0.8 }
                Repeater {
                    model: root.kc ? root.kc.regionCount : 0
                    delegate: Button {
                        required property int index
                        text: "Region " + (index + 1)
                        highlighted: root.brush === index
                        onClicked: root.brush = index
                        Rectangle { anchors { left: parent.left; bottom: parent.bottom; right: parent.right } height: 4; radius: 2; color: root.regionColors[index % 4] }
                    }
                }
                Button { text: "Show on keyboard"; onClicked: root.showEffect() }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Save to keyboard"; highlighted: root.dirty; enabled: root.dirty
                    onClicked: if (root.backend.kc_apply("save", "{}")) root.dirty = false
                }
            }

            KeyboardView {
                Layout.fillWidth: true
                Layout.preferredHeight: width / root.kbWidth * root.kbHeight
                pal: root.pal
                keys: root.keys
                kbWidth: root.kbWidth
                kbHeight: root.kbHeight
                fills: root.fills
                showLabels: false
                onKeyClicked: i => root.assign(i)
            }

            Repeater {
                model: root.kc ? root.kc.regionCount : 0
                delegate: ColumnLayout {
                    id: regionBlock
                    required property int index
                    Layout.fillWidth: true
                    spacing: 8
                    Label {
                        text: "Region " + (index + 1) + " effects (played in order)"
                        font.bold: true
                        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.bottom } height: 3; color: root.regionColors[regionBlock.index % 4]; radius: 2 }
                    }
                    Repeater {
                        model: root.kc ? root.kc.stepsPerRegion : 0
                        delegate: RowLayout {
                            id: stepRow
                            required property int index
                            readonly property var cfg: root.kc.regionEffects[regionBlock.index][index]
                            Layout.fillWidth: true
                            spacing: 10
                            Label { text: (stepRow.index + 1) + "."; Layout.preferredWidth: 20; opacity: 0.6 }
                            ComboBox {
                                Layout.preferredWidth: 220
                                model: root.effects.map(e => e.name)
                                currentIndex: root.effects.findIndex(e => e.id === stepRow.cfg.effect)
                                onActivated: i => root.step(regionBlock.index, stepRow.index, { effect: root.effects[i].id })
                            }
                            Label { text: "Hue"; opacity: 0.6 }
                            Slider { Layout.preferredWidth: 90; from: 0; to: 255; value: stepRow.cfg.hue; onMoved: root.step(regionBlock.index, stepRow.index, { hue: Math.round(value) }) }
                            Label { text: "Sat"; opacity: 0.6 }
                            Slider { Layout.preferredWidth: 90; from: 0; to: 255; value: stepRow.cfg.sat; onMoved: root.step(regionBlock.index, stepRow.index, { sat: Math.round(value) }) }
                            Label { text: "Speed"; opacity: 0.6 }
                            Slider { Layout.preferredWidth: 90; from: 0; to: 255; value: stepRow.cfg.speed; onMoved: root.step(regionBlock.index, stepRow.index, { speed: Math.round(value) }) }
                            Label { text: "Time (s)"; opacity: 0.6 }
                            SpinBox {
                                from: 0; to: 600; value: Math.round(stepRow.cfg.time / 1000)
                                editable: true
                                onValueModified: root.step(regionBlock.index, stepRow.index, { time: value * 1000 })
                            }
                        }
                    }
                }
            }
            Item { Layout.preferredHeight: 20 }
        }
    }
}
