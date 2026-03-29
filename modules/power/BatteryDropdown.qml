import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../base"

DropdownBase {
    id: batteryDrop
    reloadableId: "batteryDropdown"

    WlrLayershell.keyboardFocus: batteryDrop.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item { focus: true; Keys.onEscapePressed: batteryDrop.closePanel() }

    panelWidth: 300
    panelTitle: "Battery"
    panelIcon: iconGlyph
    panelTitleRight: present ? percentageText : "Unavailable"
    headerHeight: 34
    panelFullHeight: 170
    implicitHeight: 340

    property bool present: false
    property int percentage: 0
    property string percentageText: "--%"
    property string state: "unknown"
    property string timeToFull: "--"
    property string timeToEmpty: "--"
    property string energy: "--"
    property string energyFull: "--"
    property string technology: "--"
    property string iconGlyph: ""
    property var refreshCallback: null

    onAboutToOpen: {
        if (typeof refreshCallback === "function")
            refreshCallback()
    }

    function stateLabel(value) {
        if (value === "charging") return "Charging"
        if (value === "discharging") return "Discharging"
        if (value === "fully-charged") return "Fully Charged"
        if (value === "pending-charge") return "Pending Charge"
        if (value === "pending-discharge") return "Pending Discharge"
        return value.length > 0 ? value : "Unknown"
    }

    function etaLabel() {
        if (!present) return "--"
        if (state === "charging" || state === "pending-charge") return timeToFull
        if (state === "discharging" || state === "pending-discharge") return timeToEmpty
        if (state === "fully-charged") return "Charged"
        return "--"
    }

    Column {
        x: 30
        y: 16 + batteryDrop.headerHeight + 10
        width: batteryDrop.panelWidth - 28
        spacing: 10

        Text {
            text: batteryDrop.present ? "Battery details" : "No battery detected"
            color: batteryDrop.textColor
            font.family: batteryDrop.fontFamily
            font.pixelSize: 13
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(batteryDrop.dimColor.r, batteryDrop.dimColor.g, batteryDrop.dimColor.b, 0.2)
        }

        Grid {
            width: parent.width
            columns: 2
            rowSpacing: 8
            columnSpacing: 12

            Text {
                text: "State"
                color: batteryDrop.dimColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
            }
            Text {
                text: batteryDrop.present ? batteryDrop.stateLabel(batteryDrop.state) : "--"
                color: batteryDrop.textColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
            }

            Text {
                text: "Charge"
                color: batteryDrop.dimColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
            }
            Text {
                text: batteryDrop.present ? batteryDrop.percentageText : "--"
                color: batteryDrop.accentColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
                font.bold: true
            }

            Text {
                text: "ETA"
                color: batteryDrop.dimColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
            }
            Text {
                text: batteryDrop.etaLabel()
                color: batteryDrop.textColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
            }

            Text {
                text: "Energy"
                color: batteryDrop.dimColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
            }
            Text {
                text: batteryDrop.present ? (batteryDrop.energy + " / " + batteryDrop.energyFull) : "--"
                color: batteryDrop.textColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
            }

            Text {
                text: "Tech"
                color: batteryDrop.dimColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
            }
            Text {
                text: batteryDrop.present ? batteryDrop.technology : "--"
                color: batteryDrop.textColor
                font.family: batteryDrop.fontFamily
                font.pixelSize: 12
            }
        }
    }
}