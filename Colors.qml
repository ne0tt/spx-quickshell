pragma Singleton

import Quickshell
import QtQuick

// Singleton — colours updated by matugen on wallpaper change.
// Access from any QML file that imports the root module:
//   Colors.col_primary  Colors.col_source_color  etc.
Singleton {
    property color col_background: "#15130c"
    property color col_source_color: "#e6cb01"
    property color col_primary: "#d8c770"
    property color col_main: "#353116"
}