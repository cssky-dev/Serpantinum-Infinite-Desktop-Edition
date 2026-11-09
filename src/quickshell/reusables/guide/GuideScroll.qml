import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"

Flickable {
    id: root

    required property var rootObj
    default property alias content: col.data
    readonly property alias column: col

    anchors.fill: parent
    anchors.topMargin: root.rootObj.s(8)
    anchors.leftMargin: root.rootObj.s(8)
    anchors.rightMargin: root.rootObj.s(8)
    anchors.bottomMargin: root.rootObj.s(4)
    contentWidth: width
    contentHeight: col.implicitHeight + root.rootObj.s(16)
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ScrollBar.vertical: ScrollBar {
        active: root.moving || root.movingVertically
        width: root.rootObj.s(4)
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: root.rootObj.s(4)
            radius: root.rootObj.s(2)
            color: ThemeBackend.surface2
        }
    }

    ColumnLayout {
        id: col
        width: root.width - root.rootObj.s(6)
        spacing: root.rootObj.s(6)
    }
}
