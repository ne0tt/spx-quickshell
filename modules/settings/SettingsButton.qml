import QtQuick
import "../.."

// ============================================================
// SETTINGS BUTTON — bar icon that opens the settings dropdown.
// Follows the same pattern as BluetoothButton, VolumeButton, etc.
// ============================================================
Item {
    id: root

    property string fontFamily:  config.fontFamily
    property int    fontWeight:  config.fontWeight
    property int    iconSize:    15

    property bool   isActive:    false   // true when the dropdown is open

    property color  accentColor: Colors.col_primary
    property color  activeColor: Colors.col_source_color
    property color  hoverColor:  Colors.col_source_color

    property bool   _hovered:    false

    signal clicked(real clickX)

    width:  15
    height: 24

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text: "󰒓"   // nf-md-cog nerd-font glyph
        font.family:    root.fontFamily
        font.styleName: "Solid"
        font.weight:    root.fontWeight
        font.pixelSize: root.iconSize
        color: root.isActive  ? root.activeColor
             : root._hovered  ? root.hoverColor
             :                  root.accentColor
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: root._hovered = true
        onExited:  root._hovered = false
        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }
    }
}
