pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// ============================================================
// APP STATE — global singleton combining all reactive state.
//   • Volume    (PipeWire reactive, zero polling)
//   • Weather   (open-meteo hourly fetch)
//   • Bluetooth (rfkill power control + bluetoothctl monitor)
//
// Access from any QML file:
//   AppState.volume / AppState.muted
//   AppState.wTemp  / AppState.wIcon / AppState.wForecast …
//   AppState.btPowered / AppState.togglePower()
// ============================================================
Singleton {
    id: appState

    // ══════════════════════════════════════════════════════════════
    // VOLUME — reactive PipeWire binding, no polling needed.
    // PipeWire signals fire automatically when any client changes
    // the default sink (keyboard shortcuts, pavucontrol, etc.).
    // ══════════════════════════════════════════════════════════════

    property var _pwTracker: PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property var  audioSink: Pipewire.defaultAudioSink
    readonly property int  volume:    audioSink?.audio ? Math.min(100, Math.round(audioSink.audio.volume * 100)) : 0
    readonly property bool muted:     audioSink?.audio?.muted ?? false

    function toggleMute() { if (audioSink?.audio) audioSink.audio.muted = !audioSink.audio.muted }
    function volumeUp()   { if (audioSink?.audio) audioSink.audio.volume = Math.min(1.0, audioSink.audio.volume + 0.05) }
    function volumeDown() { if (audioSink?.audio) audioSink.audio.volume = Math.max(0.0, audioSink.audio.volume - 0.05) }
    function setVolume(v) { if (audioSink?.audio) audioSink.audio.volume = Math.max(0.0, Math.min(1.0, v / 100)) }

    // My Hyprlabd keyboard binds
    //bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0
    //bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    //bind = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    //bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    // ══════════════════════════════════════════════════════════════
    // WEATHER — open-meteo hourly fetch, auto-detects location.
    // Fetches once on startup, then every hour on the hour.
    // Call refresh() to force an immediate re-fetch.
    // ══════════════════════════════════════════════════════════════

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
                    appState.wIcon = appState._codeToIcon(parseInt(val))
                    appState.wDesc = appState._codeToDesc(parseInt(val))
                    break
                case "temp":
                    appState.wTemp = Math.round(parseFloat(val)) + "°C"
                    break
                case "feels":
                    appState.wFeels = Math.round(parseFloat(val)) + "°C"
                    break
                case "humidity":
                    appState.wHumidity = val + "%"
                    break
                case "wind":
                    appState.wWind = val + " km/h"
                    break
                case "sunrise":
                    appState.wSunrise = val
                    break
                case "sunset":
                    appState.wSunset = val
                    break
                case "day": {
                    var parts = val.split("|")
                    var dp    = parts[0].split("-")
                    appState._forecastBuf.push({
                        date: parts[0],
                        icon: appState._codeToIcon(parseInt(parts[1])),
                        desc: appState._codeToDesc(parseInt(parts[1])),
                        min:  Math.round(parseFloat(parts[2])) + "°",
                        max:  Math.round(parseFloat(parts[3])) + "°"
                    })
                    break
                }
                case "hour": {
                    var hp = val.split("|")
                    if (hp.length === 3) {
                        appState._hourlyBuf.push({
                            time: hp[0],
                            temp: Math.round(parseFloat(hp[1])) + "°",
                            icon: appState._codeToIcon(parseInt(hp[2]))
                        })
                    }
                    break
                }
                }
            }
        }

        onExited: {
            appState.wForecast    = appState._forecastBuf.slice()
            appState._forecastBuf = []
            appState.wHourly      = appState._hourlyBuf.slice()
            appState._hourlyBuf   = []
            appState.wLoading     = false
        }
    }

    SystemClock {
        id: _weatherClock
        precision: SystemClock.Hours
        onHoursChanged: appState.refresh()
    }

    // ══════════════════════════════════════════════════════════════
    // BLUETOOTH — rfkill power control + bluetoothctl live monitor.
    // Power state is read on startup and re-read (debounced 600 ms)
    // whenever bluetoothctl reports a change.
    // ══════════════════════════════════════════════════════════════

    property bool btPowered: false

    function powerOn()     { _btOnProc.running  = true }
    function powerOff()    { _btOffProc.running = true }
    function togglePower() {
        if (appState.btPowered) _btOffProc.running = true
        else                    _btOnProc.running  = true
    }

    property var _btCheckProc: Process {
        running: false
        command: ["sh", "-c",
            "bluetoothctl show | grep -q 'Powered: yes' && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => { appState.btPowered = data.trim() === "1" }
        }
    }

    property var _btOnProc: Process {
        running: false
        command: ["rfkill", "unblock", "bluetooth"]
        // Adapter needs ~400 ms to fully initialize after unblock
        onExited: _btOnDelayTimer.restart()
    }

    property var _btOnDelayTimer: Timer {
        interval: 400
        repeat:   false
        onTriggered: appState._btCheckProc.running = true
    }

    property var _btOffProc: Process {
        running: false
        command: ["rfkill", "block", "bluetooth"]
        onExited: appState._btCheckProc.running = true
    }

    property var _btMonitor: Process {
        running: true
        command: ["bluetoothctl", "monitor"]
        stdout: SplitParser {
            onRead: data => _btDebounce.restart()
        }
    }

    property var _btDebounce: Timer {
        interval: 600
        repeat:   false
        onTriggered: appState._btCheckProc.running = true
    }

    // ══════════════════════════════════════════════════════════════
    // LIFECYCLE
    // ══════════════════════════════════════════════════════════════

    Component.onCompleted: {
        // Weather: fetch now; SystemClock handles hourly refreshes automatically
        refresh()
        // Bluetooth: read initial power state
        _btCheckProc.running = true
    }
}
