import QtQuick

QtObject {
    id: root

    property bool open: false
    property bool animated: true
    property int openDuration: 700
    property int closeDuration: 180
    property int closeEasing: Easing.InQuad

    property real value: 0.0
    property bool active: false

    property real time: 0.0
    property real origin: 0.0

    function springValue(t) {
        return 1.0 - Math.exp(-7.0 * t) * (Math.cos(5.62 * t) + 1.2456 * Math.sin(5.62 * t));
    }

    onTimeChanged: {
        if (openAnim.running) value = origin + (1.0 - origin) * springValue(time);
    }

    onValueChanged: {
        if (!open && active && value <= 0.001 && !linger.running) linger.restart();
    }

    // Starts the opening spring from the current value. Every path that opens goes through here.
    function startOpening() {
        linger.stop();
        active = true;
        if (!animated) {
            value = 1.0;
            return;
        }
        origin = value;
        time = 0.0;
        openAnim.restart();
        kick.restart();
    }

    onOpenChanged: {
        openAnim.stop();
        closeAnim.stop();
        kick.stop();
        if (open) {
            startOpening();
        } else if (!animated || value <= 0.001) {
            value = 0.0;
            linger.restart();
        } else {
            closeAnim.restart();
        }
    }

    // A surface that is created already open used to jump straight to its end value, so it appeared
    // with no animation at all. It now plays the opening spring from zero like any other open;
    // only a reveal that is not animated (dock first paint, position change) lands directly.
    Component.onCompleted: {
        if (open && !active) {
            value = 0.0;
            startOpening();
        }
    }

    property NumberAnimation openAnim: NumberAnimation {
        target: root
        property: "time"
        from: 0.0
        to: 1.0
        duration: root.openDuration
        onFinished: root.value = 1.0
    }

    property NumberAnimation closeAnim: NumberAnimation {
        target: root
        property: "value"
        to: 0.0
        duration: root.closeDuration
        easing.type: root.closeEasing
    }

    // Watchdog: if the opening spring did not move the value shortly after opening (the animation
    // was stopped by a re-created window, the surface was not rendering when it started, ...),
    // run it again, and if it still has not moved, land on the end value. A reveal can therefore
    // never be left stuck at zero, which is what made popups appear with no animation or not at all.
    property int kicks: 0
    property Timer kick: Timer {
        interval: 140
        onTriggered: {
            if (!root.open || !root.animated) { root.kicks = 0; return; }
            if (openAnim.running && root.time > 0.0) { root.kicks = 0; return; }
            if (root.value > root.origin + 0.001 && root.value < 0.999) { root.kicks = 0; return; }
            if (root.value >= 0.999) { root.kicks = 0; return; }
            root.kicks++;
            if (root.kicks >= 3) {
                root.kicks = 0;
                root.value = 1.0;
                return;
            }
            root.time = 0.0;
            openAnim.restart();
            kick.restart();
        }
    }

    property Timer linger: Timer {
        interval: 60
        onTriggered: {
            if (!root.open) root.active = false;
        }
    }
}
