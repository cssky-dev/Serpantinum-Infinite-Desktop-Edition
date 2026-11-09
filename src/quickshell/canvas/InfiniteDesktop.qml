import QtQuick
import Quickshell
import "../"

Scope {
    Loader {
        active: CanvasEngine.isHyprland && CanvasEngine.masterEnabled
        sourceComponent: Scope {
            CanvasBackdrop {}
        }
    }
}
