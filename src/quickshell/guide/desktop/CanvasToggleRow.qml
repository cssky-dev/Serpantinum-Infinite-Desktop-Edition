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
    hiddenByConfig: !CanvasEngine.isHyprland || (row.needsDesktop && !CanvasEngine.masterEnabled)
    unavailableReason: !CanvasEngine.isHyprland ? row.tab.tr("guide.desktop.hyprlandonly", "Hyprland only") : ""

    Toggle {
        checked: row.value
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface1
        handleColor: ThemeBackend.crust
        handleOffColor: ThemeBackend.text
        onToggled: function(c) { row.tab.setCanvas(row.key, c); }
    }
}
