import QtQuick
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsRow {
    id: row

    required property var tab
    property string key: ""
    property bool value: false
    property bool needsDesktop: true

    rootObj: row.tab.rootObj
    verticalPadding: row.s(11)
    hiddenByConfig: !CanvasEngine.supported || (row.needsDesktop && !CanvasEngine.masterEnabled)
    unavailableReason: !CanvasEngine.supported ? row.tab.tr("guide.desktop.supported_only", "Hyprland and Sway only") : ""

    Toggle {
        checked: row.value
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface1
        handleColor: ThemeBackend.crust
        handleOffColor: ThemeBackend.text
        onToggled: function(c) { row.tab.setCanvas(row.key, c); }
    }
}
