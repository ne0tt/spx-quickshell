pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// WEATHER STATE — open-meteo hourly fetch, auto-detects location.
// Fetches once on startup, then every hour on the hour.
// Call refresh() to force an immediate re-fetch.
//
// Access from any QML file (import qs.state or "../../state"):
//   WeatherState.wTemp / WeatherState.wIcon / WeatherState.wForecast …
//   WeatherState.wLoading
//   WeatherState.refresh()
// ============================================================
Singleton {
    id: weatherState

    property string wIcon:        "…"
    property string wDesc:        ""
    property string wTemp:        ""
    property string wFeels:       ""
    property string wHumidity:    ""
    property string wWind:        ""
    property string wSunrise:     ""
    property string wSunset:      ""
    property var    wForecast:    []
    property var    wHourly:      []   // next-24h hourly array: {time, temp, icon}
    property bool   wLoading:     true
    property var    _forecastBuf: []
    property var    _hourlyBuf:   []

    function refresh() {
        wLoading      = true
        wForecast     = []
        wHourly       = []
        _forecastBuf  = []
        _hourlyBuf    = []
        wSunrise      = ""
        wSunset       = ""
        _fetchProc.running = true
    }

    function _codeToIcon(c) {
        if (c === 0)  return "󰖙"
        if (c <= 2)   return "󰖙"
        if (c === 3)  return "󰖕"
        if (c <= 48)  return "󰖐"
        if (c <= 55)  return "󰖖"
        if (c <= 65)  return "󰖗"
        if (c <= 77)  return "󰖘"
        if (c <= 82)  return "󰖖"
        if (c <= 86)  return "󰖘"
        return "󰖙"
    }

    function _codeToDesc(c) {
        if (c === 0)  return "Clear sky"
        if (c === 1)  return "Mainly clear"
        if (c === 2)  return "Partly cloudy"
        if (c === 3)  return "Overcast"
        if (c <= 48)  return "Fog"
        if (c <= 55)  return "Drizzle"
        if (c <= 65)  return "Rain"
        if (c <= 77)  return "Snow"
        if (c <= 82)  return "Rain showers"
        if (c <= 86)  return "Snow showers"
        return "Thunderstorm"
    }

    property var _fetchProc: Process {
        running: false
        command: ["sh", "-c",
            "INFO=$(curl -sf --max-time 5 https://ipinfo.io/json); " +
            "LOC=$(echo \"$INFO\" | jq -r '.loc'); " +
            "LAT=${LOC%%,*}; LON=${LOC##*,}; " +
            "curl -sf --max-time 10 \"https://api.open-meteo.com/v1/forecast?" +
            "latitude=$LAT&longitude=$LON" +
            "&current=temperature_2m,apparent_temperature,weathercode,windspeed_10m,relative_humidity_2m" +
            "&daily=weathercode,temperature_2m_max,temperature_2m_min,sunrise,sunset" +
            "&hourly=temperature_2m,weathercode" +
            "&timezone=auto&forecast_days=7\" | " +
            "jq -r '\"code=\"+(.current.weathercode|tostring)," +
            "\"temp=\"+(.current.temperature_2m|tostring)," +
            "\"feels=\"+(.current.apparent_temperature|tostring)," +
            "\"humidity=\"+(.current.relative_humidity_2m|tostring)," +
            "\"wind=\"+(.current.windspeed_10m|tostring)," +
            "\"sunrise=\"+(.daily.sunrise[0] | split(\"T\")[1])," +
            "\"sunset=\"+(.daily.sunset[0] | split(\"T\")[1])," +
            "(.daily.time[] as $i | \"day=\"+$i+\"|\"+(.daily.weathercode[(.daily.time|index($i))]|tostring)+\"|\"+(.daily.temperature_2m_min[(.daily.time|index($i))]|tostring)+\"|\"+(.daily.temperature_2m_max[(.daily.time|index($i))]|tostring))," +
            "([.hourly.time,.hourly.temperature_2m,.hourly.weathercode]|transpose|.[]" +
            "|\"hour=\"+.[0]+\"|\"+(.[1]|round|tostring)+\"|\"+(.[2]|tostring))'"]

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line === "") return
                var eq = line.indexOf("=")
                if (eq < 0) return
                var key = line.substring(0, eq)
                var val = line.substring(eq + 1)
                switch (key) {
                case "code":
                    weatherState.wIcon = weatherState._codeToIcon(parseInt(val))
                    weatherState.wDesc = weatherState._codeToDesc(parseInt(val))
                    break
                case "temp":
                    weatherState.wTemp = Math.round(parseFloat(val)) + "°C"
                    break
                case "feels":
                    weatherState.wFeels = Math.round(parseFloat(val)) + "°C"
                    break
                case "humidity":
                    weatherState.wHumidity = val + "%"
                    break
                case "wind":
                    weatherState.wWind = val + " km/h"
                    break
                case "sunrise":
                    weatherState.wSunrise = val
                    break
                case "sunset":
                    weatherState.wSunset = val
                    break
                case "day": {
                    var parts = val.split("|")
                    weatherState._forecastBuf.push({
                        date: parts[0],
                        icon: weatherState._codeToIcon(parseInt(parts[1])),
                        desc: weatherState._codeToDesc(parseInt(parts[1])),
                        min:  Math.round(parseFloat(parts[2])) + "°",
                        max:  Math.round(parseFloat(parts[3])) + "°"
                    })
                    break
                }
                case "hour": {
                    var hp = val.split("|")
                    if (hp.length === 3) {
                        weatherState._hourlyBuf.push({
                            time: hp[0],
                            temp: Math.round(parseFloat(hp[1])) + "°",
                            icon: weatherState._codeToIcon(parseInt(hp[2]))
                        })
                    }
                    break
                }
                }
            }
        }

        onExited: {
            weatherState.wForecast    = weatherState._forecastBuf.slice()
            weatherState._forecastBuf = []
            weatherState.wHourly      = weatherState._hourlyBuf.slice()
            weatherState._hourlyBuf   = []
            weatherState.wLoading     = false
        }
    }

    SystemClock {
        id: _weatherClock
        precision: SystemClock.Hours
        onHoursChanged: weatherState.refresh()
    }

    Component.onCompleted: refresh()
}
