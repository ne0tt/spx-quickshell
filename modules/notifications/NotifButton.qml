import QtQuick

// ============================================================
// NOTIF BUTTON — bar bell icon that opens the notification
// history dropdown. Shows a count badge when notifications exist.
// ============================================================
Item {
    id: root

    property string fontFamily:  config.fontFamily
    property int    fontWeight:  config.fontWeight
    property int    iconSize:    15

    property bool   isActive:    false

    property color  accentColor: colors.col_primary
    property color  activeColor: colors.col_source_color
    property color  hoverColor:  colors.col_source_color

    property bool   _hovered:    false

    signal clicked(real clickX)

    readonly property int _count: NotifService.list.filter(n => !n.closed).length

    width:  24
    height: 24

    // Bell icon
    Text {
        id: icon
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text:           "󰂚"
        font.family:    root.fontFamily
        font.weight:    root.fontWeight
        font.pixelSize: root.iconSize
        color: root.isActive ? root.activeColor
             : root._hovered ? root.hoverColor
             :                 root.accentColor
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    // Count badge — visible when there are unread notifications
    Rectangle {
        id: badge

        visible:      root._count > 0
        anchors.top:  parent.top
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.rightMargin: -2

        width:  badgeText.implicitWidth + 4
        height: 12
        radius: 6
        color:  colors.col_source_color

        Text {
            id: badgeText
            anchors.centerIn: parent
            text:           root._count > 9 ? "9+" : root._count
            font.family:    root.fontFamily
            font.pixelSize: 8
            font.bold:      true
            color:          colors.col_background
        }
    }

    MouseArea {
        anchors.fill:  parent
        hoverEnabled:  true
        cursorShape:   Qt.PointingHandCursor
        onEntered:     root._hovered = true
        onExited:      root._hovered = false
        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }
    }
}
