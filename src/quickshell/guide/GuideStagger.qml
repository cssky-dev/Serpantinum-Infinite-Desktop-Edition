import QtQuick

// Staggered entrance for the rows of a settings tab, in the spirit of the Digital
// Wellbeing intro: every visible row slides up, fades in and settles with a soft
// overshoot, one after another from the top.
//
// One shared clock drives every row, so a whole tab costs a single animation. The
// helper objects (one Translate per row) exist only while the animation runs and are
// destroyed when it ends, so nothing is kept in memory afterwards.
Item {
    id: stagger

    visible: false
    width: 0
    height: 0

    property var popup: null

    // Tuning
    property int stepMs: 38         // delay between two neighbouring rows
    property int itemMs: 620        // length of one row's entrance
    property int maxItems: 16       // rows below this count simply appear
    property real riseDp: 22        // how far a row travels before settling
    property real startScale: 0.965

    property var _targets: []
    property real _clock: 0
    property real _total: 1

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
        anim.stop();
        stagger._restore();
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

    function play(tabItem) {
        stagger.stop();
        if (!tabItem) return;

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

        let targets = [];
        let kids = col.children;
        for (let i = 0; i < kids.length && targets.length < stagger.maxItems; i++) {
            let it = kids[i];
            if (!it.visible || it.height <= 1 || it.width <= 1) continue;
            // rows that start below the fold are not animated, nobody sees them
            let top = col.mapToItem(flick, 0, it.y).y;
            if (top > flick.height) break;
            if (top + it.height < 0) continue;

            let prev = [];
            for (let k = 0; k < it.transform.length; k++) prev.push(it.transform[k]);
            let tr = trComp.createObject(it);
            it.transform = prev.concat([tr]);

            targets.push({
                item: it,
                tr: tr,
                prevTransform: prev,
                // rows that run their own fade keep it, we only move them
                fade: it.opacity > 0.999,
                start: targets.length * stagger.stepMs
            });
        }
        if (targets.length === 0) return;

        stagger._targets = targets;
        stagger._total = (targets.length - 1) * stagger.stepMs + stagger.itemMs;
        stagger._clock = 0;
        stagger._apply();
        anim.duration = stagger._total;
        anim.restart();
    }

    function _outBack(t, o) {
        let c3 = o + 1;
        let u = t - 1;
        return 1 + c3 * u * u * u + o * u * u;
    }

    function _outCubic(t) {
        let u = 1 - t;
        return 1 - u * u * u;
    }

    function _apply() {
        let list = stagger._targets;
        let rise = stagger.s(stagger.riseDp);
        for (let i = 0; i < list.length; i++) {
            let t = list[i];
            let p = (stagger._clock - t.start) / stagger.itemMs;
            p = p < 0 ? 0 : (p > 1 ? 1 : p);
            let move = stagger._outBack(p, 0.8);
            try {
                if (t.fade) t.item.opacity = stagger._outCubic(Math.min(1, p * 1.7));
                t.item.scale = stagger.startScale + (1 - stagger.startScale) * move;
                t.tr.y = rise * (1 - move);
            } catch (e) {}
        }
    }

    NumberAnimation {
        id: anim
        target: stagger
        property: "_clock"
        from: 0
        to: stagger._total
        easing.type: Easing.Linear
        onFinished: stagger._restore()
    }

    on_ClockChanged: if (anim.running) stagger._apply()

    Component {
        id: trComp
        Translate {}
    }
}
