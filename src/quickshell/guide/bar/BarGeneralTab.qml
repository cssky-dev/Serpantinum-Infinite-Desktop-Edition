import QtQuick
import QtQuick.Layouts
import "general"
import "../../reusables/guide"
import "../../reusables"

BarGeneralState {
    id: barTabRoot

    onVisibleChanged: {
        if (visible) {
            syncSettings();
            loadModuleModels();
        } else {
            clearPendingGroup();
            if (placementSection.barPosDropdown.isOpen) placementSection.barPosDropdown.closePopup();
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        onMovementStarted: {
            barTabRoot.clearPendingGroup();
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                barTabRoot.clearPendingGroup();
            }
        }

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            SectionLabel { rootObj: barTabRoot.rootObj; key: "guide.bar.sections.placement"; fallback: "Placement" }

            BarPlacementSection { id: placementSection; tab: barTabRoot }

            SectionLabel { rootObj: barTabRoot.rootObj; key: "guide.bar.sections.style"; fallback: "Style" }

            BarStyleSection { tab: barTabRoot }

            SectionLabel { rootObj: barTabRoot.rootObj; key: "guide.bar.sections.behavior"; fallback: "Behavior" }

            BarAutohideSection { tab: barTabRoot }

            SectionLabel { rootObj: barTabRoot.rootObj; key: "guide.bar.sections.layout"; fallback: "Layout" }

            BarLayoutEditor { tab: barTabRoot }
        }
    }
}
