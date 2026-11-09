import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../../"
import "../../reusables"
import "../../reusables/guide"

GuideTab {
    id: desktopTabRoot

    function tr(key, fallback) {
        let v = I18n.t(key);
        return (typeof v !== "string" || v === "" || v === key) ? fallback : v;
    }

    function setCanvasMany(values) {
        let c = Object.assign({}, Config.getSetting("canvas", ({})));
        for (let k in values) c[k] = values[k];
        Config.setSetting("canvas", c);
    }

    function setCanvas(key, value) {
        let v = {};
        v[key] = value;
        desktopTabRoot.setCanvasMany(v);
    }

    readonly property bool hypr: CanvasEngine.isHyprland
    readonly property bool desktopOn: CanvasEngine.isHyprland && CanvasEngine.masterEnabled

    Flickable {
        id: desktopFlick
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentWidth: width
        contentHeight: desktopCol.implicitHeight + rootObj.s(16)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: desktopFlick.moving || desktopFlick.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: desktopCol
            width: desktopFlick.width - rootObj.s(6)
            spacing: rootObj.s(6)

            DesktopSection {
                tab: desktopTabRoot
                title: desktopTabRoot.tr("guide.desktop.sections.canvas", "Canvas")

                CanvasToggleRow {
                    tab: desktopTabRoot
                    key: "enabled"
                    value: CanvasEngine.masterEnabled
                    needsDesktop: false
                    icon: "󰛤"
                    title: desktopTabRoot.tr("guide.desktop.infinitedesktop.title", "Infinite desktop")
                    description: desktopTabRoot.tr("guide.desktop.infinitedesktop.desc", "An endless canvas for your windows. Super+G toggles it, scroll zooms, Super+Tab shows everything")
                }

                CanvasToggleRow {
                    tab: desktopTabRoot
                    key: "allWorkspaces"
                    value: CanvasEngine.allWorkspaces
                    icon: "󰍹"
                    title: desktopTabRoot.tr("guide.desktop.canvasall.title", "Every workspace")
                    description: desktopTabRoot.tr("guide.desktop.canvasall.desc", "Use the infinite desktop on all workspaces instead of tiles")
                }
            }

            DesktopSection {
                tab: desktopTabRoot
                shown: desktopTabRoot.desktopOn
                title: desktopTabRoot.tr("guide.desktop.sections.behavior", "Behavior")

                CanvasToggleRow {
                    tab: desktopTabRoot
                    key: "followFocus"
                    value: CanvasEngine.followFocus
                    icon: "󰈈"
                    title: desktopTabRoot.tr("guide.desktop.canvasfollow.title", "Follow focus")
                    description: desktopTabRoot.tr("guide.desktop.canvasfollow.desc", "Slide to a window when it takes focus from off screen")
                }

                CanvasToggleRow {
                    tab: desktopTabRoot
                    key: "centerOnOpen"
                    value: CanvasEngine.centerOnOpen
                    icon: "󰑔"
                    title: desktopTabRoot.tr("guide.desktop.canvascenter.title", "Center new apps")
                    description: desktopTabRoot.tr("guide.desktop.canvascenter.desc", "Slide the desktop so a new app opens in the middle")
                }

                CanvasToggleRow {
                    tab: desktopTabRoot
                    key: "snap"
                    value: CanvasEngine.snapSetting
                    icon: "󰕰"
                    title: desktopTabRoot.tr("guide.desktop.snap.title", "Snap to neighbours")
                    description: desktopTabRoot.tr("guide.desktop.snap.desc", "A window you let go of near another one lines up with it")
                }

                CanvasToggleRow {
                    tab: desktopTabRoot
                    key: "hoverFocus"
                    value: CanvasEngine.hoverFocus
                    icon: "󰳽"
                    title: desktopTabRoot.tr("guide.desktop.canvashover.title", "Focus follows the mouse")
                    description: desktopTabRoot.tr("guide.desktop.canvashover.desc", "Hovering a window focuses it")
                }

                CanvasToggleRow {
                    tab: desktopTabRoot
                    key: "hideQuickactions"
                    value: CanvasEngine.hideQuickactionsSetting
                    icon: "󱓞"
                    title: desktopTabRoot.tr("guide.desktop.canvasquickactions.title", "Hide quick actions")
                    description: desktopTabRoot.tr("guide.desktop.canvasquickactions.desc", "Hide the floating quick actions on the infinite desktop")
                }
            }

            DesktopSection {
                tab: desktopTabRoot
                shown: desktopTabRoot.desktopOn
                title: desktopTabRoot.tr("guide.desktop.sections.widgets", "Widgets")

                CanvasToggleRow {
                    tab: desktopTabRoot
                    key: "widgets"
                    value: CanvasEngine.widgetsOnCanvas
                    icon: "󰖲"
                    title: desktopTabRoot.tr("guide.desktop.canvaswidgets.title", "Widgets on the canvas")
                    description: desktopTabRoot.tr("guide.desktop.canvaswidgets.desc", "Widgets sit behind apps and move with the canvas")
                }
            }

            DesktopSection {
                tab: desktopTabRoot
                shown: desktopTabRoot.desktopOn
                title: desktopTabRoot.tr("guide.desktop.sections.motion", "Motion")

                CanvasSliderRow {
                    tab: desktopTabRoot
                    icon: "󰀻"
                    title: desktopTabRoot.tr("guide.desktop.appsspeed.title", "Apps speed")
                    description: desktopTabRoot.tr("guide.desktop.appsspeed.desc", "How fast app windows move. 100% keeps your Hyprland animation")
                        + "  ·  " + Math.round(CanvasEngine.appsLagMs) + " ms"
                    from: 25
                    to: 300
                    step: 5
                    fallback: 100
                    value: CanvasEngine.appsSpeedPct
                    format: function(v) { return Math.round(v) + "%  ·  " + Math.round(CanvasEngine._lagBase / (v / 100)) + " ms"; }
                    onPicked: function(v) { desktopTabRoot.setCanvas("appsSpeed", v); }
                }

                CanvasSliderRow {
                    tab: desktopTabRoot
                    icon: "󰝤"
                    title: desktopTabRoot.tr("guide.desktop.spacing.title", "Window spacing")
                    description: desktopTabRoot.tr("guide.desktop.spacing.desc", "Gap kept between windows when they are placed or tidied")
                    from: 8
                    to: 120
                    step: 4
                    fallback: 36
                    value: CanvasEngine.gap
                    format: function(v) { return Math.round(v) + " px"; }
                    onPicked: function(v) { desktopTabRoot.setCanvas("spacing", v); }
                }
            }

            Item { Layout.preferredHeight: rootObj.s(4) }
        }
    }
}
