import Quickshell
import Quickshell.Io
import QtQuick

Rectangle {
    id: powerProfilePanel

    property string fontFamily:      config.fontFamily
    property int    iconSize:        28
    property int    fontWeight:      Font.Bold

    property bool   isActive:        false
    property color  accentColor:     "white"
    property color  activeColor:     "white"
    property color  hoverColor:      accentColor
    property color  dimColor:        Qt.rgba(1, 1, 1, 0.4)

    property color  backgroundColor: "transparent"
    property color  borderColor:     "transparent"
    property bool   _hovered:        false
    property string currentProfile: ""
    property var icons: {
        return {
            "power-saver": "󰌪", // leaf
            "balanced": "",    // scales
            "performance": ""  // rocket
        }
    }
    width: 30
    height: 24
    radius: 7
    color: backgroundColor
    border.color: borderColor
    border.width: 1

    Text {
        id: iconText
        anchors.centerIn: parent
        color: powerProfilePanel.isActive ? powerProfilePanel.activeColor : powerProfilePanel._hovered ? powerProfilePanel.hoverColor : powerProfilePanel.accentColor
        font.family: fontFamily
        font.pixelSize: iconSize
        font.weight: fontWeight
        text: powerProfilePanel.icons[powerProfilePanel.currentProfile] || "?"
        opacity: 1.0
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    signal clicked(real clickX)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: powerProfilePanel._hovered = true
        onExited:  powerProfilePanel._hovered = false
        onClicked: {
            var pos = powerProfilePanel.mapToItem(null, 0, 0)
            powerProfilePanel.clicked(pos.x + powerProfilePanel.width / 2)
        }
    }

    // ============================================================
    // INITIAL READ — get current profile once at startup
    // ============================================================
    Process {
        id: getProfileProc
        command: ["powerprofilesctl", "get"]
        stdout: SplitParser {
            onRead: data => { powerProfilePanel.currentProfile = data.trim() }
        }
    }
    Component.onCompleted: getProfileProc.running = true

    // ============================================================
    // DBUS MONITOR — persistent process, zero idle CPU
    // Subscribes to net.hadess.PowerProfiles PropertiesChanged and
    // prints the new ActiveProfile name whenever it changes.
    // ============================================================
    Process {
        id: profileMonitorProc
        running: true
        command: [
            "python3", "-c",
            "import dbus, sys\n" +
            "from dbus.mainloop.glib import DBusGMainLoop\n" +
            "from gi.repository import GLib\n" +
            "DBusGMainLoop(set_as_default=True)\n" +
            "bus = dbus.SystemBus()\n" +
            "def on_changed(iface, changed, invalidated):\n" +
            "    if 'ActiveProfile' in changed:\n" +
            "        print(str(changed['ActiveProfile']), flush=True)\n" +
            "bus.add_signal_receiver(on_changed,\n" +
            "    dbus_interface='org.freedesktop.DBus.Properties',\n" +
            "    signal_name='PropertiesChanged',\n" +
            "    path='/net/hadess/PowerProfiles')\n" +
            "GLib.MainLoop().run()\n"
        ]
        stdout: SplitParser {
            onRead: data => { powerProfilePanel.currentProfile = data.trim() }
        }
    }
}
