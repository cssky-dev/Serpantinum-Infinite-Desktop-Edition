import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../reusables"
import "../"

PanelWindow {
    id: polkitWindow

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: PolkitService.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property bool shown: PolkitService.isActive
    // Stays mapped from the first request until the loader drops the window, so each request animates
    // in and out on a live surface instead of re-creating it. While idle the input region is empty.
    property bool mapped: false
    readonly property bool onScreen: shown || introScrim > 0.001
    visible: mapped
    color: "transparent"

    mask: onScreen ? openMask : closedMask
    Region { id: openMask; x: 0; y: 0; width: polkitWindow.width; height: polkitWindow.height }
    Region { id: closedMask }

    // Same recipe as the launcher: rounder themes overshoot more, Liquid Glass starts smaller and
    // travels further so the glass seems to condense out of the backdrop.
    readonly property real introOvershoot: (ThemeBackend.liquidGlass ? 0.9 : 0.7) + 0.3 * Math.min(1.0, ThemeBackend.borderRadius / 20.0)
    readonly property real introStartScale: ThemeBackend.liquidGlass ? 0.86 : 0.9
    readonly property real introTravel: ThemeBackend.liquidGlass ? 1.35 : 1.0

    property real introScrim: 0.0
    property real introCard: 0.0
    property real introHead: 0.0
    property real introInput: 0.0
    property real failFlash: 0.0
    property bool succeeded: false

    function playIntro() {
        exitAnim.stop();
        introScrim = 0.0;
        introCard = 0.0;
        introHead = 0.0;
        introInput = 0.0;
        enterAnim.restart();
    }

    function playExit() {
        enterAnim.stop();
        exitAnim.restart();
    }

    onShownChanged: {
        if (shown) {
            mapped = true;
            succeeded = false;
            polkitWindow.isAuthenticating = false;
            passwordInput.clear();
            focusRetryTimer.restart();
            playIntro();
        } else {
            playExit();
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: polkitWindow; property: "introScrim"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 40 }
            NumberAnimation { target: polkitWindow; property: "introCard"; to: 1.0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: polkitWindow.introOvershoot + 0.2 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            NumberAnimation { target: polkitWindow; property: "introHead"; to: 1.0; duration: 480; easing.type: Easing.OutQuint }
        }
        SequentialAnimation {
            PauseAnimation { duration: 190 }
            NumberAnimation { target: polkitWindow; property: "introInput"; to: 1.0; duration: 520; easing.type: Easing.OutBack; easing.overshoot: polkitWindow.introOvershoot }
        }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: polkitWindow; property: "introInput"; to: 0.0; duration: 140; easing.type: Easing.InQuad }
        NumberAnimation { target: polkitWindow; property: "introHead"; to: 0.0; duration: 170; easing.type: Easing.InQuad }
        NumberAnimation { target: polkitWindow; property: "introCard"; to: 0.0; duration: 240; easing.type: Easing.InCubic }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: polkitWindow; property: "introScrim"; to: 0.0; duration: 240; easing.type: Easing.InQuad }
        }
    }

    SequentialAnimation {
        id: failShake
        NumberAnimation { target: cardShake; property: "x"; to: -10; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: cardShake; property: "x"; to: 9; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: cardShake; property: "x"; to: -6; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: cardShake; property: "x"; to: 3; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: cardShake; property: "x"; to: 0; duration: 120; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: failGlow
        NumberAnimation { target: polkitWindow; property: "failFlash"; to: 1.0; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: polkitWindow; property: "failFlash"; to: 0.0; duration: 720; easing.type: Easing.OutCubic }
    }

    property var rootObj
    function s(val) {
        return (rootObj && typeof rootObj.s === "function") ? rootObj.s(val) : val;
    }

    property real crLarge: ThemeBackend.borderRadius
    property real crMedium: Math.max(0, ThemeBackend.borderRadius - 2)
    property real crSmall: Math.max(0, ThemeBackend.borderRadius - 4)

    property real toolbarHeight: s(32)
    property real actionHeight: s(42)
    property bool isAuthenticating: false

    function grabInputFocus() {
        passwordInput.forceInputFocus();
    }

    onVisibleChanged: {
        if (visible && shown) {
            polkitWindow.isAuthenticating = false;
            passwordInput.clear();
            focusRetryTimer.restart();
        }
    }

    // Created on demand (see Shell.qml), so it can already be visible when it completes.
    Component.onCompleted: {
        if (shown) {
            mapped = true;
            polkitWindow.isAuthenticating = false;
            passwordInput.clear();
            focusRetryTimer.restart();
            polkitWindow.playIntro();
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 50
        repeat: false
        onTriggered: {
            polkitWindow.grabInputFocus();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: polkitWindow.shown
        onActivated: PolkitService.cancel()
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: polkitWindow.shown && passwordInput.text.length > 0
        onActivated: polkitWindow.submitPassword()
    }

    function submitPassword() {
        if (!PolkitService.flow || polkitWindow.isAuthenticating) return;
        polkitWindow.isAuthenticating = true;
        PolkitService.submit(passwordInput.text);
    }

    Connections {
        target: PolkitService

        function onRequestStarted() {
            polkitWindow.isAuthenticating = false;
            passwordInput.clear();
            focusRetryTimer.restart();
        }

        function onAuthenticationFailed() {
            polkitWindow.isAuthenticating = false;
            passwordInput.clear();
            passwordInput.markError();
            focusRetryTimer.restart();
            failShake.restart();
            failGlow.restart();
        }

        function onAuthenticationSucceeded() {
            polkitWindow.succeeded = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        opacity: polkitWindow.introScrim
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(ThemeBackend.mauve, 0.0) }
            GradientStop { position: 1.0; color: Qt.alpha(ThemeBackend.mauve, 0.07) }
        }
        opacity: polkitWindow.introScrim
    }

    MouseArea {
        anchors.fill: parent
        onClicked: PolkitService.cancel()
    }

    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: s(520)
        implicitHeight: cardLayout.implicitHeight + (polkitWindow.s(18) * 2)
        color: dialogGlass.active ? "transparent" : Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        radius: polkitWindow.crLarge
        clip: true

        opacity: Math.min(1.0, polkitWindow.introCard * 1.6)
        scale: (polkitWindow.introStartScale + (1.0 - polkitWindow.introStartScale) * polkitWindow.introCard) * (1.0 + 0.006 * passwordInput.typePulse)
        transform: [
            Translate { y: polkitWindow.s(28) * polkitWindow.introTravel * (1.0 - polkitWindow.introCard) },
            Translate { id: cardShake; x: 0 }
        ]

        GlassFill {
            id: dialogGlass
            anchors.fill: parent
            radius: dialogCard.radius
            tintColor: ThemeBackend.surface0
            tintAmount: 0.3
        }

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: dialogCard.radius
            standalone: true
        }

        Rectangle {
            z: 5
            anchors.fill: parent
            radius: dialogCard.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(polkitWindow.failFlash > 0.01 ? ThemeBackend.red : (polkitWindow.succeeded ? ThemeBackend.green : ThemeBackend.mauve),
                                   0.10 + 0.40 * passwordInput.typePulse + 0.6 * polkitWindow.failFlash + (polkitWindow.succeeded ? 0.5 : 0.0))
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: polkitWindow.s(18)
            spacing: polkitWindow.s(14)

            RowLayout {
                Layout.fillWidth: true
                spacing: polkitWindow.s(12)
                layoutDirection: I18n.layoutDirection
                opacity: polkitWindow.introHead
                transform: Translate { y: polkitWindow.s(14) * (1.0 - polkitWindow.introHead) }

                Rectangle {
                    Layout.preferredWidth: polkitWindow.s(44)
                    Layout.preferredHeight: polkitWindow.s(44)
                    Layout.alignment: Qt.AlignTop
                    radius: polkitWindow.crMedium
                    color: polkitWindow.succeeded ? Qt.alpha(ThemeBackend.green, 0.18) : ThemeBackend.surface0
                    scale: 0.6 + 0.4 * polkitWindow.introHead + 0.08 * passwordInput.typePulse
                    Behavior on color { ColorAnimation { duration: 220 } }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (polkitWindow.succeeded) return "󰄬";
                            if (!PolkitService.flow || !PolkitService.flow.iconName) return "󰌾";
                            let name = PolkitService.flow.iconName.toLowerCase();
                            if (name.indexOf("lock") !== -1 || name.indexOf("auth") !== -1) return "󰌾";
                            if (name.indexOf("system") !== -1 || name.indexOf("package") !== -1) return "󰏗";
                            if (name.indexOf("drive") !== -1 || name.indexOf("disk") !== -1) return "󰋊";
                            if (name.indexOf("network") !== -1) return "󰖩";
                            return "󰌾";
                        }
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: polkitWindow.s(22)
                        color: polkitWindow.succeeded ? ThemeBackend.green : ThemeBackend.mauve
                        Behavior on color { ColorAnimation { duration: 220 } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: polkitWindow.s(3)

                    Text {
                        text: {
                            if (PolkitService.flow && PolkitService.flow.message) return PolkitService.flow.message;
                            return typeof I18n !== "undefined" ? I18n.t("polkit.default_message") : "An application is requesting administrative rights.";
                        }
                        color: ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: polkitWindow.s(14)
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        horizontalAlignment: I18n.textAlignment
                        Layout.fillWidth: true
                    }

                    Text {
                        text: {
                            if (PolkitService.flow && PolkitService.flow.actionId) return PolkitService.flow.actionId;
                            return typeof I18n !== "undefined" ? I18n.t("polkit.default_description") : "Authentication is needed to run this action as superuser.";
                        }
                        color: ThemeBackend.subtext0
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: polkitWindow.s(12)
                        wrapMode: Text.Wrap
                        horizontalAlignment: I18n.textAlignment
                        Layout.fillWidth: true
                    }
                }

                CloseButton {
                    Layout.preferredWidth: polkitWindow.toolbarHeight
                    Layout.preferredHeight: polkitWindow.toolbarHeight
                    Layout.alignment: Qt.AlignTop
                    cornerRadius: polkitWindow.crSmall
                    iconFontSize: polkitWindow.s(14)
                    accentColor: ThemeBackend.surface1
                    onClicked: PolkitService.cancel()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: errorText.implicitHeight + polkitWindow.s(12)
                radius: polkitWindow.crSmall
                color: Qt.alpha(ThemeBackend.red, 0.12)
                visible: PolkitService.errorMessage !== ""

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: polkitWindow.s(6)
                    spacing: polkitWindow.s(8)
                    layoutDirection: I18n.layoutDirection

                    Text {
                        text: "󰅚"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: polkitWindow.s(14)
                        color: ThemeBackend.red
                    }

                    Text {
                        id: errorText
                        text: PolkitService.errorMessage
                        color: ThemeBackend.red
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: polkitWindow.s(12)
                        font.weight: Font.Medium
                        wrapMode: Text.Wrap
                        horizontalAlignment: I18n.textAlignment
                        Layout.fillWidth: true
                    }
                }
            }

            PasswordInput {
                id: passwordInput
                Layout.fillWidth: true
                opacity: polkitWindow.introInput
                transform: Translate { y: polkitWindow.s(18) * (1.0 - polkitWindow.introInput) }
                Layout.preferredHeight: polkitWindow.toolbarHeight + polkitWindow.s(6)
                visible: !PolkitService.flow || PolkitService.flow.isResponseRequired !== false

                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                errorColor: ThemeBackend.red
                busyColor: ThemeBackend.peach

                cornerRadius: polkitWindow.crSmall
                horizontalPadding: polkitWindow.s(10)
                verticalPadding: polkitWindow.s(4)

                fontFamily: ThemeBackend.fontFamily
                fontPixelSize: polkitWindow.s(13)

                showLockIcon: true
                showSubmitButton: true
                lockButtonSize: polkitWindow.toolbarHeight + polkitWindow.s(2)

                hasError: PolkitService.errorMessage !== ""
                isBusy: polkitWindow.isAuthenticating

                placeholderText: {
                    if (PolkitService.flow && PolkitService.flow.inputPrompt) {
                        let p = PolkitService.flow.inputPrompt.trim();
                        if (p.endsWith(":")) p = p.slice(0, -1);
                        return p;
                    }
                    return typeof I18n !== "undefined" ? I18n.t("polkit.password_placeholder") : "Password";
                }

                onAccepted: polkitWindow.submitPassword()
            }
        }
    }
}
