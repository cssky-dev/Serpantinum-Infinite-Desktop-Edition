import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

ColumnLayout {
    id: section

    required property var tab
    property string title: ""
    property bool shown: true

    default property alias rows: blob.content

    Layout.fillWidth: true
    spacing: tab.rootObj ? tab.rootObj.s(6) : 6
    visible: section.shown

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: section.tab.rootObj ? section.tab.rootObj.s(6) : 6
        Layout.topMargin: section.tab.rootObj ? section.tab.rootObj.s(8) : 8
        text: section.title.toUpperCase()
        font.family: ThemeBackend.fontFamily
        font.pixelSize: section.tab.rootObj ? section.tab.rootObj.s(10) : 10
        font.letterSpacing: 1.4
        color: ThemeBackend.subtext0
        opacity: 0.75
        elide: Text.ElideRight
    }

    SettingsBlob {
        id: blob
        Layout.fillWidth: true
    }
}
