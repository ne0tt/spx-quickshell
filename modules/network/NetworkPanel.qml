// components/NetworkPanel.qml

import QtQuick

// ============================================================
// NETWORK PANEL — bar pill showing the active Ethernet IP.
// Hidden when no IP is available.
// ============================================================
Item {
    id: root

    property string fontFamily:      config.fontFamily
    property int    fontSize:        config.fontSize
    property int    iconSize:        16
    property int    fontWeight:      config.fontWeight

    property string ip:              ""

    property bool   isActive:        false
    property color  accentColor:     colors.col_primary
    property color  activeColor:     colors.col_source_color
    property color  hoverColor:      colors.col_source_color
    property color  backgroundColor: colors.col_background

    property bool   _hovered: false

    signal clicked(real clickX)

    width:   visible ? pill.width : 0
    height:  24
    visible: ip !== "—" && ip !== ""

    // ── Pill background ──────────────────────────────────────
    Rectangle {
        id: pill
        width:        150
        height:       24
        radius:       7
        color:        root.backgroundColor
        border.color: "black"
        border.width: 1

        Row {
            id: pillRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            spacing: 5

            Text {
                id: netIcon
                text:           "󰈀"
                font.family:    root.fontFamily
                font.pixelSize: root.iconSize
                color:          root.isActive || root._hovered ? root.activeColor : root.accentColor
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Text {
                id: ipLabel
                text:           root.ip
                font.family:    root.fontFamily
                font.pixelSize: root.fontSize
                font.weight:    root.fontWeight
                color:          root.isActive || root._hovered ? root.activeColor : root.accentColor
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }

    // ── Interaction ──────────────────────────────────────────
    MouseArea {
        anchors.fill:  parent
        cursorShape:   Qt.PointingHandCursor
        hoverEnabled:  true
        onEntered:     root._hovered = true
        onExited:      root._hovered = false
        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }
    }
}
