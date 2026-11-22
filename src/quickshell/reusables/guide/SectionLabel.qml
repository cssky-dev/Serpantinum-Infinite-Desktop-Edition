import QtQuick
import QtQuick.Layouts
import "../../"

// Small uppercase caption above a group of settings. Same look as the
// section captions in the Desktop tab, so every guide tab reads the same.
Text {
    id: label

    required property var rootObj
    property string key: ""
    property string fallback: ""

    readonly property string resolved: {
        if (label.key === "") return label.fallback;
        let v = I18n.t(label.key);
        return (typeof v !== "string" || v === "" || v === label.key) ? label.fallback : v;
    }

    Layout.fillWidth: true
    Layout.leftMargin: label.rootObj.s(6)
    Layout.topMargin: label.rootObj.s(8)
    visible: label.resolved !== ""
    text: label.resolved.toUpperCase()
    font.family: ThemeBackend.fontFamily
    font.pixelSize: label.rootObj.s(10)
    font.letterSpacing: 1.4
    color: ThemeBackend.subtext0
    opacity: 0.75
    elide: Text.ElideRight
}
