import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "../"

Item {
    id: backdrop
    required property var screenRoot
    property alias freezeWallpaperView: freezeWallpaperView
    property bool wallpaperSettled: false

    anchors.fill: parent

    readonly property real wallpaperReveal: screenRoot.isPlayingIntro ? 1.0 : screenRoot.panelReveal
    readonly property bool showFrozenDesktop: screenRoot.lockSettings.promptBackdropMode !== "wallpaper"

    Item {
        id: freezeBackdropLayer
        anchors.fill: parent
        z: 0

        Rectangle {
            anchors.fill: parent
            color: ThemeBackend.crust
        }

        Image {
            id: fallbackWallpaperView
            anchors.fill: parent
            source: screenRoot.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))
            onStatusChanged: {
                if (status === Image.Error) {
                    let defaultPath = "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png";
                    if (source.toString() !== defaultPath) {
                        source = defaultPath;
                    }
                }
            }
        }

        Image {
            id: freezeWallpaperView
            anchors.fill: parent
            source: (screenRoot.currentFreezePath !== "" && screenRoot.root.freezeTimestamp !== "") ? ("file://" + screenRoot.currentFreezePath) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
            sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))
            opacity: (status === Image.Ready && source.toString() !== "") ? 1.0 : 0.0

            onStatusChanged: {
                if (status === Image.Ready && screenRoot.isPlayingIntro && !screenRoot.introSequence.running) {
                    screenRoot.introStartDelayTimer.stop();
                    screenRoot.introSequence.start();
                } else if (status === Image.Error && screenRoot.root.freezeTimestamp !== "") {
                    let defaultFreeze = "file://" + Caching.getRunDir("screenshot") + "/lock_freeze_default_" + screenRoot.root.freezeTimestamp + ".png";
                    if (source.toString() !== defaultFreeze) {
                        source = defaultFreeze;
                    }
                }
            }
        }
    }

    Item {
        id: wallpaperContainer
        anchors.fill: parent
        visible: false

        Image {
            id: liveWallpaperView
            anchors.fill: parent
            source: screenRoot.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))

            Component.onCompleted: if (status === Image.Ready || String(source) === "") backdrop.wallpaperSettled = true

            onStatusChanged: {
                if (status === Image.Ready) {
                    backdrop.wallpaperSettled = true;
                } else if (status === Image.Error && String(source).endsWith("/current_wallpaper.png")) {
                    backdrop.wallpaperSettled = true;
                }
                if (status === Image.Error) {
                    let defaultPath = "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png";
                    if (source.toString() !== defaultPath) {
                        source = defaultPath;
                    }
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: screenRoot.backgroundIsVideo && screenRoot.backgroundPath !== ""
            sourceComponent: VideoLock {
                wallpaperPath: screenRoot.backgroundPath
            }
        }

        Image {
            id: liveFreezeView
            anchors.fill: parent
            source: (screenRoot.currentFreezePath !== "" && screenRoot.root.freezeTimestamp !== "") ? ("file://" + screenRoot.currentFreezePath) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
            sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))
            opacity: (screenRoot.inputActive && backdrop.showFrozenDesktop && status === Image.Ready && source.toString() !== "") ? 1.0 : 0.0

            Behavior on opacity {
                enabled: !screenRoot.isUnlocking
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            onStatusChanged: {
                if (status === Image.Error && screenRoot.root.freezeTimestamp !== "") {
                    let defaultFreeze = "file://" + Caching.getRunDir("screenshot") + "/lock_freeze_default_" + screenRoot.root.freezeTimestamp + ".png";
                    if (source.toString() !== defaultFreeze) {
                        source = defaultFreeze;
                    }
                }
            }
        }
    }

    // The blur works on a half-size copy of the wallpaper: it is blurred anyway, so every frame of
    // the blur / input-open animation pushes a quarter of the pixels through the blur passes.
    ShaderEffectSource {
        id: blurSource
        sourceItem: wallpaperContainer
        textureSize: Qt.size(Math.max(1, Math.round(backdrop.width * 0.5)), Math.max(1, Math.round(backdrop.height * 0.5)))
        smooth: true
        live: screenRoot.isPlayingIntro || screenRoot.backgroundIsVideo || screenRoot.inputActive || screenRoot.isUnlocking || backdrop.recentChange
        visible: false
    }

    // Keeps the blur copy live for a moment after the picture changes (wallpaper reload, freeze
    // image decoded) so it never shows a stale frame; after that it stops re-rendering.
    property bool recentChange: true
    Timer { id: settleTimer; interval: 900; running: true; onTriggered: backdrop.recentChange = false }
    Connections {
        target: liveWallpaperView
        function onSourceChanged() { backdrop.recentChange = true; settleTimer.restart(); }
        function onStatusChanged() { backdrop.recentChange = true; settleTimer.restart(); }
    }
    Connections {
        target: liveFreezeView
        function onStatusChanged() { backdrop.recentChange = true; settleTimer.restart(); }
    }
    Connections {
        target: screenRoot
        function onInputActiveChanged() { backdrop.recentChange = true; settleTimer.restart(); }
    }

    MultiEffect {
        id: blurEffect
        source: blurSource
        anchors.fill: parent
        z: 1
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: screenRoot.s(32)   // half-res source, so half the radius = the old s(64) look
        saturation: 0.25
        contrast: 0.06
        brightness: 0.02
        blur: screenRoot.inputActive ? 1.0 : 0.72
        Behavior on blur {
            enabled: !screenRoot.isPlayingIntro && !screenRoot.isUnlocking
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }
        opacity: backdrop.wallpaperReveal
        visible: opacity > 0.01
    }

    Rectangle {
        id: dimmer
        anchors.fill: parent
        z: 2
        color: ThemeBackend.crust
        opacity: (screenRoot.inputActive ? 0.14 : 0.38) * backdrop.wallpaperReveal
        Behavior on opacity {
            enabled: !screenRoot.isPlayingIntro && !screenRoot.isUnlocking
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: wipeCanvas
        anchors.fill: parent
        z: 10

        visible: screenRoot.isPlayingIntro

        property vector2d itemSize: Qt.vector2d(width, height)
        property real reveal: screenRoot.panelReveal
        property real s28: screenRoot.s(28)
        property color color0: ThemeBackend.crust
        property color color1: ThemeBackend.surface1
        property color color2: ThemeBackend.sapphire
        property color color3: ThemeBackend.blue
        property color color4: ThemeBackend.mauve
        property var source: ShaderEffectSource {
            sourceItem: freezeBackdropLayer
            hideSource: false
            // Only the intro wipe reads this; once it is hidden there is nothing to re-render.
            live: screenRoot.isPlayingIntro
        }

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/effects/curtain_wipe.frag.qsb"
    }
}
