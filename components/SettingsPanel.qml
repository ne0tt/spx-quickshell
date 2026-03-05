import QtQuick

// ============================================================
// SETTINGS PANEL — bar icon that opens the settings dropdown.
// Follows the same pattern as BluetoothPanel, VolumePanel, etc.
// ============================================================
Item {
    id: root

    property string fontFamily:  config.fontFamily
    property int    iconSize:    15

    property bool   isActive:    false   // true when the dropdown is open

    property color  accentColor: "white"
    property color  activeColor: "white"
    property color  hoverColor:  accentColor

    property bool   _hovered:    false

    signal clicked(real clickX)

    width:  20
    height: 24

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text: "󰒓"   // nf-md-cog nerd-font glyph
        font.family:    root.fontFamily
        font.styleName: "Solid"
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
