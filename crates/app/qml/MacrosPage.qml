import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Edit the keyboard's macro slots: typed text, key taps/holds, and waits.
Item {
    id: root
    property var backend
    property var pal
    property var catalog: []          // [{group, code, label}]
    property var list: []              // [[action]] one array per slot
    property int size: 0
    property int used: 0
    property int slot: 0
    property bool dirty: false
    property string message: ""

    readonly property var keyChoices: catalog.filter(c => c.code < 256 && c.group !== "Macros")
    readonly property var kinds: [
        { kind: "text", name: "Type text" }, { kind: "tap", name: "Tap key" }, { kind: "down", name: "Hold key" },
        { kind: "up", name: "Release key" }, { kind: "delay", name: "Wait" } ]

    function esc(s) { return s.replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/\t/g, "\\t"); }
    function unesc(s) { return s.replace(/\\(n|t|\\)/g, (m, c) => c === "n" ? "\n" : c === "t" ? "\t" : "\\"); }
    function summary(m) {
        if (!m.length) return "empty";
        return m.map(a => a.kind === "text" ? esc(a.text) : a.kind === "delay" ? a.ms + "ms"
            : (a.kind === "tap" ? "" : a.kind === "down" ? "↓" : "↑") + keyName(a.code)).join(" ");
    }
    function keyName(code) {
        const c = catalog.find(k => k.code === code);
        return c ? c.label : "0x" + code.toString(16);
    }
    function refresh() {
        const raw = backend.macros();
        if (raw === "null") { list = []; return; }
        const d = JSON.parse(raw);
        list = d.macros; size = d.size; used = d.used; dirty = false; message = "";
    }
    onVisibleChanged: if (visible && backend.connected) refresh()
    Component.onCompleted: if (backend.connected) refresh()

    function mutate(fn) {
        const copy = list.map(m => m.map(a => Object.assign({}, a)));
        fn(copy[slot]);
        list = copy;
        dirty = true;
    }
    function save() {
        const err = backend.set_macros(JSON.stringify(list));
        if (err === "") { dirty = false; message = "Saved to the keyboard."; refresh(); message = "Saved to the keyboard."; }
        else message = err;
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        visible: root.list.length > 0

        // Slot list
        ColumnLayout {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            spacing: 6
            Label { text: "Macros"; font.bold: true; font.pixelSize: 22 }
            ListView {
                id: slots
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: root.list.length
                delegate: ItemDelegate {
                    required property int index
                    width: ListView.view.width
                    highlighted: root.slot === index
                    onClicked: root.slot = index
                    contentItem: ColumnLayout {
                        spacing: 0
                        Label { text: "Macro " + index; font.bold: true }
                        Label { text: root.summary(root.list[index]); elide: Text.ElideRight; Layout.fillWidth: true; opacity: 0.65; font.pixelSize: 12 }
                    }
                }
            }
        }

        // Editor
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            RowLayout {
                Label { text: "Macro " + root.slot; font.bold: true; font.pixelSize: 20; Layout.fillWidth: true }
                Label { text: root.message; opacity: 0.8 }
                Button {
                    text: "Save to keyboard"; highlighted: root.dirty; enabled: root.dirty
                    onClicked: root.save()
                }
                Button { text: "Discard changes"; enabled: root.dirty; onClicked: root.refresh() }
            }
            Label {
                text: "Assign it to a key on the Keymap page: pick “Macro " + root.slot + "” in the Macros group."
                opacity: 0.65; wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: root.list.length > root.slot ? root.list[root.slot].length : 0
                        delegate: RowLayout {
                            id: step
                            required property int index
                            readonly property var act: root.list[root.slot][index]
                            Layout.fillWidth: true
                            spacing: 8
                            Label { text: (step.index + 1) + "."; Layout.preferredWidth: 24; opacity: 0.6 }
                            ComboBox {
                                Layout.preferredWidth: 130
                                model: root.kinds.map(k => k.name)
                                currentIndex: root.kinds.findIndex(k => k.kind === step.act.kind)
                                onActivated: i => root.mutate(m => {
                                    const k = root.kinds[i].kind;
                                    m[step.index] = k === "text" ? { kind: k, text: "" } : k === "delay" ? { kind: k, ms: 100 } : { kind: k, code: 0x04 };
                                })
                            }
                            TextField {
                                visible: step.act.kind === "text"
                                Layout.fillWidth: true
                                placeholderText: "Text to type (\\n for Enter, \\t for Tab)"
                                text: step.act.kind === "text" ? root.esc(step.act.text) : ""
                                onTextEdited: { step.act.text = root.unesc(text); root.dirty = true; root.list[root.slot][step.index].text = step.act.text; }
                            }
                            ComboBox {
                                visible: step.act.kind === "tap" || step.act.kind === "down" || step.act.kind === "up"
                                Layout.fillWidth: true
                                model: root.keyChoices.map(c => c.group + " · " + c.label)
                                currentIndex: root.keyChoices.findIndex(c => c.code === step.act.code)
                                onActivated: i => root.mutate(m => { m[step.index].code = root.keyChoices[i].code; })
                            }
                            SpinBox {
                                visible: step.act.kind === "delay"
                                Layout.fillWidth: true
                                from: 0; to: 60000; stepSize: 50; editable: true
                                value: step.act.kind === "delay" ? step.act.ms : 0
                                textFromValue: v => v + " ms"
                                valueFromText: t => parseInt(t)
                                onValueModified: root.mutate(m => { m[step.index].ms = value; })
                            }
                            Button { text: "↑"; enabled: step.index > 0; onClicked: root.mutate(m => { const t = m[step.index - 1]; m[step.index - 1] = m[step.index]; m[step.index] = t; }) }
                            Button {
                                text: "↓"
                                enabled: step.index < root.list[root.slot].length - 1
                                onClicked: root.mutate(m => { const t = m[step.index + 1]; m[step.index + 1] = m[step.index]; m[step.index] = t; })
                            }
                            Button { text: "✕"; onClicked: root.mutate(m => { m.splice(step.index, 1); }) }
                        }
                    }
                    RowLayout {
                        spacing: 8
                        Label { text: "Add step"; opacity: 0.7 }
                        Repeater {
                            model: root.kinds
                            delegate: Button {
                                required property var modelData
                                text: modelData.name
                                onClicked: root.mutate(m => m.push(modelData.kind === "text" ? { kind: "text", text: "" }
                                    : modelData.kind === "delay" ? { kind: "delay", ms: 100 } : { kind: modelData.kind, code: 0x28 }))
                            }
                        }
                    }
                }
            }
            RowLayout {
                Label { text: root.used + " of " + root.size + " bytes used by all macros"; opacity: 0.7 }
                ProgressBar { Layout.fillWidth: true; from: 0; to: Math.max(1, root.size); value: root.used }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.list.length === 0
        text: backend.connected ? "Could not read the macros." : "Connect the keyboard to edit macros."
        opacity: 0.6
    }
}
