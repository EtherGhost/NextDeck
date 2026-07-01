import QtQuick 2.7
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import Lomiri.Components 1.3

Page {
    id: page

    property string appName: ""
    property var languageOptions: []
    property string translationNotice: i18n.tr("Some translations are AI-assisted and not fully reviewed. You can help improve translations in the project repository.")

    header: PageHeader {
        title: i18n.tr("Language")
    }

    Settings {
        id: appSettings
        property string languageCode: ""
    }

    ColumnLayout {
        anchors {
            fill: parent
            topMargin: page.header.height + units.gu(1)
            leftMargin: units.gu(1.5)
            rightMargin: units.gu(1.5)
            bottomMargin: units.gu(1.5)
        }
        spacing: units.gu(1)

        Label {
            Layout.fillWidth: true
            text: i18n.tr("Choose the language %1 should use. Restart the app after changing language.").arg(page.appName)
            wrapMode: Text.WordWrap
            color: theme.palette.normal.backgroundText
        }

        Label {
            Layout.fillWidth: true
            visible: page.translationNotice.length > 0
            text: page.translationNotice
            wrapMode: Text.WordWrap
            fontSize: "small"
            color: "#7a7a7a"
        }

        Rectangle {
            Layout.fillWidth: true
            visible: languageStatus.text.length > 0
            height: languageStatus.implicitHeight + units.gu(1.2)
            radius: units.gu(0.5)
            color: theme.palette.normal.background
            border.width: 1
            border.color: "#2c7fb8"

            Label {
                id: languageStatus
                anchors {
                    fill: parent
                    margins: units.gu(0.6)
                }
                text: ""
                wrapMode: Text.WordWrap
                color: theme.palette.normal.backgroundText
            }
        }

        ListView {
            id: languageList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: units.gu(0.6)
            model: page.languageOptions

            delegate: Rectangle {
                id: row

                readonly property bool selected: modelData.code === appSettings.languageCode

                width: languageList.width
                height: units.gu(6)
                radius: units.gu(0.5)
                color: selected ? "#2c7fb8" : theme.palette.normal.background
                border.width: selected ? 0 : 1
                border.color: "#7a7a7a"

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: units.gu(1)
                        rightMargin: units.gu(1)
                    }
                    spacing: units.gu(1)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: units.gu(0.1)

                        Label {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: row.selected ? "white" : theme.palette.normal.backgroundText
                            font.bold: row.selected
                            elide: Text.ElideRight
                        }

                        Label {
                            Layout.fillWidth: true
                            text: modelData.detail
                            color: row.selected ? "white" : "#7a7a7a"
                            fontSize: "small"
                            elide: Text.ElideRight
                        }
                    }

                    Label {
                        visible: row.selected
                        text: "\u2713"
                        color: "white"
                        font.pixelSize: units.gu(2.4)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        appSettings.languageCode = modelData.code
                        languageStatus.text = modelData.code.length === 0
                            ? i18n.tr("%1 will follow the system language after restart.").arg(page.appName)
                            : i18n.tr("%1 will use %2 after restart.").arg(page.appName).arg(modelData.label)
                    }
                }
            }
        }
    }
}
