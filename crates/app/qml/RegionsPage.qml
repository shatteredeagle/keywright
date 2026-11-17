import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Split the keys into regions and give each region its own effect playlist ("Mixed RGB").
Item {
    id: root
    property var backend
    property var keys: []
    property real kbWidth: 22.5
    property real kbHeight: 6.25
    property var kc: null
    property var effects: []       // [{name, id}] built-in effects
    property int brush: 0
    property bool dirty: false
    property int effectId: -1
    signal showEffect()

    function save() { if (backend.kc_apply("save", "{}")) dirty = false; }

    readonly property var regionColors: ["#6f86ff", "#f0952e", "#3fc58a", "#cf5fbd"]
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
                ScrollBar.vertical: KScrollBar {}
        clip: true
        ColumnLayout {
            width: parent.width
            spacing: 16

            Card {
                Layout.fillWidth: true
                padding: 16
                RowLayout {
                    anchors.fill: parent
                    spacing: 12
                    Text { text: "Paint region"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Repeater {
                        model: root.kc ? root.kc.regionCount : 0
                        delegate: Rectangle {
                            id: chip
                            required property int index
                            readonly property bool on: root.brush === index
                            implicitWidth: chipRow.implicitWidth + 28
                            implicitHeight: 32
                            radius: 16
                            color: on ? Theme.accentSoft : (ch.hovered ? Theme.panelHi : Theme.panel)
                            border.color: on ? Theme.accent : Theme.line
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 8
                                Rectangle { width: 10; height: 10; radius: 5; color: root.regionColors[chip.index % 4]; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Region " + (chip.index + 1); color: chip.on ? Theme.accentHi : Theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                            }
                            HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.brush = chip.index }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text { text: "Click or drag across the keys. Region colours here are just labels."; color: Theme.faint; font.pixelSize: 12 }
                    KButton { text: "Show on keyboard"; variant: "ghost"; iconName: "bolt"; onClicked: root.showEffect() }
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
                    onKeyClicked: i => root.assign(i)
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 1000 ? 2 : 1
                columnSpacing: 16
                uniformCellWidths: true
                rowSpacing: 16
                Repeater {
                    model: root.kc ? root.kc.regionCount : 0
                    delegate: Card {
                        id: regionCard
                        required property int index
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10
                            RowLayout {
                                Rectangle { width: 12; height: 12; radius: 6; color: root.regionColors[regionCard.index % 4] }
                                Text { text: "Region " + (regionCard.index + 1) + " effects"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                                Text { text: "played in order"; color: Theme.faint; font.pixelSize: 12 }
                            }
                            Repeater {
                                model: root.kc ? root.kc.stepsPerRegion : 0
                                delegate: GridLayout {
                                    id: stepRow
                                    required property int index
                                    readonly property var cfg: root.kc.regionEffects[regionCard.index][index]
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 4
                                    columnSpacing: 10
                                    Text { text: (stepRow.index + 1); color: Theme.faint; font.pixelSize: 12; Layout.alignment: Qt.AlignTop; Layout.topMargin: 9 }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        RowLayout {
                                            spacing: 8
                                            KCombo {
                                                Layout.fillWidth: true
                                                model: root.effects.map(e => e.name)
                                                currentIndex: root.effects.findIndex(e => e.id === stepRow.cfg.effect)
                                                onActivated: i => root.step(regionCard.index, stepRow.index, { effect: root.effects[i].id })
                                            }
                                            KSpin {
                                                implicitWidth: 120
                                                from: 0; to: 600
                                                value: Math.round(stepRow.cfg.time / 1000)
                                                textFromValue: v => v + " s"
                                                valueFromText: t => parseInt(t)
                                                onValueModified: root.step(regionCard.index, stepRow.index, { time: value * 1000 })
                                            }
                                        }
                                        RowLayout {
                                            visible: stepRow.cfg.effect !== 0
                                            spacing: 8
                                            Text { text: "Hue"; color: Theme.faint; font.pixelSize: 11 }
                                            KSlider { Layout.fillWidth: true; implicitHeight: 22; value: stepRow.cfg.hue; stops: ["#ff0000", "#ffff00", "#00ff00", "#00ffff", "#0000ff", "#ff00ff", "#ff0000"]; onMoved: root.step(regionCard.index, stepRow.index, { hue: Math.round(value) }) }
                                            Text { text: "Sat"; color: Theme.faint; font.pixelSize: 11 }
                                            KSlider { Layout.fillWidth: true; implicitHeight: 22; value: stepRow.cfg.sat; onMoved: root.step(regionCard.index, stepRow.index, { sat: Math.round(value) }) }
                                            Text { text: "Speed"; color: Theme.faint; font.pixelSize: 11 }
                                            KSlider { Layout.fillWidth: true; implicitHeight: 22; value: stepRow.cfg.speed; onMoved: root.step(regionCard.index, stepRow.index, { speed: Math.round(value) }) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
