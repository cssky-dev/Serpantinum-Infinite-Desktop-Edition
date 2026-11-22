import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

Scope {
    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: backdrop
            required property var modelData

            screen: modelData
            visible: CanvasEngine.activeOnMonitor(modelData.name)
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "qs-canvas-backdrop"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: (pressed && moved) ? Qt.ClosedHandCursor : Qt.ArrowCursor

                property real pressX: 0
                property real pressY: 0
                property real startCamX: 0
                property real startCamY: 0
                property real lastX: 0
                property real lastY: 0
                property bool moved: false
                property int pressedButton: 0
                property var samples: []
                readonly property real dragSlop: 8

                function _reset() {
                    moved = false;
                    samples = [];
                }

                onPressed: function(mouse) {
                    CanvasEngine.selectMonitor(backdrop.modelData.name);
                    pressedButton = mouse.button;
                    moved = false;
                    if (mouse.button === Qt.RightButton) return;
                    CanvasEngine.prepare();
                    lastX = mouse.x; lastY = mouse.y;
                    pressX = mouse.x; pressY = mouse.y;
                    startCamX = CanvasEngine.camX; startCamY = CanvasEngine.camY;
                    samples = [{ t: Date.now(), x: mouse.x, y: mouse.y }];
                }

                onPositionChanged: function(mouse) {
                    lastX = mouse.x; lastY = mouse.y;
                    if (!pressed || pressedButton === Qt.RightButton) return;

                    if (!moved) {
                        if (Math.hypot(mouse.x - pressX, mouse.y - pressY) < dragSlop) return;
                        moved = true;
                        CanvasEngine.stopAnim();
                        CanvasEngine.dragBegin();
                        pressX = mouse.x; pressY = mouse.y;
                        startCamX = CanvasEngine.camX; startCamY = CanvasEngine.camY;
                        samples = [{ t: Date.now(), x: mouse.x, y: mouse.y }];
                        return;
                    }

                    let z = CanvasEngine.zoom > 0 ? CanvasEngine.zoom : 1;
                    CanvasEngine.snapCamera(startCamX - (mouse.x - pressX) / z, startCamY - (mouse.y - pressY) / z);
                    let s = samples.slice(-5);
                    s.push({ t: Date.now(), x: mouse.x, y: mouse.y });
                    samples = s;
                }

                onDoubleClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) CanvasEngine.focusNearest(mouse.x, mouse.y);
                }

                onCanceled: { if (moved) CanvasEngine.dragEnd(); _reset(); }

                onReleased: function(mouse) {
                    if (pressedButton !== Qt.RightButton && moved) CanvasEngine.dragEnd();
                    if (pressedButton === Qt.RightButton || !moved || samples.length < 2) return;
                    let a = samples[0], b = samples[samples.length - 1];
                    let dt = (b.t - a.t) / 1000;
                    if (dt <= 0 || Date.now() - b.t > 90) return;
                    let vx = (b.x - a.x) / dt, vy = (b.y - a.y) / dt;
                    if (Math.hypot(vx, vy) > 250) CanvasEngine.fling(vx, vy);
                }

                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        if (typeof DesktopMenuController !== "undefined")
                            DesktopMenuController.toggle(backdrop.modelData, mouse.x, mouse.y, "desktop");
                    } else if (!moved) {
                        if (typeof DesktopMenuController !== "undefined") DesktopMenuController.hide();
                    }
                }

                onWheel: function(wheel) {
                    CanvasEngine.selectMonitor(backdrop.modelData.name);
                    wheel.accepted = true;
                    let ctrl = (wheel.modifiers & Qt.ControlModifier) !== 0;
                    let shift = (wheel.modifiers & Qt.ShiftModifier) !== 0;
                    let rawY = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y * 3 : wheel.angleDelta.y;
                    let rawX = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x * 3 : wheel.angleDelta.x;

                    if (ctrl) {
                        let d = rawY !== 0 ? rawY : rawX;
                        let amount = -d / 120 * CanvasEngine.wheelStep;
                        if (shift) CanvasEngine.panBy(amount, 0);
                        else CanvasEngine.panBy(0, amount);
                        return;
                    }
                    if (rawX !== 0 && rawY === 0) {
                        CanvasEngine.panBy(-rawX / 120 * CanvasEngine.wheelStep, 0);
                        return;
                    }
                    if (rawY !== 0) CanvasEngine.zoomWheel(rawY, wheel.x, wheel.y);
                }
            }
        }
    }
}
