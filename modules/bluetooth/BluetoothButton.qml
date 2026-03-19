import QtQuick

// ============================================================
// BLUETOOTH BUTTON — bar icon showing BT power state.
// ============================================================
Item {
    id: root

    property string fontFamily: config.fontFamily
    property int    fontWeight: config.fontWeight
    property int    iconSize:   18

    property bool   btPowered:  false
    property bool   isActive:   false   // true when the dropdown is open

    property color  accentColor: colors.col_primary      // powered + dropdown closed
    property color  activeColor: colors.col_source_color  // dropdown open
    property color  hoverColor:  colors.col_source_color  // mouse hover
    property color  dimColor:    Qt.rgba(colors.col_primary.r, colors.col_primary.g, colors.col_primary.b, 0.4)  // BT off

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
        font.weight:    root.fontWeight
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
