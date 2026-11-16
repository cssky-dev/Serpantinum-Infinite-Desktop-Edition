import QtQuick
import "../../"
import "../../reusables"
import "../../reusables/guide"

SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󱓞"
        title: I18n.t("guide.general.quickactions.title") || "Quickactions"
        description: I18n.t("guide.general.quickactions.desc") || "Enable floating quickactions overlay"

        Toggle {
            checked: section.tab.quickactions
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                section.tab.quickactions = c;
                section.tab.updateGeneralSettings();
            }
        }
    }

    SettingsRow {
        rootObj: section.tab.rootObj
        icon: "󰖲"
        title: I18n.t("guide.general.standalone.title") || "Standalone Window"
        description: I18n.t("guide.general.standalone.desc") || "Open settings in its own window instead of the overlay panel"

        Toggle {
            checked: section.tab.standaloneWindow
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface1
            handleColor: ThemeBackend.crust
            handleOffColor: ThemeBackend.text
            onToggled: function(c) {
                section.tab.standaloneWindow = c;
                section.tab.updateGeneralSettings();
            }
        }
    }
}
