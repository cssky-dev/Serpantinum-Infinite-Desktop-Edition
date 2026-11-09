import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"
import "../../reusables/guide"

DisplayWidgetsState {
    id: displayWidgetsRoot
    subTabIndex: 1

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: widgetsCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: widgetsCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(6)

            SectionLabel { rootObj: displayWidgetsRoot.rootObj; key: "guide.display.sections.redactor"; fallback: "Redactor" }

            SettingsRow {
                rootObj: displayWidgetsRoot.rootObj
                settingId: "widgets_hide_bar"
                icon: "󰘓"
                title: I18n.t("guide.display.widgets.hide_bar.title", "Hide the bar in the redactor")
                description: I18n.t("guide.display.widgets.hide_bar.desc", "Automatically hide the bar when editing widgets in redactor mode")
                searchKeywords: "widgets redactor hide bar panel"

                Toggle {
                    id: hideBarToggle
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: displayWidgetsRoot.currentHideBarInRedactor
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(val) {
                        displayWidgetsRoot.currentHideBarInRedactor = val;
                        displayWidgetsRoot.updateWidgetsSetting("hideBarInRedactor", val);
                    }
                }
            }

            SettingsRow {
                rootObj: displayWidgetsRoot.rootObj
                settingId: "widgets_show_distances"
                icon: "󰑭"
                title: I18n.t("guide.display.widgets.show_distances.title", "Show distances")
                description: I18n.t("guide.display.widgets.show_distances.desc", "Show the distances between widgets while moving or resizing them in the redactor")
                searchKeywords: "widgets redactor distances spacing gaps measurements"

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: displayWidgetsRoot.currentShowDistances
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(val) {
                        displayWidgetsRoot.currentShowDistances = val;
                        displayWidgetsRoot.updateWidgetsSetting("showDistances", val);
                    }
                }
            }

            SectionLabel { rootObj: displayWidgetsRoot.rootObj; key: "guide.display.sections.mode"; fallback: "Mode" }

            // Plain text only: which mode is active and how to switch it
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: rootObj.s(6)
                Layout.rightMargin: rootObj.s(6)
                text: displayWidgetsRoot.tr("guide.display.widgets.mode_title", "Current mode") + ": " + displayWidgetsRoot.modeLabelText + "  -  " + displayWidgetsRoot.tr("guide.display.widgets.mode_hint", "Widgets are saved separately for Tiled and Infinite desktop mode. Press Super+G to switch between the two modes.")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(11)
                color: ThemeBackend.subtext0
                wrapMode: Text.WordWrap
            }

            SettingsRow {
                rootObj: displayWidgetsRoot.rootObj
                settingId: "widgets_delete_all"
                title: displayWidgetsRoot.tr("guide.display.widgets.delete_all.title", "Delete all widgets")
                description: displayWidgetsRoot.tr("guide.display.widgets.delete_all.desc", "Removes every widget from both Tiled and Infinite desktop on every workspace and screen")
                searchKeywords: "widgets delete remove clear all reset tiled infinite desktop"

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    maxWidth: rootObj.s(200)
                    implicitHeight: rootObj.s(32)
                    horizontalPadding: rootObj.s(14)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: displayWidgetsRoot.tr("guide.display.widgets.delete_all.button", "Delete all")
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: displayWidgetsRoot.removeAllWidgets()
                }
            }

            SectionLabel { rootObj: displayWidgetsRoot.rootObj; key: "guide.display.sections.screens"; fallback: "Screens" }

            Repeater {
                model: displayWidgetsRoot.monitorsList
                delegate: WidgetMonitorCard { tab: displayWidgetsRoot }
            }
        }
    }
}
