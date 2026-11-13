import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root
    color: "transparent"

    property string wId: Quickshell.env("QS_WIDGET_ID") || "preview"
    property string wType: "time"
    property string wVariant: ""
    property string wImagePath: ""
    property real wX: 0
    property real wY: 0
    property real wWidth: 250
    property real wHeight: 120
    property real wOpacity: 1.0
    property real wRotation: 0

    property var customProps: ({})
    property bool pinned: false
    property int layoutMode: -1
    property real fade: 1
    // Plain property fed by a handler (not a binding): reading root.screen inside canvasOn made it
    // depend on the window's own visibility (visible <- culled <- canvasOn), a binding loop.
    property string screenName: ""
    property real screenW: 0
    property real screenH: 0
    function syncScreen() {
        screenName = root.screen ? (root.screen.name || "") : "";
        screenW = root.screen ? root.screen.width : 0;
        screenH = root.screen ? root.screen.height : 0;
    }
    onScreenChanged: syncScreen()
    Connections {
        target: root.screen
        ignoreUnknownSignals: true
        function onWidthChanged() { root.syncScreen(); }
        function onHeightChanged() { root.syncScreen(); }
    }
    readonly property bool canvasOn: !pinned && screenName !== ""
        && typeof CanvasEngine !== "undefined" && CanvasEngine.widgetsOnCanvas
        && (layoutMode < 0 ? CanvasEngine.activeOnMonitor(screenName) : layoutMode === 1)
    readonly property var camOffset: !canvasOn ? ({ x: 0, y: 0, z: 1 })
        : (layoutMode < 0 ? CanvasEngine.camTarget(screenName) : CanvasEngine.camHold(screenName))
    readonly property real camZoom: camOffset.z
    readonly property bool canvasSync: root.initialized && !root.isRedacting && canvasOn
    readonly property real targetX: (animX - camOffset.x) * camZoom
    readonly property real targetY: (animY - camOffset.y) * camZoom
    property real _sx: targetX
    property real _sy: targetY
    property real _vx: 0
    property real _vy: 0
    readonly property real screenX: canvasSync ? _sx : targetX
    readonly property real screenY: canvasSync ? _sy : targetY
    onCanvasSyncChanged: { _sx = targetX; _sy = targetY; _vx = 0; _vy = 0; }
    readonly property bool _springBusy: canvasSync
        && (Math.abs(targetX - _sx) > 0.05 || Math.abs(targetY - _sy) > 0.05
            || Math.abs(_vx) > 0.05 || Math.abs(_vy) > 0.05)

    function _stepSpring(dt) {
        let total = Math.min(Math.max(dt, 0), 0.05);
        if (total <= 0) return;
        let ts = CanvasEngine.springTimeScale;
        let k = CanvasEngine.springStiffness * ts * ts, c = CanvasEngine.springDamping * ts, m = CanvasEngine.springMass;
        let n = Math.max(1, Math.ceil(total / 0.004));
        let h = total / n;
        let x = _sx, y = _sy, vx = _vx, vy = _vy;
        let tx = targetX, ty = targetY;
        for (let i = 0; i < n; i++) {
            vx += (k * (tx - x) - c * vx) / m * h;
            vy += (k * (ty - y) - c * vy) / m * h;
            x += vx * h;
            y += vy * h;
        }
        if (Math.abs(tx - x) < 0.05 && Math.abs(vx) < 0.05) { x = tx; vx = 0; }
        if (Math.abs(ty - y) < 0.05 && Math.abs(vy) < 0.05) { y = ty; vy = 0; }
        _sx = x; _sy = y; _vx = vx; _vy = vy;
    }

    FrameAnimation {
        running: root._springBusy
        onTriggered: root._stepSpring(frameTime)
    }

    readonly property bool culled: canvasOn
        && (screenX + implicitWidth < -400 || screenX > screenW + 400
            || screenY + implicitHeight < -400 || screenY > screenH + 400)

    readonly property real auraMargin: 8

    readonly property bool isSelected: typeof DesktopMenuController !== "undefined"
        && DesktopMenuController.isVisible
        && DesktopMenuController.mode === "widget"
        && DesktopMenuController.targetWidgetId === String(root.wId)
        && (!DesktopMenuController.screen || !root.screen || !DesktopMenuController.screen.name || !root.screen.name || DesktopMenuController.screen.name === root.screen.name)

    function applyCustomProps() {
        let it = faceLoader.item;
        if (!it || !customProps) return;
        let ignoredProps = [
            "objectName", "destroyed", "deleteLater", "parent", "data",
            "resources", "children", "visible", "enabled", "x", "y", "z",
            "width", "height", "opacity", "rotation", "scale"
        ];
        for (let k in customProps) {
            if (!k || typeof k !== "string") continue;
            if (k.endsWith("Changed") || k.startsWith("on") || typeof customProps[k] === "function" || customProps[k] === undefined) continue;
            if (ignoredProps.includes(k)) continue;
            try {
                if (it[k] !== undefined && it[k] !== customProps[k]) {
                    it[k] = customProps[k];
                }
            } catch (e) {}
        }
    }

    onCustomPropsChanged: applyCustomProps()

    property bool isRedacting: false
    property bool initialized: false

    property bool wantsKeyboardFocus: false
    readonly property bool effectiveKeyboardFocus: wantsKeyboardFocus || (faceLoader.item && (faceLoader.item.wantsKeyboardFocus || faceLoader.item.keyboardFocus || faceLoader.item.isEditingUser)) || false

    property real animX: wX
    property real animY: wY
    Behavior on animX {
        enabled: root.initialized && !root.isRedacting
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on animY {
        enabled: root.initialized && !root.isRedacting
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    property real effectiveWidth: wWidth
    property real effectiveHeight: wHeight

    onWWidthChanged: updateEffectiveSize()
    onWHeightChanged: updateEffectiveSize()
    onWVariantChanged: updateEffectiveSize()
    onWTypeChanged: updateEffectiveSize()

    WlrLayershell.namespace: "qs-widget-" + wType + "-" + wId
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: effectiveKeyboardFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore
    focusable: effectiveKeyboardFocus

    onEffectiveKeyboardFocusChanged: {
        if (effectiveKeyboardFocus && typeof root.requestActivate === "function") {
            root.requestActivate();
        }
    }

    anchors.top: true
    anchors.left: true
    margins.left: screenX - root.auraMargin
    margins.top: screenY - root.auraMargin

    implicitWidth: Math.ceil((((Math.round(wRotation || 0) % 180 === 0) ? effectiveWidth : effectiveHeight) + (root.auraMargin * 2)))
    implicitHeight: Math.ceil((((Math.round(wRotation || 0) % 180 === 0) ? effectiveHeight : effectiveWidth) + (root.auraMargin * 2)))

    Component.onCompleted: {
        syncScreen();
        Qt.callLater(() => {
            root.initialized = true;
        });
    }

    Component.onDestruction: {
        visible = false;
        faceLoader.active = false;
        faceLoader.source = "";
    }

    function updateEffectiveSize() {
        if (!faceLoader.item) {
            root.effectiveWidth = root.wWidth;
            root.effectiveHeight = root.wHeight;
            return;
        }
        let item = faceLoader.item;
        let c = {
            minW: item.minWidth !== undefined ? item.minWidth : 10,
            minH: item.minHeight !== undefined ? item.minHeight : 10,
            maxW: item.maxWidth !== undefined ? item.maxWidth : 9999,
            maxH: item.maxHeight !== undefined ? item.maxHeight : 9999,
            minA: item.minAspect !== undefined ? item.minAspect : 0,
            maxA: item.maxAspect !== undefined ? item.maxAspect : 9999
        };
        let w = Math.max(c.minW, Math.min(c.maxW, root.wWidth));
        let h = Math.max(c.minH, Math.min(c.maxH, root.wHeight));

        let ratio = w / h;
        if (ratio < c.minA && c.minA > 0) {
            let mA = c.minA;
            let hProj = (w * mA + h) / (mA * mA + 1);
            let hMin = Math.max(c.minH, c.minW / mA);
            let hMax = Math.min(c.maxH, c.maxW / mA);
            h = Math.max(hMin, Math.min(hMax, hProj));
            w = h * mA;
        } else if (ratio > c.maxA && c.maxA > 0) {
            let mA = c.maxA;
            let hProj = (w * mA + h) / (mA * mA + 1);
            let hMin = Math.max(c.minH, c.minW / mA);
            let hMax = Math.min(c.maxH, c.maxW / mA);
            h = Math.max(hMin, Math.min(hMax, hProj));
            w = h * mA;
        }

        w = Math.max(c.minW, Math.min(c.maxW, w));
        h = Math.max(c.minH, Math.min(c.maxH, h));

        root.effectiveWidth = w;
        root.effectiveHeight = h;
    }

    Loader {
        id: faceLoader
        property string wImagePath: root.wImagePath
        property string imagePath: root.wImagePath
        property string path: root.wImagePath
        visible: root.visible
        active: !root.culled
        source: WidgetRegistry.faceFile(root.wType, root.wVariant)
        width: root.effectiveWidth
        height: root.effectiveHeight
        anchors.centerIn: parent
        rotation: root.wRotation || 0
        opacity: root.wOpacity * root.fade
        Behavior on opacity { enabled: root.fade >= 0.999; NumberAnimation { duration: CanvasEngine.hlMs; easing.type: Easing.BezierSpline; easing.bezierCurve: CanvasEngine.hlCurve } }
        Behavior on rotation { NumberAnimation { duration: CanvasEngine.hlMs; easing.type: Easing.BezierSpline; easing.bezierCurve: CanvasEngine.hlCurve } }
        onLoaded: {
            if (item) {
                try {
                    item.visible = Qt.binding(() => root.visible);
                    if (item.imagePath !== undefined) {
                        item.imagePath = Qt.binding(() => root.wImagePath);
                    }
                    if (item.wImagePath !== undefined) {
                        item.wImagePath = Qt.binding(() => root.wImagePath);
                    }
                    if (item.path !== undefined) {
                        item.path = Qt.binding(() => root.wImagePath);
                    }
                    if (item.source !== undefined && typeof item.source === "string") {
                        item.source = Qt.binding(() => root.wImagePath);
                    }
                } catch (e) {}
            }
            root.applyCustomProps();
            root.updateEffectiveSize();
        }
    }

    Item {
        id: auraContainer
        width: faceLoader.width + (root.auraMargin * 2)
        height: faceLoader.height + (root.auraMargin * 2)
        anchors.centerIn: faceLoader
        rotation: faceLoader.rotation
        visible: opacity > 0.001
        opacity: root.isSelected ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        SelectionOutline {
            anchors.fill: parent
            running: root.isSelected && auraContainer.opacity > 0.001
        }
    }

    MouseArea {
        id: widgetMenuArea
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | (DesktopMenuController.isVisible ? Qt.LeftButton : 0)
        enabled: !root.isRedacting
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                DesktopMenuController.toggle(root.screen, root.margins.left + mouse.x, root.margins.top + mouse.y, "widget", root.wId);
            } else {
                DesktopMenuController.hide();
            }
        }
    }
}
