import QtQuick
import "../../"
import "../"

SettingsRow {
    id: row

    property bool checked: false
    property bool available: true
    property string unavailableText: ""

    signal toggled(bool value)

    verticalPadding: row.s(11)
    hiddenByConfig: !row.available
    unavailableReason: row.unavailableText

    Toggle {
        checked: row.checked
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface1
        handleColor: ThemeBackend.crust
        handleOffColor: ThemeBackend.text
        onToggled: function(c) { row.toggled(c); }
    }
}
