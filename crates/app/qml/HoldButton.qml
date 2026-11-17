import QtQuick

// A button that only fires after being held down, so a stray click cannot trigger it. Mouse only,
// because the keyboard being configured may be unusable while it is flashed.
Item {
    id: h
    property string text: "Hold to confirm"
    property int holdMs: 2000
    property real progress: 0
    signal activated()
    implicitWidth: 230
    implicitHeight: 40
    opacity: enabled ? 1 : 0.45

    Rectangle {
        id: face
        anchors.fill: parent
        radius: Theme.radiusSmall
        color: Theme.danger
        clip: true
        Rectangle {
            width: parent.width * h.progress; height: parent.height
            color: Qt.darker(Theme.danger, 1.5)
        }
        Text {
            anchors.centerIn: parent
            text: h.progress > 0 ? "Keep holding…" : h.text
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
    NumberAnimation { id: hold; target: h; property: "progress"; from: 0; to: 1; duration: h.holdMs
        onFinished: { if (h.progress >= 1) h.activated(); h.progress = 0; } }
    MouseArea {
        anchors.fill: parent
        enabled: h.enabled
        cursorShape: Qt.PointingHandCursor
        onPressed: hold.restart()
        onReleased: { hold.stop(); h.progress = 0; }
        onCanceled: { hold.stop(); h.progress = 0; }
    }
}
