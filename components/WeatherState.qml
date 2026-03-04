import QtQuick
import Quickshell.Io

// ============================================================
// WEATHER STATE — single fetch source for WeatherPanel and
// WeatherDropdown. Fetches once on startup, then every hour.
// Call refresh() to force an immediate re-fetch.
// ============================================================
QtObject {
    id: _state

    // ── Public state ──────────────────────────────────────
    property string wIcon:     "…"
    property string wDesc:     ""
    property string wTemp:     ""
    property string wFeels:    ""
    property string wHumidity: ""
    property string wWind:     ""
    property string wSunrise:  ""
    property string wSunset:   ""
    property var    wForecast:    []
    property bool   wLoading:     true
    property var    _forecastBuf: []   // accumulates during parse; assigned once in onExited

    function refresh() {
        wLoading      = true;
        wForecast     = [];
        _forecastBuf  = [];
        wSunrise      = "";
        wSunset       = "";
        _fetchProc.running = true;
    }

    // ── Helpers ────────────────────────────────────────────
    function _codeToIcon(c) {
        if (c === 0)  return "\uf185"
        if (c <= 2)   return "\uf6c4"
        if (c === 3)  return "\uf0c2"
        if (c <= 48)  return "\uf75f"
        if (c <= 55)  return "\uf740"
        if (c <= 65)  return "\uf73d"
        if (c <= 77)  return "\uf2dc"
        if (c <= 82)  return "\uf740"
        if (c <= 86)  return "\uf2dc"
        return "\uf0e7"
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

    function _msUntilNextHour() {
        var now = new Date()
        var ms = (60 - now.getMinutes()) * 60000
                 - now.getSeconds() * 1000
                 - now.getMilliseconds()
        return ms <= 0 ? 3600000 : ms
    }

    // ── Fetch process ─────────────────────────────────────
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
            "&timezone=auto&forecast_days=3\" | " +
            "jq -r '\"code=\"+(.current.weathercode|tostring)," +
            "\"temp=\"+(.current.temperature_2m|tostring)," +
            "\"feels=\"+(.current.apparent_temperature|tostring)," +
            "\"humidity=\"+(.current.relative_humidity_2m|tostring)," +
            "\"wind=\"+(.current.windspeed_10m|tostring)," +
            "\"sunrise=\"+(.daily.sunrise[0] | split(\"T\")[1])," +
            "\"sunset=\"+(.daily.sunset[0] | split(\"T\")[1])," +
            "(.daily.time[] as $i | \"day=\"+$i+\"|\"+(.daily.weathercode[(.daily.time|index($i))]|tostring)+\"|\"+(.daily.temperature_2m_min[(.daily.time|index($i))]|tostring)+\"|\"+(.daily.temperature_2m_max[(.daily.time|index($i))]|tostring))'"]

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
                    _state.wIcon = _state._codeToIcon(parseInt(val))
                    _state.wDesc = _state._codeToDesc(parseInt(val))
                    break
                case "temp":
                    _state.wTemp = Math.round(parseFloat(val)) + "°C"
                    break
                case "feels":
                    _state.wFeels = Math.round(parseFloat(val)) + "°C"
                    break
                case "humidity":
                    _state.wHumidity = val + "%"
                    break
                case "wind":
                    _state.wWind = val + " km/h"
                    break
                case "sunrise":
                    _state.wSunrise = val
                    break
                case "sunset":
                    _state.wSunset = val
                    break
                case "day": {
                    var parts = val.split("|")
                    var dp  = parts[0].split("-")
                    _state._forecastBuf.push({
                        date: dp[2] + "/" + dp[1] + "/" + dp[0],
                        icon: _state._codeToIcon(parseInt(parts[1])),
                        desc: _state._codeToDesc(parseInt(parts[1])),
                        min:  Math.round(parseFloat(parts[2])) + "°",
                        max:  Math.round(parseFloat(parts[3])) + "°"
                    })
                    break
                }
                }
            }
        }

        onExited: {
            _state.wForecast    = _state._forecastBuf.slice()
            _state._forecastBuf = []
            _state.wLoading     = false
        }
    }

    // ── Hourly refresh timer ──────────────────────────────
    property var _timer: Timer {
        interval: 1000
        running: false
        repeat: false
        onTriggered: {
            _state.refresh()
            interval = _state._msUntilNextHour()
            restart()
        }
    }

    Component.onCompleted: {
        refresh()
        _timer.interval = _msUntilNextHour()
        _timer.start()
    }
}
