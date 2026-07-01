import QtQuick 2.7
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Lomiri.Components 1.3
import "qrc:/NextCommon" as NextCommon

NextCommon.SettingsShell {
    id: page

    property var appController

    title: i18n.tr("Settings")

    Settings {
        id: appSettings
        category: "app"
        property bool syncOnStartup: true
        property bool swipeActionsEnabled: true
        property bool swipeActionsReversed: false
        property bool pullToRefreshEnabled: true
        property bool dragForMoveEnabled: true
        property bool multiSelectEnabled: true
    }

    Component.onCompleted: {
        if (appController) {
            appController.syncOnStartup = appSettings.syncOnStartup
            appController.swipeActionsEnabled = appSettings.swipeActionsEnabled
            appController.swipeActionsReversed = appSettings.swipeActionsReversed
            appController.pullToRefreshEnabled = appSettings.pullToRefreshEnabled
            appController.dragForMoveEnabled = appSettings.dragForMoveEnabled
            appController.multiSelectEnabled = appSettings.multiSelectEnabled
        }
    }

    function switchTrackColor(checked) {
        return checked ? "#2c7fb8" : Qt.rgba(0.5, 0.5, 0.5, 0.22)
    }

    function setSyncOnStartup(value) {
        appSettings.syncOnStartup = value
        if (appController) {
            appController.setSyncOnStartup(value)
        }
    }

    function setListControlSetting(key, value) {
        appSettings[key] = value
        if (appController) {
            appController.setListControlSetting(key, value)
        }
    }

    function listControlRows() {
        return [
            {"key": "swipeActionsEnabled", "label": i18n.tr("Swipe actions")},
            {"key": "swipeActionsReversed", "label": i18n.tr("Reverse left/right actions")},
            {"key": "pullToRefreshEnabled", "label": i18n.tr("Pull to refresh")},
            {"key": "dragForMoveEnabled", "label": i18n.tr("Drag to move")},
            {"key": "multiSelectEnabled", "label": i18n.tr("Bulk selection")}
        ]
    }

    NextCommon.SettingsCard {
        Label {
            Layout.fillWidth: true
            text: i18n.tr("Sync")
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: units.gu(1)

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Sync on startup")
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: units.gu(6.2)
                Layout.preferredHeight: units.gu(3.2)
                radius: height / 2
                color: page.switchTrackColor(appSettings.syncOnStartup)
                border.width: 0

                Rectangle {
                    width: units.gu(2.6)
                    height: units.gu(2.6)
                    radius: width / 2
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: appSettings.syncOnStartup ? parent.width - width - units.gu(0.3) : units.gu(0.3)
                    Behavior on x { NumberAnimation { duration: 110 } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.setSyncOnStartup(!appSettings.syncOnStartup)
                }
            }
        }
    }

    NextCommon.SettingsCard {
        Label {
            Layout.fillWidth: true
            text: i18n.tr("List interaction")
            font.bold: true
        }

        Label {
            Layout.fillWidth: true
            text: i18n.tr("Configure card list gestures.")
            wrapMode: Text.WordWrap
            opacity: 0.72
        }

        Repeater {
            model: page.listControlRows()

            RowLayout {
                Layout.fillWidth: true
                spacing: units.gu(1)

                Label {
                    Layout.fillWidth: true
                    text: modelData.label
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.preferredWidth: units.gu(6.2)
                    Layout.preferredHeight: units.gu(3.2)
                    radius: height / 2
                    color: page.switchTrackColor(appSettings[modelData.key] === true)
                    border.width: 0

                    Rectangle {
                        width: units.gu(2.6)
                        height: units.gu(2.6)
                        radius: width / 2
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        x: appSettings[modelData.key] === true ? parent.width - width - units.gu(0.3) : units.gu(0.3)
                        Behavior on x { NumberAnimation { duration: 110 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.setListControlSetting(modelData.key, !(appSettings[modelData.key] === true))
                    }
                }
            }
        }
    }

    NextCommon.SettingsCard {
        Label {
            Layout.fillWidth: true
            text: i18n.tr("Cards")
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: units.gu(1)

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Open card links in browser directly")
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: units.gu(6.2)
                Layout.preferredHeight: units.gu(3.2)
                radius: height / 2
                color: page.switchTrackColor(appController && appController.openCardLinksDirectly)
                border.width: 0

                Rectangle {
                    width: units.gu(2.6)
                    height: units.gu(2.6)
                    radius: width / 2
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: appController && appController.openCardLinksDirectly ? parent.width - width - units.gu(0.3) : units.gu(0.3)
                    Behavior on x { NumberAnimation { duration: 110 } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: if (appController) appController.setOpenCardLinksDirectly(!appController.openCardLinksDirectly)
                }
            }
        }
    }
}
