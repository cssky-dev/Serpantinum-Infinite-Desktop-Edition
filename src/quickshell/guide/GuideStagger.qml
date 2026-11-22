import QtQuick

// Springy staggered entrance for the rows of a settings tab, in the spirit of the Digital
// Wellbeing intro. Every visible row rises, fades in and settles on a damped spring with a
// small overshoot, one after another from the top.
//
// What changed compared to the first version:
//  - a real damped spring replaces the single outBack curve, so rows bounce and settle
//  - rows slide a little sideways in the direction the user navigated (next / previous tab)
//  - rows that appear a moment later (tabs that build their content in stages, like Weather,
//    or sections inside Loaders) join the wave as soon as they get a size, instead of popping
//    in with no animation
//
// One shared frame clock drives every row, so a whole tab costs a single animation. The helper
// objects (one Translate per row) exist only while the animation runs and are destroyed when it
// ends, so nothing is kept in memory afterwards.
Item {
    id: stagger

    visible: false
    width: 0
    height: 0

    property var popup: null

    // Tuning
    property int stepMs: 40           // delay between two neighbouring rows
    property int itemMs: 780          // length of one row's entrance (the spring is normalised to it)
    property int maxItems: 24         // rows beyond this count simply appear
    property real riseDp: 26          // how far a row travels before settling
    property real slideDp: 12         // sideways travel, signed by the navigation direction
    property real startScale: 0.955
    property int lateWindowMs: 1000   // rows that get a size this long after the start still join
    property int lateStepMs: 34
    property int direction: 1         // 1 = came from a later tab, -1 = from an earlier one

    // Damped spring: decay and angular frequency per normalised unit. These give ~10% overshoot.
    readonly property real _decay: 7.5
    readonly property real _omega: 10.5

    property var _targets: []
    property var _known: []
    property var _col: null
    property var _flick: null
    property real _clock: 0
    property real _total: 1
    property bool _active: false

    function s(v) {
        return (popup && typeof popup.s === "function") ? popup.s(v) : v;
    }

    // Tabs keep their rows in a ColumnLayout inside a Flickable. Find that column.
    function _findFlickable(root) {
        let queue = [root];
        let depth = 0;
        while (queue.length > 0 && depth < 5) {
            let next = [];
            for (let i = 0; i < queue.length; i++) {
                let it = queue[i];
                if (!it) continue;
                if (it.contentItem !== undefined && it.contentY !== undefined && it.contentHeight !== undefined) return it;
                let kids = it.children;
                for (let k = 0; k < kids.length; k++) next.push(kids[k]);
            }
            queue = next;
            depth++;
        }
        return null;
    }

    function _findColumn(flick) {
        let best = null;
        let kids = flick.contentItem.children;
        for (let i = 0; i < kids.length; i++) {
            if (!best || kids[i].children.length > best.children.length) best = kids[i];
        }
        return best;
    }

    function stop() {
        stagger._active = false;
        stagger._restore();
        stagger._known = [];
        stagger._col = null;
        stagger._flick = null;
    }

    function _restore() {
        let list = stagger._targets;
        stagger._targets = [];
        for (let i = 0; i < list.length; i++) {
            let t = list[i];
            try {
                if (!t.item) continue;
                if (t.fade) t.item.opacity = 1.0;
                t.item.scale = 1.0;
                t.item.transform = t.prevTransform;
                if (t.tr) t.tr.destroy();
            } catch (e) {}
        }
    }

    // Starts the clock-driven entrance for one row. `start` is in clock milliseconds.
    function _attach(it, start) {
        let prev = [];
        for (let k = 0; k < it.transform.length; k++) prev.push(it.transform[k]);
        let tr = trComp.createObject(it);
        it.transform = prev.concat([tr]);

        stagger._known.push(it);
        stagger._targets.push({
            item: it,
            tr: tr,
            prevTransform: prev,
            // rows that run their own fade keep it, we only move them
            fade: it.opacity > 0.999,
            start: start
        });
        let end = start + stagger.itemMs;
        if (end > stagger._total) stagger._total = end;
    }

    function _eligible(it) {
        if (!it || !it.visible || it.height <= 1 || it.width <= 1) return false;
        return stagger._known.indexOf(it) < 0;
    }

    function play(tabItem, dir) {
        stagger.stop();
        if (!tabItem) return;
        stagger.direction = (dir === undefined || dir === 0) ? 1 : (dir > 0 ? 1 : -1);

        // A tab can name its own column (staggerColumn) when it holds a list view that
        // would otherwise be mistaken for the scrolling area.
        let flick = null;
        let col = null;
        if (tabItem.staggerColumn !== undefined && tabItem.staggerColumn) {
            flick = tabItem;
            col = tabItem.staggerColumn;
        } else {
            flick = stagger._findFlickable(tabItem);
            if (!flick) return;
            col = stagger._findColumn(flick);
        }
        if (!col) return;

        stagger._flick = flick;
        stagger._col = col;
        stagger._total = 1;
        stagger._clock = 0;

        let kids = col.children;
        let n = 0;
        for (let i = 0; i < kids.length && n < stagger.maxItems; i++) {
            let it = kids[i];
            if (!stagger._eligible(it)) continue;
            // rows that start below the fold are not animated, nobody sees them
            let top = col.mapToItem(flick, 0, it.y).y;
            if (top > flick.height) break;
            if (top + it.height < 0) continue;
            stagger._attach(it, n * stagger.stepMs);
            n++;
        }

        // Even with nothing to animate yet, keep watching for rows that show up late.
        stagger._active = true;
        stagger._apply();
    }

    // Rows that got a size after the wave started (staged tabs, Loaders, revealed sections).
    function _scanLate() {
        let col = stagger._col;
        let flick = stagger._flick;
        if (!col || !flick || stagger._targets.length >= stagger.maxItems) return;
        let kids = col.children;
        let late = 0;
        for (let i = 0; i < kids.length && stagger._targets.length < stagger.maxItems; i++) {
            let it = kids[i];
            if (!stagger._eligible(it)) continue;
            let top = col.mapToItem(flick, 0, it.y).y;
            if (top > flick.height) break;
            if (top + it.height < 0) continue;
            stagger._attach(it, stagger._clock + 16 + late * stagger.lateStepMs);
            late++;
        }
    }

    function _tick(dt) {
        if (!stagger._active) return;
        stagger._clock += Math.min(dt, 0.05) * 1000;
        // every frame while the window is open: a late row must be caught before it is painted
        if (stagger._clock < stagger.lateWindowMs) stagger._scanLate();
        stagger._apply();
        if (stagger._clock >= stagger._total && stagger._clock >= stagger.lateWindowMs) {
            stagger._active = false;
            stagger._restore();
            stagger._known = [];
            stagger._col = null;
            stagger._flick = null;
        }
    }

    // 0 -> 1 with overshoot; exactly 1 at p >= 1
    function _spring(p) {
        if (p <= 0) return 0;
        if (p >= 1) return 1;
        let a = stagger._decay;
        let w = stagger._omega;
        return 1 - Math.exp(-a * p) * (Math.cos(w * p) + (a / w) * Math.sin(w * p));
    }

    function _outCubic(t) {
        let u = 1 - t;
        return 1 - u * u * u;
    }

    function _apply() {
        let list = stagger._targets;
        let rise = stagger.s(stagger.riseDp);
        let slide = stagger.s(stagger.slideDp) * stagger.direction;
        for (let i = 0; i < list.length; i++) {
            let t = list[i];
            let p = (stagger._clock - t.start) / stagger.itemMs;
            p = p < 0 ? 0 : (p > 1 ? 1 : p);
            let move = stagger._spring(p);
            try {
                if (t.fade) t.item.opacity = stagger._outCubic(Math.min(1, p * 2.2));
                t.item.scale = stagger.startScale + (1 - stagger.startScale) * move;
                t.tr.y = rise * (1 - move);
                t.tr.x = slide * (1 - move);
            } catch (e) {}
        }
    }

    FrameAnimation {
        running: stagger._active
        onTriggered: stagger._tick(frameTime)
    }

    Component {
        id: trComp
        Translate {}
    }
}
