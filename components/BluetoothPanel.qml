import QtQuick

// ============================================================
// BLUETOOTH PANEL — bar icon showing BT power state.
// ============================================================
Item {
    id: root

    property string fontFamily: config.fontFamily
    property int    iconSize:   20

    property bool   btPowered:  false
    property bool   isActive:   false   // true when the dropdown is open

    property color  accentColor: "white"        // powered + dropdown closed
    property color  activeColor: "white"        // dropdown open
    property color  hoverColor:  accentColor    // mouse hover
    property color  dimColor:    Qt.rgba(1, 1, 1, 0.4)  // BT off

    property bool   _hovered:   false

    signal clicked(real clickX)

    width:  20
    height: 24

    Text {
        id: btIcon
        anchors.centerIn: parent
        text: root.btPowered ? "" : "󰂯"
        font.family:    root.fontFamily
        font.styleName: "Solid"
        font.pixelSize: root.iconSize
        color: root.isActive  ? root.activeColor
             : root._hovered  ? root.hoverColor
             : root.btPowered ? root.accentColor
             :                  root.dimColor
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: root._hovered = true
        onExited:  root._hovered = false
        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }
    }
}
