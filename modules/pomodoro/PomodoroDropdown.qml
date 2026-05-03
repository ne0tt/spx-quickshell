import Quickshell
import Quickshell.Wayland
import QtQuick
import "../.."
import "../../base"

// ============================================================
// POMODORO DROPDOWN — work/break timer with configurable lengths.
// ============================================================
DropdownBase {
    id: pomo
    reloadableId: "pomodoroDropdown"

    keyboardFocusEnabled: true

    panelWidth:      380
    panelFullHeight: 262
    panelTitle:      "Pomodoro"
    panelIcon:       "P"
    panelTitleRight: pomo.modeLabel
    headerHeight:    34

    property int workMinutes:       25
    property int shortBreakMinutes: 5
    property int longBreakMinutes:  15

    property int remainingSeconds: 0
    property int totalSeconds:     0
    property bool timerRunning:    false
    property string mode:          "work"

    readonly property string modeLabel: {
        if (mode === "shortBreak") return "Short break"
        if (mode === "longBreak") return "Long break"
        return "Work"
    }

    readonly property real progress: totalSeconds > 0
        ? Math.max(0, Math.min(1, remainingSeconds / totalSeconds))
        : 0

    function fmtTime(seconds) {
        var safe = Math.max(0, seconds)
        var mins = Math.floor(safe / 60)
        var secs = safe % 60
        return String(mins).padStart(2, "0") + ":" + String(secs).padStart(2, "0")
    }

    function _sessionSeconds(which) {
        if (which === "shortBreak") return Math.max(1, shortBreakMinutes) * 60
        if (which === "longBreak") return Math.max(1, longBreakMinutes) * 60
        return Math.max(1, workMinutes) * 60
    }

    function startSession(which) {
        mode = which
        totalSeconds = _sessionSeconds(which)
        remainingSeconds = totalSeconds
        timerRunning = true
    }

    function toggleRunPause() {
        if (remainingSeconds <= 0 || totalSeconds <= 0)
            startSession(mode)
        else
            timerRunning = !timerRunning
    }

    function resetSession() {
        timerRunning = false
        totalSeconds = _sessionSeconds(mode)
        remainingSeconds = totalSeconds
    }

    onAboutToOpen: {
        if (totalSeconds <= 0)
            resetSession()
    }

    Timer {
        interval: 1000
        repeat: true
        running: pomo.timerRunning
        onTriggered: {
            if (pomo.remainingSeconds > 0) {
                pomo.remainingSeconds -= 1
            }
            if (pomo.remainingSeconds <= 0) {
                pomo.remainingSeconds = 0
                pomo.timerRunning = false
            }
        }
    }

    Item {
        focus: true
        Keys.onEscapePressed: pomo.closePanel()
    }

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 0
        spacing: 10

        readonly property int sidePad: 30
        readonly property real innerWidth: width - (2 * sidePad)

        Rectangle {
            x: contentColumn.sidePad
            width: contentColumn.innerWidth
            height: 86
            radius: 10
            color: pomo.panelColor

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Item {
                    width: parent.width
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: pomo.panelIcon
                        font.family: config.fontFamily
                        font.pixelSize: 24
                        font.weight: Font.Medium
                        color: Colors.col_source_color
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 34
                        anchors.verticalCenter: parent.verticalCenter
                        text: pomo.panelTitle
                        font.family: config.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        color: Colors.col_primary
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: pomo.modeLabel
                        font.family: config.fontFamily
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        color: Colors.col_primary
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pomo.fmtTime(pomo.remainingSeconds)
                    font.family: config.fontFamily
                    font.pixelSize: 26
                    font.bold: true
                    color: Colors.col_source_color
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Qt.rgba(0, 0, 0, 0.22)

                    Rectangle {
                        width: parent.width * pomo.progress
                        height: parent.height
                        radius: 3
                        color: Colors.col_source_color
                    }
                }
            }
        }

        Row {
            x: contentColumn.sidePad
            width: contentColumn.innerWidth
            spacing: 8

            readonly property real sectionWidth: width
            readonly property real buttonWidth: (sectionWidth - (2 * spacing)) / 3

            Rectangle {
                width: parent.buttonWidth
                height: 30
                radius: 8
                color: pomo.mode === "work" ? Colors.col_source_color : Colors.col_background
                border.color: "black"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Work"
                    font.family: config.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: pomo.mode === "work" ? Colors.col_background : Colors.col_primary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pomo.startSession("work")
                }
            }

            Rectangle {
                width: parent.buttonWidth
                height: 30
                radius: 8
                color: pomo.mode === "shortBreak" ? Colors.col_source_color : Colors.col_background
                border.color: "black"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Short"
                    font.family: config.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: pomo.mode === "shortBreak" ? Colors.col_background : Colors.col_primary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pomo.startSession("shortBreak")
                }
            }

            Rectangle {
                width: parent.buttonWidth
                height: 30
                radius: 8
                color: pomo.mode === "longBreak" ? Colors.col_source_color : Colors.col_background
                border.color: "black"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Long"
                    font.family: config.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: pomo.mode === "longBreak" ? Colors.col_background : Colors.col_primary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pomo.startSession("longBreak")
                }
            }
        }

        Row {
            x: contentColumn.sidePad
            width: contentColumn.innerWidth
            spacing: 8

            readonly property real sectionWidth: width
            readonly property real buttonWidth: (sectionWidth - spacing) / 2

            Rectangle {
                width: parent.buttonWidth
                height: 30
                radius: 8
                color: Colors.col_background
                border.color: "black"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: pomo.timerRunning ? "Pause" : "Start"
                    font.family: config.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Colors.col_primary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pomo.toggleRunPause()
                }
            }

            Rectangle {
                width: parent.buttonWidth
                height: 30
                radius: 8
                color: Colors.col_background
                border.color: "black"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "Reset"
                    font.family: config.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Colors.col_primary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pomo.resetSession()
                }
            }
        }

        Row {
            id: optionsRow
            x: contentColumn.sidePad
            width: contentColumn.innerWidth
            spacing: 12

            readonly property real cardWidth: (width - (2 * spacing)) / 3

            function label(which) {
                if (which === "shortBreak") return "Short"
                if (which === "longBreak") return "Long"
                return "Work"
            }

            function value(which) {
                if (which === "shortBreak") return pomo.shortBreakMinutes
                if (which === "longBreak") return pomo.longBreakMinutes
                return pomo.workMinutes
            }

            function adjust(which, delta) {
                if (which === "work") {
                    pomo.workMinutes = Math.max(1, Math.min(90, pomo.workMinutes + delta))
                } else if (which === "shortBreak") {
                    pomo.shortBreakMinutes = Math.max(1, Math.min(60, pomo.shortBreakMinutes + delta))
                } else {
                    pomo.longBreakMinutes = Math.max(1, Math.min(90, pomo.longBreakMinutes + delta))
                }

                if (!pomo.timerRunning && pomo.mode === which)
                    pomo.resetSession()
            }

            Repeater {
                model: ["work", "shortBreak", "longBreak"]

                Rectangle {
                    width: optionsRow.cardWidth
                    height: 64
                    radius: 8
                    color: Qt.rgba(0, 0, 0, 0.08)
                    border.color: "black"
                    border.width: 1

                    Column {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: optionsRow.label(modelData)
                            font.family: config.fontFamily
                            font.pixelSize: 10
                            color: Colors.col_primary
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 4
                                color: Colors.col_background
                                border.color: "black"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "-"
                                    font.family: config.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Colors.col_primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: optionsRow.adjust(modelData, -1)
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: optionsRow.value(modelData) + "m"
                                font.family: config.fontFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: Colors.col_source_color
                            }

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 4
                                color: Colors.col_background
                                border.color: "black"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.family: config.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Colors.col_primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: optionsRow.adjust(modelData, 1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
