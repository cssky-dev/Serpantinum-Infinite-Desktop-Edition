import QtQuick
import QtQuick.Window
import Quickshell.Wayland
import "../"

WlSessionLockSurface {
    id: lockSurface
    required property var sRoot
    required property var sRootLock
    required property var sPam
    required property var sLockUI
    required property var sSuspendProcess
    required property var sReloadProcess
    required property var sPoweroffProcess

    // The animation is read once when the surface is created, so changing the
    // setting never swaps the lock screen while the session is already locked.
    property bool animationReady: false
    property int framesSwapped: 0
    property string animationId: "waved"

    Component.onCompleted: {
        let cfg = Config.getSetting("lockscreen", {});
        lockSurface.animationId = (cfg && (cfg.animation === "padlock" || cfg.animation === "popwave")) ? cfg.animation : "waved";
        lockSurface.animationReady = true;
    }

    Connections {
        target: animationLoader.Window.window
        enabled: lockSurface.framesSwapped < 2
        function onFrameSwapped() {
            lockSurface.framesSwapped++;
            if (lockSurface.framesSwapped === 1) animationLoader.Window.window.update();
            else lockSurface.sRoot.surfaceShown();
        }
    }

    Loader {
        id: animationLoader
        anchors.fill: parent
        active: lockSurface.animationReady
        sourceComponent: lockSurface.animationId === "popwave" ? popwaveComponent : (lockSurface.animationId === "padlock" ? padlockComponent : wavedComponent)
    }

    Component {
        id: wavedComponent

        LockScreen {
            surface: lockSurface
            root: lockSurface.sRoot
            rootLock: lockSurface.sRootLock
            pam: lockSurface.sPam
            lockUI: lockSurface.sLockUI
            suspendProcess: lockSurface.sSuspendProcess
            reloadProcess: lockSurface.sReloadProcess
            poweroffProcess: lockSurface.sPoweroffProcess
        }
    }

    Component {
        id: padlockComponent

        PadlockScreen {
            surface: lockSurface
            root: lockSurface.sRoot
            rootLock: lockSurface.sRootLock
            pam: lockSurface.sPam
            lockUI: lockSurface.sLockUI
            suspendProcess: lockSurface.sSuspendProcess
            reloadProcess: lockSurface.sReloadProcess
            poweroffProcess: lockSurface.sPoweroffProcess
        }
    }

    Component {
        id: popwaveComponent

        PopwaveScreen {
            surface: lockSurface
            root: lockSurface.sRoot
            rootLock: lockSurface.sRootLock
            pam: lockSurface.sPam
            lockUI: lockSurface.sLockUI
            suspendProcess: lockSurface.sSuspendProcess
            reloadProcess: lockSurface.sReloadProcess
            poweroffProcess: lockSurface.sPoweroffProcess
        }
    }
}
