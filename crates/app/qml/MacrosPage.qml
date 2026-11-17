import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Edit the keyboard's macro slots: typed text, key taps/holds, and waits.
Item {
    id: root
    property var backend
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
        if (!m.length) return "Empty";
        return m.map(a => a.kind === "text" ? esc(a.text) : a.kind === "delay" ? a.ms + "ms"
            : (a.kind === "tap" ? "" : a.kind === "down" ? "↓" : "↑") + keyName(a.code)).join("  ");
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
        if (err === "") { refresh(); message = "Saved to the keyboard."; }
        else message = err;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 18
        visible: root.list.length > 0

        PageHeader {
            Layout.fillWidth: true
            title: "Macros"
            subtitle: "Replay text or key presses with a single key. Assign a macro on the Keymap page."
            Text { text: root.message; color: Theme.dim; font.pixelSize: 13 }
            KButton { text: "Discard"; iconName: "undo"; enabled: root.dirty; onClicked: root.refresh() }
            KButton { text: "Save to keyboard"; iconName: "save"; variant: "primary"; enabled: root.dirty; onClicked: root.save() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            // Slot list
            Card {
                Layout.preferredWidth: 270
                Layout.fillHeight: true
                padding: 10
                ListView {
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    model: root.list.length
                    delegate: Rectangle {
                        id: slotItem
                        required property int index
                        readonly property bool active: root.slot === index
                        width: ListView.view.width
                        height: 52
                        radius: 10
                        color: active ? Theme.accentSoft : sh.hovered ? Theme.panelHi : "transparent"
                        border.color: active ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: 110 } }
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14; anchors.rightMargin: 14
                            spacing: 0
                            Item { Layout.fillHeight: true }
                            Text { text: "Macro " + slotItem.index; color: slotItem.active ? Theme.accentHi : Theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Text { text: root.summary(root.list[slotItem.index]); elide: Text.ElideRight; Layout.fillWidth: true; color: Theme.faint; font.pixelSize: 12 }
                            Item { Layout.fillHeight: true }
                        }
                        HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.slot = slotItem.index }
                    }
                    ScrollBar.vertical: KScrollBar {}
                }
            }

            // Editor
            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 14
                    RowLayout {
                        Text { text: "Macro " + root.slot; color: Theme.text; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        Text { text: "Assign with the “Macro " + root.slot + "” key in the picker"; color: Theme.faint; font.pixelSize: 12 }
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: availableWidth
                ScrollBar.vertical: KScrollBar {}
                        clip: true
                        ColumnLayout {
                            width: parent.width
                            spacing: 8
                            Text {
                                visible: root.list.length > root.slot && root.list[root.slot].length === 0
                                text: "This macro is empty. Add a step below."
                                color: Theme.faint; font.pixelSize: 13
                            }
                            Repeater {
                                model: root.list.length > root.slot ? root.list[root.slot].length : 0
                                delegate: Rectangle {
                                    id: step
                                    required property int index
                                    readonly property var act: root.list[root.slot][index]
                                    Layout.fillWidth: true
                                    implicitHeight: 54
                                    radius: 10
                                    color: Theme.panelHi
                                    border.color: Theme.line
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 8
                                        spacing: 10
                                        Rectangle {
                                            width: 24; height: 24; radius: 12; color: Theme.field; border.color: Theme.line
                                            Text { anchors.centerIn: parent; text: step.index + 1; color: Theme.dim; font.pixelSize: 11; font.weight: Font.DemiBold }
                                        }
                                        KCombo {
                                            Layout.preferredWidth: 140
                                            model: root.kinds.map(k => k.name)
                                            currentIndex: root.kinds.findIndex(k => k.kind === step.act.kind)
                                            onActivated: i => root.mutate(m => {
                                                const k = root.kinds[i].kind;
                                                m[step.index] = k === "text" ? { kind: k, text: "" } : k === "delay" ? { kind: k, ms: 100 } : { kind: k, code: 0x04 };
                                            })
                                        }
                                        KField {
                                            visible: step.act.kind === "text"
                                            Layout.fillWidth: true
                                            placeholderText: "Text to type (\\n for Enter, \\t for Tab)"
                                            text: step.act.kind === "text" ? root.esc(step.act.text) : ""
                                            onTextEdited: { step.act.text = root.unesc(text); root.dirty = true; root.list[root.slot][step.index].text = step.act.text; }
                                        }
                                        KCombo {
                                            visible: step.act.kind === "tap" || step.act.kind === "down" || step.act.kind === "up"
                                            Layout.fillWidth: true
                                            model: root.keyChoices.map(c => c.group + " · " + c.label)
                                            currentIndex: root.keyChoices.findIndex(c => c.code === step.act.code)
                                            onActivated: i => root.mutate(m => { m[step.index].code = root.keyChoices[i].code; })
                                        }
                                        KSpin {
                                            visible: step.act.kind === "delay"
                                            implicitWidth: 170
                                            from: 0; to: 60000; stepSize: 50
                                            value: step.act.kind === "delay" ? step.act.ms : 0
                                            textFromValue: v => v + " ms"
                                            valueFromText: t => parseInt(t)
                                            onValueModified: root.mutate(m => { m[step.index].ms = value; })
                                        }
                                        Item { visible: step.act.kind === "delay"; Layout.fillWidth: true }
                                        KButton { iconName: "arrow-up"; variant: "ghost"; implicitWidth: 34; leftPadding: 0; rightPadding: 0; enabled: step.index > 0
                                            onClicked: root.mutate(m => { const t = m[step.index - 1]; m[step.index - 1] = m[step.index]; m[step.index] = t; }) }
                                        KButton { iconName: "arrow-down"; variant: "ghost"; implicitWidth: 34; leftPadding: 0; rightPadding: 0
                                            enabled: step.index < root.list[root.slot].length - 1
                                            onClicked: root.mutate(m => { const t = m[step.index + 1]; m[step.index + 1] = m[step.index]; m[step.index] = t; }) }
                                        KButton { iconName: "x"; variant: "ghost"; implicitWidth: 34; leftPadding: 0; rightPadding: 0; onClicked: root.mutate(m => { m.splice(step.index, 1); }) }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.topMargin: 6
                                spacing: 8
                                Text { text: "Add step"; color: Theme.dim; font.pixelSize: 13 }
                                Repeater {
                                    model: root.kinds
                                    delegate: KButton {
                                        required property var modelData
                                        text: modelData.name
                                        iconName: "plus"
                                        chip: true
                                        onClicked: root.mutate(m => m.push(modelData.kind === "text" ? { kind: "text", text: "" }
                                            : modelData.kind === "delay" ? { kind: "delay", ms: 100 } : { kind: modelData.kind, code: 0x28 }))
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        spacing: 12
                        Text { text: root.used + " of " + root.size + " bytes used"; color: Theme.faint; font.pixelSize: 12 }
                        Rectangle {
                            Layout.fillWidth: true; height: 6; radius: 3; color: Theme.field; border.color: Theme.line
                            Rectangle { width: Math.max(6, parent.width * root.used / Math.max(1, root.size)); height: parent.height; radius: 3; color: Theme.accent }
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.list.length === 0
        text: backend.connected ? "Could not read the macros." : "Connect the keyboard to edit macros."
        color: Theme.dim
        font.pixelSize: 14
    }
}
