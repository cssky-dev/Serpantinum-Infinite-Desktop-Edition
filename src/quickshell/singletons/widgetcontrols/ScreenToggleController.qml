import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: controller

    property bool isVisible: false
    property var screen: null

    // A toggle that arrives while the open/close animation is still running is dropped instead of
    // reversing the animation half-way (pressing a launcher / calendar keybind repeatedly used to
    // restart or cancel the reveal every time). Explicit show() / hide() calls are never dropped.
    property int lockMs: 380
    property double lastChangeMs: 0

    onIsVisibleChanged: lastChangeMs = Date.now()

    function getFocusedScreen() {
        try {
            if (typeof Hyprland !== "undefined") {
                let monName = "";
                if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
                    monName = Hyprland.focusedMonitor.name;
                } else if (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.monitor && Hyprland.focusedWorkspace.monitor.name) {
                    monName = Hyprland.focusedWorkspace.monitor.name;
                }

                if (monName && typeof Quickshell !== "undefined" && Quickshell.screens) {
                    for (let i = 0; i < Quickshell.screens.length; i++) {
                        if (Quickshell.screens[i].name === monName) {
                            return Quickshell.screens[i];
                        }
                    }
                }
            }
        } catch (e) {}
        return null;
    }

    function getScreen(scr) {
        if (scr === undefined || scr === null) return getFocusedScreen();
        if (typeof scr === "object") {
            if (typeof Quickshell !== "undefined" && Quickshell.screens) {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i] === scr || Quickshell.screens[i].name === scr.name) {
                        return Quickshell.screens[i];
                    }
                }
            }
            return scr;
        }
        if (typeof Quickshell !== "undefined" && Quickshell.screens) {
            if (typeof scr === "number") {
                if (scr >= 0 && scr < Quickshell.screens.length) {
                    return Quickshell.screens[scr];
                }
            }
            if (typeof scr === "string") {
                for (let i = 0; i < Quickshell.screens.length; i++) {
                    if (Quickshell.screens[i].name === scr) {
                        return Quickshell.screens[i];
                    }
                }
            }
        }
        return getFocusedScreen() || scr;
    }

    function show(scr) {
        let target = getScreen(scr);
        if (target !== null && target !== undefined) {
            controller.screen = target;
        } else {
            let focused = getFocusedScreen();
            if (focused !== null && focused !== undefined) {
                controller.screen = focused;
            }
        }
        controller.isVisible = true;
    }

    function hide() {
        controller.isVisible = false;
    }

    function toggle(scr) {
        if (Date.now() - controller.lastChangeMs < controller.lockMs) return;
        let target = getScreen(scr);
        let resolved = target !== null && target !== undefined ? target : getFocusedScreen();

        if (controller.isVisible) {
            if (resolved !== undefined && resolved !== null && controller.screen !== resolved) {
                controller.screen = resolved;
            } else {
                hide();
            }
        } else {
            show(resolved);
        }
    }
}
