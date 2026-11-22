import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

ColumnLayout {
    id: section

    required property var rootObj
    property string title: ""
    property bool shown: true

    default property alias rows: blob.content

    Layout.fillWidth: true
    spacing: section.rootObj.s(6)
    visible: section.shown

    Text {
        Layout.fillWidth: true
        Layout.leftMargin: section.rootObj.s(6)
        Layout.topMargin: section.rootObj.s(8)
        visible: section.title !== ""
        text: section.title.toUpperCase()
        font.family: ThemeBackend.fontFamily
        font.pixelSize: section.rootObj.s(10)
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
