import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Lock-key indicator LEDs: which ones light up, and their colour.
Item {
    id: root
    property var backend
    property var kc: null
    property bool dirty: false
    property int h: 0
    property int s: 0
    property int v: 255
    property int disabled: 0

    function save() { if (backend.kc_apply("save", "{}")) dirty = false; }
    onKcChanged: if (kc && !dirty) { h = kc.indicators.color.h; s = kc.indicators.color.s; v = kc.indicators.color.v; disabled = kc.indicators.disabled; }
    function push() {
        if (backend.kc_apply("indicators", JSON.stringify({ disabled: disabled, h: h, s: s, v: v }))) dirty = true;
    }

    Card {
        width: Math.min(parent.width, 720)
        ColumnLayout {
            anchors.fill: parent
            spacing: 18
            Text { text: "Lock indicators"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { text: "The LEDs that show Num Lock and Caps Lock."; color: Theme.dim; font.pixelSize: 13 }
            Repeater {
                model: [{ bit: 0, name: "Num Lock light" }, { bit: 1, name: "Caps Lock light" }]
                delegate: KSwitch {
                    required property var modelData
                    visible: root.kc && (root.kc.indicators.available & (1 << modelData.bit)) !== 0
                    text: modelData.name
                    checked: (root.disabled & (1 << modelData.bit)) === 0
                    onToggled: { root.disabled = checked ? root.disabled & ~(1 << modelData.bit) : root.disabled | (1 << modelData.bit); root.push(); }
                }
            }
            Text { text: "Indicator colour"; color: Theme.text; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.topMargin: 6 }
            HsvPicker {
                Layout.fillWidth: true
                h: root.h; s: root.s; v: root.v
                onEdited: (nh, ns, nv) => { root.h = nh; root.s = ns; root.v = nv; root.push(); }
            }
        }
    }
}
