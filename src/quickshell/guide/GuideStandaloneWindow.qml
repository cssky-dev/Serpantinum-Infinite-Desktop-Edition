import QtQuick
import Quickshell
import "../"

FloatingWindow {
    id: win

    property string tab: ""
    readonly property alias popup: popupItem
    readonly property real uiScale: Scaler.s(1)

    signal closeRequested()

    title: "Serpantinum Settings"
    color: "transparent"
    visible: true

    implicitWidth: Math.min(Math.round(1200 * uiScale), Math.max(640, (screen ? screen.width : 1280) - 80))
    implicitHeight: Math.min(Math.round(750 * uiScale), Math.max(480, (screen ? screen.height : 800) - 80))
    minimumSize: Qt.size(Math.round(640 * uiScale), Math.round(480 * uiScale))

    function gotoTab(name) {
        if (name !== undefined && name !== null && String(name) !== "") popupItem.gotoTab(name);
    }

    function requestClose() {
        popupItem.startExit(function() { win.closeRequested(); });
    }

    onClosed: win.closeRequested()
    onTabChanged: gotoTab(tab)

    GuidePopup {
        id: popupItem
        anchors.fill: parent
        visible: win.visible
        dragEnabled: false
        hostDismiss: function() { win.requestClose(); }
        Component.onCompleted: win.gotoTab(win.tab)
    }
}
