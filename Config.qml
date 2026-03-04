import QtQuick

// ============================================================
// CONFIG — shell-wide non-colour settings.
// Declared once in ShellRoot; all components reference via
// the global `config` id, e.g. config.fontFamily.
// ============================================================
QtObject {
    // Font used everywhere in the bar and all dropdowns.
    // Change this one line to restyle the entire shell.
    property string fontFamily: "JetBrainsMonoNF-Regular"
}
