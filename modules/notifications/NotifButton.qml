import QtQuick
import "../.."

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

    property color  accentColor: Colors.col_primary
    property color  activeColor: Colors.col_source_color
    property color  hoverColor:  Colors.col_source_color

    property bool   _hovered:    false

    signal clicked(real clickX)

    readonly property int _count: NotifService.list.filter(n => !n.closed).length
    property int _prevCount: 0

    on_CountChanged: {
        if (_count > _prevCount && _prevCount >= 0) {
            bellFlashAnim.stop();
            icon.color = root.accentColor;
            bellFlashAnim.start();
        }
        _prevCount = _count;
    }

    width:  20
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

    // Flash the bell when a new notification arrives
    SequentialAnimation {
        id: bellFlashAnim
        loops: 4
        ColorAnimation { target: icon; property: "color"; to: "white";            duration: 200 }
        ColorAnimation { target: icon; property: "color"; to: root.accentColor;   duration: 200 }
        onStopped: icon.color = Qt.binding(() =>
            root.isActive ? root.activeColor
          : root._hovered ? root.hoverColor
          :                 root.accentColor
        )
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
        color:  Colors.col_source_color

        Text {
            id: badgeText
            anchors.centerIn: parent
            text:           root._count > 9 ? "9+" : root._count
            font.family:    root.fontFamily
            font.pixelSize: 8
            font.bold:      true
            color:          Colors.col_background
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
