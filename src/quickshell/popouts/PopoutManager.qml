import QtQuick
import Quickshell
import "../"

Item {
    id: root

    Osd {}

    // Hover popouts are created on first use and released after a period of inactivity.
    property bool trayAlive: false
    LazyLoader {
        active: trayAlive
        TrayBase {}
    }
    Timer { id: trayKeepAlive; interval: 20000; repeat: false; onTriggered: if (!TrayMenuController.isVisible) trayAlive = false }
    Connections {
        target: TrayMenuController
        function onIsVisibleChanged() { if (TrayMenuController.isVisible) trayAlive = true; trayKeepAlive.restart(); }
    }

    property bool sideMusicAlive: false
    LazyLoader {
        active: sideMusicAlive
        SideMusicPopout {}
    }
    Timer { id: sideMusicKeepAlive; interval: 20000; repeat: false; onTriggered: if (!SideMusicController.isVisible) sideMusicAlive = false }
    Connections {
        target: SideMusicController
        function onIsVisibleChanged() { if (SideMusicController.isVisible) sideMusicAlive = true; sideMusicKeepAlive.restart(); }
    }

    DesktopMenu {}
    DockAppMenu {}
}
