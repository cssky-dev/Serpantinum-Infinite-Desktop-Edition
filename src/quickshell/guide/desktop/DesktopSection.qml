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

    SettingsBlob {
        id: blob
        Layout.fillWidth: true
    }
}
