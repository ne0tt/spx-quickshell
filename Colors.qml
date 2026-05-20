pragma Singleton

import Quickshell
import QtQuick

// Singleton — colours updated by matugen on wallpaper change.
// Access from any QML file that imports the root module:
//   Colors.col_primary  Colors.col_source_color  etc.
Singleton {
    property color col_background: "#0e1514"
    property color col_source_color: "#2decec"
    property color col_primary: "#80d5d4"
    property color col_main: "#1b3534"
}