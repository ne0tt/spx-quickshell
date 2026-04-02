import QtQuick
import "../.."

Rectangle {
    id: powerButton

    property string fontFamily:      config.fontFamily
    property int    iconSize:        16
    property int    fontWeight:      config.fontWeight

    property bool   isActive:        false
    property color  accentColor:     Colors.col_primary
    property color  activeColor:     "#ff0000"
    property color  hoverColor:      "#ff0000"

    property color  backgroundColor: "transparent"
    property color  borderColor:     "transparent"
    property bool   _hovered:        false

    readonly property string powerIcon: ""

    signal clicked(real clickX)

    width: 10
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: powerButton.powerIcon
        font.family: powerButton.fontFamily
        font.pixelSize: powerButton.iconSize
        font.weight: powerButton.fontWeight
        color: powerButton.isActive
            ? powerButton.activeColor
            : powerButton._hovered
                ? powerButton.hoverColor
                : powerButton.accentColor
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: powerButton._hovered = true
        onExited:  powerButton._hovered = false
        onClicked: {
            var pos = powerButton.mapToItem(null, 0, 0)
            powerButton.clicked(pos.x + powerButton.width / 2)
        }
    }
}
