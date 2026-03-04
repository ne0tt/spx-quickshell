import Quickshell
import QtQuick
import QtQuick.Effects

// ============================================================
// CALENDAR PANEL — drops down from the clock.
// Boilerplate handled by DropdownBase.
// ============================================================
DropdownBase {
    id: calPanel
    reloadableId: "calendarPanel"

    barHeight: 16
    // 10 top-pad + header(32) + gap(6) + dow-row + gap-to-grid(16) + rows×36 + 10 bottom-pad
    panelFullHeight: 10 + 32 + 6 + dowRow.implicitHeight + 16
                     + (dayGrid.calDays.length / 7) * dayGrid.cellH + 10
    implicitHeight:  panelFullHeight + 48   // +16 ears +32 footer
    panelWidth: 280
    panelZ: 99998

    // ----------------------------------------------------
    // CALENDAR UI
    // ----------------------------------------------------
    Item {
        id: calBody
        x: 16 + 10
        y: 16 + 10
        width: calPanel.panelWidth - 20
        height: calPanel.panelFullHeight - 10

        property var  _now:          new Date()
        property int  displayYear:  _now.getFullYear()
        property int  displayMonth: _now.getMonth()

        readonly property var _monthNames: [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]

        Item {
            id: calHeader
            width: parent.width
            height: 32

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                text: "\u2039"
                color: calPanel.accentColor
                font.pixelSize: 22
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (calBody.displayMonth === 0) {
                            calBody.displayMonth = 11;
                            calBody.displayYear -= 1;
                        } else {
                            calBody.displayMonth -= 1;
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: calBody._monthNames[calBody.displayMonth] + "  " + calBody.displayYear
                color: calPanel.accentColor
                font.pixelSize: 15
                font.bold: true
            }

            Text {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                text: "\u203a"
                color: calPanel.accentColor
                font.pixelSize: 22
                font.bold: true
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (calBody.displayMonth === 11) {
                            calBody.displayMonth = 0;
                            calBody.displayYear += 1;
                        } else {
                            calBody.displayMonth += 1;
                        }
                    }
                }
            }
        }

        Row {
            id: dowRow
            y: calHeader.height + 6
            width: parent.width
            property int cellW: Math.floor(parent.width / 7)

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                Text {
                    width: dowRow.cellW
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: calPanel.dimColor
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        Rectangle {
            y: calHeader.height + dowRow.height + 10
            width: parent.width
            height: 1
            color: calPanel.dimColor
            opacity: 0.4
        }

        Grid {
            id: dayGrid
            y: calHeader.height + dowRow.height + 16
            width: parent.width
            columns: 7

            property int cellW: Math.floor(parent.width / 7)
            property int cellH: 36

            property var calDays: {
                var yr = calBody.displayYear;
                var mo = calBody.displayMonth;
                var days = [];
                var firstDay = new Date(yr, mo, 1).getDay();
                var offset = (firstDay === 0) ? 6 : firstDay - 1;
                var total = new Date(yr, mo + 1, 0).getDate();
                var tod = new Date();
                var todayD = (tod.getFullYear() === yr && tod.getMonth() === mo) ? tod.getDate() : -1;

                for (var i = 0; i < offset; i++)
                    days.push({
                        day: 0,
                        isToday: false
                    });
                for (var d = 1; d <= total; d++)
                    days.push({
                        day: d,
                        isToday: d === todayD
                    });
                while (days.length % 7 !== 0)
                    days.push({
                        day: 0,
                        isToday: false
                    });
                return days;
            }

            Repeater {
                model: dayGrid.calDays
                Item {
                    width: dayGrid.cellW
                    height: dayGrid.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: modelData.isToday ? calPanel.textColor : "transparent"
                        visible: modelData.day > 0
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.day > 0 ? modelData.day : ""
                        color: modelData.isToday ? calPanel.panelColor : calPanel.accentColor
                        font.pixelSize: 12
                        font.bold: modelData.isToday
                    }
                }
            }
        }
    }
}
