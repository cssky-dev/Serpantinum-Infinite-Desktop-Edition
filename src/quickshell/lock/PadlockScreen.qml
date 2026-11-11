import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import "../"
import "../reusables"
import "redactor"
import "redactor/elements"

// "Padlock" lock screen animation, ported from the Caelestia lock screen.
//
// A padlock spins in, then morphs into a rounded card holding the weather, media,
// clock, password field, system resources and notifications. Unlocking plays the
// same sequence backwards (card collapses into the padlock, then the session unlocks).
//
// It exposes the same context API as LockScreen.qml so the shared lock elements
// (password input, avatar, fingerprint, notifications, battery) work unchanged.
FocusScope {
    id: padlockRoot

    required property var surface
    required property var root
    required property var rootLock
    required property var pam
    required property var lockUI
    required property var suspendProcess
    required property var reloadProcess
    required property var poweroffProcess

    readonly property var passwordInput: dashboard.passwordInput

    anchors.fill: parent
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    // ---- context shared with the lock elements ---------------------------------
    readonly property var glassScreen: surface.screen
    property string safeScreenName: (surface.screen && surface.screen.name) ? surface.screen.name : (surface.output && surface.output.name ? surface.output.name : "")
    readonly property var lockSettings: Config.getSetting("lockscreen", {})
    readonly property string customBackgroundPath: lockSettings.customBackground ? String(lockSettings.customBackground) : ""
    readonly property bool customBackgroundActive: lockSettings.backgroundMode === "custom" && customBackgroundPath !== ""

    function isVideoPath(path) {
        let lp = String(path || "").toLowerCase();
        return lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm");
    }

    readonly property string wallpaperSource: {
        if (customBackgroundActive && !isVideoPath(customBackgroundPath)) {
            return "file://" + customBackgroundPath;
        }
        let cacheDir = Caching.getCacheDir("wallpaper");
        if (safeScreenName !== "" && safeScreenName !== "default") {
            return "file://" + cacheDir + "/current_wallpaper_" + safeScreenName + ".png";
        }
        return "file://" + cacheDir + "/current_wallpaper.png";
    }
    // "Wallpaper only" prompt background: never show the frozen desktop behind the prompt.
    readonly property bool useFrozenDesktop: lockSettings.promptBackdropMode !== "wallpaper"
    readonly property string currentFreezePath: {
        if (!useFrozenDesktop || root.freezeTimestamp === "") return "";
        let scrName = (safeScreenName !== "" && safeScreenName !== "default") ? safeScreenName : "default";
        return Caching.getRunDir("screenshot") + "/lock_freeze_" + scrName + "_" + root.freezeTimestamp + ".png";
    }

    readonly property string currentUser: SystemInfo.username !== "" ? SystemInfo.username : I18n.t("lock.default_user")
    readonly property string faceIconPath: SystemInfo.avatarPath !== "" ? (SystemInfo.avatarPath.startsWith("file://") ? SystemInfo.avatarPath : "file://" + SystemInfo.avatarPath) : ""
    readonly property bool dndEnabled: {
        let n = Config.getSetting("notifications", { "dnd": false });
        return Boolean(n && n.dnd);
    }

    property bool powerMenuOpen: false
    property bool inputActive: false
    property bool isPlayingIntro: true
    readonly property bool isUnlocking: root.isUnlocking
    readonly property bool backdropSettled: true

    property alias idleTimer: idleTimer

    // The padlock tile (intro / unlock only; the login UI itself is LockDashboard).
    readonly property real padlockSize: s(220)
    readonly property real closedRadius: padlockSize / 4

    // ---- animation state -----------------------------------------------------------
    property real bgBlur: 0.0         // 0 = sharp frozen desktop, 1 = fully blurred
    property real cardScale: 0.0
    property real cardRotation: 180
    property real cardOpacity: 0.0
    property real iconRotation: 360
    property bool glyphOpen: false    // false = locked glyph, true = open glyph
    property real snap: 1.0           // squash-and-pop multiplier on the tile
    property real ringScale: 1.0      // shock ring that rings out when the lock snaps shut / opens
    property real ringOpacity: 0.0
    property real iconOpacity: 1.0
    property real clockOpacity: 0.0
    // Same properties and meaning as LockScreen.qml, so LockDashboard / LockClock behave identically.
    property real centerReveal: 0.0   // the centre card (avatar, password, ...)
    property real wingsReveal: 0.0    // the side panels widening out of the centre card
    property real foldScaleX: 1.0
    property real foldScaleY: 1.0

    function restoreFocus() {
        if (!rootLock.locked || padlockRoot.isUnlocking) return;
        if (padlockRoot.inputActive && padlockRoot.passwordInput) {
            if (!padlockRoot.passwordInput.activeFocus) {
                padlockRoot.focus = true;
                padlockRoot.forceActiveFocus();
                padlockRoot.passwordInput.focus = true;
                padlockRoot.passwordInput.forceInputFocus();
            }
        } else if (!padlockRoot.activeFocus) {
            padlockRoot.focus = true;
            padlockRoot.forceActiveFocus();
        }
    }

    onActiveFocusChanged: {
        if (!activeFocus && rootLock.locked && !isUnlocking) Qt.callLater(padlockRoot.restoreFocus);
    }

    onInputActiveChanged: {
        lockUI.inputActive = inputActive;
        if (isUnlocking || isPlayingIntro) return;
        if (inputActive) {
            closeDashboardAnim.stop();
            openDashboardAnim.restart();
        } else {
            openDashboardAnim.stop();
            closeDashboardAnim.restart();
            powerMenuOpen = false;
        }
        restoreFocus();
    }

    Connections {
        target: lockUI
        function onInputActiveChanged() {
            if (padlockRoot.inputActive !== lockUI.inputActive) padlockRoot.inputActive = lockUI.inputActive;
        }
    }

    Keys.onPressed: (event) => {
        if (event.isAutoRepeat && event.key !== Qt.Key_Backspace) {
            event.accepted = true;
            return;
        }
        if (padlockRoot.isPlayingIntro || padlockRoot.isUnlocking) return;
        if (!padlockRoot.inputActive) {
            // First key press on the clock opens the lock screen UI.
            if (event.key !== Qt.Key_Escape) {
                padlockRoot.inputActive = true;
                padlockRoot.restoreFocus();
                if (padlockRoot.passwordInput && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backspace) {
                    padlockRoot.passwordInput.insertText(event.text);
                }
                event.accepted = true;
            }
            return;
        }
        padlockRoot.restoreFocus();
        if (!padlockRoot.passwordInput) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            lockUI.submitPassword(padlockRoot.passwordInput.text);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            padlockRoot.passwordInput.clear();
            padlockRoot.inputActive = false;
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            event.accepted = true;
        } else if (event.text.length > 0 && event.key !== Qt.Key_Backspace) {
            padlockRoot.passwordInput.insertText(event.text);
            event.accepted = true;
        }
    }

    // Back to the clock after a while without typing.
    Timer {
        id: idleTimer
        interval: 15000
        repeat: false
        running: padlockRoot.inputActive && !padlockRoot.isUnlocking && padlockRoot.passwordInput !== null && padlockRoot.passwordInput.text.length === 0
        onTriggered: {
            padlockRoot.inputActive = false;
            padlockRoot.restoreFocus();
        }
    }

    Connections {
        target: rootLock
        function onLockedChanged() {
            if (rootLock.locked) padlockRoot.restoreFocus();
        }
    }

    Connections {
        target: surface
        function onVisibleChanged() {
            if (surface.visible && rootLock.locked && !padlockRoot.isUnlocking) padlockRoot.restoreFocus();
        }
    }

    Connections {
        target: root
        function onResumeRevisionChanged() {
            if (rootLock.locked && !padlockRoot.isUnlocking) padlockRoot.restoreFocus();
        }
    }

    // Squash-and-pop on the tile plus an expanding ring, used when the lock snaps shut or opens.
    ParallelAnimation {
        id: pulseAnim
        running: false

        SequentialAnimation {
            NumberAnimation { target: padlockRoot; property: "snap"; to: 0.86; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: padlockRoot; property: "snap"; to: 1.0; duration: 360; easing.type: Easing.OutElastic; easing.amplitude: 1.0; easing.period: 0.4 }
        }
        SequentialAnimation {
            ScriptAction { script: { padlockRoot.ringScale = 1.0; padlockRoot.ringOpacity = 0.55; } }
            ParallelAnimation {
                NumberAnimation { target: padlockRoot; property: "ringScale"; to: 2.3; duration: 620; easing.type: Easing.OutCubic }
                NumberAnimation { target: padlockRoot; property: "ringOpacity"; to: 0.0; duration: 620; easing.type: Easing.OutQuad }
            }
        }
    }

    // ---- intro: the padlock appears, scales out exponentially, the clock appears -----------
    SequentialAnimation {
        id: introAnim
        running: false

        ParallelAnimation {
            NumberAnimation { target: padlockRoot; property: "bgBlur"; to: 1.0; duration: 450; easing.type: Easing.OutCubic }
            SequentialAnimation {
                ScriptAction { script: { padlockRoot.glyphOpen = true; padlockRoot.cardOpacity = 1.0; padlockRoot.iconOpacity = 1.0; } }
                ParallelAnimation {
                    NumberAnimation { target: padlockRoot; property: "cardScale"; to: 1.0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    NumberAnimation { target: padlockRoot; property: "cardRotation"; to: 360; duration: 300; easing.type: Easing.OutCubic }
                }
                ScriptAction { script: padlockRoot.glyphOpen = false }
                PauseAnimation { duration: 80 }
                ParallelAnimation {
                    NumberAnimation { target: padlockRoot; property: "cardScale"; to: 0.0; duration: 260; easing.type: Easing.InCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: 120 }
                        NumberAnimation { target: padlockRoot; property: "clockOpacity"; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        ScriptAction {
            script: {
                padlockRoot.isPlayingIntro = false;
                padlockRoot.restoreFocus();
            }
        }
    }

    // ---- typing / click: identical to LockScreen.qml (centre card first, then the wings) ----
    SequentialAnimation {
        id: openDashboardAnim
        running: false
        NumberAnimation { target: padlockRoot; property: "centerReveal"; to: 1.0; duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        NumberAnimation { target: padlockRoot; property: "wingsReveal"; to: 1.0; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.12 }
        ScriptAction { script: padlockRoot.restoreFocus() }
    }

    ParallelAnimation {
        id: closeDashboardAnim
        running: false
        NumberAnimation { target: padlockRoot; property: "wingsReveal"; to: 0.0; duration: 110; easing.type: Easing.InQuad }
        NumberAnimation { target: padlockRoot; property: "centerReveal"; to: 0.0; duration: 100; easing.type: Easing.InQuad }
    }

    // ---- unlock: the UI folds away exactly like LockScreen.qml, then the padlock opens and shrinks ----
    SequentialAnimation {
        id: unlockAnim
        running: false

        ScriptAction {
            script: {
                padlockRoot.powerMenuOpen = false;
                padlockRoot.iconRotation = 360;
                padlockRoot.cardRotation = 360;
                padlockRoot.glyphOpen = false;
            }
        }

        NumberAnimation { target: padlockRoot; property: "wingsReveal"; to: 0.0; duration: 130; easing.type: Easing.InQuad }

        ParallelAnimation {
            NumberAnimation { target: padlockRoot; property: "foldScaleX"; to: 0.0; duration: 250; easing.type: Easing.InBack; easing.overshoot: 1.3 }
            NumberAnimation { target: padlockRoot; property: "foldScaleY"; to: 0.0; duration: 250; easing.type: Easing.InBack; easing.overshoot: 1.3 }
            NumberAnimation { target: padlockRoot; property: "centerReveal"; to: 0.0; duration: 250; easing.type: Easing.InQuad }
            NumberAnimation { target: padlockRoot; property: "clockOpacity"; to: 0.0; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: padlockRoot; property: "cardOpacity"; to: 1.0; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: padlockRoot; property: "iconOpacity"; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
            NumberAnimation { target: padlockRoot; property: "cardScale"; to: 1.0; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        ScriptAction { script: padlockRoot.glyphOpen = true }
        PauseAnimation { duration: 120 }

        ParallelAnimation {
            NumberAnimation { target: padlockRoot; property: "cardScale"; to: 0.0; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: padlockRoot; property: "bgBlur"; to: 0.0; duration: 380; easing.type: Easing.InOutCubic }
        }
        PauseAnimation { duration: 20 }

        ScriptAction {
            script: padlockRoot.root.completeUnlock()
        }
    }

    onIsUnlockingChanged: {
        if (isUnlocking) {
            introAnim.stop();
            openDashboardAnim.stop();
            closeDashboardAnim.stop();
            unlockAnim.restart();
        } else {
            unlockAnim.stop();
            glyphOpen = false;
            foldScaleX = 1.0;
            foldScaleY = 1.0;
            snap = 1.0;
            ringOpacity = 0.0;
            bgBlur = 1.0;
            cardOpacity = 0.0;
            clockOpacity = 1.0;
        }
    }

    Timer {
        id: introStartTimer
        interval: 120
        repeat: false
        onTriggered: if (!introAnim.running && padlockRoot.isPlayingIntro && !padlockRoot.isUnlocking) introAnim.start()
    }

    Component.onCompleted: {
        restoreFocus();
        introStartTimer.start();
    }

    // Resource tile polling is only needed while the card is open.
    property bool sysSubscribed: false
    readonly property bool resourcesLive: wingsReveal > 0.98 && !isUnlocking
    onResourcesLiveChanged: {
        if (resourcesLive && !sysSubscribed) {
            SysData.subscribe();
            Spectrum.registerConsumer();
            sysSubscribed = true;
        } else if (!resourcesLive && sysSubscribed) {
            SysData.unsubscribe();
            Spectrum.unregisterConsumer();
            sysSubscribed = false;
        }
    }
    Component.onDestruction: {
        if (sysSubscribed) {
            SysData.unsubscribe();
            Spectrum.unregisterConsumer();
            sysSubscribed = false;
        }
    }

    // ---- background -------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.crust
        z: -2
    }

    // A new wallpaper rewrites the same cache file, so the picture has to be reloaded.
    Timer {
        id: padWallpaperReload
        interval: 40
        onTriggered: padWallpaperImg.source = padlockRoot.wallpaperSource
    }
    Connections {
        target: typeof Wallpaper !== "undefined" ? Wallpaper : null
        function onWallpaperChanged() {
            padWallpaperImg.source = "";
            padWallpaperReload.restart();
        }
    }

    Item {
        id: backdrop
        anchors.fill: parent
        z: -1
        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: padlockRoot.bgBlur > 0.001
            blur: padlockRoot.bgBlur
            blurMax: 64
            blurMultiplier: 1.0
        }

        Image {
            id: padWallpaperImg
            anchors.fill: parent
            source: padlockRoot.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))
            onStatusChanged: {
                if (status === Image.Error) {
                    let fallback = "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png";
                    if (source.toString() !== fallback) source = fallback;
                }
            }
        }

        Image {
            anchors.fill: parent
            source: (padlockRoot.currentFreezePath !== "" && padlockRoot.root.freezeTimestamp !== "") ? ("file://" + padlockRoot.currentFreezePath) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
            sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))
            visible: status === Image.Ready
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.28 * padlockRoot.bgBlur)
        }
    }

    // Idle layout: the same clock module Serpantinum uses (it hides itself when the dashboard opens).
    Item {
        anchors.fill: parent
        z: 2
        opacity: padlockRoot.clockOpacity
        visible: opacity > 0.01

        LockClock {
            screenRoot: padlockRoot
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 1
        preventStealing: true
        enabled: !padlockRoot.isPlayingIntro && !padlockRoot.isUnlocking
        onPressed: padlockRoot.restoreFocus()
        onClicked: {
            if (!padlockRoot.inputActive) padlockRoot.inputActive = true;
            padlockRoot.restoreFocus();
        }
    }

    // shock ring behind the tile
    Rectangle {
        z: 4
        anchors.centerIn: parent
        width: padlockRoot.padlockSize
        height: padlockRoot.padlockSize
        radius: padlockRoot.closedRadius
        color: "transparent"
        border.width: Math.max(2, padlockRoot.s(3))
        border.color: ThemeBackend.text
        scale: padlockRoot.ringScale
        opacity: padlockRoot.ringOpacity
        visible: opacity > 0.01
    }

    // ---- the card -----------------------------------------------------------------------
    Item {
        id: card
        z: 5
        anchors.centerIn: parent
        width: padlockRoot.padlockSize
        height: padlockRoot.padlockSize
        rotation: padlockRoot.cardRotation
        scale: padlockRoot.cardScale * padlockRoot.snap
        opacity: padlockRoot.cardOpacity
        visible: opacity > 0.01 && scale > 0.001

        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: padlockRoot.closedRadius
            color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity * LockLayoutStore.panelOpacity)
            border.width: 1
            border.color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.07)

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.9
                shadowColor: Qt.rgba(0, 0, 0, 0.7)
            }
        }

        // Same glyph as Caelestia: the Material "lock" icon (nf-md-lock), bold, in the
        // normal text colour, centred on the tile and spinning with it.
        Text {
            id: padlockGlyph
            anchors.centerIn: parent
            text: padlockRoot.glyphOpen ? "\uDB80\uDF3F" : "\uDB80\uDF3E"
            font.family: ThemeBackend.iconFont
            font.pixelSize: padlockRoot.s(140)
            font.bold: true
            color: ThemeBackend.text
            renderType: Text.NativeRendering
            rotation: padlockRoot.iconRotation
            opacity: padlockRoot.iconOpacity
            visible: opacity > 0.01
        }
    }

    // The real lock screen UI (centre card + wings), shared with LockScreen.qml.
    LockDashboard {
        id: dashboard
        z: 6
        screenRoot: padlockRoot
    }

    // Suspend / reboot / power off, the same menu as LockScreen.qml.
    LockPowerControls {
        z: 7
        screenRoot: padlockRoot
    }
}
