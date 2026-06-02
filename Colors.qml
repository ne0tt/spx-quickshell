pragma Singleton

import Quickshell
import QtQuick

// Singleton — colours updated by matugen on wallpaper change.
// Access from any QML file that imports the root module:
//   Colors.col_primary  Colors.col_source_color  etc.
Singleton {
    property color col_background: "#121413"
    property color col_source_color: "#2decec"
    property color col_primary: "#a1f7f7"
    property color col_main: "#222a2a"
}