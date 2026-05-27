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
    readonly property bool wHasData: (wTemp !== "" && wTemp !== "…") || wForecast.length > 0 || wHourly.length > 0 || wSunrise !== "" || wSunset !== ""
    property int    refreshCooldownMs: 120000
    property double _lastFetchMs: 0
    property var    _forecastBuf: []
    property var    _hourlyBuf:   []

    function refresh(force) {
        var now = Date.now()
        if (_fetchProc.running) return
        if (force !== true && wHasData && _lastFetchMs > 0 && (now - _lastFetchMs) < refreshCooldownMs) return

        wLoading      = true
        _forecastBuf  = []
        _hourlyBuf    = []
        _fetchProc.running = true
    }

    function _codeToIcon(c) {
        // wttr.in fallback weather codes
        if (c === 113) return "󰖙"
        if (c === 116) return "󰖕"
        if (c === 119 || c === 122) return "󰖐"
        if (c === 143) return "󰖐"
        if (c === 176 || c === 263 || c === 266) return "󰖖"
        if (c === 293 || c === 296 || c === 299 || c === 302 || c === 305 || c === 308) return "󰖗"
        if (c === 323 || c === 326 || c === 329 || c === 332 || c === 335 || c === 338 || c === 368 || c === 371) return "󰖘"
        if (c === 200 || c === 386 || c === 389 || c === 392 || c === 395) return "󰙾"

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
        // wttr.in fallback weather codes
        if (c === 113) return "Clear sky"
        if (c === 116) return "Partly cloudy"
        if (c === 119) return "Cloudy"
        if (c === 122) return "Overcast"
        if (c === 143) return "Fog"
        if (c === 176 || c === 263 || c === 266) return "Drizzle"
        if (c === 293 || c === 296 || c === 299 || c === 302 || c === 305 || c === 308) return "Rain"
        if (c === 323 || c === 326 || c === 329 || c === 332 || c === 335 || c === 338 || c === 368 || c === 371) return "Snow"
        if (c === 200 || c === 386 || c === 389 || c === 392 || c === 395) return "Thunderstorm"

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

    function _to24Hour(t) {
        if (!t || typeof t !== "string") return ""

        var s = t.trim()
        if (s === "") return ""

        // Already 24-hour clock (e.g. "06:12" or "06:12:00")
        var m24 = s.match(/^(\d{1,2}):(\d{2})(?::\d{2})?$/)
        if (m24) {
            var h24 = Math.max(0, Math.min(23, parseInt(m24[1])))
            return String(h24).padStart(2, "0") + ":" + m24[2]
        }

        // 12-hour clock with suffix (e.g. "6:12 AM", "6:12PM")
        var m12 = s.match(/^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$/)
        if (m12) {
            var h = parseInt(m12[1])
            var mins = m12[2]
            var ampm = m12[3].toUpperCase()

            if (h === 12) h = 0
            if (ampm === "PM") h += 12

            return String(h).padStart(2, "0") + ":" + mins
        }

        return s
    }

    property var _fetchProc: Process {
        running: false
        command: ["sh", "-c",
            "IP=$(curl -sf --max-time 5 https://ip.me || true); " +
            "GEO=$(curl -sf --max-time 8 \"http://ip-api.com/json/$IP\" || true); " +
            "LAT=$(echo \"$GEO\" | jq -r '.lat // empty'); " +
            "LON=$(echo \"$GEO\" | jq -r '.lon // empty'); " +
            "if [ -z \"$LAT\" ] || [ -z \"$LON\" ]; then echo 'error=Unable to determine location'; exit 0; fi; " +
            "OM=$(curl -sf --max-time 12 \"https://api.open-meteo.com/v1/forecast?" +
            "latitude=$LAT&longitude=$LON" +
            "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset" +
            "&hourly=temperature_2m,weather_code" +
            "&timezone=auto&forecast_days=7\" || true); " +
            "if [ -n \"$OM\" ] && echo \"$OM\" | jq -e '.current and .daily and .hourly' >/dev/null 2>&1; then " +
            "  echo \"$OM\" | jq -r '\"code=\"+((.current.weather_code // .current.weathercode // 0)|tostring)," +
            "\"temp=\"+((.current.temperature_2m // 0)|tostring)," +
            "\"feels=\"+((.current.apparent_temperature // 0)|tostring)," +
            "\"humidity=\"+((.current.relative_humidity_2m // 0)|tostring)," +
            "\"wind=\"+((.current.wind_speed_10m // .current.windspeed_10m // 0)|tostring)," +
            "\"sunrise=\"+((.daily.sunrise[0] // \"\") | split(\"T\")[1])," +
            "\"sunset=\"+((.daily.sunset[0] // \"\") | split(\"T\")[1])," +
            "(.daily.time[] as $i | \"day=\"+$i+\"|\"+((.daily.weather_code // .daily.weathercode)[(.daily.time|index($i))]|tostring)+\"|\"+(.daily.temperature_2m_min[(.daily.time|index($i))]|tostring)+\"|\"+(.daily.temperature_2m_max[(.daily.time|index($i))]|tostring))," +
            "([.hourly.time,.hourly.temperature_2m,((.hourly.weather_code // .hourly.weathercode))]|transpose|.[]" +
            "|\"hour=\"+.[0]+\"|\"+(.[1]|round|tostring)+\"|\"+(.[2]|tostring))'; " +
            "else " +
            "  WT=$(curl -sf --max-time 12 \"https://wttr.in/${LAT},${LON}?format=j1\" || curl -sf --max-time 12 \"https://wttr.in/?format=j1\" || true); " +
            "  echo \"$WT\" | jq -r '\"code=\"+((.current_condition[0].weatherCode // 0)|tostring)," +
            "\"temp=\"+((.current_condition[0].temp_C // 0)|tostring)," +
            "\"feels=\"+((.current_condition[0].FeelsLikeC // 0)|tostring)," +
            "\"humidity=\"+((.current_condition[0].humidity // 0)|tostring)," +
            "\"wind=\"+((.current_condition[0].windspeedKmph // 0)|tostring)," +
            "\"sunrise=\"+(.weather[0].astronomy[0].sunrise // \"\")," +
            "\"sunset=\"+(.weather[0].astronomy[0].sunset // \"\")," +
            "(.weather[] | \"day=\"+.date+\"|\"+((.hourly[0].weatherCode // 0)|tostring)+\"|\"+(.mintempC|tostring)+\"|\"+(.maxtempC|tostring))," +
            "(.weather[] as $d | $d.hourly[] | .time as $t | \"hour=\"+$d.date+\"T\"+((((($t|tonumber)/100)|floor|tostring) as $hh | if ($hh|length)==1 then \"0\"+$hh else $hh end))+\":00\"+\"|\"+((.tempC // 0)|tostring)+\"|\"+((.weatherCode // 0)|tostring))'; " +
            "fi"]

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
                    weatherState.wSunrise = weatherState._to24Hour(val)
                    break
                case "sunset":
                    weatherState.wSunset = weatherState._to24Hour(val)
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
            if (weatherState.wHasData) weatherState._lastFetchMs = Date.now()
        }
    }

    SystemClock {
        id: _weatherClock
        precision: SystemClock.Hours
        onHoursChanged: weatherState.refresh()
    }

    Component.onCompleted: refresh()
}
