import QtQuick
import Quickshell
import Quickshell.Io
import "widgets"
import "notifications/weather"
import "notifications/battery"

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool quickactionsEnabled: Config.getSetting("general", {}).quickactions !== false
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    LazyLoader {
        id: screenshotLoader
        ScreenshotOverlay {}
    }

    function ensureScreenshotOverlay() {
        if (!screenshotLoader.item) screenshotLoader.active = true;
        return screenshotLoader.item;
    }

    IpcHandler {
        target: "screenshotOverlay"

        function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.toggleOverlay(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function deactivate(): void {
            if (screenshotLoader.item) screenshotLoader.item.deactivate();
        }
    }

    Main {}
    Bar {}
    Lock {}
    WidgetRedactor {}
    LockRedactor {}

    // Launcher and Clipboard are fullscreen windows with large QML trees (lists, delegates, models).
    // They are only instantiated while open, and kept for a while after closing so re-opening is instant.
    LazyLoader {
        active: LauncherController.isVisible || launcherKeepAlive.running
        Launcher {}
    }
    Timer { id: launcherKeepAlive; interval: 45000; repeat: false }
    Connections {
        target: LauncherController
        function onIsVisibleChanged() { launcherKeepAlive.restart(); }
    }

    LazyLoader {
        active: ClipboardController.isVisible || clipboardKeepAlive.running
        Clipboard {}
    }
    Timer { id: clipboardKeepAlive; interval: 45000; repeat: false }
    Connections {
        target: ClipboardController
        function onIsVisibleChanged() { clipboardKeepAlive.restart(); }
    }
    // The dashboard is a fullscreen overlay window: it only exists while it is open (plus a
    // short grace period so its close animation can finish).
    LazyLoader {
        id: dashboardLoader
        active: DashboardController.isVisible || dashboardKeepAlive.running
        Dashboard {}
    }

    Timer {
        id: dashboardKeepAlive
        interval: 2500
        repeat: false
    }

    Connections {
        target: DashboardController
        function onIsVisibleChanged() { dashboardKeepAlive.restart(); }
    }
    InfiniteDesktop {}

    LazyLoader {
        active: PolkitService.isActive || polkitKeepAlive.running
        Polkit {}
    }
    Timer { id: polkitKeepAlive; interval: 2000; repeat: false }
    Connections {
        target: PolkitService
        function onIsActiveChanged() { polkitKeepAlive.restart(); }
    }
    WellbeingLimitOverlay {}
    PopoutManager {}

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Idle {}
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }
    Loader {
        active: !performanceMode && quickactionsEnabled && !CanvasEngine.hidesQuickactions
        sourceComponent: Floating {}
    }

    Component.onCompleted: {
        Qt.application.organization = "serpantinum";
        Qt.application.domain = "serpantinum.org";
        Qt.application.name = "serpantinum";
        FirstLaunch.checkFirstLaunch();
        SysNotif.checkBattery();
        WeatherAlerts.isQuietNow();
        GovAlerts.refresh();
    }
}
