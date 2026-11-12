import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

SettingsRow {
    id: row

    property var options: []
    property int currentIndex: 0
    property real controlWidth: 200
    property bool available: true
    property string unavailableText: ""

    signal picked(int index)

    verticalPadding: row.s(11)
    hiddenByConfig: !row.available
    unavailableReason: row.unavailableText

    function close() {
        if (dropdown.isOpen) dropdown.closePopup();
    }

    Dropdown {
        id: dropdown
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        implicitWidth: row.s(row.controlWidth)
        implicitHeight: row.s(32)
        options: row.options
        currentIndex: row.currentIndex
        accentColor: ThemeBackend.mauve
        baseColor: ThemeBackend.surface0
        hoverColor: ThemeBackend.surface1
        dropdownColor: ThemeBackend.surface0
        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
        textColor: ThemeBackend.text
        activeTextColor: ThemeBackend.crust
        fontPixelSize: row.s(11)
        onValueChanged: function(index, value) { row.picked(index); }
    }
}
