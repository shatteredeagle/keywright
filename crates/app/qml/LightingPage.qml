import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Backlight controls. Changes apply live; "Save to keyboard" makes them survive a power cycle.
Item {
    id: root
    property var backend
    property var pal
    property var state: null   // {brightness, effect, speed, hue, saturation, effects:[{name,id}]}
    property bool dirty: false
    property bool saved: false
    property int hueVal: 0
    property int satVal: 0

    function refresh() {
        const raw = backend.rgb();
        state = raw === "null" ? null : JSON.parse(raw);
        if (state) { hueVal = state.hue; satVal = state.saturation; }
        dirty = false;
        saved = false;
    }
    onVisibleChanged: if (visible && backend.connected) refresh()
    Component.onCompleted: if (backend.connected) refresh()

    function put(field, value) {
        if (backend.set_rgb(field, value)) { state[field] = value; dirty = true; saved = false; }
    }
    function putColor(hue, sat) {
        if (backend.set_rgb_color(hue, sat)) { hueVal = hue; satVal = sat; dirty = true; saved = false; }
    }

    // A labelled slider row.
    component Row2: RowLayout {
        property alias label: lbl.text
        property alias slider: sl
        property string valueText: Math.round(sl.value)
        property alias from: sl.from
        property alias to: sl.to
        property alias value: sl.value
        signal moved(real v)
        Layout.fillWidth: true
        spacing: 16
        Label { id: lbl; Layout.preferredWidth: 110; opacity: 0.8 }
        Slider {
            id: sl
            Layout.fillWidth: true
            from: 0; to: 255; stepSize: 1
            onMoved: parent.moved(value)
        }
        Label { text: parent.valueText; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight; opacity: 0.7 }
    }

    readonly property color swatch: Qt.hsva(hueVal / 255, satVal / 255, 1, 1)

    ColumnLayout {
        visible: root.state !== null
        width: Math.min(parent.width - 40, 720)
        x: 20; y: 20
        spacing: 22

        Label { text: "Backlight"; font.bold: true; font.pixelSize: 22 }

        RowLayout {
            spacing: 16
            Label { text: "Effect"; Layout.preferredWidth: 110; opacity: 0.8 }
            ComboBox {
                Layout.fillWidth: true
                model: root.state ? root.state.effects.map(e => e.name) : []
                currentIndex: root.state ? root.state.effects.findIndex(e => e.id === root.state.effect) : -1
                onActivated: i => root.put("effect", root.state.effects[i].id)
            }
        }

        Row2 {
            label: "Brightness"
            value: root.state ? root.state.brightness : 0
            valueText: Math.round(value / 255 * 100) + "%"
            onMoved: v => root.put("brightness", Math.round(v))
        }
        Row2 {
            label: "Effect speed"
            value: root.state ? root.state.speed : 0
            valueText: Math.round(value / 255 * 100) + "%"
            onMoved: v => root.put("speed", Math.round(v))
        }

        // Colour: hue and saturation, with a live swatch.
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            Label { text: "Colour"; Layout.preferredWidth: 110; opacity: 0.8; Layout.alignment: Qt.AlignTop }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 14
                Slider {
                    id: hue
                    Layout.fillWidth: true
                    from: 0; to: 255; stepSize: 1
                    value: root.hueVal
                    onMoved: root.putColor(Math.round(value), root.satVal)
                    background: Rectangle {
                        y: hue.height / 2 - 5; height: 10; radius: 5; width: hue.availableWidth; x: hue.leftPadding
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.00; color: "#ff0000" }
                            GradientStop { position: 0.17; color: "#ffff00" }
                            GradientStop { position: 0.33; color: "#00ff00" }
                            GradientStop { position: 0.50; color: "#00ffff" }
                            GradientStop { position: 0.67; color: "#0000ff" }
                            GradientStop { position: 0.83; color: "#ff00ff" }
                            GradientStop { position: 1.00; color: "#ff0000" }
                        }
                    }
                }
                Slider {
                    id: sat
                    Layout.fillWidth: true
                    from: 0; to: 255; stepSize: 1
                    value: root.satVal
                    onMoved: root.putColor(root.hueVal, Math.round(value))
                    background: Rectangle {
                        y: sat.height / 2 - 5; height: 10; radius: 5; width: sat.availableWidth; x: sat.leftPadding
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#ffffff" }
                            GradientStop { position: 1; color: Qt.hsva(root.hueVal / 255, 1, 1, 1) }
                        }
                    }
                }
            }
            Rectangle {
                Layout.preferredWidth: 64; Layout.preferredHeight: 64; radius: 12
                Layout.alignment: Qt.AlignTop
                color: root.swatch
                border.color: Qt.rgba(0, 0, 0, 0.25)
            }
        }

        RowLayout {
            spacing: 14
            Button {
                text: "Save to keyboard"
                highlighted: root.dirty
                enabled: root.dirty
                onClicked: if (backend.save_rgb()) { root.dirty = false; root.saved = true; }
            }
            Label {
                text: root.dirty ? "Applied now. Save to keep it after the keyboard powers off."
                    : root.saved ? "Saved." : ""
                opacity: 0.7
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.state === null
        text: backend.connected ? "Could not read the lighting settings." : "Connect the keyboard to change lighting."
        opacity: 0.6
    }
}
