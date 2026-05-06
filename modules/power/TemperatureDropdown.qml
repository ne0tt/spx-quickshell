import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import "../../base"

// ============================================================
// TEMPERATURE DROPDOWN — shows all hwmon sensor readings.
//
// Data is fetched by iterating /sys/class/hwmon/ — no external
// tools needed.  Each line from the shell probe is formatted as:
//   device_name|sensor_label|millidegree_value
//
// Sensors are displayed as a scrollable flat list; label + device
// name are stacked on the left and the coloured value on the right.
// ============================================================
DropdownBase {
    id: tempDrop
    reloadableId: "temperatureDropdown"

    keyboardFocusEnabled: true

    Item { focus: true; Keys.onEscapePressed: tempDrop.closePanel() }

    panelWidth:      280
    panelTitle:      "Temperatures"
    panelIcon:       ""
    panelTitleRight: cpuTemp
    headerHeight:    34
    // Shrinks to fit the sensor list; clamps between 60 (empty state) and 240 (scrolls above)
    panelFullHeight: _sensors.length > 0
                     ? Math.min(240, _sensors.length * 32 + 16)
                     : 60
    implicitHeight:  16 + headerHeight + panelFullHeight + 28

    // Injected from TemperatureButton so the header always mirrors the bar
    property string cpuTemp: "--°C"

    // Internal: flat list of { device, label, temp } objects
    property var _sensors: []

    onAboutToOpen: _fetchSensors()

    // Called by shell.qml whenever the button's temperature updates
    function refresh() { _fetchSensors() }

    function _fetchSensors() {
        if (!_sensorProc.running)
            _sensorProc.running = true
    }

    // ─── Sensor probe ────────────────────────────────────────────
    Process {
        id: _sensorProc
        running: false
        command: [
            "sh", "-c",
            // Walk every hwmon device; for each temp*_input print:
            //   device_name|label_or_filename|millidegree_value
            "for d in /sys/class/hwmon/hwmon*; do" +
            "  [ -d \"$d\" ] || continue;" +
            "  n=$(cat \"$d/name\" 2>/dev/null);" +
            "  [ -z \"$n\" ] && continue;" +
            "  for i in \"$d\"/temp*_input; do" +
            "    [ -r \"$i\" ] || continue;" +
            "    val=$(cat \"$i\" 2>/dev/null);" +
            "    [ -z \"$val\" ] && continue;" +
            "    lf=\"${i%_input}_label\";" +
            "    if [ -r \"$lf\" ]; then lbl=$(cat \"$lf\" 2>/dev/null);" +
            "    else lbl=\"${i##*/}\"; lbl=\"${lbl%_input}\"; fi;" +
            "    echo \"${n}|${lbl}|${val}\";" +
            "  done;" +
            "done"
        ]

        property var _buf: []

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var line = data.trim()
                if (line.length > 0)
                    _sensorProc._buf.push(line)
            }
        }

        onExited: {
            var result = []
            for (var i = 0; i < _buf.length; i++) {
                var parts = _buf[i].split("|")
                if (parts.length < 3) continue
                var raw = parseInt(parts[2].trim())
                if (isNaN(raw)) continue
                result.push({
                    device: parts[0].trim(),
                    label:  parts[1].trim(),
                    temp:   Math.round(raw / 1000)
                })
            }
            tempDrop._sensors = result
            _buf = []
        }
    }

    // ─── Content ─────────────────────────────────────────────────
    // A Flickable lets the list scroll when there are many sensors.
    Flickable {
        x:            32
        y:            16 + tempDrop.headerHeight + 10
        width:        tempDrop.panelWidth - 38
        height:       tempDrop.panelFullHeight - 10
        clip:         true
        contentHeight: _sensorColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        // Subtle scroll indicator
        ScrollIndicator.vertical: ScrollIndicator {}

        Column {
            id: _sensorColumn
            width: parent.width
            spacing: 0

            // ── Empty state ─────────────────────────────────────
            Text {
                visible:            tempDrop._sensors.length === 0
                text:               "No sensors detected"
                color:              tempDrop.dimColor
                font.family:        tempDrop.fontFamily
                font.pixelSize:     12
                width:              parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding:         20
            }

            // ── Sensor rows ─────────────────────────────────────
            Repeater {
                model: tempDrop._sensors

                Item {
                    id: _row
                    width:  _sensorColumn.width
                    height: 30

                    readonly property color _valueColor:
                        modelData.temp >= 85 ? "#ff5555" :
                        modelData.temp >= 70 ? "#ffaa55" :
                                               tempDrop.textColor

                    // Label + device (left side)
                    Column {
                        anchors {
                            left:           parent.left
                            verticalCenter: parent.verticalCenter
                            right:          _tempLabel.left
                            rightMargin:    6
                        }
                        spacing: 1

                        Text {
                            text:           modelData.label
                            color:          tempDrop.textColor
                            font.family:    tempDrop.fontFamily
                            font.pixelSize: 12
                            font.bold:      true
                            elide:          Text.ElideRight
                            width:          parent.width
                        }
                        Text {
                            text:           modelData.device
                            color:          tempDrop.dimColor
                            font.family:    tempDrop.fontFamily
                            font.pixelSize: 10
                            elide:          Text.ElideRight
                            width:          parent.width
                        }
                    }

                    // Temperature value (right side)
                    Text {
                        id:                  _tempLabel
                        anchors {
                            right:           parent.right
                            verticalCenter:  parent.verticalCenter
                        }
                        text:                modelData.temp + "°C"
                        color:               _row._valueColor
                        font.family:         tempDrop.fontFamily
                        font.pixelSize:      13
                        font.bold:           true
                        horizontalAlignment: Text.AlignRight

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    // Divider
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width:          parent.width
                        height:         1
                        color:          Qt.rgba(
                                            tempDrop.dimColor.r,
                                            tempDrop.dimColor.g,
                                            tempDrop.dimColor.b,
                                            0.12)
                    }
                }
            }
        }
    }
}
