import QtQuick

// ============================================================
// DASHBOARD BUTTON — bar icon that opens the dashboard dropdown.
// Follows the same pattern as SettingsButton, NotifButton, etc.
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

    width:  25
    height: 24

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text: "󱇘"   // nf-md-view_dashboard
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
