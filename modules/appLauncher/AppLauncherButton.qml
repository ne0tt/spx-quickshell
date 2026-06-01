import QtQuick
import "../.."

Rectangle {
    id: launcherButton

    property string fontFamily:      config.fontFamily
    property int    iconSize:        24
    property int    fontWeight:      config.fontWeight

    property bool   isActive:        false
    property color  accentColor:     Colors.col_source_color
    property color  activeColor:     Colors.col_source_color
    property color  hoverColor:      Colors.col_source_color

    property color  backgroundColor: "transparent"
    property color  borderColor:     "transparent"
    property bool   _hovered:        false

    readonly property string launcherIcon: "󰀻"

    signal clicked(real clickX)

    width: 24
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 0

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.verticalCenter: parent.verticalCenter
        text: launcherButton.launcherIcon
        font.family: launcherButton.fontFamily
        font.pixelSize: launcherButton.iconSize
        font.weight: launcherButton.fontWeight
        color: launcherButton.isActive
            ? launcherButton.activeColor
            : launcherButton._hovered
                ? launcherButton.hoverColor
                : launcherButton.accentColor
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: launcherButton._hovered = true
        onExited:  launcherButton._hovered = false
        onClicked: {
            var pos = launcherButton.mapToItem(null, 0, 0)
            launcherButton.clicked(pos.x + launcherButton.width / 2)
        }
    }
}