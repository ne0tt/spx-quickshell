import Quickshell
import QtQuick

// ============================================================
// WEATHER DROPDOWN — extends DropdownBase.
// Uses open-meteo (free, no API key, not blocked).
// Auto-detects location from ipinfo.io.
// ============================================================
DropdownBase {
    id: wDrop
    reloadableId: "weatherDropdown"

    // ── Shared state (from WeatherState singleton) ─────────────
    property QtObject weatherData: null

    readonly property string wIcon:     weatherData ? weatherData.wIcon     : "\uf185"
    readonly property string wDesc:     weatherData ? weatherData.wDesc     : ""
    readonly property string wTemp:     weatherData ? weatherData.wTemp     : ""
    readonly property string wFeels:    weatherData ? weatherData.wFeels    : ""
    readonly property string wHumidity: weatherData ? weatherData.wHumidity : ""
    readonly property string wWind:     weatherData ? weatherData.wWind     : ""
    readonly property string wSunrise:  weatherData ? weatherData.wSunrise  : ""
    readonly property string wSunset:   weatherData ? weatherData.wSunset   : ""
    readonly property var    wForecast: weatherData ? weatherData.wForecast : []
    readonly property bool   wLoading:  weatherData ? weatherData.wLoading  : true

    // ── Panel geometry ────────────────────────────────────────
    readonly property int _cardH: 52
    readonly property int _gapH: 10

    panelFullHeight: 16 + 140 + _gapH + 44 + _gapH + 3 * _cardH + 2 * _gapH
    implicitHeight: panelFullHeight + 58
    panelWidth: 330
    panelColor: colors.col_main

    // ── Refresh on open ───────────────────────────────────────────
    onAboutToOpen: { if (wDrop.weatherData) wDrop.weatherData.refresh() }


    // ── UI ────────────────────────────────────────────────────
    Item {
        x: 16 + 14
        y: 16 + 10
        width: wDrop.panelWidth - 28
        height: wDrop.panelFullHeight

        Text {
            visible: wDrop.wLoading
            anchors.centerIn: parent
            text: "Fetching weather…"
            color: wDrop.dimColor
            font.pixelSize: 13
        }

        // ── Current card ──────────────────────────────────────
        Rectangle {
            id: currentCard
            visible: !wDrop.wLoading
            width: parent.width
            height: 140
            radius: 10
            color: Qt.rgba(wDrop.accentColor.r, wDrop.accentColor.g, wDrop.accentColor.b, 0.08)
            border.color: Qt.rgba(wDrop.accentColor.r, wDrop.accentColor.g, wDrop.accentColor.b, 0.18)
            border.width: 1

            // Icon left, temp+desc right, details pinned to card bottom
            Text {
                id: bigIcon
                anchors {
                    left: parent.left
                    leftMargin: 18
                    top: parent.top
                    topMargin: 24
                }
                text: wDrop.wIcon
                font.family: fontFamily
                font.styleName: "Solid"
                font.pixelSize: 58
                color: wDrop.accentColor
            }

            Column {
                anchors {
                    left: bigIcon.right
                    leftMargin: 14
                    right: parent.right
                    rightMargin: 14
                    top: parent.top
                    topMargin: 14
                }
                spacing: 3

                Text {
                    text: wDrop.wTemp
                    color: wDrop.textColor
                    font.pixelSize: 32
                    font.bold: true
                }
                Text {
                    text: wDrop.wDesc
                    color: wDrop.dimColor
                    font.pixelSize: 13
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 9
                    width: currentCard.width - bigIcon.width - 14 - 36
                    elide: Text.ElideNone
                }
            }

            // Details row pinned to bottom-center of card
            Row {
                anchors {
                    bottom: parent.bottom
                    bottomMargin: 20
                    horizontalCenter: parent.horizontalCenter
                }
                spacing: 12
                // Feels like
                Row {
                    spacing: 4
                    Text {
                        text: "\uf2c9"
                        font.family: fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 11
                        color: wDrop.dimColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: wDrop.wFeels
                        color: wDrop.dimColor
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                // Humidity
                Row {
                    spacing: 4
                    Text {
                        text: "\uf043"
                        font.family: fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 11
                        color: wDrop.dimColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: wDrop.wHumidity
                        color: wDrop.dimColor
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                // Wind
                Row {
                    spacing: 4
                    Text {
                        text: "\uf72e"
                        font.family: fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 11
                        color: wDrop.dimColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: wDrop.wWind
                        color: wDrop.dimColor
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ── Sunrise / sunset bar ──────────────────────────────
        Rectangle {
            id: sunRow
            visible: !wDrop.wLoading && wDrop.wSunrise !== ""
            anchors.top: currentCard.bottom
            anchors.topMargin: wDrop._gapH
            width: parent.width
            height: 44
            radius: 9
            color: Qt.rgba(0, 0, 0, 0.15)
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 32

                Row {
                    spacing: 7
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: ""
                        font.family: fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 60
                        color: "#f5a623"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: wDrop.wSunrise
                        color: wDrop.textColor
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    text: "|"
                    color: Qt.rgba(1, 1, 1, 0.15)
                    font.pixelSize: 18
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    spacing: 7
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: ""
                        font.family: fontFamily
                        font.styleName: "Solid"
                        font.pixelSize: 60
                        color: "#e07b39"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: wDrop.wSunset
                        color: wDrop.textColor
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ── 3-day forecast ────────────────────────────────────
        Column {
            visible: !wDrop.wLoading
            anchors.top: sunRow.bottom
            anchors.topMargin: wDrop._gapH
            width: parent.width
            spacing: wDrop._gapH

            Repeater {
                model: wDrop.wForecast

                Rectangle {
                    width: parent.width
                    height: wDrop._cardH
                    radius: 9
                    color: Qt.rgba(0, 0, 0, 0.15)
                    border.color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1

                    Row {
                        anchors {
                            left: parent.left
                            leftMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 0
                        width: parent.width - 24

                        Text {
                            width: 30
                            text: modelData.icon
                            font.family: fontFamily
                            font.styleName: "Solid"
                            font.pixelSize: 17
                            color: wDrop.dimColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            width: 90
                            text: modelData.date
                            color: wDrop.dimColor
                            font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            width: parent.width - 30 - 90 - 72
                            text: modelData.desc
                            color: wDrop.textColor
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            width: 72
                            text: modelData.min + " – " + modelData.max
                            color: wDrop.accentColor
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }
}
