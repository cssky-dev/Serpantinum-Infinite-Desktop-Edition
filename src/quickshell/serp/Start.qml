import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"

PanelWindow {
    id: window

    signal finished()
    signal closed()

    WlrLayershell.namespace: "welcome-guide"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    exclusionMode: ExclusionMode.Ignore
    focusable: true
    screen: Quickshell.primaryScreen || null

    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080
    color: "transparent"

    function s(val) {
        let res = Scaler.s(val);
        return res > 0 ? res : val;
    }

    readonly property color base:     ThemeBackend.base
    readonly property color mantle:   ThemeBackend.mantle   || ThemeBackend.base
    readonly property color crust:    ThemeBackend.crust
    readonly property color surface0: ThemeBackend.surface0
    readonly property color surface1: ThemeBackend.surface1
    readonly property color surface2: ThemeBackend.surface2
    readonly property color text:     ThemeBackend.text
    readonly property color subtext0: ThemeBackend.subtext0
    readonly property color green:    ThemeBackend.green
    readonly property color blue:     ThemeBackend.blue     || "#89b4fa"
    readonly property color mauve:    ThemeBackend.mauve    || "#cba6f7"
    readonly property color peach:    ThemeBackend.peach    || "#fab387"

    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        from: 0; to: Math.PI * 2; duration: 120000; loops: Animation.Infinite; running: true
    }

    property real panelReveal: 0.0
    property real introPhase: 0.0
    NumberAnimation on introPhase {
        from: 0.0; to: 1.0; duration: 2500; easing.type: Easing.OutExpo; running: window.panelReveal > 0.5
    }

    property real orbBoost: 0.0

    property real welcomeReveal: 0.0
    property real welcomeOpacity: 1.0

    property real shellTextReveal: 0.0
    property real shellTextOpacity: 0.0
    property real shellTextScale: 0.94

    property real authorOpacity: 0.0
    property real authorScale: 0.94
    property real authorAnimX: 0
    property real authorAnimY: window.s(20)

    property bool authorAbsolute: false
    property real finalAuthorOpacity: 0.0

    property real toSerpReveal: 0.0
    property real toSerpOpacity: 0.0

    property real logoOpacity: 0.0
    property real logoScale: 0.94

    property bool colorizeActive: false
    property real logoFillLevel: 0.0
    property real btnOpacity: 0.0

    property real textGroupOffset: 0
    property real mainOpacity: 1.0

    property int bgSoundHandle: -1
    property int exitSoundHandle: -1

    property bool idleTextActive: false
    property real idlePhase: 0.0
    NumberAnimation on idlePhase {
        from: 0.0; to: Math.PI * 2; duration: 8000; loops: Animation.Infinite; running: window.idleTextActive
    }

    property real monitorZoomProgress: 0.0

    // Final scene: logo, title, edition and credits are one centered stack,
    // with the start button as the last item of the same stack.
    readonly property real finalLogoSize: window.s(250)
    readonly property real finalButtonGap: window.s(30)
    readonly property real finalGroupHeight: finalLogoSize + serpText.height + editionText.height + finalAuthorText.height
                                             + window.s(2) + window.s(4) + window.s(8)
    readonly property real finalStackHeight: finalGroupHeight + finalButtonGap + window.s(48)

    component TypewriterText : Row {
        id: twRoot
        property string text: ""
        property real reveal: 0.0
        property font font
        property color color: window.text
        property bool soundEnabled: true
        property string typeSfx: "start/type.wav"

        spacing: 0
        layoutDirection: I18n.layoutDirection

        // Cursive / combining scripts (Arabic, Persian, Hindi...) break when split per
        // character, so those are revealed word by word instead.
        readonly property bool needsShaping: /[\u0590-\u08FF\u0900-\u0DFF]/.test(twRoot.text)
        readonly property var parts: needsShaping ? twRoot.text.split(/(\s+)/).filter(function(x) { return x.length > 0; }) : Array.from(twRoot.text)

        Repeater {
            model: twRoot.parts
            Text {
                required property string modelData
                required property int index
                text: modelData.replace(/ /g, "\u00A0")
                font: twRoot.font
                color: twRoot.color

                property bool shown: (twRoot.reveal * (twRoot.parts.length + 2)) > index

                onShownChanged: {
                    if (shown && twRoot.soundEnabled && modelData !== " ") {
                        if (typeof Sounds !== "undefined") Sounds.playSfx(twRoot.typeSfx);
                    }
                }

                opacity: shown ? 1.0 : 0.0
                scale: shown ? 1.0 : 0.94
                rotation: 0

                transform: Translate {
                    y: (shown ? 0 : window.s(10)) + (window.idleTextActive && shown ? Math.sin(window.idlePhase + (index * 0.3)) * window.s(1.2) : 0)
                    Behavior on y { NumberAnimation { duration: 550; easing.type: Easing.OutQuint } }
                }

                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
                Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutQuint } }
                Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.OutCubic } }
            }
        }
    }

    Timer {
        id: initStartTimer
        interval: 100
        repeat: false
        onTriggered: introChoreography.start()
    }

    Component.onCompleted: initStartTimer.start()

    SequentialAnimation {
        id: introChoreography
        ScriptAction { script: window.bgSoundHandle = Sounds.playUntilStopped("start/background.wav", 0.4, true) }
        ScriptAction { script: Sounds.playSfx("start/start.wav") }
        PauseAnimation { duration: 100 }

        NumberAnimation { target: window; property: "panelReveal"; from: 0.0; to: 1.0; duration: 2000; easing.type: Easing.InOutCubic }
        PauseAnimation { duration: 150 }

        NumberAnimation { target: window; property: "welcomeReveal"; to: 1.0; duration: 850; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 800 }
        NumberAnimation { target: window; property: "welcomeOpacity"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
        ScriptAction { script: Sounds.playSfx("start/transition_serp.wav", 0.6) }

        ParallelAnimation {
            PropertyAction { target: window; property: "shellTextOpacity"; value: 1.0 }
            NumberAnimation { target: window; property: "shellTextReveal"; to: 1.0; duration: 1600; easing.type: Easing.InOutSine }
            NumberAnimation { target: window; property: "shellTextScale"; from: 0.94; to: 1.0; duration: 1600; easing.type: Easing.OutExpo }
        }
        PauseAnimation { duration: 150 }
        ParallelAnimation {
            NumberAnimation { target: window; property: "authorOpacity"; to: 1.0; duration: 500; easing.type: Easing.OutQuint }
            NumberAnimation { target: window; property: "authorScale"; to: 1.0; duration: 500; easing.type: Easing.OutQuint }
            ScriptAction { script: Sounds.playSfx("start/pop_author.wav") }
        }

        PauseAnimation { duration: 1500 }

        ParallelAnimation {
            NumberAnimation { target: window; property: "shellTextOpacity"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "authorOpacity"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
        }
        ScriptAction { script: Sounds.playSfx("start/transition_serp.wav", 0.6) }

        ParallelAnimation {
            SequentialAnimation {
                PropertyAction { target: window; property: "authorAbsolute"; value: true }
                PauseAnimation { duration: 800 }
                NumberAnimation { target: window; property: "finalAuthorOpacity"; to: 0.6; duration: 1000; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 210 }

                ParallelAnimation {
                    ParallelAnimation {
                        PropertyAction { target: window; property: "toSerpOpacity"; value: 1.0 }
                        NumberAnimation { target: window; property: "toSerpReveal"; to: 1.0; duration: 1500; easing.type: Easing.InOutSine }
                        NumberAnimation { target: window; property: "logoOpacity"; to: 1.0; duration: 1500; easing.type: Easing.OutQuart }
                        NumberAnimation { target: window; property: "logoScale"; from: 0.94; to: 1.0; duration: 1800; easing.type: Easing.OutExpo }
                    }

                    SequentialAnimation {
                        PauseAnimation { duration: 1200 }
                        ParallelAnimation {
                            NumberAnimation { target: window; property: "btnOpacity"; to: 1.0; duration: 600; easing.type: Easing.OutQuint }
                            ScriptAction { script: window.idleTextActive = true }
                        }
                    }
                }
            }

            SequentialAnimation {
                ScriptAction { script: Sounds.playSfx("start/wave.wav", 0.2) }
                PauseAnimation { duration: 250 }

                ParallelAnimation {
                    NumberAnimation { target: window; property: "orbBoost"; to: 1.0; duration: 3200; easing.type: Easing.OutSine }
                    ScriptAction { script: window.colorizeActive = true }
                    NumberAnimation { target: window; property: "logoFillLevel"; to: 1.5; duration: 4500; easing.type: Easing.OutSine }
                    NumberAnimation { target: window; property: "monitorZoomProgress"; from: 0.0; to: 1.0; duration: 2800; easing.type: Easing.OutQuint }
                }
            }
        }
    }

    ShaderEffect {
        id: bgCanvas
        anchors.fill: parent

        property real phase: 0.0
        NumberAnimation on phase {
            loops: Animation.Infinite
            running: window.panelReveal > 0.0 && window.panelReveal < 1.0
            from: 0; to: Math.PI * 2; duration: 3600
        }

        property vector2d itemSize: Qt.vector2d(width, height)
        property real reveal: window.panelReveal
        property color color0: window.crust
        property color color1: window.surface1
        property color color2: window.blue
        property color color3: window.mauve
        property color color4: window.base
        property vector4d params: Qt.vector4d(window.s(45), 0.0, 0.0, 0.0)

        fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/effects/screen_wipe.frag.qsb"
    }

    Item {
        id: rootItem
        anchors.fill: parent
        focus: true
        opacity: window.mainOpacity

        Shortcut {
            sequence: "Escape"
            onActivated: closeSequence.start()
        }

        Item {
            id: mauveOrbContainer
            width: window.s(1200); height: width
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height / 2
            opacity: window.introPhase * 0.04 + window.orbBoost * 0.12
            z: 1

            transform: Translate {
                x: Math.cos(window.globalOrbitAngle * 2) * window.s(450)
                y: Math.sin(window.globalOrbitAngle * 2) * window.s(250)
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true

                Rectangle {
                    id: mauveOrbSource
                    anchors.fill: parent
                    radius: width / 2
                    color: window.mauve
                    visible: false
                }

                MultiEffect {
                    source: mauveOrbSource
                    anchors.fill: parent
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 36
                }
            }
        }

        Item {
            id: blueOrbContainer
            width: window.s(1400); height: width
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - height / 2
            opacity: window.introPhase * 0.04 + window.orbBoost * 0.10
            z: 1

            transform: Translate {
                x: Math.sin(window.globalOrbitAngle * 1.5) * window.s(-450)
                y: Math.cos(window.globalOrbitAngle * 1.5) * window.s(-250)
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true

                Rectangle {
                    id: blueOrbSource
                    anchors.fill: parent
                    radius: width / 2
                    color: window.blue
                    visible: false
                }

                MultiEffect {
                    source: blueOrbSource
                    anchors.fill: parent
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 36
                }
            }
        }

        ShaderEffect {
            id: vignetteCanvas
            anchors.fill: parent
            z: 0

            property vector2d itemSize: Qt.vector2d(width, height)
            property color vignetteColor: "#000000"
            property vector4d params: Qt.vector4d(0.4, 0.75, 0.4, 0.0)

            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/effects/vignette.frag.qsb"
        }

        Item {
            id: monitorRig
            width: window.s(1200)
            height: window.s(900)
            anchors.centerIn: parent
            scale: 1.5 - (0.5 * window.monitorZoomProgress)
            opacity: window.monitorZoomProgress
            transformOrigin: Item.Center
            z: 2

            Item {
                id: finalMonitorContent
                anchors.fill: parent
                opacity: window.toSerpOpacity

                Item {
                    id: logoContainer
                    width: window.finalLogoSize
                    height: window.finalLogoSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -window.finalStackHeight / 2 + window.finalLogoSize / 2
                    scale: window.logoScale
                    transformOrigin: Item.Center

                    Item {
                        id: paddedMaskSource
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        layer.smooth: true

                        Image {
                            anchors.centerIn: parent
                            width: window.finalLogoSize * 0.91
                            height: window.finalLogoSize * 0.91
                            source: "file://" + Caching.serpantinumDir + "/assets/logo.svg"
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            antialiasing: true
                        }
                    }

                    Item {
                        id: logoColorBlock
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        layer.smooth: true

                        Rectangle { anchors.fill: parent; color: window.text }

                        ShaderEffect {
                            id: logoWaveCanvas
                            anchors.fill: parent

                            property real wavePhase: 0.0
                            NumberAnimation on wavePhase {
                                running: window.logoFillLevel > 0.0 && window.logoFillLevel < 1.45
                                loops: Animation.Infinite
                                from: 0; to: Math.PI * 2; duration: 3500
                            }

                            property vector2d itemSize: Qt.vector2d(width, height)
                            property real fillLevel: window.logoFillLevel
                            property color baseColor: window.mauve
                            property vector4d params: Qt.vector4d(window.s(10), 0.0, 0.0, 0.0)

                            fragmentShader: "file://" + Caching.serpantinumDir + "/assets/shaders/fluid/logo_water_wave.frag.qsb"
                        }
                    }

                    MultiEffect {
                        source: logoColorBlock
                        anchors.fill: parent
                        maskEnabled: true
                        maskSource: paddedMaskSource
                        autoPaddingEnabled: false
                        shadowEnabled: true

                        shadowColor: window.colorizeActive ? window.mauve : window.crust
                        shadowBlur: window.colorizeActive ? 1.0 : 0.6
                        shadowOpacity: window.colorizeActive ? 0.3 : 0.6
                        shadowVerticalOffset: window.colorizeActive ? 0 : window.s(6)

                        Behavior on shadowColor { ColorAnimation { duration: 800; easing.type: Easing.InOutCubic } }
                        Behavior on shadowBlur { NumberAnimation { duration: 800; easing.type: Easing.InOutCubic } }
                        Behavior on shadowOpacity { NumberAnimation { duration: 800; easing.type: Easing.InOutCubic } }
                        Behavior on shadowVerticalOffset { NumberAnimation { duration: 800; easing.type: Easing.InOutCubic } }
                    }
                }

                TypewriterText {
                    id: serpText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: logoContainer.bottom
                    anchors.topMargin: window.s(2)
                    text: I18n.t("start.title")
                    reveal: window.toSerpReveal
                    color: window.colorizeActive ? window.mauve : window.text
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: window.s(36)
                    soundEnabled: false
                }

                // Plain text, no icon: shown centered as soon as the logo has appeared
                Text {
                    id: editionText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: serpText.bottom
                    anchors.topMargin: window.s(4)
                    text: I18n.t("start.edition", "Infinite Desktop Edition")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: window.s(14)
                    font.weight: Font.Medium
                    color: window.colorizeActive ? window.mauve : window.text
                    opacity: Math.min(1.0, window.finalAuthorOpacity / 0.6)
                }

                Column {
                    id: finalAuthorText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: editionText.bottom
                    anchors.topMargin: window.s(8)
                    spacing: window.s(2)
                    opacity: window.finalAuthorOpacity

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.t("start.made_by", { "author": "CSSKY" })
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(13)
                        color: window.subtext0
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.t("start.original_dev", { "author": "ilyamiro" })
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: window.s(12)
                        color: window.subtext0
                    }
                }
            }
        }

        Item {
            id: textScene
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: window.textGroupOffset
            width: window.s(600)
            height: window.s(160)
            z: 5

            Item {
                anchors.centerIn: parent
                width: welcomeText.implicitWidth
                height: welcomeText.implicitHeight
                opacity: window.welcomeOpacity

                TypewriterText {
                    id: welcomeText
                    text: I18n.t("start.welcome")
                    reveal: window.welcomeReveal
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: window.s(48)
                }
            }

            Item {
                id: shellTextContainer
                anchors.centerIn: parent
                width: shellTextRow.implicitWidth
                height: shellTextRow.implicitHeight + introAuthorContainer.height
                opacity: window.shellTextOpacity
                scale: window.shellTextScale

                Row {
                    id: shellTextRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: window.s(8)
                    layoutDirection: I18n.layoutDirection

                    TypewriterText {
                        text: I18n.t("start.tagline")
                        reveal: window.shellTextReveal
                        color: window.text
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: window.s(28)
                        y: window.s(12)
                    }

                    TypewriterText {
                        id: youText
                        text: I18n.t("start.you")
                        reveal: Math.max(0.0, Math.min(1.0, (window.shellTextReveal - 0.70) * 3.33))
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: window.s(48)

                        property color blinkColor: window.mauve
                        SequentialAnimation on blinkColor {
                            loops: Animation.Infinite
                            running: window.shellTextOpacity > 0
                            ColorAnimation { to: window.blue; duration: 900; easing.type: Easing.InOutSine }
                            ColorAnimation { to: window.peach; duration: 900; easing.type: Easing.InOutSine }
                            ColorAnimation { to: window.mauve; duration: 900; easing.type: Easing.InOutSine }
                        }
                        color: blinkColor

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: youText.blinkColor
                            shadowBlur: 0.8
                            shadowOpacity: 0.85
                            shadowVerticalOffset: 0
                        }
                    }
                }

                Item {
                    id: introAuthorContainer
                    anchors.top: shellTextRow.bottom
                    anchors.topMargin: window.s(0)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: introAuthorText.implicitWidth
                    height: introAuthorText.implicitHeight
                    opacity: window.authorOpacity
                    scale: window.authorScale

                    Column {
                        id: introAuthorText
                        property real implicitWidth: Math.max(introMadeBy.implicitWidth, introOrigDev.implicitWidth)
                        property real implicitHeight: introMadeBy.implicitHeight + introOrigDev.implicitHeight + spacing
                        spacing: window.s(2)

                        Text {
                            id: introMadeBy
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.t("start.made_by", { "author": "CSSKY" })
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(14)
                            color: window.subtext0
                        }
                        Text {
                            id: introOrigDev
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.t("start.original_dev", { "author": "ilyamiro" })
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: window.s(12)
                            color: window.subtext0
                        }
                    }
                }
            }
        }

        Item {
            id: btnSpacer
            anchors.top: parent.verticalCenter
            anchors.topMargin: window.finalStackHeight / 2 - window.s(48)
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            z: 10

            FillButton {
                id: startBtn
                anchors.top: parent.top
                anchors.topMargin: 0
                anchors.horizontalCenter: parent.horizontalCenter

                width: Math.max(window.s(220), implicitWidth)
                height: window.s(48)
                textFontSize: 16
                opacity: window.btnOpacity

                buttonText: I18n.t("start.start_preview")
                buttonIcon: "󰐊"
                accentColor: window.blue
                baseColor: window.surface0
                hoverColor: window.surface1
                textColor: window.text
                filledTextColor: window.crust
                fillDuration: 800

                Timer {
                    id: delayCloseTimer
                    interval: 800
                    onTriggered: closeSequence.start()
                }

                onTriggered: delayCloseTimer.start()
            }
        }
    }

    SequentialAnimation {
        id: closeSequence
        ScriptAction { script: Sounds.playSfx("start/transition_serp.wav", 0.6) }
        ScriptAction { script: window.exitSoundHandle = Sounds.playUntilStopped("start/exit.wav", 0.7, false) }
        PauseAnimation { duration: 400 }
        ParallelAnimation {
            NumberAnimation { target: window; property: "mainOpacity"; to: 0.0; duration: 400; easing.type: Easing.OutQuint }
            NumberAnimation { target: window; property: "panelReveal"; to: 0.0; duration: 1760; easing.type: Easing.InOutCubic }
        }
        ScriptAction {
            script: {
                if (window.exitSoundHandle !== -1 ) {
                    Sounds.stopSfx(window.exitSoundHandle);
                    window.exitSoundHandle = -1;
                }
                if (startBtn.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                    Sounds.stopSfx(startBtn.chargingSoundHandle);
                    startBtn.chargingSoundHandle = -1;
                }
                if (window.bgSoundHandle !== -1) {
                    Sounds.stopSfx(window.bgSoundHandle);
                    window.bgSoundHandle = -1;
                }
            }
        }
        ScriptAction {
            script: {
                window.finished();
                window.closed();
                window.visible = false;
            }
        }
    }
}
