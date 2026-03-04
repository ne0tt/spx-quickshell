import Quickshell
import Quickshell.Io
import QtQuick

Rectangle {
    id: vpnModule
    width: vpnBoxWidth
    height: 24
    radius: 8
    color: backgroundColor
    border.color: "black"
    border.width: 1
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    // Don't hide immediately — debounce so reloads don't cause a flash
    visible: _stableVisible
    property bool _stableVisible: false
    onVpnIpChanged: {
        if (vpnIp !== "") {
            _stableVisible = true
            hideTimer.stop()
        } else {
            hideTimer.restart()
        }
    }
    Timer {
        id: hideTimer
        interval: 5000   // only hide after 5 s of empty vpnIp
        repeat: false
        onTriggered: vpnModule._stableVisible = false
    }
    property int vpnBoxWidth: 110
    property string fontFamily: config.fontFamily
    property int    fontSize:   11
    property int    iconSize:   14
    property int    fontWeight: Font.Bold

    property bool   isActive:   false
    property color  accentColor: "#2decec"
    property color  activeColor: "white"
    property color  hoverColor:  accentColor
    property color  dimColor:    Qt.rgba(1, 1, 1, 0.4)

    property color  backgroundColor: "#0e1514"
    property bool   _hovered:   false
    property string vpnIp: ""
    property bool showVpnIp: false
    signal clicked(real clickX)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: vpnModule._hovered = true
        onExited:  vpnModule._hovered = false
        onClicked: {
            var pos = vpnModule.mapToItem(null, 0, 0)
            vpnModule.clicked(pos.x + vpnModule.width / 2)
        }
    }
    Row {
        anchors.centerIn: parent
        spacing: 3
        height: parent.height

        Text {
            id: vpnIcon
            visible: vpnModule.showVpnIp
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: vpnModule.isActive ? vpnModule.activeColor : vpnModule._hovered ? vpnModule.hoverColor : vpnModule.accentColor
            font.family: fontFamily
            font.styleName: "Solid"
            font.pixelSize: vpnModule.iconSize
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Text {
            id: vpnText
            anchors.verticalCenter: parent.verticalCenter
            color: vpnModule.isActive ? vpnModule.activeColor : vpnModule._hovered ? vpnModule.hoverColor : vpnModule.accentColor
            font {
                family: fontFamily
                pixelSize: fontSize
                weight: fontWeight
            }
            text: vpnModule.showVpnIp ? vpnModule.vpnIp : "VPN CONNECTED"
            opacity: 1.0
            Behavior on color { ColorAnimation { duration: 160 } }
        }
    }
    SequentialAnimation {
        id: vpnPulseAnim
        running: false
        loops: 5
        ColorAnimation { target: vpnText; to: "white";      duration: 200 }
        ColorAnimation { target: vpnText; to: accentColor;  duration: 200 }
    }
    // ============================================================
    // FILEVIEW — reacts to inotify events, zero polling overhead
    // ============================================================
    FileView {
        id: ipinfoFile
        path: Quickshell.env("HOME") + "/.ipinfo/ipinfo.txt"
        watchChanges: true          // inotify: reload only when file actually changes
        onFileChanged: this.reload()
        onLoaded: {
            var prevVpn = vpnModule.vpnIp
            try {
                var ipinfo = JSON.parse(ipinfoFile.text())
                vpnModule.vpnIp = ipinfo.ip || ""
            } catch (e) {
                vpnModule.vpnIp = ""
            }
            if (vpnModule.vpnIp !== "" && prevVpn === "") {
                vpnPulseAnim.running = true
            }
        }
        onLoadFailed: vpnModule.vpnIp = ""
    }
}
