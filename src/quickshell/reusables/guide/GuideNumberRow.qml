import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

SettingsRow {
    id: row

    property real from: 0
    property real to: 100
    property real step: 1
    property real value: 0
    property bool available: true
    property string unavailableText: ""

    signal picked(real v)

    verticalPadding: row.s(11)
    hiddenByConfig: !row.available
    unavailableReason: row.unavailableText

    NumberSelector {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        implicitWidth: row.s(120)
        implicitHeight: row.s(32)
        from: row.from
        to: row.to
        stepSize: row.step
        decimals: 0
        value: row.value
        baseColor: ThemeBackend.surface0
        accentColor: ThemeBackend.mauve
        buttonColor: ThemeBackend.surface1
        buttonTextColor: ThemeBackend.text
        textColor: ThemeBackend.text
        subTextColor: ThemeBackend.subtext0
        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
        cornerRadius: ThemeBackend.borderRadius
        fontFamily: ThemeBackend.fontFamily
        fontPixelSize: row.s(11)
        onValueChanged: {
            let v = Math.round(value);
            if (!isNaN(v) && v !== Math.round(row.value)) row.picked(v);
        }
    }
}
