import Quickshell
import Quickshell.Services.UPower
import QtQuick

Rectangle {
    id: powerProfilePanel

    property string fontFamily:      config.fontFamily
    property int    iconSize:        14
    property int    fontWeight:      config.fontWeight

    property bool   isActive:        false
    property color  accentColor:     colors.col_primary
    property color  activeColor:     colors.col_source_color
    property color  hoverColor:      colors.col_source_color
    property color  dimColor:        Qt.rgba(1, 1, 1, 0.4)

    property color  backgroundColor: "transparent"
    property color  borderColor:     "transparent"
    property bool   _hovered:        false
    property var icons: ({
        "power-saver": "󰌪",
        "balanced":    "",
        "performance":  ""
    })

    // Derived from the reactive PowerProfiles singleton — no polling needed
    readonly property string currentProfile: {
        switch (PowerProfiles.profile) {
            case PowerProfile.PowerSaver:  return "power-saver"
            case PowerProfile.Balanced:    return "balanced"
            case PowerProfile.Performance: return "performance"
            default:                       return ""
        }
    }
    width: 30
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 1

    Text {
        id: iconText
        anchors.centerIn: parent
        color: powerProfilePanel.isActive ? powerProfilePanel.activeColor : powerProfilePanel._hovered ? powerProfilePanel.hoverColor : powerProfilePanel.accentColor
        font.family: fontFamily
        font.pixelSize: iconSize
        font.weight: fontWeight
        text: icons[currentProfile] || "?"
        opacity: 1.0
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    signal clicked(real clickX)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: powerProfilePanel._hovered = true
        onExited:  powerProfilePanel._hovered = false
        onClicked: {
            var pos = powerProfilePanel.mapToItem(null, 0, 0)
            powerProfilePanel.clicked(pos.x + powerProfilePanel.width / 2)
        }
    }

}
