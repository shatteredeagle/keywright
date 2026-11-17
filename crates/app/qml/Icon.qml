import QtQuick
import QtQuick.Shapes

// 24x24 stroke icons, drawn from SVG path data so they follow the theme colours.
Item {
    id: root
    property string name: ""
    property color color: "#ffffff"
    property real size: 18
    property real weight: 1.8
    implicitWidth: size
    implicitHeight: size

    readonly property var paths: ({
        "keyboard": "M3 7h18a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1z M6 10.5h.01 M10 10.5h.01 M14 10.5h.01 M18 10.5h.01 M7 14h10",
        "sun": "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z M12 2.5v2 M12 19.5v2 M4.6 4.6l1.4 1.4 M18 18l1.4 1.4 M2.5 12h2 M19.5 12h2 M4.6 19.4L6 18 M18 6l1.4-1.4",
        "macro": "M4 17l6-6-6-6 M12 19h8",
        "list": "M8 6h13 M8 12h13 M8 18h13 M3.5 6h.01 M3.5 12h.01 M3.5 18h.01",
        "chevron-down": "M6 9l6 6 6-6",
        "chevron-up": "M6 15l6-6 6 6",
        "refresh": "M21 12a9 9 0 1 1-2.6-6.4 M21 3v6h-6",
        "plus": "M12 5v14 M5 12h14",
        "minus": "M5 12h14",
        "x": "M6 6l12 12 M18 6L6 18",
        "arrow-up": "M12 19V5 M5 12l7-7 7 7",
        "arrow-down": "M12 5v14 M19 12l-7 7-7-7",
        "check": "M5 12.5l4.5 4.5L19 7",
        "knob": "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M12 7v5",
        "save": "M5 4h11l3 3v13H5z M8 4v5h7V4 M8 20v-6h8v6",
        "undo": "M9 14L4 9l5-5 M4 9h10a6 6 0 0 1 0 12h-3",
        "bolt": "M13 3L5 14h6l-1 7 8-11h-6z",
        "usb": "M12 3v13 M12 16a2 2 0 1 0 0 4 2 2 0 0 0 0-4z M12 9l4-2v-2 M12 12l-4-2v-3",
        "wifi": "M3 9a14 14 0 0 1 18 0 M6 12.5a9.5 9.5 0 0 1 12 0 M9.5 16a5 5 0 0 1 5 0 M12 19.5h.01",
        "play": "M7 4l13 8-13 8z",
        "palette": "M12 3a9 9 0 1 0 0 18c1.2 0 2-.8 2-1.8 0-.5-.3-.9-.5-1.3-.3-.5-.1-1.2.6-1.2H17a4 4 0 0 0 4-4C21 6.9 17 3 12 3z M7.5 11h.01 M10 7.5h.01 M14 7.5h.01 M16.5 11h.01"
    })

    Shape {
        width: 24; height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.weight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.paths[root.name] || "" }
        }
    }
}
