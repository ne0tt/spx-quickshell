// components/WallpaperPanel.qml

import QtQuick

// ============================================================
// WALLPAPER PANEL — bar icon button for the wallpaper picker.
// ============================================================
Item {
    id: root

    property string fontFamily: config.fontFamily
    property int    fontWeight: config.fontWeight
    property int    iconSize:   16

    property bool   isActive:    false
    property color  accentColor: colors.col_primary
    property color  activeColor: colors.col_source_color
    property color  hoverColor:  colors.col_source_color

    property bool   _hovered: false

    signal clicked(real clickX)

    width:  iconSize + 4
    height: 24

    Text {
        anchors.centerIn: parent
        text:           "󰸉"
        font.family:    root.fontFamily
        font.weight:    root.fontWeight
        font.pixelSize: root.iconSize
        color: root.isActive || root._hovered ? root.activeColor : root.accentColor
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        hoverEnabled: true
        onEntered:    root._hovered = true
        onExited:     root._hovered = false
        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }
    }
}
