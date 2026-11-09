import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

Rectangle {
    id: strip

    required property var tab
    visible: strip.on || !CanvasEngine.isHyprland
    function s(v) { return strip.tab.rootObj ? strip.tab.rootObj.s(v) : v; }

    readonly property bool available: CanvasEngine.isHyprland && CanvasEngine.masterEnabled
    readonly property bool on: strip.available && CanvasEngine.curActive
    readonly property int windows: {
        let r = CanvasEngine.rev;
        let w = CanvasEngine.curWorld;
        return (w && w.wins) ? Object.keys(w.wins).length : 0;
    }
    readonly property string headline: !CanvasEngine.isHyprland
        ? strip.tab.tr("guide.desktop.status.unsupported", "Hyprland only")
        : (!CanvasEngine.masterEnabled
            ? strip.tab.tr("guide.desktop.status.off", "Infinite desktop is off")
            : (strip.on ? strip.tab.tr("guide.desktop.status.canvas", "Infinite desktop") : strip.tab.tr("guide.desktop.status.tiled", "Tiled")))
    readonly property string detail: {
        if (!strip.available || CanvasEngine.curWs <= 0) return "";
        let parts = [strip.tab.tr("guide.desktop.status.workspace", "Workspace") + " " + CanvasEngine.curWs];
        if (strip.on) {
            parts.push(strip.windows + " " + (strip.windows === 1 ? strip.tab.tr("guide.desktop.status.window", "window") : strip.tab.tr("guide.desktop.status.windows", "windows")));
            parts.push(Math.round(CanvasEngine.zoom * 100) + "%");
        }
        return parts.join("  ·  ");
    }

    Layout.fillWidth: true
    implicitHeight: strip.s(54)
    radius: ThemeBackend.borderRadius
    color: stripGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.4)
    clip: true

    GlassFill {
        id: stripGlass
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        tintColor: ThemeBackend.surface0
        tintAmount: 0.26
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: strip.s(14)
        anchors.rightMargin: strip.s(10)
        spacing: strip.s(12)

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: strip.s(8)
            Layout.preferredHeight: strip.s(8)
            radius: width / 2
            color: strip.on ? ThemeBackend.green : ThemeBackend.surface2
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: strip.s(1)

            Text {
                Layout.fillWidth: true
                text: strip.headline
                font.family: ThemeBackend.fontFamily
                font.pixelSize: strip.s(13)
                color: ThemeBackend.text
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: strip.detail
                font.family: ThemeBackend.fontFamily
                font.pixelSize: strip.s(11)
                color: ThemeBackend.subtext0
                elide: Text.ElideRight
            }
        }

        ClickButton {
            visible: strip.on
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: strip.s(28)
            horizontalPadding: strip.s(10)
            cornerRadius: ThemeBackend.borderRadius
            textFontSize: strip.s(11)
            buttonText: strip.tab.tr("guide.desktop.actions.overview", "Overview")
            accentColor: Qt.alpha(ThemeBackend.surface1, 0.6)
            onClicked: CanvasEngine.toggleFit()
        }
        ClickButton {
            visible: strip.on
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: strip.s(28)
            horizontalPadding: strip.s(10)
            cornerRadius: ThemeBackend.borderRadius
            textFontSize: strip.s(11)
            buttonText: strip.tab.tr("guide.desktop.actions.home", "Home")
            accentColor: Qt.alpha(ThemeBackend.surface1, 0.6)
            onClicked: CanvasEngine.home()
        }
        ClickButton {
            visible: strip.on
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: strip.s(28)
            horizontalPadding: strip.s(10)
            cornerRadius: ThemeBackend.borderRadius
            textFontSize: strip.s(11)
            buttonText: strip.tab.tr("guide.desktop.actions.tidy", "Tidy")
            accentColor: Qt.alpha(ThemeBackend.surface1, 0.6)
            onClicked: CanvasEngine.tidy()
        }
    }
}
