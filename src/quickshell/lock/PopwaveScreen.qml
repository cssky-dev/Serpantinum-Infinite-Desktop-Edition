import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import "../"
import "../reusables"
import "redactor"
import "redactor/elements"

// "Popwave" lock screen animation, ported from the sekaipop shell (its sekaiRing lock transition).
//
// Locking: a wavy emblem ring grows out of the centre of the screen over the frozen desktop and
// the lock screen (blurred backdrop + clock) appears inside it. Unlocking plays the same ring
// the other way: it opens a hole in the lock screen and the desktop grows inside the hole, then
// the session unlocks. The shader is sekai_ring_lock (assets/shaders/lock), the same maths as
// the sekaipop wallpaper ring, with transparency instead of a second picture.
//
// It exposes the same context API as LockScreen.qml so the shared lock elements
// (password input, avatar, fingerprint, notifications, battery) work unchanged.
FocusScope {
    id: popRoot

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

    // The frozen desktop the ring starts from. It is used in both prompt backdrop modes: "Wallpaper
    // only" just keeps it out of the blurred picture, so the ring still grows out of the desktop.
    readonly property string introFreezePath: {
        if (root.freezeTimestamp === "") return "";
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

    // ---- animation state -------------------------------------------------------------
    property real centerReveal: 0.0   // the centre card (avatar, password, ...)
    property real wingsReveal: 0.0    // the side panels widening out of the centre card
    property real foldScaleX: 1.0
    property real foldScaleY: 1.0

    // The ring. progress runs 0..1 Linear (the shader eases inside itself).
    property real progress: 0.0
    property bool leaving: false      // false = the lock is arriving, true = it is leaving
    property bool ringArmed: false    // waiting for the backdrop before the lock ring starts
    readonly property bool ringActive: isUnlocking || (!root.staticLock && (ringAnim.running || ringArmed || progress < 1.0))
    readonly property int ringMs: 1000
    readonly property int unlockMs: 950

    // Blur-in: the lock picture inside the ring goes from sharp to the Waved blur while the ring
    // grows, and back to sharp while the ring opens the desktop again. It rides the same linear
    // progress as the ring, eased, so both always finish together.
    readonly property real blurPhase: {
        let p = Math.max(0.0, Math.min(1.0, progress));
        let e = 1.0 - Math.pow(1.0 - p, 3.0);          // OutCubic on the way in
        let i = p * p * p;                              // InCubic on the way out, mirrors it
        return leaving ? 1.0 - i : e;
    }
    // Same strengths as the Waved lock screen: 0.72 on the clock, 1.0 once the login UI is open.
    property real blurLevel: blurPhase * (inputActive ? 1.0 : 0.72)
    Behavior on blurLevel {
        enabled: !popRoot.ringActive
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }

    function restoreFocus() {
        if (!rootLock.locked || popRoot.isUnlocking) return;
        if (popRoot.inputActive && popRoot.passwordInput) {
            if (!popRoot.passwordInput.activeFocus) {
                popRoot.focus = true;
                popRoot.forceActiveFocus();
                popRoot.passwordInput.focus = true;
                popRoot.passwordInput.forceInputFocus();
            }
        } else if (!popRoot.activeFocus) {
            popRoot.focus = true;
            popRoot.forceActiveFocus();
        }
    }

    onActiveFocusChanged: {
        if (!activeFocus && rootLock.locked && !isUnlocking) Qt.callLater(popRoot.restoreFocus);
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
            if (popRoot.inputActive !== lockUI.inputActive) popRoot.inputActive = lockUI.inputActive;
        }
    }

    Keys.onPressed: (event) => {
        if (event.isAutoRepeat && event.key !== Qt.Key_Backspace) {
            event.accepted = true;
            return;
        }
        if (popRoot.isPlayingIntro || popRoot.isUnlocking) return;
        if (!popRoot.inputActive) {
            // First key press on the clock opens the lock screen UI.
            if (event.key !== Qt.Key_Escape) {
                popRoot.inputActive = true;
                popRoot.restoreFocus();
                if (popRoot.passwordInput && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backspace) {
                    popRoot.passwordInput.insertText(event.text);
                }
                event.accepted = true;
            }
            return;
        }
        popRoot.restoreFocus();
        if (!popRoot.passwordInput) return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            lockUI.submitPassword(popRoot.passwordInput.text);
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            popRoot.passwordInput.clear();
            popRoot.inputActive = false;
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            event.accepted = true;
        } else if (event.text.length > 0 && event.key !== Qt.Key_Backspace) {
            popRoot.passwordInput.insertText(event.text);
            event.accepted = true;
        }
    }

    // Back to the clock after a while without typing.
    Timer {
        id: idleTimer
        interval: 15000
        repeat: false
        running: popRoot.inputActive && !popRoot.isUnlocking && popRoot.passwordInput !== null && popRoot.passwordInput.text.length === 0
        onTriggered: {
            popRoot.inputActive = false;
            popRoot.restoreFocus();
        }
    }

    Connections {
        target: rootLock
        function onLockedChanged() {
            if (rootLock.locked) popRoot.restoreFocus();
        }
    }

    Connections {
        target: surface
        function onVisibleChanged() {
            if (surface.visible && rootLock.locked && !popRoot.isUnlocking) popRoot.restoreFocus();
        }
    }

    Connections {
        target: root
        function onResumeRevisionChanged() {
            if (rootLock.locked && !popRoot.isUnlocking) popRoot.restoreFocus();
        }
    }

    // ---- typing / click: identical to LockScreen.qml (centre card first, then the wings) ----
    SequentialAnimation {
        id: openDashboardAnim
        running: false
        NumberAnimation { target: popRoot; property: "centerReveal"; to: 1.0; duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        NumberAnimation { target: popRoot; property: "wingsReveal"; to: 1.0; duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.12 }
        ScriptAction { script: popRoot.restoreFocus() }
    }

    ParallelAnimation {
        id: closeDashboardAnim
        running: false
        NumberAnimation { target: popRoot; property: "wingsReveal"; to: 0.0; duration: 110; easing.type: Easing.InQuad }
        NumberAnimation { target: popRoot; property: "centerReveal"; to: 0.0; duration: 100; easing.type: Easing.InQuad }
    }

    // ---- the ring: one animation drives both the lock and the unlock -------------------------
    NumberAnimation {
        id: ringAnim
        target: popRoot
        property: "progress"
        from: 0.0
        to: 1.0
        duration: popRoot.leaving ? popRoot.unlockMs : popRoot.ringMs
        easing.type: Easing.Linear
        onFinished: {
            if (popRoot.leaving) {
                popRoot.root.completeUnlock();
            } else {
                popRoot.isPlayingIntro = false;
                popRoot.restoreFocus();
            }
        }
    }

    // Starts the lock ring once the backdrop has been decoded, so the ring never runs over a
    // half-loaded wallpaper. The timer is the fallback (e.g. no wallpaper set yet).
    function startLockRing() {
        if (!popRoot.ringArmed) return;
        popRoot.ringArmed = false;
        armTimeout.stop();
        popRoot.progress = 0.0;
        popRoot.leaving = false;
        ringAnim.restart();
    }

    Timer {
        id: armTimeout
        interval: 700
        repeat: false
        onTriggered: popRoot.startLockRing()
    }

    // Safety net: if the ring animation never reports finished (e.g. the surface was not rendering),
    // the session still unlocks right after the ring should have ended.
    Timer {
        id: unlockGuard
        interval: popRoot.unlockMs + 500
        repeat: false
        onTriggered: if (popRoot.isUnlocking) popRoot.root.completeUnlock()
    }

    onIsUnlockingChanged: {
        if (isUnlocking) {
            armTimeout.stop();
            ringArmed = false;
            ringAnim.stop();
            openDashboardAnim.stop();
            closeDashboardAnim.stop();
            powerMenuOpen = false;
            leaving = true;
            isPlayingIntro = false;
            progress = 0.0;
            ringAnim.restart();
            unlockGuard.restart();
        } else {
            unlockGuard.stop();
            ringAnim.stop();
            leaving = false;
            foldScaleX = 1.0;
            foldScaleY = 1.0;
            progress = 1.0;
        }
    }

    Component.onCompleted: {
        restoreFocus();
        if (root.staticLock) {
            // Waking from sleep: the lock was already up, so no ring.
            isPlayingIntro = false;
            progress = 1.0;
        } else {
            progress = 0.0;
            ringArmed = true;
            armTimeout.start();
            // Wallpaper already decoded (cached): no reason to wait for the fallback timer.
            if (wallpaperImg.status === Image.Ready || wallpaperImg.status === Image.Error) Qt.callLater(popRoot.startLockRing);
        }
    }

    // Resource tile polling is only needed while the wings are fully out.
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

    // ---- visuals ---------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.crust
        z: -3
    }

    // The live desktop, frozen. Everything the ring shader leaves transparent shows this.
    Image {
        id: frozenDesktop
        anchors.fill: parent
        z: -2
        source: popRoot.introFreezePath !== "" ? ("file://" + popRoot.introFreezePath) : popRoot.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        sourceSize: Qt.size(Math.ceil(width * (Screen.devicePixelRatio || 1)), Math.ceil(height * (Screen.devicePixelRatio || 1)))
    }

    // The lock screen picture: blurred backdrop + clock + the real login UI. While the ring plays it
    // is only drawn through the shader; at rest it is drawn (and used) directly.
    Item {
        id: pic
        anchors.fill: parent
        z: 1

        Item {
            id: backdrop
            anchors.fill: parent
            // Half-size texture: it gets blurred anyway, and the ring re-renders this every frame.
            layer.enabled: true
            layer.textureSize: Qt.size(Math.max(1, Math.round(width * 0.5)), Math.max(1, Math.round(height * 0.5)))
            layer.smooth: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: popRoot.blurLevel > 0.001
                blur: popRoot.blurLevel
                blurMax: popRoot.s(32)   // half-res texture, so half the radius = Waved's s(64) look
                saturation: 0.25 * popRoot.blurPhase
                contrast: 0.06 * popRoot.blurPhase
                brightness: 0.02 * popRoot.blurPhase
            }

            Image {
                id: wallpaperImg
                anchors.fill: parent
                source: popRoot.wallpaperSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))
                onStatusChanged: {
                    if (status === Image.Error) {
                        let fallback = "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png";
                        if (source.toString() !== fallback) source = fallback;
                    }
                    if (status === Image.Ready || status === Image.Error) popRoot.startLockRing();
                }
            }

            Image {
                anchors.fill: parent
                source: (popRoot.currentFreezePath !== "" && popRoot.root.freezeTimestamp !== "") ? ("file://" + popRoot.currentFreezePath) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                cache: true
                sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))
                visible: status === Image.Ready
            }

        }

        // Same dimmer as the Waved lock screen (crust, lighter once the login UI is open).
        Rectangle {
            anchors.fill: parent
            color: ThemeBackend.crust
            opacity: (popRoot.inputActive ? 0.14 : 0.38) * popRoot.blurPhase
            Behavior on opacity {
                enabled: !popRoot.ringActive
                NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
            }
        }

        LockClock {
            screenRoot: popRoot
        }

        LockDashboard {
            id: dashboard
            screenRoot: popRoot
        }

        // Suspend / reboot / power off, the same menu as LockScreen.qml.
        LockPowerControls {
            screenRoot: popRoot
        }
    }

    ShaderEffectSource {
        id: picTexture
        sourceItem: pic
        live: ring.visible
        hideSource: ring.visible
        visible: false
    }

    ShaderEffect {
        id: ring
        anchors.fill: parent
        z: 2
        visible: popRoot.ringActive

        property var source1: picTexture
        property real progress: popRoot.progress
        property real aspect: height > 0 ? width / height : 1.0
        property int transitionStyle: 0          // 0 = plain ring (1 petal, 2 echo, 3 swirl)
        property real distortion: 1.0
        property real colorIntensity: 1.0
        property real speed: 1.0
        property real ringWidth: 0.44
        property int unlocking: popRoot.leaving ? 1 : 0
        property vector2d center: Qt.vector2d(0.5, 0.5)
        // Ring colours. The first (cyan) band follows the light / dark mode: in dark mode it is the
        // theme's own dark colour (crust with a little surface so the band keeps some body on the
        // blurred picture), in light mode it is white. The mode is read from the theme's base
        // colour, which is live, so switching dark / light in Settings -> Theme recolours the ring
        // with the usual 450 ms fade, for matugen and static themes alike. The other two bands are
        // still Waved's palette (mauve, blue), and the white band is near-white tinted with blue.
        readonly property bool lightMode: (0.2126 * ThemeBackend.base.r + 0.7152 * ThemeBackend.base.g + 0.0722 * ThemeBackend.base.b) > 0.5
        readonly property color accentA: lightMode
            ? Qt.rgba(1.0, 1.0, 1.0, 1.0)
            : Qt.rgba(ThemeBackend.crust.r * 0.75 + ThemeBackend.surface1.r * 0.25,
                      ThemeBackend.crust.g * 0.75 + ThemeBackend.surface1.g * 0.25,
                      ThemeBackend.crust.b * 0.75 + ThemeBackend.surface1.b * 0.25, 1.0)
        readonly property color accentB: ThemeBackend.mauve
        readonly property color accentC: ThemeBackend.blue
        property color colorCyan: accentA
        property color colorPink: accentB
        property color colorWhite: Qt.rgba(0.94 + 0.06 * accentC.r, 0.94 + 0.06 * accentC.g, 0.94 + 0.06 * accentC.b, 1.0)
        Behavior on colorCyan { ColorAnimation { duration: 450 } }
        Behavior on colorPink { ColorAnimation { duration: 450 } }
        Behavior on colorWhite { ColorAnimation { duration: 450 } }

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/lock/sekai_ring_lock.frag.qsb"
        vertexShader: "file://" + Caching.serpantinumDir + "/assets/shaders/lock/sekai_ring_lock.vert.qsb"
    }

    // A new wallpaper rewrites the same cache file, so the cached decode has to be dropped for the
    // lock picture to show it (the theme colours already follow through ThemeBackend).
    Connections {
        target: typeof Wallpaper !== "undefined" ? Wallpaper : null
        function onWallpaperChanged() {
            wallpaperImg.source = "";
            popWallpaperReload.restart();
        }
    }
    Timer {
        id: popWallpaperReload
        interval: 40
        onTriggered: wallpaperImg.source = popRoot.wallpaperSource
    }

    // Clicking the bare lock screen opens the login UI (same as LockScreen.qml). Sits under the lock
    // picture so the picture's own controls get their clicks first.
    MouseArea {
        anchors.fill: parent
        z: 0
        preventStealing: true
        enabled: !popRoot.isPlayingIntro && !popRoot.isUnlocking
        onPressed: popRoot.restoreFocus()
        onClicked: {
            if (popRoot.powerMenuOpen) popRoot.powerMenuOpen = false;
            if (!popRoot.inputActive) popRoot.inputActive = true;
            popRoot.restoreFocus();
        }
    }
}
