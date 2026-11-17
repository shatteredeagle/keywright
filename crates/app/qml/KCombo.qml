import QtQuick
import QtQuick.Controls

ComboBox {
    id: c
    implicitHeight: 36
    implicitWidth: 180
    hoverEnabled: true
    font.pixelSize: 13

    contentItem: Text {
        leftPadding: 12
        rightPadding: 30
        text: c.displayText
        font: c.font
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Icon {
        x: c.width - width - 10
        y: (c.height - height) / 2
        name: "chevron-down"; size: 16; color: Theme.dim
    }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: Theme.field
        border.width: 1
        border.color: c.popup.visible || c.activeFocus ? Theme.accent : c.hovered ? Theme.lineStrong : Theme.line
        Behavior on border.color { ColorAnimation { duration: 110 } }
    }
    delegate: ItemDelegate {
        id: d
        required property int index
        required property var modelData
        width: c.width - 8
        height: 34
        highlighted: c.highlightedIndex === index
        contentItem: Text {
            text: typeof d.modelData === "string" ? d.modelData : (d.modelData[c.textRole] !== undefined ? d.modelData[c.textRole] : d.modelData)
            color: c.currentIndex === d.index ? Theme.accentHi : Theme.text
            font: c.font
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle { radius: 6; color: d.highlighted ? Theme.panelHi : "transparent" }
    }
    popup: Popup {
        y: c.height + 4
        width: c.width
        padding: 4
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 340)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: c.popup.visible ? c.delegateModel : null
            currentIndex: c.highlightedIndex
            ScrollBar.vertical: ScrollBar {}
        }
        background: Rectangle {
            radius: Theme.radiusSmall + 2
            color: Theme.panel
            border.color: Theme.lineStrong
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
