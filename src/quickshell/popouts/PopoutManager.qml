import QtQuick
import Quickshell
import "../"

Item {
    id: root

    Osd {}

    // Hover popouts are created on first use and released after a period of inactivity.
    LazyLoader {
        active: TrayMenuController.isVisible || trayKeepAlive.running
        TrayBase {}
    }
    Timer { id: trayKeepAlive; interval: 20000; repeat: false }
    Connections {
        target: TrayMenuController
        function onIsVisibleChanged() { trayKeepAlive.restart(); }
    }

    LazyLoader {
        active: SideMusicController.isVisible || sideMusicKeepAlive.running
        SideMusicPopout {}
    }
    Timer { id: sideMusicKeepAlive; interval: 20000; repeat: false }
    Connections {
        target: SideMusicController
        function onIsVisibleChanged() { sideMusicKeepAlive.restart(); }
    }

    DesktopMenu {}
    DockAppMenu {}
}
