// components/VlanPanel.qml

import QtQuick

// ============================================================
// VLAN PANEL — bar icon button for the VLAN dropdown.
// ============================================================
Item {
    id: root

    property string fontFamily: config.fontFamily
    property int    iconSize:   24

    property bool   isActive:    false
    property color  accentColor: "white"
    property color  activeColor: "white"
    property color  hoverColor:  accentColor

    property bool   _hovered: false

    signal clicked(real clickX)

    width:  iconSize + 4
    height: 24

    Text {
        anchors.centerIn: parent
        text:           "󰲝"
        font.family:    root.fontFamily
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
