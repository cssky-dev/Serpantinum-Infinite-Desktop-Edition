pragma Singleton
import QtQuick
import Quickshell
import "../../widgets"

QtObject {
    id: root

    signal geometryChanged(string monitor, string widgetId, real x, real y, real w, real h, real opacity, real rotation)
    signal positionChanged(string monitor, string widgetId, real x, real y)
    signal opacityChanged(string monitor, string widgetId, real opacity)
    signal rotationChanged(string monitor, string widgetId, real rotation)
    signal variantChanged(string monitor, string widgetId, string variant)
    signal imagePathChanged(string monitor, string widgetId, string imagePath)
    signal propertyChanged(string monitor, string widgetId, string propName, var val)
    signal widgetPropertyChanged(string monitor, string widgetId, string propName, var val)
    signal customPropertyChanged(string monitor, string widgetId, string propName, var val)
    signal widgetAdded(string monitor, string widgetId, string type, real x, real y, real w, real h, real opacity, string imagePath, real rotation, string variant)
    signal widgetRemoved(string monitor, string widgetId)
    signal widgetsByTypeRemoved(string monitor, string type)
    signal widgetsCleared(string monitor)
    signal presetApplied(string monitor, var widgetsList)
    signal bringToFrontRequested(string monitor, string widgetId)
    signal redactModeChanged(string monitor, bool active)
    signal flushRequested(string monitor)

    // While the widget redactor is open on an infinite desktop it edits in screen
    // coordinates. The offset is the camera and its zoom, so everything that leaves this
    // singleton (and is saved by the loaders) is in canvas world coordinates:
    //   world = camera + screen / zoom   (sizes are never scaled)
    property var redactOffsets: ({})

    function setOffset(monitor: string, x: real, y: real, z: real): void {
        let zz = (z > 0) ? z : 1;
        let o = Object.assign({}, root.redactOffsets);
        if (x === 0 && y === 0 && zz === 1) delete o[monitor]; else o[monitor] = { x: x, y: y, z: zz };
        root.redactOffsets = o;
    }

    function offsetX(monitor: string): real { let o = root.redactOffsets[monitor]; return o ? o.x : 0; }
    function offsetY(monitor: string): real { let o = root.redactOffsets[monitor]; return o ? o.y : 0; }
    function offsetZ(monitor: string): real { let o = root.redactOffsets[monitor]; return o ? o.z : 1; }
    function toWorldX(monitor: string, x: real): real { return offsetX(monitor) + x / offsetZ(monitor); }
    function toWorldY(monitor: string, y: real): real { return offsetY(monitor) + y / offsetZ(monitor); }
    function toScreenX(monitor: string, x: real): real { return (x - offsetX(monitor)) * offsetZ(monitor); }
    function toScreenY(monitor: string, y: real): real { return (y - offsetY(monitor)) * offsetZ(monitor); }

    function setPosition(monitor: string, widgetId: string, x: real, y: real): void {
        root.positionChanged(monitor, widgetId, toWorldX(monitor, x), toWorldY(monitor, y));
    }

    function setPositions(monitor: string, positions: var): void {
        if (!positions) return;
        if (Array.isArray(positions)) {
            for (let i = 0; i < positions.length; i++) {
                let p = positions[i];
                if (p && p.id !== undefined && p.x !== undefined && p.y !== undefined) {
                    root.positionChanged(monitor, String(p.id), toWorldX(monitor, p.x), toWorldY(monitor, p.y));
                }
            }
        } else if (typeof positions === "object") {
            for (let k in positions) {
                let p = positions[k];
                if (p && p.x !== undefined && p.y !== undefined) {
                    root.positionChanged(monitor, String(k), toWorldX(monitor, p.x), toWorldY(monitor, p.y));
                }
            }
        }
    }

    function setGeometry(monitor: string, widgetId: string, x: real, y: real, w: real, h: real, opacity: real, rotation: real): void {
        root.setGeometryEx(monitor, widgetId, x, y, w, h, opacity, rotation, false);
    }

    // Full-screen (stretched) widgets are pinned to the screen, not to the canvas: they stay
    // where they are while the desktop is panned. Their position must leave the editor
    // unchanged, otherwise the camera offset is added to it, the loader no longer sees them
    // at 0,0 and silently drops the stretch.
    function setGeometryEx(monitor: string, widgetId: string, x: real, y: real, w: real, h: real, opacity: real, rotation: real, pinned: bool): void {
        let wx = pinned ? x : toWorldX(monitor, x);
        let wy = pinned ? y : toWorldY(monitor, y);
        root.geometryChanged(monitor, widgetId, wx, wy, w, h, opacity, rotation);
    }

    function setOpacity(monitor: string, widgetId: string, opacity: real): void {
        root.opacityChanged(monitor, widgetId, opacity);
    }

    function setRotation(monitor: string, widgetId: string, rotation: real): void {
        root.rotationChanged(monitor, widgetId, rotation);
    }

    function setVariant(monitor: string, widgetId: string, variant: string): void {
        root.variantChanged(monitor, widgetId, variant);
    }

    function setImagePath(monitor: string, widgetId: string, imagePath: string): void {
        root.imagePathChanged(monitor, widgetId, imagePath);
    }

    function setProperty(monitor: string, widgetId: string, propName: string, val: var): void {
        let m = monitor;
        let id = widgetId;
        let prop = propName;
        let v = val;
        if (v === undefined && prop !== undefined) {
            v = prop;
            prop = id;
            id = m;
            m = "";
        }
        root.propertyChanged(m, id, prop, v);
        root.widgetPropertyChanged(m, id, prop, v);
        root.customPropertyChanged(m, id, prop, v);
    }

    function setWidgetProperty(monitor: string, widgetId: string, propName: string, val: var): void {
        root.setProperty(monitor, widgetId, propName, val);
    }

    function setCustomProperty(monitor: string, widgetId: string, propName: string, val: var): void {
        root.setProperty(monitor, widgetId, propName, val);
    }

    function addWidget(monitor: string, widgetId: string, type: string, x: real, y: real, w: real, h: real, opacity: real, imagePath: string, rotation: real, variant: string): void {
        root.widgetAdded(monitor, widgetId, type, toWorldX(monitor, x), toWorldY(monitor, y), w, h, opacity, imagePath, rotation, variant || "");
    }

    function addFromRegistry(monitor: string, type: string, config: var): string {
        let def = WidgetRegistry.defaultSize(type);
        let id = (config && config.id) ? String(config.id) : ("w_" + Date.now() + "_" + Math.floor(Math.random() * 1000));
        let op = (config && config.opacity !== undefined) ? config.opacity : 1.0;
        let img = (config && config.imagePath !== undefined) ? config.imagePath : "";
        let rot = (config && config.rotation !== undefined) ? config.rotation : 0;
        let variant = (config && config.variant) ? config.variant : WidgetRegistry.defaultVariant(type);

        let sw = 1920;
        let sh = 1080;
        if (Quickshell.screens && Quickshell.screens.length > 0) {
            let target = String(monitor || "").trim().toLowerCase();
            let found = null;
            for (let i = 0; i < Quickshell.screens.length; i++) {
                let scr = Quickshell.screens[i];
                if (scr && scr.name) {
                    let nm = String(scr.name).trim().toLowerCase();
                    let safe = nm.replace(/[^a-zA-Z0-9_-]/g, "_");
                    if (nm === target || safe === target) {
                        found = scr;
                        break;
                    }
                }
            }
            if (!found) found = Quickshell.screens[0];
            if (found) {
                if (found.width > 0) sw = found.width;
                if (found.height > 0) sh = found.height;
            }
        }

        let rawW = (config && config.w !== undefined) ? config.w : (config && config.width !== undefined ? config.width : def.w);
        let rawH = (config && config.h !== undefined) ? config.h : (config && config.height !== undefined ? config.height : def.h);
        let w = (config && (config.stretchWidth || config.wStretchWidth)) ? sw : WidgetRegistry.resolveDimension(rawW, sw, def.w);
        let h = (config && (config.stretchHeight || config.wStretchHeight)) ? sh : WidgetRegistry.resolveDimension(rawH, sh, def.h);

        let pos = WidgetRegistry.resolvePosition(config || {}, sw, sh, w, h);
        let x = pos.x;
        let y = pos.y;

        root.widgetAdded(monitor, id, type, x, y, w, h, op, img, rot, variant);

        if (config && typeof config === "object") {
            let standardKeys = WidgetRegistry.standardKeys;
            for (let k in config) {
                if (!standardKeys.includes(k)) {
                    root.setProperty(monitor, id, k, config[k]);
                }
            }
        }

        return id;
    }

    function removeWidget(monitor: string, widgetId: string): void {
        root.widgetRemoved(monitor, widgetId);
    }

    function removeWidgetsByType(monitor: string, type: string): void {
        root.widgetsByTypeRemoved(monitor, type);
    }

    function clearWidgets(monitor: string): void {
        root.widgetsCleared(monitor);
    }

    function applyPreset(monitor: string, widgetsList: var, clearFirst: bool): void {
        let len = (widgetsList && widgetsList.length !== undefined) ? widgetsList.length : 0;
        if (!widgetsList || len === 0) {
            return;
        }
        root.presetApplied(monitor, widgetsList);
    }

    function bringToFront(monitor: string, widgetId: string): void {
        root.bringToFrontRequested(monitor, widgetId);
    }

    function setRedactMode(monitor: string, active: bool): void {
        root.redactModeChanged(monitor, active);
    }

    // Ask the loader of a screen to write its layout now instead of after the save delay
    // (used when the editor leaves a workspace so nothing is lost mid-switch).
    function flush(monitor: string): void {
        root.flushRequested(monitor);
    }
}
