import QtQuick
import "../.."

// ============================================================
// POMODORO BUTTON — shows a timer icon or live mm:ss countdown.
// ============================================================
Item {
    id: root

    property string fontFamily: config.fontFamily
    property int    fontWeight: config.fontWeight
    property int    iconSize:   14

    property bool   isActive:   false
    property bool   isRunning:  false
    property int    remainingSeconds: 0

    property color  accentColor: Colors.col_primary
    property color  activeColor: Colors.col_source_color
    property color  hoverColor:  Colors.col_source_color

    property bool   _hovered: false

    signal clicked(real clickX)

    readonly property bool showCountdown: isRunning && remainingSeconds > 0

    function fmtTime(seconds) {
        var safe = Math.max(0, seconds)
        var mins = Math.floor(safe / 60)
        var secs = safe % 60
        return String(mins).padStart(2, "0") + ":" + String(secs).padStart(2, "0")
    }

    width: showCountdown ? 54 : 18
    height: 24

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text: root.showCountdown ? root.fmtTime(root.remainingSeconds) : "P"
        font.family: root.fontFamily
        font.weight: root.fontWeight
        font.pixelSize: root.showCountdown ? 11 : root.iconSize
        color: root.isActive ? root.activeColor
             : root._hovered ? root.hoverColor
             : root.showCountdown ? root.activeColor
             : root.accentColor
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: root._hovered = true
        onExited: root._hovered = false
        onClicked: {
            var pos = root.mapToItem(null, 0, 0)
            root.clicked(pos.x + root.width / 2)
        }
    }
}
