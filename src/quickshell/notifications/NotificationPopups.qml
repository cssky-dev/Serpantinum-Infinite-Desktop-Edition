import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"
import "../reusables"

PanelWindow {
    id: popupWindow

    readonly property real sf: Scaler.baseScale

    function s(val) {
        return Math.round(val * popupWindow.sf);
    }

    property bool hasCriticalPopup: {
        for (let i = 0; i < NotificationManager.activePopupsModel.count; i++) {
            let p = NotificationManager.activePopupsModel.get(i);
            if (p && p.urgency === 2) return true;
        }
        return false;
    }

    visible: (!popupWindow.dndEnabled || popupWindow.hasCriticalPopup) && !NotificationManager.sysPanelOpen && NotificationManager.activePopupsModel.count > 0

    function storeNotif(uid, notif) {
        NotificationManager.liveNotifs[uid] = notif;
    }

    function getNotif(uid) {
        return NotificationManager.liveNotifs[uid] || null;
    }

    function removeNotif(uid) {
        NotificationManager.removePopup(uid);
    }

    property var rawBarSettings: Config.getSetting("bar", {})
    property string barPosition: (rawBarSettings && rawBarSettings.position !== undefined) ? rawBarSettings.position : "top"
    property bool barAutohide: (rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false

    readonly property bool isFullscreenActive: {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive

    property string barStyle: {
        if (!rawBarSettings || rawBarSettings.style === undefined) return "modular";
        let st = rawBarSettings.style;
        if (typeof st === "string") return st;
        if (typeof st === "object") {
            if (st.fill || st.mode === "fill") return "fill";
            if (st.solid || st.mode === "solid") return "solid";
        }
        return "modular";
    }
    property bool isBarFill: barStyle === "fill"
    property int barThickness: s(40) + (isBarFill || isBarEffectivelyHidden ? 0 : s(4))

    property var notifSettings: Config.getSetting("notifications", { "dnd": false, "position": "top right", "horizontalPosition": 95, "verticalPosition": 5 })
    property string position: notifSettings.position !== undefined ? notifSettings.position : "top right"
    property real horizontalPosition: notifSettings.horizontalPosition !== undefined ? notifSettings.horizontalPosition : 95
    property real verticalPosition: notifSettings.verticalPosition !== undefined ? notifSettings.verticalPosition : 5

    property bool isPreset: position !== "custom"

    // Which edge the cards come from: slideX / slideY are -1, 0 or 1 towards that edge.
    readonly property int slideX: isPreset ? (isCenter ? 0 : (isLeft ? -1 : 1)) : (horizontalPosition < 33 ? -1 : (horizontalPosition > 66 ? 1 : 0))
    readonly property int slideY: isPreset ? (isBottom ? 1 : -1) : (verticalPosition > 50 ? 1 : -1)

    // Entrance spring. Rounder themes bounce a little more, Liquid Glass starts smaller and
    // travels further (same recipe as the launcher and the polkit prompt).
    readonly property real springOvershoot: (ThemeBackend.liquidGlass ? 1.5 : 1.2) + 0.4 * Math.min(1.0, ThemeBackend.borderRadius / 20.0)
    readonly property real startScale: ThemeBackend.liquidGlass ? 0.8 : 0.88
    readonly property real glassTravel: ThemeBackend.liquidGlass ? 1.3 : 1.0
    readonly property int springMs: ThemeBackend.liquidGlass ? 700 : 600

    property bool isTop: position.indexOf("top") !== -1
    property bool isBottom: position.indexOf("bottom") !== -1
    property bool isCenter: position.indexOf("center") !== -1
    property bool isLeft: position.indexOf("left") !== -1
    property bool isRight: position.indexOf("right") !== -1 || (!isLeft && !isCenter)

    WlrLayershell.namespace: "qs-popups"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        bottom: true
        left: isPreset ? (popupWindow.isCenter || popupWindow.isLeft) : true
        right: isPreset ? (popupWindow.isCenter || popupWindow.isRight) : true
    }

    margins {
        top: isPreset ? ((popupWindow.barPosition === "top" && !popupWindow.isBarEffectivelyHidden ? popupWindow.barThickness : 0) + popupWindow.s(12)) : 0
        bottom: isPreset ? ((popupWindow.barPosition === "bottom" && !popupWindow.isBarEffectivelyHidden ? popupWindow.barThickness : 0) + popupWindow.s(12)) : 0
        left: isPreset ? ((popupWindow.barPosition === "left" && popupWindow.isLeft && !popupWindow.isBarEffectivelyHidden ? popupWindow.barThickness : 0) + (popupWindow.isLeft ? popupWindow.s(16) : 0)) : 0
        right: isPreset ? ((popupWindow.barPosition === "right" && popupWindow.isRight && !popupWindow.isBarEffectivelyHidden ? popupWindow.barThickness : 0) + (popupWindow.isRight ? popupWindow.s(16) : 0)) : 0
    }

    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: "transparent"

    implicitWidth: s(360)

    mask: Region {
        item: popupContainer
    }

    property bool dndEnabled: {
        let n = Config.getSetting("notifications", { "dnd": false, "position": "top right" });
        return Boolean(n && n.dnd);
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            let n = Config.getSetting("notifications", { "dnd": false, "position": "top right" });
            popupWindow.dndEnabled = Boolean(n && n.dnd);
            popupWindow.position = (n && n.position !== undefined) ? n.position : "top right";
            popupWindow.horizontalPosition = (n && n.horizontalPosition !== undefined) ? n.horizontalPosition : 95;
            popupWindow.verticalPosition = (n && n.verticalPosition !== undefined) ? n.verticalPosition : 5;
            popupWindow.rawBarSettings = Config.getSetting("bar", {});
            popupWindow.barPosition = (popupWindow.rawBarSettings && popupWindow.rawBarSettings.position !== undefined) ? popupWindow.rawBarSettings.position : "top";
            popupWindow.barAutohide = (popupWindow.rawBarSettings && popupWindow.rawBarSettings.autohide !== undefined) ? Boolean(popupWindow.rawBarSettings.autohide) : false;
        }
    }

    Item {
        id: popupRoot
        anchors.fill: parent

        function s(val) {
            return popupWindow.s(val);
        }

        Item {
            id: popupContainer
            width: popupWindow.s(360)
            height: popupList.height

            x: popupWindow.isPreset ? (popupWindow.isCenter ? (popupWindow.width - width) / 2 : (popupWindow.isLeft ? 0 : (popupWindow.width - width))) : ((popupWindow.width - width) * (popupWindow.horizontalPosition / 100.0))
            y: popupWindow.isPreset ? (popupWindow.isTop ? 0 : (popupWindow.height - height)) : ((popupWindow.height - height) * (popupWindow.verticalPosition / 100.0))

            ListView {
                id: popupList
                width: parent.width
                height: Math.min(popupWindow.height, contentHeight)
                verticalLayoutDirection: (popupWindow.isPreset ? popupWindow.isBottom : (popupWindow.verticalPosition > 50)) ? ListView.BottomToTop : ListView.TopToBottom
                model: NotificationManager.activePopupsModel
                spacing: popupWindow.s(12)
                interactive: false
                clip: false
                boundsBehavior: Flickable.StopAtBounds

                // The entrance is NOT a ListView transition any more. An "add" transition that is
                // interrupted by the next card (or animates y to a fixed 0) leaves the card at a
                // stale scale / offset, which showed up as a card that was narrower and not lined
                // up with the one above it. Each card now drives its own entrance from a single
                // `enter` value (see `entry` below), so the end state is always exactly x 0, scale 1.
                // The list only moves cards vertically, with no overshoot, so they never overlap.
                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 0.0; duration: 190; easing.type: Easing.InCubic }
                        NumberAnimation { property: "x"; to: popupWindow.slideX * popupWindow.s(34); duration: 240; easing.type: Easing.InCubic }
                    }
                }

                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 320; easing.type: Easing.OutCubic }
                }

                addDisplaced: Transition {
                    NumberAnimation { property: "y"; duration: 320; easing.type: Easing.OutCubic }
                }

                removeDisplaced: Transition {
                    NumberAnimation { property: "y"; duration: 320; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    id: delegateWrapper
                    width: ListView.view.width
                    transformOrigin: popupWindow.slideY < 0 ? Item.Top : Item.Bottom

                    property bool isSuppressedByDnd: popupWindow.dndEnabled && model.urgency !== 2

                    implicitHeight: isSuppressedByDnd ? 0 : (typeLoader.item ? typeLoader.item.implicitHeight : popupWindow.s(70))
                    height: implicitHeight
                    visible: !isSuppressedByDnd

                    property int popupUid: model.uid || model.latestUid
                    property var realNotif: popupWindow.getNotif(popupUid) || (model.notif ? model.notif : null)
                    property bool isPopupContext: true
                    property var msgModel: model
                    property bool isExpanded: typeLoader.item && typeLoader.item.expanded ? true : false
                    property bool isHovered: typeLoader.item && typeLoader.item.isHovered ? true : false
                    property bool isDragging: typeLoader.item && typeLoader.item.isDragging ? true : false

                    property var actionArray: {
                        try {
                            return model.actionsJson ? JSON.parse(model.actionsJson) : []
                        } catch (e) {
                            return []
                        }
                    }

                    property int effectiveTimeout: {
                        if (model.urgency === 2) return 0;
                        var n = delegateWrapper.realNotif;
                        var fallback = /battery-kind-/.test(String(model.image)) ? 10000 : 5000;
                        if (!n) return fallback;
                        var t = typeof n.expireTimeout === "number" ? n.expireTimeout : (typeof n.timeout === "number" ? n.timeout : -1);
                        if (t === 0) return 0;
                        if (t > 0) return t;
                        return fallback;
                    }

                    Connections {
                        target: delegateWrapper.realNotif || null
                        function onClosed() {
                            popupWindow.removeNotif(delegateWrapper.popupUid);
                        }
                    }

                    Timer {
                        id: dismissTimer
                        interval: delegateWrapper.effectiveTimeout > 0 ? delegateWrapper.effectiveTimeout : 5000
                        running: delegateWrapper.effectiveTimeout > 0 && !delegateWrapper.isHovered && !delegateWrapper.isExpanded && !delegateWrapper.isDragging
                        repeat: false
                        onTriggered: popupWindow.removeNotif(delegateWrapper.popupUid)
                    }

                    function removeThisNotif() {
                        popupWindow.removeNotif(delegateWrapper.popupUid);
                    }

                    Item {
                        id: entry
                        width: parent.width
                        height: parent.height
                        transformOrigin: popupWindow.slideY < 0 ? Item.Top : Item.Bottom

                        // 0 = just created, 1 = settled. Everything below is derived from it.
                        property real enter: 0.0
                        property real fade: 0.0
                        Component.onCompleted: { enter = 1.0; fade = 1.0; }
                        Behavior on enter {
                            NumberAnimation {
                                duration: popupWindow.springMs
                                easing.type: Easing.OutBack
                                easing.overshoot: popupWindow.springOvershoot
                            }
                        }
                        Behavior on fade { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                        opacity: fade
                        scale: popupWindow.startScale + (1.0 - popupWindow.startScale) * enter
                        transform: Translate {
                            x: popupWindow.slideX * popupWindow.s(56) * popupWindow.glassTravel * (1.0 - entry.enter)
                            y: popupWindow.slideY * popupWindow.s(72) * popupWindow.glassTravel * (1.0 - entry.enter)
                        }

                        Loader {
                            id: typeLoader
                            width: parent.width
                            source: {
                                let app = (model.appName || "").toLowerCase();
                                if (app === "weather" || /weather-kind-/.test(String(model.image))) return "types/Weather.qml";
                                if (/battery-kind-/.test(String(model.image))) return "types/Battery.qml";
                                if (app === "screenshot" || app === "screen recorder") return "types/Screenshot.qml";
                                return "types/Default.qml";
                            }
                            onLoaded: {
                                if (item) {
                                    item.model = delegateWrapper.msgModel;
                                    item.root = popupRoot;
                                    item.delegateWrapper = delegateWrapper;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: NotificationManager
        function onPopupAdded(uid, notif) {
            popupWindow.storeNotif(uid, notif);
        }
    }
}
