import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables/guide"
import "../../reusables"

WallpaperTabState {
    id: wallpaperTabRoot

    property alias wpDirDropdown: wallpaperDirRow.wpDirDropdown

    onVisibleChanged: {
        if (!visible && wpDirDropdown.isOpen) wpDirDropdown.closePopup();
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: wallpaperCol.implicitHeight + rootObj.s(16)
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
            id: wallpaperCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(6)

            SectionLabel { rootObj: wallpaperTabRoot.rootObj; key: "guide.wallpaper.sections.wallpaper"; fallback: "Wallpaper" }

            WallpaperPreview { tab: wallpaperTabRoot }

            WallpaperDirRow { id: wallpaperDirRow; tab: wallpaperTabRoot }

            SectionLabel { rootObj: wallpaperTabRoot.rootObj; key: "guide.wallpaper.sections.transition"; fallback: "Transition" }

            TransitionModeRow { tab: wallpaperTabRoot }

            TransitionEffectsSection { tab: wallpaperTabRoot }
        }
    }
}
