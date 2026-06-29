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
        property bool syncWhileActive: true
        property bool syncOnStartup: true
        property int syncIntervalMinutes: 15
    }

    NextCommon.SettingsCard {
        ColumnLayout {
            Layout.fillWidth: true
            spacing: units.gu(1)

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Sync")
                font.bold: true
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: units.gu(1)

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Sync while app is active")
                    wrapMode: Text.WordWrap
                }

                Switch {
                    checked: appSettings.syncWhileActive
                    onCheckedChanged: appSettings.syncWhileActive = checked
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: units.gu(1)

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Sync on startup")
                    wrapMode: Text.WordWrap
                }

                Switch {
                    checked: appSettings.syncOnStartup
                    onCheckedChanged: appSettings.syncOnStartup = checked
                }
            }

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Active sync interval")
                opacity: appSettings.syncWhileActive ? 0.72 : 0.42
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: units.gu(1)
                enabled: appSettings.syncWhileActive
                opacity: appSettings.syncWhileActive ? 1.0 : 0.42

                Repeater {
                    model: [5, 15, 30]

                    Button {
                        Layout.fillWidth: true
                        text: modelData + "m"
                        color: appSettings.syncIntervalMinutes === modelData ? "#2c7fb8" : theme.palette.normal.background
                        onClicked: appSettings.syncIntervalMinutes = modelData
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Ubuntu Touch does not provide Android-style background services for this app. Sync runs while NextDeck is open or activated.")
                wrapMode: Text.WordWrap
                opacity: 0.68
            }
        }
    }

    NextCommon.SettingsCard {
        ColumnLayout {
            Layout.fillWidth: true
            spacing: units.gu(1)

            Label {
                Layout.fillWidth: true
                text: i18n.tr("Cards")
                font.bold: true
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: units.gu(1)

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Open card links in browser directly")
                    wrapMode: Text.WordWrap
                }

                Switch {
                    checked: appController && appController.openCardLinksDirectly
                    onCheckedChanged: if (appController) appController.setOpenCardLinksDirectly(checked)
                }
            }
        }
    }
}
