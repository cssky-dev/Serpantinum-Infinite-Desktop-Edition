import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"
import "../reusables/guide"

GuideTab {
    id: dockTab

    readonly property var defaults: ({
        "enabled": true,
        "position": "bottom",
        "onTop": true,
        "elementSize": 44,
        "floating": false,
        "background": true,
        "exclusive": false,
        "autohide": false,
        "smartAutohide": true,
        "autohideTimeout": 1000,
        "editing": false,
        "apps": [
            { "name": "Kitty", "comment": "Fast, feature-rich, GPU based terminal", "desktop_id": "kitty.desktop", "icon": "kitty" },
            { "name": "Files", "comment": "Access and organize files", "desktop_id": "ski.desktop", "icon": "ski" }
        ],
        "overrideBoundsCorrection": false,
        "enableScrolling": false,
        "visibleElements": 7,
        "hoverScale": 120,
        "cascadeScale": false,
        "focusRunning": true,
        "showRunningIndicators": true,
        "showRunningApps": true,
        "runningScope": "auto"
    })

    readonly property var positions: ["bottom", "top", "left", "right"]
    readonly property var scopes: ["auto", "all", "output", "workspace"]

    property var live: ({})

    readonly property var cfg: {
        let raw = Config.rawSettings ? Config.rawSettings["dock"] : undefined;
        let merged = Object.assign({}, dockTab.defaults);
        if (raw && typeof raw === "object") {
            if (raw.exclusive === undefined && raw.exclusiveMode !== undefined) merged.exclusive = Boolean(raw.exclusiveMode);
            for (let k in raw) {
                if (raw[k] !== undefined && raw[k] !== null) merged[k] = raw[k];
            }
        }
        for (let k in dockTab.live) merged[k] = dockTab.live[k];
        return merged;
    }

    readonly property bool on: dockTab.cfg.enabled !== false
    readonly property var appsList: Array.isArray(dockTab.cfg.apps) ? dockTab.cfg.apps : []
    readonly property string offText: dockTab.tr("guide.dock.unavailable", "Enable the dock first")

    function tr(key, fallback) {
        let v = I18n.t(key);
        return (typeof v !== "string" || v === "" || v === key) ? fallback : v;
    }

    function commit(values) {
        let cur = JSON.parse(JSON.stringify(Config.getSetting("dock", dockTab.defaults) || dockTab.defaults));
        for (let k in dockTab.live) cur[k] = dockTab.live[k];
        for (let k in values) cur[k] = values[k];
        dockTab.live = ({});
        flushTimer.stop();
        Config.setSetting("dock", cur);
    }

    function setLive(key, value) {
        let l = Object.assign({}, dockTab.live);
        l[key] = value;
        dockTab.live = l;
        flushTimer.restart();
    }

    function set(key, value) {
        let v = {};
        v[key] = value;
        dockTab.commit(v);
    }

    function removeApp(idx) {
        let list = dockTab.appsList.slice();
        if (idx < 0 || idx >= list.length) return;
        list.splice(idx, 1);
        dockTab.set("apps", list);
    }

    function iconSource(ic) {
        if (!ic) return "";
        if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
        return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
    }

    Timer {
        id: flushTimer
        interval: 120
        repeat: false
        onTriggered: dockTab.commit({})
    }

    onVisibleChanged: {
        if (!visible) {
            positionRow.close();
            scopeRow.close();
        }
    }

    GuideScroll {
        rootObj: dockTab.rootObj

        GuideSection {
            rootObj: dockTab.rootObj
            title: dockTab.tr("guide.dock.sections.dock", "Dock")

            GuideToggleRow {
                settingId: "dock_enabled"
                rootObj: dockTab.rootObj
                icon: "󰅀"
                title: dockTab.tr("guide.dock.enabled.title", "Enable dock")
                description: dockTab.tr("guide.dock.enabled.desc", "Enable floating application dock")
                checked: dockTab.on
                onToggled: function(v) { dockTab.set("enabled", v); }
            }
        }

        GuideSection {
            rootObj: dockTab.rootObj
            shown: dockTab.on
            title: dockTab.tr("guide.dock.sections.applications", "Applications")

            SettingsRow {
                settingId: "dock_apps"
                rootObj: dockTab.rootObj
                verticalPadding: dockTab.rootObj.s(11)
                icon: "󰀻"
                title: dockTab.tr("guide.dock.apps.title", "Dock Applications")
                description: dockTab.appsList.length + " " + (dockTab.appsList.length === 1
                    ? dockTab.tr("guide.dock.apps.singular", "app")
                    : dockTab.tr("guide.dock.apps.plural", "apps"))
                searchKeywords: "applications shortcuts pins favorites"
                hiddenByConfig: !dockTab.on
                unavailableReason: dockTab.offText

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    maxWidth: dockTab.rootObj.s(160)
                    implicitHeight: dockTab.rootObj.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: dockTab.cfg.editing ? dockTab.tr("guide.dock.apps.exit_edit", "Exit edit mode") : dockTab.tr("guide.dock.apps.enter_edit", "Edit")
                    buttonIcon: dockTab.cfg.editing ? "󰅖" : "󰏫"
                    iconFontSize: dockTab.rootObj.s(14)
                    accentColor: dockTab.cfg.editing ? ThemeBackend.red : ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    onClicked: {
                        let next = !dockTab.cfg.editing;
                        dockTab.set("editing", next);
                        Sounds.playSfx(next ? "guide/barconfig/out.wav" : "guide/barconfig/in.wav");
                        dockTab.rootObj.dismissHost();
                    }
                }

                bottomContent: [
                    GridLayout {
                        id: appsGrid
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: dockTab.rootObj.s(8)
                        columnSpacing: dockTab.rootObj.s(8)
                        visible: dockTab.appsList.length > 0

                        readonly property real colWidth: Math.max(0, (width - columnSpacing * 2) / 3)

                        Repeater {
                            model: dockTab.appsList

                            delegate: Rectangle {
                                id: appCard
                                required property var modelData
                                required property int index

                                Layout.preferredWidth: appsGrid.colWidth
                                Layout.maximumWidth: appsGrid.colWidth
                                Layout.preferredHeight: dockTab.rootObj.s(48)
                                radius: ThemeBackend.borderRadius
                                color: Qt.alpha(ThemeBackend.surface1, 0.3)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: dockTab.rootObj.s(8)
                                    anchors.rightMargin: dockTab.rootObj.s(8)
                                    spacing: dockTab.rootObj.s(8)

                                    Rectangle {
                                        Layout.alignment: Qt.AlignVCenter
                                        Layout.preferredWidth: dockTab.rootObj.s(32)
                                        Layout.preferredHeight: dockTab.rootObj.s(32)
                                        radius: Math.round(dockTab.rootObj.s(32) * 0.28)
                                        color: ThemeBackend.surface0
                                        clip: true

                                        Image {
                                            id: appIcon
                                            anchors.fill: parent
                                            anchors.margins: dockTab.rootObj.s(4)
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            smooth: true
                                            mipmap: true
                                            source: dockTab.iconSource(appCard.modelData.icon || "")
                                            visible: source !== "" && status === Image.Ready
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !appIcon.visible
                                            text: appCard.modelData.name ? appCard.modelData.name.charAt(0).toUpperCase() : "?"
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: dockTab.rootObj.s(13)
                                            font.bold: true
                                            color: ThemeBackend.text
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: dockTab.rootObj.s(1)

                                        Text {
                                            Layout.fillWidth: true
                                            text: appCard.modelData.name || appCard.modelData.desktop_id || "App"
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: dockTab.rootObj.s(12)
                                            font.bold: true
                                            color: ThemeBackend.text
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: appCard.modelData.comment || appCard.modelData.desktop_id || ""
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: dockTab.rootObj.s(10)
                                            color: ThemeBackend.subtext0
                                            elide: Text.ElideRight
                                        }
                                    }

                                    DeleteButton {
                                        Layout.alignment: Qt.AlignVCenter
                                        size: dockTab.rootObj.s(28)
                                        cornerRadius: Math.min(ThemeBackend.borderRadius, dockTab.rootObj.s(8))
                                        iconFontSize: dockTab.rootObj.s(14)
                                        onClicked: dockTab.removeApp(appCard.index)
                                    }
                                }
                            }
                        }
                    },
                    Text {
                        Layout.fillWidth: true
                        visible: dockTab.appsList.length === 0
                        text: dockTab.tr("guide.dock.apps.empty", "No applications configured for the dock")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: dockTab.rootObj.s(12)
                        color: ThemeBackend.subtext0
                    }
                ]
            }
        }

        GuideSection {
            rootObj: dockTab.rootObj
            shown: dockTab.on
            title: dockTab.tr("guide.dock.sections.position", "Position")

            GuideDropdownRow {
                id: positionRow
                settingId: "dock_position"
                rootObj: dockTab.rootObj
                icon: "󰍹"
                title: dockTab.tr("guide.dock.position.title", "Dock position")
                description: dockTab.tr("guide.dock.position.desc", "Select the screen edge to anchor the dock")
                available: dockTab.on
                unavailableText: dockTab.offText
                options: [
                    dockTab.tr("guide.dock.position.bottom", "Bottom"),
                    dockTab.tr("guide.dock.position.top", "Top"),
                    dockTab.tr("guide.dock.position.left", "Left"),
                    dockTab.tr("guide.dock.position.right", "Right")
                ]
                currentIndex: Math.max(0, dockTab.positions.indexOf(dockTab.cfg.position))
                onPicked: function(i) { dockTab.set("position", dockTab.positions[i]); }
            }

            GuideToggleRow {
                settingId: "dock_on_top"
                rootObj: dockTab.rootObj
                icon: "󰹤"
                title: dockTab.tr("guide.dock.on_top.title", "Place dock on top of windows")
                description: dockTab.tr("guide.dock.on_top.desc", "Keep the dock visible above application windows")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.onTop)
                onToggled: function(v) { dockTab.set("onTop", v); }
            }

            GuideToggleRow {
                settingId: "dock_floating"
                rootObj: dockTab.rootObj
                icon: "󰉈"
                title: dockTab.tr("guide.dock.floating.title", "Floating dock")
                description: dockTab.tr("guide.dock.floating.desc", "Detach dock from screen edge with rounded corners")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.floating)
                onToggled: function(v) { dockTab.set("floating", v); }
            }

            GuideToggleRow {
                settingId: "dock_background"
                rootObj: dockTab.rootObj
                icon: "󰂵"
                title: dockTab.tr("guide.dock.background.title", "Draw a background behind apps")
                description: dockTab.tr("guide.dock.background.desc", "Show the dock panel behind app icons")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.background)
                onToggled: function(v) { dockTab.set("background", v); }
            }

            GuideToggleRow {
                settingId: "dock_exclusive"
                rootObj: dockTab.rootObj
                icon: "󰖲"
                title: dockTab.tr("guide.dock.exclusive.title", "Exclusive mode")
                description: dockTab.tr("guide.dock.exclusive.desc", "Prevent windows from taking space occupied by the dock")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.exclusive)
                onToggled: function(v) { dockTab.set("exclusive", v); }
            }
        }

        GuideSection {
            rootObj: dockTab.rootObj
            shown: dockTab.on
            title: dockTab.tr("guide.dock.sections.size", "Size")

            GuideSliderRow {
                settingId: "dock_element_size"
                rootObj: dockTab.rootObj
                icon: "󰘖"
                title: dockTab.tr("guide.dock.size.title", "Element size")
                description: dockTab.tr("guide.dock.size.desc", "Dimensions of individual app buttons in pixels")
                available: dockTab.on
                unavailableText: dockTab.offText
                from: 32
                to: 72
                step: 2
                fallback: 44
                value: Number(dockTab.cfg.elementSize)
                format: function(v) { return Math.round(v) + " px"; }
                onPicked: function(v) { dockTab.setLive("elementSize", v); }
            }

            GuideToggleRow {
                settingId: "dock_override_bounds"
                rootObj: dockTab.rootObj
                icon: "󰜤"
                title: dockTab.tr("guide.dock.override_bounds.title", "Override out-of-screen-bounds size correction")
                description: dockTab.tr("guide.dock.override_bounds.desc", "Keep custom element size even if dock exceeds screen limits")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.overrideBoundsCorrection)
                onToggled: function(v) { dockTab.set("overrideBoundsCorrection", v); }
            }

            GuideToggleRow {
                settingId: "dock_scrolling"
                rootObj: dockTab.rootObj
                icon: "󰍽"
                title: dockTab.tr("guide.dock.scrolling.title", "Enable element scrolling")
                description: dockTab.tr("guide.dock.scrolling.desc", "Limit visible elements and allow mouse wheel or touchpad scrolling")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.enableScrolling)
                onToggled: function(v) { dockTab.set("enableScrolling", v); }
            }

            GuideNumberRow {
                settingId: "dock_visible_elements"
                rootObj: dockTab.rootObj
                icon: "󰅫"
                title: dockTab.tr("guide.dock.visible_elements.title", "Visible elements")
                description: dockTab.tr("guide.dock.visible_elements.desc", "Number of dock items visible at the same time")
                available: dockTab.on && Boolean(dockTab.cfg.enableScrolling)
                unavailableText: !dockTab.on ? dockTab.offText : dockTab.tr("guide.dock.scrolling.required", "Turn on element scrolling first")
                from: 1
                to: 20
                step: 1
                value: Number(dockTab.cfg.visibleElements)
                onPicked: function(v) { if (v > 0) dockTab.set("visibleElements", v); }
            }
        }

        GuideSection {
            rootObj: dockTab.rootObj
            shown: dockTab.on
            title: dockTab.tr("guide.dock.sections.effects", "Effects")

            GuideSliderRow {
                settingId: "dock_hover_scale"
                rootObj: dockTab.rootObj
                icon: "󰍔"
                title: dockTab.tr("guide.dock.hover_scale.title", "Hover scale effect")
                description: dockTab.tr("guide.dock.hover_scale.desc", "Magnification level when hovering over dock items")
                available: dockTab.on
                unavailableText: dockTab.offText
                from: 100
                to: 160
                step: 2
                fallback: 120
                value: Number(dockTab.cfg.hoverScale)
                format: function(v) { return Math.round(v) + "%"; }
                onPicked: function(v) { dockTab.setLive("hoverScale", v); }
            }

            GuideToggleRow {
                settingId: "dock_cascade_scale"
                rootObj: dockTab.rootObj
                icon: "󰘚"
                title: dockTab.tr("guide.dock.cascade_scale.title", "Scale nearest elements")
                description: dockTab.tr("guide.dock.cascade_scale.desc", "Cascading magnification on neighboring icons")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.cascadeScale)
                onToggled: function(v) { dockTab.set("cascadeScale", v); }
            }
        }

        GuideSection {
            rootObj: dockTab.rootObj
            shown: dockTab.on
            title: dockTab.tr("guide.dock.sections.autohide", "Auto-hide")

            GuideToggleRow {
                settingId: "dock_autohide"
                rootObj: dockTab.rootObj
                icon: "󰘓"
                title: dockTab.tr("guide.dock.autohide.title", "Auto-hide")
                description: dockTab.tr("guide.dock.autohide.desc", "Hide the dock when not hovering over the screen edge")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.autohide)
                onToggled: function(v) { dockTab.set("autohide", v); }
            }

            GuideToggleRow {
                settingId: "dock_smart_autohide"
                rootObj: dockTab.rootObj
                icon: "󱂬"
                title: dockTab.tr("guide.dock.smart_autohide.title", "Smart auto-hide")
                description: dockTab.tr("guide.dock.smart_autohide.desc", "Auto-hide dock only when windows are open, keep visible on desktop")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.smartAutohide)
                onToggled: function(v) { dockTab.set("smartAutohide", v); }
            }

            GuideSliderRow {
                settingId: "dock_autohide_delay"
                rootObj: dockTab.rootObj
                icon: "󰔛"
                title: dockTab.tr("guide.dock.timeout.title", "Auto-hide delay")
                description: dockTab.tr("guide.dock.timeout.desc", "Duration before hiding after pointer leaves")
                available: dockTab.on && (Boolean(dockTab.cfg.autohide) || Boolean(dockTab.cfg.smartAutohide))
                unavailableText: !dockTab.on ? dockTab.offText : dockTab.tr("guide.dock.timeout.required", "Turn on auto-hide first")
                from: 250
                to: 5000
                step: 50
                fallback: 1000
                value: Number(dockTab.cfg.autohideTimeout)
                format: function(v) { return Math.round(v) + " ms"; }
                onPicked: function(v) { dockTab.setLive("autohideTimeout", v); }
            }
        }

        GuideSection {
            rootObj: dockTab.rootObj
            shown: dockTab.on
            title: dockTab.tr("guide.dock.sections.behavior", "Behavior")

            GuideToggleRow {
                settingId: "dock_focus_running"
                rootObj: dockTab.rootObj
                icon: "󱂬"
                title: dockTab.tr("guide.dock.focus_running.title", "Focus existing window")
                description: dockTab.tr("guide.dock.focus_running.desc", "Clicking an app icon activates its open window instead of launching a new instance")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.focusRunning)
                onToggled: function(v) { dockTab.set("focusRunning", v); }
            }

            GuideToggleRow {
                settingId: "dock_show_running_indicators"
                rootObj: dockTab.rootObj
                icon: "󰄯"
                title: dockTab.tr("guide.dock.show_running_indicators.title", "Running indicators")
                description: dockTab.tr("guide.dock.show_running_indicators.desc", "Show dot or pill indicators on open application icons")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.showRunningIndicators)
                onToggled: function(v) { dockTab.set("showRunningIndicators", v); }
            }

            GuideToggleRow {
                settingId: "dock_show_running_apps"
                rootObj: dockTab.rootObj
                icon: "󰘓"
                title: dockTab.tr("guide.dock.show_running_apps.title", "Show open applications")
                description: dockTab.tr("guide.dock.show_running_apps.desc", "Display unpinned open applications in the dock")
                available: dockTab.on
                unavailableText: dockTab.offText
                checked: Boolean(dockTab.cfg.showRunningApps)
                onToggled: function(v) { dockTab.set("showRunningApps", v); }
            }

            GuideDropdownRow {
                id: scopeRow
                settingId: "dock_running_scope"
                rootObj: dockTab.rootObj
                icon: "󰍹"
                title: dockTab.tr("guide.dock.running_scope.title", "Active window scope")
                description: dockTab.tr("guide.dock.running_scope.desc", "Filter running windows displayed and controlled by the dock")
                available: dockTab.on
                unavailableText: dockTab.offText
                controlWidth: 220
                options: [
                    dockTab.tr("guide.dock.running_scope.auto", "Automatic (compositor default)"),
                    dockTab.tr("guide.dock.running_scope.all", "All workspaces & monitors"),
                    dockTab.tr("guide.dock.running_scope.output", "Current monitor only"),
                    dockTab.tr("guide.dock.running_scope.workspace", "Active workspace only")
                ]
                currentIndex: Math.max(0, dockTab.scopes.indexOf(dockTab.cfg.runningScope))
                onPicked: function(i) { dockTab.set("runningScope", dockTab.scopes[i]); }
            }
        }
    }
}
