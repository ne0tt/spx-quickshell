pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// WEATHER STATE — OpenWeather One Call test version.
// Uses ipinfo.io for location, then OpenWeather for current,
// hourly, and daily forecast data.
// Reads openWeatherApiKey from modules/settings/settings.json.
// ============================================================
Singleton {
    id: weatherState

    readonly property string settingsPath: Quickshell.env("HOME") + "/dotfiles/.config/quickshell/modules/settings/settings.json"
    property string openWeatherApiKey: ""

    property string wIcon:        "…"
    property string wDesc:        ""
    property string wTemp:        ""
    property string wFeels:       ""
    property string wHumidity:    ""
    property string wWind:        ""
    property string wSunrise:     ""
    property string wSunset:      ""
    property var    wForecast:    []
    property var    wHourly:      []
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

    function _titleCase(text) {
        if (!text || typeof text !== "string") return ""

        var words = text.trim().split(/\s+/)
        for (var i = 0; i < words.length; i++) {
            if (words[i].length > 0) {
                words[i] = words[i].charAt(0).toUpperCase() + words[i].slice(1)
            }
        }
        return words.join(" ")
    }

    function _codeToIcon(code) {
        if (code >= 200 && code <= 232) return "󰙾"
        if (code >= 300 && code <= 321) return "󰖖"
        if (code >= 500 && code <= 531) return "󰖗"
        if (code >= 600 && code <= 622) return "󰖘"
        if (code >= 701 && code <= 781) return "󰖐"
        if (code === 800) return "󰖙"
        if (code === 801) return "󰖕"
        if (code === 802) return "󰖐"
        if (code === 803 || code === 804) return "󰖐"
        return "󰖙"
    }

    function _codeToDesc(code) {
        if (code >= 200 && code <= 232) return "Thunderstorm"
        if (code >= 300 && code <= 321) return "Drizzle"
        if (code >= 500 && code <= 531) return "Rain"
        if (code >= 600 && code <= 622) return "Snow"
        if (code >= 701 && code <= 781) return "Fog"
        if (code === 800) return "Clear sky"
        if (code === 801) return "Few clouds"
        if (code === 802) return "Scattered clouds"
        if (code === 803) return "Broken clouds"
        if (code === 804) return "Overcast clouds"
        return "Weather"
    }

    function _to24Hour(t) {
        if (!t || typeof t !== "string") return ""

        var s = t.trim()
        if (s === "") return ""

        var m24 = s.match(/^(\d{1,2}):(\d{2})(?::\d{2})?$/)
        if (m24) {
            var h24 = Math.max(0, Math.min(23, parseInt(m24[1])))
            return String(h24).padStart(2, "0") + ":" + m24[2]
        }

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

    property var _settingsFile: FileView {
        path: weatherState.settingsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var settings = JSON.parse(text())
                weatherState.openWeatherApiKey = typeof settings.openWeatherApiKey === "string" ? settings.openWeatherApiKey : ""
            } catch (error) {
                weatherState.openWeatherApiKey = ""
            }
        }
    }

    property var _fetchProc: Process {
        running: false
        command: ["sh", "-c",
            "API_KEY=\"" + weatherState.openWeatherApiKey + "\"; " +
            "if [ -z \"$API_KEY\" ]; then echo 'error=Missing OpenWeather API key in settings.json'; exit 0; fi; " +
            "INFO=$(curl -sf --max-time 5 https://ipinfo.io/json || true); " +
            "LOC=$(echo \"$INFO\" | jq -r '.loc // empty'); " +
            "if [ -n \"$LOC\" ]; then LAT=${LOC%%,*}; LON=${LOC##*,}; else echo 'error=Unable to determine location'; exit 0; fi; " +
            "OW=$(curl -s --max-time 12 \"https://api.openweathermap.org/data/3.0/onecall?lat=$LAT&lon=$LON&exclude=minutely,alerts&units=metric&appid=$API_KEY\" || true); " +
            "if [ -z \"$OW\" ]; then echo 'error=OpenWeather request failed'; exit 0; fi; " +
            "if ! echo \"$OW\" | jq -e '.current and .hourly and .daily' >/dev/null 2>&1; then ERR=$(echo \"$OW\" | jq -r '.message // empty'); if [ -n \"$ERR\" ]; then echo \"error=$ERR\"; else echo 'error=OpenWeather request failed'; fi; exit 0; fi; " +
            "OFF=$(echo \"$OW\" | jq -r '.timezone_offset // 0'); " +
            "echo \"$OW\" | jq -r --argjson off \"$OFF\" '" +
            "def ts($v): ($v + $off) | strftime(\"%Y-%m-%dT%H:%M\"); " +
            "def hm($v): ($v + $off) | strftime(\"%H:%M\"); " +
            "\"code=\" + ((.current.weather[0].id // 800)|tostring), " +
            "\"desc=\" + ((.current.weather[0].description // \"\")|tostring), " +
            "\"temp=\" + ((.current.temp // 0)|tostring), " +
            "\"feels=\" + ((.current.feels_like // 0)|tostring), " +
            "\"humidity=\" + ((.current.humidity // 0)|tostring), " +
            "\"wind=\" + ((.current.wind_speed // 0)|tostring), " +
            "\"sunrise=\" + hm(.current.sunrise), " +
            "\"sunset=\" + hm(.current.sunset), " +
            "(.daily[] | \"day=\" + ts(.dt) + \"|\" + ((.weather[0].id // 800)|tostring) + \"|\" + (.temp.min|tostring) + \"|\" + (.temp.max|tostring) + \"|\" + ((.weather[0].description // \"\")|tostring)), " +
            "(.hourly[0:24][] | \"hour=\" + ts(.dt) + \"|\" + ((.temp|round)|tostring) + \"|\" + ((.weather[0].id // 800)|tostring))'; "
        ]

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
                    if (weatherState.wDesc === "") weatherState.wDesc = weatherState._codeToDesc(parseInt(val))
                    break
                case "desc":
                    weatherState.wDesc = weatherState._titleCase(val)
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
                    weatherState.wWind = Math.round(parseFloat(val)) + " km/h"
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
                        desc: parts.length > 4 && parts[4] !== "" ? weatherState._titleCase(parts[4]) : weatherState._codeToDesc(parseInt(parts[1])),
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
                case "error":
                    weatherState.wDesc = val
                    break
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