pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../"

Item {
    id: root
    visible: false

    readonly property bool isHyprland: Compositor.name === "hyprland"
    readonly property bool masterEnabled: root.setting("enabled", true) !== false
    readonly property bool allWorkspaces: root.setting("allWorkspaces", false) === true
    readonly property bool followFocus: root.setting("followFocus", true) !== false
    readonly property bool snapSetting: root.setting("snap", false) === true
    readonly property int animMs: Number(root.setting("animationMs", 340))
    readonly property real wheelStep: Number(root.setting("scrollStep", 160))
    readonly property real zoomMin: 0.3
    readonly property real zoomMax: 1.6
    readonly property bool widgetsOnCanvas: root.setting("widgets", true) !== false
    readonly property real gap: Math.max(8, Number(root.setting("spacing", 36)))
    readonly property bool hoverFocus: root.setting("hoverFocus", false) === true
    readonly property string zoomMode: "resize"
    function _k(w) { return zoomMode === "resize" ? ((w && w.z) || 1) : 1; }
    property double _sizedK: 1
    onZoomModeChanged: { if (anyActive) _flushAll(true); }
    readonly property bool centerOnOpen: root.setting("centerOnOpen", true) !== false
    readonly property real zoomStep: Math.max(1.05, Number(root.setting("zoomStep", 1.15)))
    readonly property bool blurFix: true
    readonly property bool hideQuickactionsSetting: root.setting("hideQuickactions", true) !== false
    readonly property bool hidesQuickactions: isHyprland && masterEnabled && anyActive && hideQuickactionsSetting
    readonly property int hlMs: 550
    readonly property var hlCurve: [0.3, 0.31, 0.17, 1.33, 1, 1]
    readonly property bool liquidSetting: root.setting("liquidGlass", true) !== false
    readonly property bool liquidWanted: isHyprland && masterEnabled && anyActive && liquidSetting && ThemeBackend.liquidGlass

    function setting(key, dflt) {
        let c = Config.getSetting("canvas", ({}));
        return (c && c[key] !== undefined && c[key] !== null) ? c[key] : dflt;
    }

    property var worlds: ({})
    property var monitors: []
    property var _clients: []
    property var _saved: ({})
    property bool _loaded: false
    property int curWs: -1
    property string curMon: ""
    property real camX: 0
    property real camY: 0
    property real tgtX: 0
    property real tgtY: 0
    property bool _loading: false
    property int rev: 0
    property bool anyActive: false
    property bool globalMoveCoords: false
    property bool _verified: false
    property bool cameraLocked: false
    property real zoom: 1
    property real tgtZ: 1
    property bool _compAnim: false
    property double _focusGateUntil: 0
    property var _fit: null
        property var _autoWs: ({})
    property var _userOff: ({})
    property double _settleUntil: 0
    property bool _dirty: false
    property int _blurXray: -1
    property bool _blurFrozen: false
    property double _lastCamMove: 0
    property var _pendingFn: null
    readonly property bool animating: animX.running || animY.running
    readonly property var curWorld: worlds[curWs] || null
    readonly property bool curActive: curWorld !== null && curWorld.active === true
    readonly property string stateFile: Caching.getStateDir("canvas") + "/canvas.json"
    function _touch() { rev++; }
    function monFor(ws) {
        for (let i = 0; i < monitors.length; i++) if (monitors[i].ws === ws) return monitors[i];
        for (let j = 0; j < _clients.length; j++) {
            let c = _clients[j];
            if (c.workspace && c.workspace.id === ws) {
                for (let i = 0; i < monitors.length; i++) if (monitors[i].id === c.monitor) return monitors[i];
            }
        }
        return null;
    }

    function monByName(name) {
        for (let i = 0; i < monitors.length; i++) if (monitors[i].name === name) return monitors[i];
        return null;
    }

    function isActive(ws) { let w = worlds[ws]; return !!(w && w.active); }

    function activeOnMonitor(name) {
        let m = monByName(name);
        return !!(m && root.masterEnabled && isActive(m.ws));
    }

    function modeFor(name) { return activeOnMonitor(name) ? "canvas" : "tiled"; }
    function layoutFileFor(name) { return modeFor(name) === "canvas" ? "layout-canvas.json" : "layout.json"; }
    function modeLabel(name) { return modeFor(name) === "canvas" ? "Infinite desktop" : "Tiled"; }

    property var _camMemo: ({})
    function camHold(name) {
        let r = rev;
        let m = monByName(name);
        let w = m ? worlds[m.ws] : null;
        if (w && w.active) {
            let c = root._cmdCam(w, m.ws);
            _camMemo[name] = c;
            return c;
        }
        return _camMemo[name] || { x: 0, y: 0, z: 1 };
    }

    function viewport() {
        let m = monFor(curWs);
        let z = zoom > 0 ? zoom : 1;
        return m ? { w: m.w / z, h: m.h / z } : { w: 1920 / z, h: 1080 / z };
    }

    function _addr(a) {
        a = String(a || "");
        return a.indexOf("0x") === 0 ? a : ("0x" + a);
    }

    function _selector(addr) { return "address:" + _addr(addr); }

    function entry(addr) {
        let w = worlds[curWs];
        return (w && w.wins[addr]) ? w.wins[addr] : null;
    }

    function windowList(ws) {
        let w = worlds[ws === undefined ? curWs : ws];
        let out = [];
        if (!w) return out;
        for (let a in w.wins) {
            let e = w.wins[a];
            out.push({ addr: a, x: e.x, y: e.y, w: e.w, h: e.h, fs: !!e.fs, cls: e.cls, title: e.title });
        }
        return out;
    }

    function marks() { let w = worlds[curWs]; return w ? w.marks : ({}); }

    function camForMon(name) {
        let r = rev;
        if (name === curMon) return { x: camX, y: camY };
        let m = monByName(name);
        let w = m ? worlds[m.ws] : null;
        return (w && w.active) ? { x: w.cx, y: w.cy } : { x: 0, y: 0 };
    }

    function zoomForMon(name) {
        let r = rev;
        if (name === curMon) return zoom;
        let m = monByName(name);
        let w = m ? worlds[m.ws] : null;
        return (w && w.active) ? (w.z || 1) : 1;
    }

    function camTarget(name) {
        let r = rev;
        let m = monByName(name);
        let w = m ? worlds[m.ws] : null;
        return (w && w.active) ? root._cmdCam(w, m.ws) : { x: 0, y: 0, z: 1 };
    }

    function _cmdCam(w, ws) {
        let sc = root._sentCam;
        let pending = mover.running || root._dirty || root._queue.length > 0 || flushTimer.running;
        if (pending && ws === curWs && sc.ws === ws) return { x: sc.x, y: sc.y, z: sc.z };
        return { x: w.cx, y: w.cy, z: w.z || 1 };
    }

    function stopAnim() {
        let moving = animX.running || animY.running || animZ.running;
        animX.stop(); animY.stop(); animZ.stop();
        _compAnim = false;
        let w = worlds[curWs];
        if (w && w.active) {
            w.z = zoom; tgtZ = zoom;
            if (moving) {
                w.cx = camX; w.cy = camY; tgtX = camX; tgtY = camY;
                _touch();
                _requestFlush();
            }
        }
    }

    property bool _fast: false
    readonly property int fastMs: 60
    readonly property real springSpeed: Number(root.setting("springSpeed", 6))
    readonly property real springStiffness: Math.max(1, Number(root.setting("springStiffness", 140)))
    readonly property real springDamping: Math.max(0, Number(root.setting("springDamping", 16)))
    readonly property real springMass: Math.max(0.05, Number(root.setting("springMass", 1)))
    readonly property bool syncWidgetSpeed: true
    readonly property real manualTimeScale: Math.max(0.25, Number(root.setting("springTimeScale", 0.7)))
    readonly property real widgetSpeedTrim: Math.max(0.5, Math.min(2, Number(root.setting("widgetSpeedTrim", 1))))
    readonly property real springTimeScale: Math.max(0.25, appsSpeedPct / 100 * widgetSpeedTrim)
    readonly property real baseAppsSpeed: 6
    readonly property real widgetSpeedPct: Math.round(manualTimeScale * 100)
    readonly property real appsSpeedPct: Math.max(25, Math.min(300, Number(root.setting("appsSpeed", 100))))
    readonly property real _lagBase: springDamping / springStiffness * 1000
    readonly property real widgetLagMs: _lagBase / springTimeScale
    readonly property real appsLagMs: _lagBase / (appsSpeedPct / 100)
    readonly property real widgetTrailMs: widgetLagMs - appsLagMs

    property bool _appsSpeedSent: false
    function _applyAppsSpeed() {
        if (!isHyprland) return;
        let pct = appsSpeedPct;
        if (pct === 100 && !_appsSpeedSent) return;
        _appsSpeedSent = (pct !== 100);
        let sp = Math.round(baseAppsSpeed * pct) / 100;
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.animation({ leaf = \"windowsMove\", enabled = true, speed = " + sp + ", spring = \"elasticSmooth\" })"]);
    }
    onAppsSpeedPctChanged: _applyAppsSpeed()
    Component.onCompleted: _applyAppsSpeed()
    readonly property int moveMs: _fast ? fastMs : hlMs
    readonly property int widgetMs: hlMs

    readonly property int settleMs: Math.round(Math.max(hlMs, Math.min(2600, hlMs * 100 / appsSpeedPct)))

    function _fastTouch() { }
    function _fastEnd() { }

    function dragBegin() { _fastTouch(); }
    function dragEnd() { }

    Timer { id: fastTimer; interval: 320; repeat: false; onTriggered: root._fastEnd() }

    function snapCamera(x, y, force) {
        if (cameraLocked && force !== true) return;
        _fastTouch();
        stopAnim();
        _lastCamMove = Date.now();
        _fit = null;
        tgtX = x; tgtY = y;
        camX = x; camY = y;
    }

    function snapView(x, y, z, force) {
        let w = worlds[curWs];
        if (!w || !w.active || (cameraLocked && force !== true)) return;
        _fastTouch();
        stopAnim();
        _lastCamMove = Date.now();
        _fit = null;
        let zz = Math.max(zoomMin, Math.min(zoomMax, z));
        _loading = true;
        camX = x; camY = y; zoom = zz;
        _loading = false;
        tgtX = x; tgtY = y; tgtZ = zz;
        w.cx = x; w.cy = y; w.z = zz;
        _touch();
        _blurMotion();
        _requestFlush();
        saveTimer.restart();
    }

    function glideTo(x, y, zz, ms) {
        let w = worlds[curWs];
        if (!w || !w.active || cameraLocked) return;
        let needAbsorb = _needAbsorb();
        let z0 = w.z || 1;
        let z = (zz === undefined) ? z0 : Math.max(zoomMin, Math.min(zoomMax, zz));
        let d = (ms !== undefined && ms <= 1) ? 1 : hlMs;
        _fastEnd();
        _fit = null;
        tgtX = x; tgtY = y; tgtZ = z;
        w.cx = x; w.cy = y; w.z = z;
        animX.duration = d; animY.duration = d; animZ.duration = d;
        animX.to = x; animY.to = y; animZ.to = z;
        animX.restart(); animY.restart(); animZ.restart();
        _touch();
        _compAnim = true;
        _settleUntil = Date.now() + d + 500;
        _focusGateUntil = Date.now() + d + 350;
        _blurMotion();
        if (_debugOn) _dbg("glide to " + Math.round(x) + "," + Math.round(y) + " z=" + z.toFixed(2) + " ms=" + d);
        if (needAbsorb) _absorbThen(function() { root._flushAll(true); });
        else _flushAll(true);
        _scheduleSave();
    }

    function animateTo(x, y, ms) { glideTo(x, y, undefined, ms); }

    function panBy(dx, dy) {
        let w = worlds[curWs];
        if (!w || !w.active) return;
        let z = w.z || 1;
        glideTo(w.cx + dx / z, w.cy + dy / z, undefined, Math.min(animMs, 240));
    }

    function panPage(fx, fy) {
        let v = viewport();
        let w = worlds[curWs];
        if (!w || !w.active) return;
        glideTo(w.cx + fx * v.w, w.cy + fy * v.h, undefined, animMs);
    }

    function fling(vx, vy) {
        let w = worlds[curWs];
        if (!w || !w.active) return;
        let z = w.z || 1;
        let v = viewport();
        let lim = function(d, m) { return Math.max(-m, Math.min(m, d)); };
        glideTo(w.cx + lim(-vx * 0.22 / z, v.w * 0.8), w.cy + lim(-vy * 0.22 / z, v.h * 0.8), undefined, 640);
    }

    function _settleCamera(w) {
        if (w !== worlds[curWs]) return;
        if (!(_compAnim || animX.running || animY.running || animZ.running)) return;
        let x = camX, y = camY, z = zoom;
        stopAnim();
        _fit = null;
        tgtX = x; tgtY = y; tgtZ = z;
        w.cx = x; w.cy = y; w.z = z;
        _lastCamMove = Date.now();
        if (_debugOn) _dbg("settle camera at " + Math.round(x) + "," + Math.round(y));
        _touch();
        _flushAll(true);
    }

    function home() { glideTo(0, 0, 1, animMs); }

    function centerOnEntry(e, ms) {
        let w = worlds[curWs]; let mon = monFor(curWs);
        if (!w || !mon) return;
        let z = w.z || 1;
        let k = _k(w);
        glideTo(e.x - (mon.w / 2 - e.w * k / 2) / z, e.y - (mon.h / 2 - e.h * k / 2) / z, undefined, ms);
    }

    function zoomAt(factor, mx, my) {
        let w = worlds[curWs]; let mon = monFor(curWs);
        if (!w || !w.active || !mon || cameraLocked) return;
        let z0 = w.z || 1;
        let z1 = Math.max(zoomMin, Math.min(zoomMax, z0 * factor));
        if (Math.abs(z1 - z0) < 0.001) return;
        let px = (mx === undefined) ? mon.w / 2 : mx;
        let py = (my === undefined) ? mon.h / 2 : my;
        let wx = w.cx + px / z0, wy = w.cy + py / z0;
        glideTo(wx - px / z1, wy - py / z1, z1, 260);
    }

    property real _zoomAcc: 1
    property var _zoomAnchor: null

    function zoomBy(factor) {
        if (!isHyprland || !masterEnabled || !curActive || cameraLocked) return;
        _zoomAcc *= factor;
        let now = Date.now();
        if (_zoomAnchor && now - _zoomAnchor.t < 500) { _zoomAnchor.t = now; zoomTimer.restart(); return; }
        _zoomAnchor = null;
        if (!cursorProc.running) cursorProc.running = true;
    }

    function zoomWheel(delta, px, py) {
        if (!isHyprland || !masterEnabled || !curActive || cameraLocked) return;
        _zoomAcc *= Math.exp(delta / 600);
        _zoomAnchor = { px: px, py: py, t: Date.now() };
        zoomTimer.restart();
    }

    function _applyCursor(text) {
        let mon = monFor(curWs);
        try {
            let c = JSON.parse(text);
            _zoomAnchor = { px: c.x - (mon ? mon.x : 0), py: c.y - (mon ? mon.y : 0), t: Date.now() };
        } catch (e) { _zoomAnchor = null; }
        zoomTimer.restart();
    }

    function _zoomApply() {
        let f = _zoomAcc;
        _zoomAcc = 1;
        if (Math.abs(f - 1) < 0.0005) return;
        let a = _zoomAnchor;
        zoomAt(f, a ? a.px : undefined, a ? a.py : undefined);
    }

    Timer { id: zoomTimer; interval: 24; repeat: false; onTriggered: root._zoomApply() }

    function toggleFit() {
        if (!isHyprland || !masterEnabled) return;
        _whenFresh(function() {
            if (!curActive) _activate(curWs);
            let w = worlds[curWs]; let mon = monFor(curWs);
            if (!w || !w.active || !mon || cameraLocked) return;
            if (_fit) { let f = _fit; glideTo(f.x, f.y, f.z, 460); return; }
            let x0 = 1e18, y0 = 1e18, x1 = -1e18, y1 = -1e18, n = 0, mw = 0, mh = 0;
            for (let a in w.wins) {
                let e = w.wins[a];
                x0 = Math.min(x0, e.x); y0 = Math.min(y0, e.y);
                x1 = Math.max(x1, e.x); y1 = Math.max(y1, e.y);
                mw = Math.max(mw, e.w); mh = Math.max(mh, e.h);
                n++;
            }
            if (n === 0) return;
            let pad = 70;
            let zx = (x1 - x0) > 1 ? (mon.w - mw - pad * 2) / (x1 - x0) : 1;
            let zy = (y1 - y0) > 1 ? (mon.h - mh - pad * 2) / (y1 - y0) : 1;
            let z = Math.max(zoomMin, Math.min(1, Math.min(zx, zy)));
            let before = { x: w.cx, y: w.cy, z: w.z || 1 };
            glideTo(x0 - (mon.w - ((x1 - x0) * z + mw)) / (2 * z), y0 - (mon.h - ((y1 - y0) * z + mh)) / (2 * z), z, 480);
            _fit = before;
        });
    }

    function focusAddr(addr) {
        Hyprland.dispatch("hl.dsp.focus({ window = \"" + _selector(addr) + "\" })");
    }

    function goToWindow(addr) {
        let e = entry(addr);
        if (!e) return;
        _navAddr = String(addr).replace(/^0x/, "");
        _navUntil = Date.now() + 1800;
        centerOnEntry(e, 380);
        focusAddr(addr);
    }

    property string _navAddr: ""
    property double _navUntil: 0

    function focusDir(dir) {
        if (!isHyprland) return;
        let d = String(dir).toLowerCase();
        let hl = { left: "left", l: "left", right: "right", r: "right", up: "up", u: "up", down: "down", d: "down" }[d];
        if (!hl) return;
        let w = worlds[curWs]; let mon = monFor(curWs);
        if (!masterEnabled || !w || !w.active || !mon) {
            Hyprland.dispatch("hl.dsp.focus({ direction = \"" + hl + "\" })");
            return;
        }
        let z = w.z || 1;
        let curAddr = (Date.now() < _navUntil && _navAddr !== "") ? _addr(_navAddr) : (_focusAddr !== "" ? _addr(_focusAddr) : "");
        let cur = curAddr !== "" ? w.wins[curAddr] : null;
        let fx, fy;
        if (cur) { fx = cur.x + cur.w / 2; fy = cur.y + cur.h / 2; }
        else { fx = w.cx + mon.w / (2 * z); fy = w.cy + mon.h / (2 * z); }
        let best = null, bs = 1e18;
        for (let a in w.wins) {
            if (a === curAddr) continue;
            let e = w.wins[a];
            let dx = (e.x + e.w / 2) - fx, dy = (e.y + e.h / 2) - fy;
            let along = (hl === "left") ? -dx : (hl === "right") ? dx : (hl === "up") ? -dy : dy;
            let across = (hl === "left" || hl === "right") ? Math.abs(dy) : Math.abs(dx);
            if (along < 8 || across > along * 2.5 + 160) continue;
            let score = along + across * 1.8;
            if (score < bs) { bs = score; best = a; }
        }
        if (best) goToWindow(best);
    }

    function selectMonitor(name) {
        let m = monByName(name);
        if (m && m.ws !== curWs) _setCur(m.ws, m.name);
    }

    function markSet(n) {
        let w = worlds[curWs];
        if (!w || !w.active) return;
        w.marks[n] = { x: camX, y: camY };
        _touch(); _scheduleSave();
    }

    function markGo(n) {
        let w = worlds[curWs];
        if (!w || !w.active || !w.marks[n]) return;
        glideTo(w.marks[n].x, w.marks[n].y, undefined, 520);
    }

    function tidy() {
        let w = worlds[curWs]; let mon = monFor(curWs);
        if (!w || !w.active || !mon) return;
        let z = w.z || 1;
        let vpw = { w: mon.w, h: mon.h };
        let list = [];
        for (let a in w.wins) list.push(a);
        if (list.length === 0) return;
        list.sort((a, b) => (w.wins[a].x - w.wins[b].x) || (w.wins[a].y - w.wins[b].y));
        let gap = Math.round(root.gap * 0.5);
        let cols = 1, bestScore = 1e9;
        for (let c = 1; c <= list.length; c++) {
            let r = Math.ceil(list.length / c);
            let cellW = (vpw.w - gap * (c + 1)) / c, cellH = (vpw.h - gap * (r + 1)) / r;
            if (cellW < 120 || cellH < 80) continue;
            let score = Math.abs(Math.log((cellW / cellH) / 1.5)) + (c * r - list.length) * 0.05;
            if (score < bestScore) { bestScore = score; cols = c; }
        }
        let rows = Math.ceil(list.length / cols);
        let cw = Math.floor((vpw.w - gap * (cols + 1)) / cols);
        let ch = Math.floor((vpw.h - gap * (rows + 1)) / rows);
        let batch = [];
        for (let i = 0; i < list.length; i++) {
            let e = w.wins[list[i]];
            e.x = Math.round(camX + (gap + (i % cols) * (cw + gap)) / z);
            e.y = Math.round(camY + (gap + Math.floor(i / cols) * (ch + gap)) / z);
            { let kk = _k(w); e.w = Math.round(cw / kk); e.h = Math.round(ch / kk); } e.off = false; e.sent = true; e.needFloat = false;
            batch.push(list[i]);
        }
        _applyGeometry(batch);
        _touch(); _scheduleSave();
    }

    function _screenPos(w, e, mon) {
        let z = w.z || 1;
        let sx = (e.x - w.cx) * z, sy = (e.y - w.cy) * z;
        if (globalMoveCoords) { sx += mon.x; sy += mon.y; }
        return [Math.round(sx), Math.round(sy)];
    }

    property var _blurBase: ({ xray: 0, size: 8, passes: 3 })
    readonly property real blurBudget: Math.max(4, Number(root.setting("blurBudget", 14)))

    function _visibleCount() {
        let w = worlds[curWs]; let mon = monFor(curWs);
        if (!w || !mon) return 0;
        let z = w.z || 1, n = 0;
        for (let a in w.wins) {
            let e = w.wins[a];
            let sx = (e.x - camX) * z, sy = (e.y - camY) * z;
            let kv = _k(w);
            if (sx < mon.w && sy < mon.h && sx + e.w * kv > 0 && sy + e.h * kv > 0) n++;
        }
        return n;
    }

    function blurCost(size, passes, n) { return Math.max(1, n) * passes * (1 + size / 8); }

    function blurMotionPasses(n) {
        let b = _blurBase;
        let perPass = Math.max(1, n) * (1 + b.size / 8);
        return Math.max(1, Math.min(b.passes, Math.floor(blurBudget / perPass)));
    }

    function _readBlur() {
        if (_blurXray < 0 && !blurReader.running) blurReader.running = true;
    }

    function _blurMotion() {
        if (!isHyprland || !blurFix || !anyActive) return;
        if (_blurXray < 0) { _readBlur(); return; }
        if (!_blurFrozen && _blurXray !== 1) {
            _blurFrozen = true;
            let p = blurMotionPasses(_visibleCount());
            let lowered = p < _blurBase.passes;
            if (_debugOn) _dbg("blur motion xray on, passes " + _blurBase.passes + " -> " + p + " (cost " + blurCost(_blurBase.size, _blurBase.passes, _visibleCount()).toFixed(1) + ", budget " + blurBudget + ")");
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { xray = true" + (lowered ? ", passes = " + p : "") + " } } })"]);
        }
        if (_blurFrozen) blurTimer.restart();
    }

    function _blurSettle() {
        if (!_blurFrozen) return;
        _blurFrozen = false;
        let b = _blurBase;
        Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { xray = false, passes = " + b.passes + " } } })"]);
    }

    property bool _liquidOn: false
    function _applyLiquid() {
        if (!isHyprland) return;
        if (liquidWanted && !_liquidOn) {
            _liquidOn = true;
            _blurBase = { xray: _blurBase.xray, size: 12, passes: 3 };
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { rounding = 16, blur = { size = 12, passes = 3, vibrancy = 0.34, vibrancy_darkness = 0.2, brightness = 1.06, contrast = 1.02, noise = 0.012 } } })"]);
        } else if (!liquidWanted && _liquidOn) {
            _liquidOn = false;
            _blurBase = { xray: _blurBase.xray, size: 8, passes: 3 };
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { rounding = 12, blur = { size = 8, passes = 3, vibrancy = 0.1696, vibrancy_darkness = 0.0, brightness = 0.9, contrast = 0.95, noise = 0.0117 } } })"]);
        }
    }
    onLiquidWantedChanged: _applyLiquid()

    property int _followOrig: -1
    property bool _followOff: false
    function _applyFollowMouse() {
        if (!isHyprland) return;
        let want = masterEnabled && anyActive && !hoverFocus;
        if (want && !_followOff) {
            if (_followOrig < 0) { if (!followReader.running) followReader.running = true; return; }
            _followOff = true;
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ input = { follow_mouse = 0 } })"]);
        } else if (!want && _followOff) {
            _followOff = false;
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ input = { follow_mouse = " + Math.max(0, _followOrig) + " } })"]);
        }
    }
    onHoverFocusChanged: _applyFollowMouse()
    onMasterEnabledChanged: _applyFollowMouse()

    Process {
        id: followReader
        command: ["hyprctl", "-j", "getoption", "input:follow_mouse"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = 1;
                try { let o = JSON.parse(this.text); v = Number(o.int); if (isNaN(v)) v = 1; } catch (e) { v = 1; }
                root._followOrig = v;
                root._applyFollowMouse();
            }
        }
    }

    function _requestFlush() {
        if (!flushTimer.running) flushTimer.start();
    }

    property var _queue: []

    function _enqueue(lua) {
        _queue.push(lua);
        _pump();
    }

    function _pump() {
        if (mover.running || _queue.length === 0) return;
        mover.command = ["hyprctl", "eval", _queue.shift()];
        mover.running = true;
    }

    property var _sentCam: ({ x: 0, y: 0, z: 1, ws: -1 })
    property double _lastAbsorb: 0
    property var _afterAbsorb: null
    property int _flushSeq: 0
    property int _absorbSeq: 0
    property bool _absorbReplied: false
    property double _preparedAt: 0

    function _noteSent(w) { _sentCam = { x: w.cx, y: w.cy, z: w.z || 1, ws: curWs }; _flushSeq++; }

    function _needAbsorb() {
        if (!isHyprland) return false;
        if (absorber.running) return !_absorbReplied;
        let now = Date.now();
        if (now < _settleUntil) return false;
        if (now - _preparedAt < 1500) return false;
        return now - _lastAbsorb > 120;
    }

    function _absorbThen(fn) {
        if (absorber.running && _absorbReplied) { if (fn) fn(); return; }
        _afterAbsorb = fn;
        if (!absorber.running) {
            _absorbReplied = false;
            _absorbSeq = _flushSeq;
            absorber.running = true;
        }
    }

    function prepare() {
        if (!isHyprland || !masterEnabled || !curActive) return;
        if (_needAbsorb()) _absorbThen(null);
        _preparedAt = Date.now();
    }

    function _absorbDone(text) {
        let fn = _afterAbsorb;
        _afterAbsorb = null;
        _absorbReplied = true;
        _lastAbsorb = Date.now();
        let w = worlds[curWs]; let mon = monFor(curWs);
        let sc = _sentCam;
        if (w && w.active && mon && sc.ws === curWs && _flushSeq === _absorbSeq) {
            let list = [];
            try { list = JSON.parse(text); } catch (e) { list = []; }
            let touched = false;
            for (let i = 0; i < list.length; i++) {
                let c = list[i];
                if (!c || !c.workspace || c.workspace.id !== curWs) continue;
                let e = w.wins[c.address];
                if (!e || e.fs || !e.sent || e.off || !c.floating) continue;
                let kz = (zoomMode === "resize") ? sc.z : 1;
                if (c.size && c.size[0] >= 60 && c.size[1] >= 40 && e.w * kz >= 60 && e.h * kz >= 40) {
                    if (Math.abs(c.size[0] - e.w * kz) > 1.5 || Math.abs(c.size[1] - e.h * kz) > 1.5) { e.w = c.size[0] / kz; e.h = c.size[1] / kz; touched = true; }
                }
                let ex = mon.x + (e.x - sc.x) * sc.z, ey = mon.y + (e.y - sc.y) * sc.z;
                let dx = c.at[0] - ex, dy = c.at[1] - ey;
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    e.x = Math.round((c.at[0] - mon.x) / sc.z + sc.x);
                    e.y = Math.round((c.at[1] - mon.y) / sc.z + sc.y);
                    touched = true;
                    if (_debugOn) _dbg("absorbed manual move " + c.address + " dx=" + Math.round(dx) + " dy=" + Math.round(dy));
                }
            }
            if (touched) _scheduleSave();
        }
        if (fn) fn();
    }

    Process {
        id: absorber
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: root._absorbDone(this.text)
        }
    }

    function _sendItem(a, e, w, mon, withSize) {
        let p = _screenPos(w, e, mon);
        if (!withSize) return "{\"" + a + "\"," + p[0] + "," + p[1] + "}";
        let k = _k(w);
        return "{\"" + a + "\"," + p[0] + "," + p[1] + "," + Math.max(60, Math.round(e.w * k)) + "," + Math.max(40, Math.round(e.h * k)) + "}";
    }
    readonly property string _sendLua: "local s=\"address:\"..v[1] if v[4] then hl.dispatch(hl.dsp.window.resize({x=v[4],y=v[5],window=s})) end hl.dispatch(hl.dsp.window.move({x=v[2],y=v[3],window=s}))"

    function _flush() {
        let w = worlds[curWs];
        if (!w || !w.active) return;
        let mon = monFor(curWs);
        if (!mon) return;
        if (mover.running || _queue.length > 0) { _dirty = true; return; }
        if (_needAbsorb()) { _absorbThen(function() { root._flush(); }); return; }
        _lastAbsorb = Date.now();
        _noteSent(w);

        let kNow = _k(w);
        let withSize = Math.abs(kNow - _sizedK) > 0.0005;
        if (withSize) _sizedK = kNow;
        let items = [];
        for (let a in w.wins) {
            let e = w.wins[a];
            if (e.fs) continue;
            e.off = false;
            e.sent = true;
            items.push(_sendItem(a, e, w, mon, withSize));
        }

        _touch();
        if (items.length === 0) return;

        _settleUntil = Date.now() + settleMs + 200;
        _focusGateUntil = Date.now() + settleMs + 300;
        _dirty = false;
        let lua = "for _,v in ipairs({" + items.join(",") + "}) do " + _sendLua + " end";
        mover.command = ["hyprctl", "eval", lua];
        mover.running = true;
    }

    function _flushAll(force) {
        let w = worlds[curWs];
        if (!w || !w.active) return;
        let mon = monFor(curWs);
        if (!mon) return;
        if (force !== true && _needAbsorb()) { _absorbThen(function() { root._flushAll(true); }); return; }
        _lastAbsorb = Date.now();
        _noteSent(w);
        let kNow = _k(w);
        let withSize = Math.abs(kNow - _sizedK) > 0.0005;
        if (withSize) _sizedK = kNow;
        let items = [];
        for (let a in w.wins) {
            let e = w.wins[a];
            if (e.fs) continue;
            e.off = false;
            e.sent = true;
            items.push(_sendItem(a, e, w, mon, withSize));
        }
        if (items.length === 0) return;
        let lua = "for _,v in ipairs({" + items.join(",") + "}) do " + _sendLua + " end";
        _enqueue(lua);
    }

    function _applyGeometry(addrs, ws) {
        let id = (ws === undefined) ? curWs : ws;
        let w = worlds[id]; let mon = monFor(id);
        if (!w || !mon || addrs.length === 0) return;
        let items = [];
        let now = Date.now();
        for (let i = 0; i < addrs.length; i++) {
            let e = w.wins[addrs[i]];
            if (!e) continue;
            let p = _screenPos(w, e, mon);
            let fl = e.needFloat ? 1 : 0;
            if (e.needFloat) { e.needFloat = false; e.floatUntil = now + 1500; }
            items.push("{\"" + addrs[i] + "\"," + p[0] + "," + p[1] + "," + Math.max(60, Math.round(e.w * _k(w))) + "," + Math.max(40, Math.round(e.h * _k(w))) + "," + fl + "}");
        }
        if (items.length === 0) return;
        if (id === curWs) { _noteSent(w); _lastAbsorb = now; } else _flushSeq++;
        _settleUntil = now + settleMs + 400;
        let lua = "for _,v in ipairs({" + items.join(",") + "}) do local s=\"address:\"..v[1] " +
                  "if v[6]==1 then hl.dispatch(hl.dsp.window.float({action=\"toggle\",window=s})) end " +
                  "hl.dispatch(hl.dsp.window.resize({x=v[4],y=v[5],window=s})) " +
                  "hl.dispatch(hl.dsp.window.move({x=v[2],y=v[3],window=s})) end";
        _enqueue(lua);
    }

    property bool _debugOn: false
    readonly property string debugFile: Caching.getStateDir("canvas") + "/debug.log"

    function setDebug(on) { _debugOn = (on === true); _dbg("debug " + (_debugOn ? "on" : "off")); }

    function _dbg(msg) {
        if (!_debugOn) return;
        Quickshell.execDetached(["bash", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s %s\\n' \"$(date +%T.%3N)\" \"$2\" >> \"$1\"", "_", debugFile, String(msg)]);
    }

    function dumpState() {
        let w = worlds[curWs]; let mon = monFor(curWs);
        if (!w || !mon) return "no canvas on this workspace";
        let z = w.z || 1, out = [];
        out.push("camera " + Math.round(w.cx) + "," + Math.round(w.cy) + " zoom " + z.toFixed(2));
        for (let a in w.wins) {
            let e = w.wins[a];
            let p = _screenPos(w, e, mon);
            let real = null;
            for (let i = 0; i < _clients.length; i++) if (_addr(_clients[i].address) === _addr(a)) real = _clients[i];
            out.push(a + " " + e.cls + " expect " + p[0] + "," + p[1] + " " + Math.round(e.w * _k(w)) + "x" + Math.round(e.h * _k(w)) +
                     (real ? " real " + (real.at[0] - mon.x) + "," + (real.at[1] - mon.y) + " " + real.size[0] + "x" + real.size[1] : " real -"));
        }
        return out.join("\n");
    }

    function _placeNew(w, ww, hh, tx, ty, mon) {
        let mode = String(root.setting("placement", "nearest"));
        let n = 0;
        for (let a in w.wins) n++;
        if (mode === "cascade" && n > 0) {
            let step = 44 + (n % 8) * 6;
            return { x: Math.round(tx + (n % 8) * step * 0.5), y: Math.round(ty + (n % 8) * step * 0.5) };
        }
        if (mode === "grid" && n > 0) {
            let cols = Math.max(1, Math.round(Math.sqrt(n + 1)));
            return { x: Math.round(tx + ((n % cols) - (cols - 1) / 2) * (ww + gap)), y: Math.round(ty + (Math.floor(n / cols)) * (hh + gap)) };
        }
        let spot = _freeSpot(w, ww, hh, tx, ty);
        return _snapToNeighbour(w, spot.x, spot.y, ww, hh, null);
    }

    function _snapToNeighbour(w, x, y, ww, hh, selfAddr) {
        if (root.setting("snap", false) !== true) return { x: x, y: y };
        let z = w.z || 1;
        let tol = 22 / z;
        let bx = x, by = y, dxBest = tol, dyBest = tol;
        for (let a in w.wins) {
            if (a === selfAddr) continue;
            let o = w.wins[a];
            let vert = y < o.y + o.h + tol && y + hh + tol > o.y;
            let horiz = x < o.x + o.w + tol && x + ww + tol > o.x;
            if (vert) {
                let d1 = Math.abs(x - (o.x + o.w + gap)); if (d1 < dxBest) { dxBest = d1; bx = o.x + o.w + gap; }
                let d2 = Math.abs(x + ww + gap - o.x);   if (d2 < dxBest) { dxBest = d2; bx = o.x - ww - gap; }
            }
            if (horiz) {
                let d3 = Math.abs(y - (o.y + o.h + gap)); if (d3 < dyBest) { dyBest = d3; by = o.y + o.h + gap; }
                let d4 = Math.abs(y + hh + gap - o.y);   if (d4 < dyBest) { dyBest = d4; by = o.y - hh - gap; }
            }
        }
        return { x: Math.round(bx), y: Math.round(by) };
    }

    property real _snapProbeX: -99999
    property real _snapProbeY: -99999
    property int _snapStill: 0

    Timer {
        id: snapTimer
        interval: 220
        repeat: false
        onTriggered: {
            let w = worlds[curWs];
            if (!w || !w.active) return;
            if (!snapProbe.running) snapProbe.running = true;
        }
    }

    Process {
        id: snapProbe
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: root._snapProbeDone(this.text)
        }
    }

    function _snapProbeDone(text) {
        let cx = -1, cy = -1;
        try { let c = JSON.parse(text); cx = c.x; cy = c.y; } catch (err) { cx = -1; cy = -1; }
        let still = Math.abs(cx - _snapProbeX) <= 2 && Math.abs(cy - _snapProbeY) <= 2;
        _snapProbeX = cx; _snapProbeY = cy;
        _snapStill = still ? _snapStill + 1 : 0;
        if (_snapStill < 1) { snapTimer.restart(); return; }
        _snapStill = 0;
        _snapProbeX = -99999; _snapProbeY = -99999;

        let w = worlds[curWs];
        if (!w || !w.active) return;
        let batch = [];
        for (let a in w.wins) {
            let e = w.wins[a];
            if (!e.pend) continue;
            e.pend = false;
            let p = _snapToNeighbour(w, e.x, e.y, e.w, e.h, a);
            if (p.x !== e.x || p.y !== e.y) { e.x = p.x; e.y = p.y; batch.push(a); }
        }
        if (batch.length > 0) { _applyGeometry(batch); _touch(); }
    }

    function arrange(mode) {
        let w = worlds[curWs]; let mon = monFor(curWs);
        if (!w || !w.active || !mon) return;
        if (mode === "grid") { tidy(); return; }
        let list = [];
        for (let a in w.wins) list.push(a);
        if (list.length === 0) return;
        list.sort((a, b) => (w.wins[a].x - w.wins[b].x) || (w.wins[a].y - w.wins[b].y));
        let z = w.z || 1;
        let batch = [], x = camX + 60 / z, y = camY + 60 / z;
        for (let i = 0; i < list.length; i++) {
            let e = w.wins[list[i]];
            if (mode === "row") { e.x = Math.round(x); e.y = Math.round(camY + (mon.h - e.h) / (2 * z)); x += e.w / 1 + gap; }
            else { e.x = Math.round(x); e.y = Math.round(y); x += 48 / z; y += 48 / z; }
            e.off = false; e.sent = true;
            batch.push(list[i]);
        }
        _applyGeometry(batch);
        _touch(); _scheduleSave();
    }

    function focusNearest(px, py) {
        let w = worlds[curWs]; let mon = monFor(curWs);
        if (!w || !w.active || !mon) return;
        let z = w.z || 1, best = null, bd = 1e18;
        for (let a in w.wins) {
            let e = w.wins[a];
            let kc = _k(w);
            let cx = (e.x - w.cx) * z + e.w * kc / 2, cy = (e.y - w.cy) * z + e.h * kc / 2;
            let d = Math.hypot(cx - px, cy - py);
            if (d < bd) { bd = d; best = a; }
        }
        if (best) goToWindow(best);
    }

    function _toggleFloat(addr) {
        Hyprland.dispatch("hl.dsp.window.float({ action = \"toggle\", window = \"" + _selector(addr) + "\" })");
    }

    function toggleCanvas() {
        _whenFresh(function() {
            if (curActive) { _userOff[curWs] = true; _deactivate(curWs); }
            else { delete _userOff[curWs]; _activate(curWs, true); }
        });
    }

    function enableCanvas() { _whenFresh(function() { if (!curActive) _activate(curWs, true); }); }
    function disableCanvas() { _whenFresh(function() { if (curActive) _deactivate(curWs); }); }

    function _activate(ws, spread) {
        let mon = monFor(ws);
        if (!mon || ws <= 0) return;
        let saved = _saved[ws] || null;
        let w = {
            active: true,
            cx: saved ? Number(saved.cx) || 0 : 0,
            cy: saved ? Number(saved.cy) || 0 : 0,
            mon: mon.name,
            wins: ({}),
            marks: saved && saved.marks ? saved.marks : ({}),
            z: 1,
            released: ({}),
            savedWins: saved && saved.wins ? saved.wins.slice() : []
        };
        worlds[ws] = w;
        let moved = [];
        for (let i = 0; i < _clients.length; i++) {
            let c = _clients[i];
            if (c.workspace.id !== ws) continue;
            if (_ignored(c)) continue;
            if (_addWindow(w, c, mon, true)) moved.push(c.address);
        }
        let restored = moved.length > 0 && (saved && saved.wins && saved.wins.length > 0) && (saved.wins.length - w.savedWins.length) > 0;
        if (restored && saved && Number(saved.z) > 0) w.z = Math.max(zoomMin, Math.min(zoomMax, Number(saved.z)));
        w.pendingUntil = Date.now() + 600000;
        if (spread === true && !restored) _spreadOut(w, mon, moved);
        worldsChanged();
        if (ws === curWs) {
            _loading = true; camX = w.cx; camY = w.cy; tgtX = w.cx; tgtY = w.cy; zoom = w.z; tgtZ = w.z; _loading = false;
        }
        if (moved.length > 0) _applyGeometry(moved, ws);
        _requestFlush();
        _recount();
        _scheduleSave();
    }

    function _spreadOut(w, mon, moved) {
        let list = [];
        for (let a in w.wins) list.push(a);
        if (list.length < 2) return;
        let sx = 0, sy = 0;
        for (let i = 0; i < list.length; i++) {
            let e = w.wins[list[i]];
            sx += e.x + e.w / 2; sy += e.y + e.h / 2;
        }
        let mx = sx / list.length, my = sy / list.length;
        let k = 1.0 + Math.min(0.12, gap / 420);
        for (let i = 0; i < list.length; i++) {
            let e = w.wins[list[i]];
            if (e.fs) continue;
            e.x = Math.round(mx + (e.x + e.w / 2 - mx) * k - e.w / 2);
            e.y = Math.round(my + (e.y + e.h / 2 - my) * k - e.h / 2);
            if (moved.indexOf(list[i]) < 0) moved.push(list[i]);
        }
    }

    function _deactivate(ws) {
        let w = worlds[ws];
        if (!w) return;
        let mon = monFor(ws);
        stopAnim();
        let zSaved = w.z || 1;
        let keepList = [];
        for (let a in w.wins) {
            let e = w.wins[a];
            keepList.push({ cls: e.cls, title: e.ititle, x: e.x, y: e.y, w: e.w, h: e.h });
        }
        _saved[ws] = { active: false, cx: w.cx, cy: w.cy, z: zSaved, marks: w.marks, wins: keepList };

        w.z = 1;
        if (ws === curWs) { zoom = 1; tgtZ = 1; _fit = null; }
        let keep = [];
        for (let a in w.wins) {
            let e = w.wins[a];
            if (!e.wasFloating) {
                _toggleFloat(a);
            } else if (mon) {
                let sx = Math.max(0, Math.min(e.x - w.cx, mon.w - Math.min(e.w, mon.w)));
                let sy = Math.max(0, Math.min(e.y - w.cy, mon.h - Math.min(e.h, mon.h)));
                e.x = Math.round(sx + w.cx); e.y = Math.round(sy + w.cy);
                keep.push(a);
            }
        }
        w.active = false;
        if (keep.length > 0) _applyGeometry(keep, ws);
        delete worlds[ws];
        worldsChanged();
        _recount();
        _scheduleSave();
    }

    function _recount() {
        let n = false;
        for (let k in worlds) if (worlds[k] && worlds[k].active) { n = true; break; }
        anyActive = n;
        if (!n) { _blurSettle(); _fastEnd(); }
        else _readBlur();
        _applyFollowMouse();
    }

    function _ignored(c) {
        let k = String(c.class || "").toLowerCase();
        if (c.title === "Serpantinum Settings" || c.initialTitle === "Serpantinum Settings") return true;
        let extra = root.setting("ignoreClasses", []);
        if (Array.isArray(extra)) for (let i = 0; i < extra.length; i++) if (k === String(extra[i]).toLowerCase()) return true;
        return k === "satty" || k === "com.gabm.satty" || k.indexOf("gpu-screen-recorder") === 0
            || k === "wf-recorder" || k === "slurp" || k === "grim" || k.indexOf("qs-") === 0
            || k === "swappy" || k === "flameshot";
    }

    property string _focusAddr: ""
    property string _blankFrom: ""
    property double _blankAt: 0

    function _addWindow(w, c, mon, seed) {
        let saved = _takeSaved(w, c);
        let e = {
            x: 0, y: 0,
            w: (c.size[0] >= 120 ? c.size[0] : Math.round(mon.w * 0.5)) / _k(w),
            h: (c.size[1] >= 80 ? c.size[1] : Math.round(mon.h * 0.55)) / _k(w),
            cls: c.class || "", title: c.title || "", ititle: c.initialTitle || "",
            wasFloating: !!c.floating,
            needFloat: false,
            off: false, sent: false,
            fs: (c.fullscreen || 0) > 0,
            floatUntil: 0
        };
        let push = false;

        if (saved) {
            e.x = saved.x; e.y = saved.y; e.w = saved.w; e.h = saved.h;
            push = true;
        } else if (seed) {
            e.x = c.at[0] - mon.x + w.cx;
            e.y = c.at[1] - mon.y + w.cy;
        } else {
            if (!c.floating) {
                e.w = Math.round(mon.w * 0.62 / _k(w));
                e.h = Math.round(mon.h * 0.70 / _k(w));
            }
            _settleCamera(w);
            let zc = w.z || 1;
            let tx = w.cx + (mon.w - e.w * _k(w)) / (2 * zc);
            let ty = w.cy + (mon.h - e.h * _k(w)) / (2 * zc);
            let spot = _placeNew(w, e.w, e.h, tx, ty, mon);
            e.x = spot.x;
            e.y = spot.y;
            push = true;
        }

        if (!c.floating) {
            e.needFloat = true;
            e.floatUntil = Date.now() + 1500;
            push = true;
        }
        w.wins[c.address] = e;
        return push;
    }

    function _overlaps(w, x, y, ww, hh) {
        for (let a in w.wins) {
            let o = w.wins[a];
            if (x < o.x + o.w + gap && x + ww + gap > o.x && y < o.y + o.h + gap && y + hh + gap > o.y) return true;
        }
        return false;
    }

    function _freeSpot(w, ww, hh, cx0, cy0) {
        if (!_overlaps(w, cx0, cy0, ww, hh)) return { x: Math.round(cx0), y: Math.round(cy0) };
        let sx = ww + gap, sy = hh + gap;
        let best = null, bd = 1e18;
        for (let i = -4; i <= 4; i++) {
            for (let j = -4; j <= 4; j++) {
                if (i === 0 && j === 0) continue;
                let x = cx0 + i * sx, y = cy0 + j * sy;
                let d = Math.hypot(i * sx, j * sy * 1.35);
                if (d >= bd) continue;
                if (_overlaps(w, x, y, ww, hh)) continue;
                bd = d; best = { x: Math.round(x), y: Math.round(y) };
            }
        }
        return best || { x: Math.round(cx0 + 40), y: Math.round(cy0 + 40) };
    }

    function _takeSaved(w, c) {
        let list = w.savedWins;
        if (!list || list.length === 0) return null;
        let pick = -1;
        for (let i = 0; i < list.length; i++) {
            if (list[i].cls === c.class && list[i].title === (c.initialTitle || "")) { pick = i; break; }
        }
        if (pick < 0) {
            for (let i = 0; i < list.length; i++) {
                if (list[i].cls === c.class) { pick = i; break; }
            }
        }
        if (pick < 0) return null;
        return list.splice(pick, 1)[0];
    }

    function refresh() {
        if (!isHyprland || !masterEnabled) return;
        if (reader.running) { _again = true; return; }
        reader.running = true;
    }
    property bool _again: false

    function _whenFresh(fn) {
        if (!isHyprland || !masterEnabled) return;
        _pendingFn = fn;
        refresh();
    }

    function _setCur(ws, name) {
        if (ws === curWs && name === curMon) return;
        stopAnim();
        _loading = true;
        curWs = ws;
        curMon = name;
        let w = worlds[ws];
        camX = w ? w.cx : 0; camY = w ? w.cy : 0;
        tgtX = camX; tgtY = camY;
        zoom = (w && w.z) ? w.z : 1; tgtZ = zoom;
        _fit = null;
        _loading = false;
        _touch();
    }

    function _onSnapshot(text) {
        let lines = text.split("\n").filter(function(l) { return l.trim().length > 0; });
        if (lines.length < 2) { _pendingFn = null; return; }
        let mons, cls;
        try { mons = JSON.parse(lines[0]); cls = JSON.parse(lines[1]); } catch (e) { _pendingFn = null; return; }

        let ml = [];
        for (let i = 0; i < mons.length; i++) {
            let m = mons[i];
            let sc = m.scale || 1;
            let w = Math.round(m.width / sc), h = Math.round(m.height / sc);
            if ((m.transform || 0) % 2 === 1) { let t = w; w = h; h = t; }
            ml.push({ id: m.id, name: m.name, x: m.x, y: m.y, w: w, h: h,
                      ws: m.activeWorkspace ? m.activeWorkspace.id : -1, focused: !!m.focused });
        }
        monitors = ml;
        _clients = cls.filter(function(c) {
            return c.mapped !== false && !c.hidden && c.workspace && c.workspace.id > 0;
        });

        let fm = null;
        for (let i = 0; i < ml.length; i++) if (ml[i].focused) fm = ml[i];
        if (!fm && ml.length > 0) fm = ml[0];
        if (fm) _setCur(fm.ws, fm.name);

        if (masterEnabled) _autoActivate();
        _reconcile();

        let fn = _pendingFn;
        _pendingFn = null;
        if (fn) fn();
        _touch();
    }

    function _autoActivate() {
        for (let k in _saved) {
            let ws = parseInt(k);
            if (!_saved[k] || !_saved[k].active || isActive(ws)) continue;
            let has = false;
            for (let i = 0; i < _clients.length; i++) if (_clients[i].workspace.id === ws) { has = true; break; }
            if (has && monFor(ws)) _activate(ws);
        }
        if (allWorkspaces) {
            let todo = {};
            for (let i = 0; i < monitors.length; i++) if (monitors[i].ws > 0) todo[monitors[i].ws] = true;
            for (let i = 0; i < _clients.length; i++) todo[_clients[i].workspace.id] = true;
            for (let k in todo) {
                let ws = parseInt(k);
                if (ws > 0 && !isActive(ws) && !_userOff[ws] && monFor(ws)) {
                    _autoWs[ws] = true;
                    _activate(ws);
                }
            }
        }
    }

    onAllWorkspacesChanged: {
        if (!isHyprland || !masterEnabled) return;
        if (allWorkspaces) {
            _userOff = ({});
            _whenFresh(function() { _autoActivate(); });
        } else {
            _whenFresh(function() {
                for (let k in _autoWs) {
                    let ws = parseInt(k);
                    if (isActive(ws)) _deactivate(ws);
                }
                _autoWs = ({});
            });
        }
    }

    function _reconcile() {
        let now = Date.now();
        let calm = !animating && !mover.running && _queue.length === 0 && !_dirty && now > _settleUntil && now - _lastCamMove > settleMs + 300;

        for (let k in worlds) {
            let w = worlds[k];
            if (!w || !w.active) continue;
            let ws = parseInt(k);
            let mon = monFor(ws);
            let seen = {};
            let geom = [];

            for (let i = 0; i < _clients.length; i++) {
                let c = _clients[i];
                if (c.workspace.id !== ws) continue;
                seen[c.address] = true;
                if (_ignored(c)) continue;
                let e = w.wins[c.address];

                if (!e) {
                    if (w.released[c.address]) {
                        if (!c.floating) continue;
                        delete w.released[c.address];
                        if (mon) _addWindow(w, c, mon, true);
                        continue;
                    }
                    if (mon && _addWindow(w, c, mon, false)) geom.push(c.address);
                    continue;
                }

                e.cls = c.class || e.cls; e.title = c.title || e.title;
                e.fs = (c.fullscreen || 0) > 0;

                if (!c.floating && now > e.floatUntil) {
                    delete w.wins[c.address];
                    w.released[c.address] = true;
                    continue;
                }
                if (e.fs || !mon) continue;
                if (!calm) continue;

                let z = w.z || 1;
                if (c.size[0] >= 60 && c.size[1] >= 40) { let kr = _k(w); if (e.w * kr >= 60 && e.h * kr >= 40) { e.w = c.size[0] / kr; e.h = c.size[1] / kr; } }
                if (!e.sent || e.off) continue;

                let ex = mon.x + (e.x - w.cx) * z, ey = mon.y + (e.y - w.cy) * z;
                let dx = c.at[0] - ex, dy = c.at[1] - ey;

                if (!_verified && (mon.x !== 0 || mon.y !== 0)) {
                    _verified = true;
                    if (Math.abs(dx + mon.x) < 3 && Math.abs(dy + mon.y) < 3) {
                        globalMoveCoords = true;
                        _requestFlush();
                        continue;
                    }
                }
                if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
                    if (_debugOn) _dbg("drift " + c.address + " dx=" + Math.round(dx) + " dy=" + Math.round(dy));
                    e.x = Math.round((c.at[0] - mon.x) / z + w.cx);
                    e.y = Math.round((c.at[1] - mon.y) / z + w.cy);
                    e.pend = true;
                    snapTimer.restart();
                    _scheduleSave();
                }
            }

            for (let a in w.wins) {
                if (!seen[a]) delete w.wins[a];
            }
            for (let a in w.released) {
                if (!seen[a]) delete w.released[a];
            }
            if (geom.length > 0) {
                _applyGeometry(geom, ws);
                if (centerOnOpen && ws === curWs && !cameraLocked) goToWindow(geom[geom.length - 1]);
            }
        }
        _recount();
    }

    function _onActiveWindow(addr) {
        let raw = String(addr || "").replace(/^0x/, "").trim();
        let now0 = Date.now();
        if (raw === "" || raw === ",") {
            if (_focusAddr !== "") { _blankFrom = _focusAddr; _blankAt = now0; }
            _focusAddr = "";
            return;
        }
        let back = (_blankFrom !== "" && raw === _blankFrom && now0 - _blankAt < 15000);
        _blankFrom = "";
        _focusAddr = raw;
        if (back) return;
        if (!followFocus || !curActive || cameraLocked) return;
        if (raw === _navAddr && Date.now() < _navUntil) return;
        if (animating || _compAnim || mover.running) return;
        if (Date.now() < Math.max(_focusGateUntil, _settleUntil)) return;
        let a = _addr(addr);
        let w = worlds[curWs];
        let e = w ? w.wins[a] : null;
        let mon = monFor(curWs);
        if (!e || !mon || e.fs) return;

        let z = w.z || 1;
        let m = 40;
        let kf = _k(w);
        let ew = e.w * kf, eh = e.h * kf;
        let sx = (e.x - w.cx) * z, sy = (e.y - w.cy) * z;
        if (sx >= m / 2 && sy >= m / 2 && sx + ew <= mon.w - m / 2 && sy + eh <= mon.h - m / 2) return;

        let ms = Math.min(animMs, 380);
        let vis = Math.max(0, Math.min(sx + ew, mon.w) - Math.max(sx, 0)) * Math.max(0, Math.min(sy + eh, mon.h) - Math.max(sy, 0));
        if (vis >= 0.4 * Math.max(1, ew * eh) || vis >= 0.4 * mon.w * mon.h) return;

        let cx0 = w.cx, cy0 = w.cy;
        let run = function() {
            if (animating || _compAnim || mover.running) return;
            if (vis === 0 || ew > mon.w - m * 2 || eh > mon.h - m * 2) {
                centerOnEntry(e, ms);
                return;
            }
            let dx = 0, dy = 0;
            if (sx < m) dx = sx - m; else if (sx + ew > mon.w - m) dx = sx + ew - mon.w + m;
            if (sy < m) dy = sy - m; else if (sy + eh > mon.h - m) dy = sy + eh - mon.h + m;
            glideTo(cx0 + dx / z, cy0 + dy / z, undefined, ms);
        };

        _focusGlide = { sx: sx, sy: sy, w: ew, h: eh, run: run };
        if (!focusCursorProc.running) focusCursorProc.running = true;
    }

    property var _focusGlide: null

    function _focusCursorDone(text) {
        let g = _focusGlide;
        _focusGlide = null;
        if (!g) return;
        let mon = monFor(curWs);
        try {
            let c = JSON.parse(text);
            let px = c.x - (mon ? mon.x : 0), py = c.y - (mon ? mon.y : 0);
            if (px >= g.sx && px <= g.sx + g.w && py >= g.sy && py <= g.sy + g.h) return;
        } catch (err) {}
        g.run();
    }

    Process {
        id: focusCursorProc
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: root._focusCursorDone(this.text)
        }
    }

    function _scheduleSave() { saveTimer.restart(); }

    function _save() {
        if (!_loaded) { saveTimer.restart(); return; }
        let out = {};
        for (let k in _saved) {
            if (_saved[k] && !isActive(parseInt(k))) out[k] = _saved[k];
        }
        for (let k in worlds) {
            let w = worlds[k];
            if (!w || !w.active) continue;
            let list = [];
            for (let a in w.wins) {
                let e = w.wins[a];
                list.push({ cls: e.cls, title: e.ititle, x: e.x, y: e.y, w: e.w, h: e.h });
            }
            if (w.savedWins && Date.now() < (w.pendingUntil || 0)) {
                for (let i = 0; i < w.savedWins.length && list.length < 80; i++) list.push(w.savedWins[i]);
            }
            out[k] = { active: true, cx: w.cx, cy: w.cy, z: w.z || 1, marks: w.marks, wins: list };
        }
        _saved = out;
        let json = JSON.stringify({ version: 1, workspaces: out });
        Quickshell.execDetached(["bash", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"", "_", stateFile, json]);
    }

    onCamXChanged: _onCamChanged()
    onCamYChanged: _onCamChanged()

    function _onCamChanged() {
        if (_loading) return;
        let w = worlds[curWs];
        if (!w || !w.active) return;
        if (_compAnim) return;
        w.cx = camX; w.cy = camY;
        _lastCamMove = Date.now();
        _blurMotion();
        _requestFlush();
        saveTimer.restart();
    }

    NumberAnimation { id: animX; target: root; property: "camX"; easing.type: Easing.BezierSpline; easing.bezierCurve: root.hlCurve; onRunningChanged: root._glideEnded() }
    NumberAnimation { id: animY; target: root; property: "camY"; easing.type: Easing.BezierSpline; easing.bezierCurve: root.hlCurve; onRunningChanged: root._glideEnded() }
    NumberAnimation { id: animZ; target: root; property: "zoom"; easing.type: Easing.BezierSpline; easing.bezierCurve: root.hlCurve; onRunningChanged: root._glideEnded() }

    function _glideEnded() {
        if (!animX.running && !animY.running && !animZ.running) _compAnim = false;
    }

    Process {
        id: cursorProc
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: root._applyCursor(this.text)
        }
    }

    Timer { id: blurTimer; interval: 520; repeat: false; onTriggered: root._blurSettle() }

    Process {
        id: blurReader
        command: ["bash", "-c", "for o in xray size passes; do hyprctl -j getoption decoration:blur:$o | tr -d '\\n'; echo; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                let vals = [];
                let lines = this.text.split("\n").filter(function(l) { return l.trim().length > 0; });
                for (let i = 0; i < lines.length; i++) {
                    let v = NaN;
                    try { let o = JSON.parse(lines[i]); v = (o.int !== undefined) ? Number(o.int) : (o.bool ? 1 : 0); } catch (e) {}
                    vals.push(v);
                }
                let size = (vals[1] > 0) ? vals[1] : root._blurBase.size;
                let passes = (vals[2] > 0) ? vals[2] : root._blurBase.passes;
                root._blurBase = { xray: vals[0] ? 1 : 0, size: size, passes: passes };
                root._blurXray = vals[0] ? 1 : 0;
            }
        }
    }

    Timer { id: flushTimer; interval: 8; repeat: false; onTriggered: root._flush() }
    Timer { id: saveTimer; interval: 1200; repeat: false; onTriggered: root._save() }
    Timer {
        id: eventTimer
        interval: 70
        repeat: false
        onTriggered: {
            if (root._fast || root.animating || root._compAnim || mover.running) { eventTimer.restart(); return; }
            root.refresh();
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.isHyprland && root.masterEnabled && root.anyActive
        onTriggered: if (!root._fast && !root.animating && !root._compAnim && !mover.running) root.refresh()
    }

    Process {
        id: mover
        onExited: {
            if (root._queue.length > 0) root._pump();
            else if (root._dirty) root._flush();
        }
    }

    Process {
        id: reader
        command: ["bash", "-c", "hyprctl -j monitors | tr -d '\\n'; echo; hyprctl -j clients | tr -d '\\n'; echo"]
        stdout: StdioCollector {
            onStreamFinished: root._onSnapshot(this.text)
        }
        onExited: {
            if (root._again) { root._again = false; root.refresh(); }
        }
    }

    FileView {
        id: store
        path: root.stateFile
        onLoaded: {
            try {
                let data = JSON.parse(text());
                root._saved = (data && data.workspaces) ? data.workspaces : ({});
            } catch (e) {}
            root._loaded = true;
            root.refresh();
        }
        onLoadFailed: function(error) {
            root._loaded = true;
            root.refresh();
        }
    }

    Connections {
        target: (root.isHyprland && typeof Hyprland !== "undefined") ? Hyprland : null
        function onRawEvent(event) {
            if (!event || !event.name || !root.masterEnabled) return;
            let n = event.name;
            if (n === "activewindowv2") {
                root._onActiveWindow(event.data);
                return;
            }
            if (!root._loaded) return;
            if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" ||
                n === "changefloatingmode" || n === "workspacev2" || n === "focusedmonv2" ||
                n === "fullscreen" || n === "monitoraddedv2" || n === "monitorremoved") {
                eventTimer.restart();
            }
        }
    }

    IpcHandler {
        target: "canvas"

        function toggle(): void { root.toggleCanvas(); }
        function enable(): void { root.enableCanvas(); }
        function disable(): void { root.disableCanvas(); }
        function focus(dir: string): void { root.focusDir(dir); }
        function overview(): void { root.toggleFit(); }
        function fit(): void { root.toggleFit(); }
        function zoomIn(): void { root.zoomBy(root.zoomStep); }
        function zoomOut(): void { root.zoomBy(1 / root.zoomStep); }
        function zoom(factor: real): void { root.zoomBy(factor); }
        function zoomReset(): void { let w = root.curWorld; if (w) root.glideTo(w.cx, w.cy, 1, root.animMs); }
        function panBy(dx: real, dy: real): void { root.panBy(dx, dy); }
        function panPage(fx: real, fy: real): void { root.panPage(fx, fy); }
        function home(): void { root.home(); }
        function tidy(): void { root.tidy(); }
        function arrange(mode: string): void { root.arrange(mode); }
        function debug(on: bool): void { root.setDebug(on); }
        function dump(): string { return root.dumpState(); }
        function markSet(n: int): void { root.markSet(n); }
        function markGo(n: int): void { root.markGo(n); }

        function status(): string {
            let w = root.curWorld;
            return JSON.stringify({
                workspace: root.curWs,
                monitor: root.curMon,
                active: root.curActive,
                camera: { x: Math.round(root.camX), y: Math.round(root.camY) },
                zoom: root.zoom,
                widgetsOnCanvas: root.widgetsOnCanvas,
                allWorkspaces: root.allWorkspaces,
                windows: w ? Object.keys(w.wins).length : 0,
                globalMoveCoords: root.globalMoveCoords
            });
        }
    }
}
