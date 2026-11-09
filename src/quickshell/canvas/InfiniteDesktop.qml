import QtQuick
import Quickshell
import "../"

Scope {
    Loader {
        active: CanvasEngine.supported && CanvasEngine.masterEnabled
        sourceComponent: Scope {
            CanvasBackdrop {}
        }
    }
}
