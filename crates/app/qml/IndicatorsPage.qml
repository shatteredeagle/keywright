import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Lock-key indicator LEDs: which ones light up, and their colour.
Item {
    id: root
    property var backend
    property var pal
    property var kc: null
    property bool dirty: false
    property int h: 0
    property int s: 0
    property int v: 255
    property int disabled: 0

    onKcChanged: if (kc && !dirty) { h = kc.indicators.color.h; s = kc.indicators.color.s; v = kc.indicators.color.v; disabled = kc.indicators.disabled; }

    function push() {
        if (backend.kc_apply("indicators", JSON.stringify({ disabled: disabled, h: h, s: s, v: v }))) dirty = true;
    }

    ColumnLayout {
        x: 20; y: 20
        width: Math.min(parent.width - 40, 720)
        spacing: 20
        Label { text: "Lock indicators"; font.bold: true; font.pixelSize: 22 }
        Label { text: "The LEDs that show Num Lock and Caps Lock."; opacity: 0.7 }
        Repeater {
            model: [{ bit: 0, name: "Num Lock" }, { bit: 1, name: "Caps Lock" }]
            delegate: CheckBox {
                required property var modelData
                visible: root.kc && (root.kc.indicators.available & (1 << modelData.bit)) !== 0
                text: modelData.name + " light"
                checked: (root.disabled & (1 << modelData.bit)) === 0
                onToggled: { root.disabled = checked ? root.disabled & ~(1 << modelData.bit) : root.disabled | (1 << modelData.bit); root.push(); }
            }
        }
        Label { text: "Indicator colour"; opacity: 0.8 }
        HsvPicker {
            Layout.fillWidth: true
            h: root.h; s: root.s; v: root.v
            onEdited: (nh, ns, nv) => { root.h = nh; root.s = ns; root.v = nv; root.push(); }
        }
        Button {
            text: "Save to keyboard"; highlighted: root.dirty; enabled: root.dirty
            onClicked: if (root.backend.kc_apply("save", "{}")) root.dirty = false
        }
    }
}
