import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsRow {
    id: row

    required property var tab
    property real from: 0
    property real to: 100
    property real step: 1
    property real fallback: 0
    property real value: 0
    property bool hideWhen: false
    property var format: function(v) { return Math.round(v).toString(); }

    signal picked(real v)

    rootObj: row.tab.rootObj
    verticalPadding: row.s(11)
    hiddenByConfig: !CanvasEngine.supported || !CanvasEngine.masterEnabled || row.hideWhen
    unavailableReason: !CanvasEngine.supported ? row.tab.tr("guide.desktop.supported_only", "Hyprland and Sway only") : ""

    Draggable {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        implicitWidth: row.s(200)
        implicitHeight: row.s(18)
        from: row.from
        to: row.to
        stepSize: row.step
        defaultValue: row.fallback
        showValueBubble: true
        valueFormatter: row.format
        value: row.value
        backgroundColor: ThemeBackend.surface0
        accentColor: ThemeBackend.mauve
        handleColor: ThemeBackend.text
        handleBorderColor: ThemeBackend.mantle
        onMoved: function(val) {
            let r = Math.round(val / row.step) * row.step;
            if (Math.abs(r - row.value) > 0.0001) row.picked(r);
        }
    }
}
