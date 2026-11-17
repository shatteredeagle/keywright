import QtQuick
import QtQuick.Controls

// variant: "primary" | "secondary" | "ghost". `chip` makes a compact toggle-style pill.
Button {
    id: c
    property string variant: "secondary"
    property string iconName: ""
    property bool chip: false
    property bool selected: false
    implicitHeight: chip ? 30 : 36
    leftPadding: chip ? 12 : 14
    rightPadding: chip ? 12 : 14
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45

    readonly property color fg: variant === "danger" ? "#ffffff" : variant === "primary" && !chip ? Theme.accentText
        : selected ? Theme.accentHi : Theme.text

    contentItem: Row {
        spacing: 8
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Icon { visible: c.iconName !== ""; name: c.iconName; color: c.fg; size: 16; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: c.text
            visible: c.text !== ""
            color: c.fg
            font.pixelSize: 13
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    background: Rectangle {
        radius: c.chip ? height / 2 : Theme.radiusSmall
        color: {
            if (c.variant === "danger") return c.down || c.hovered ? Qt.darker(Theme.danger, 1.15) : Theme.danger;
            if (c.variant === "primary" && !c.chip) return c.down ? Theme.accentHi : c.hovered ? Theme.accentHi : Theme.accent;
            if (c.selected) return Theme.accentSoft;
            if (c.variant === "ghost") return c.hovered ? Theme.panelHi : "transparent";
            return c.down ? Theme.line : c.hovered ? Theme.panelHi : Theme.panel;
        }
        border.width: c.variant === "ghost" || c.variant === "danger" || (c.variant === "primary" && !c.chip) ? 0 : 1
        border.color: c.selected ? Theme.accent : Theme.line
        Behavior on color { ColorAnimation { duration: 110 } }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
