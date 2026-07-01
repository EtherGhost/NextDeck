import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

Rectangle {
    id: root

    property string appName: ""
    property color borderColor: theme.palette.normal.base
    property color itemBorderColor: "#7a7a7a"
    property color textColor: theme.palette.normal.backgroundText
    property var bottomItems: []
    readonly property real availableContentHeight: contentFlickable.height
    default property alias content: contentColumn.data

    signal closeClicked()
    signal bottomItemClicked(string pageUrl)

    width: parent ? Math.min(parent.width * 0.78, units.gu(44)) : units.gu(44)
    color: theme.palette.normal.background
    border.width: 1
    border.color: root.borderColor

    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: units.gu(1.5)
            rightMargin: units.gu(1.5)
            topMargin: units.gu(1.5)
            bottomMargin: units.gu(1.2)
        }
        spacing: units.gu(1)

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: units.gu(5.2)
            spacing: units.gu(1)

            Label {
                Layout.fillWidth: true
                text: root.appName
                color: root.textColor
                fontSize: "x-large"
                font.bold: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                Layout.preferredWidth: units.gu(4.6)
                Layout.preferredHeight: units.gu(4.6)
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: root.itemBorderColor

                Label {
                    anchors.centerIn: parent
                    text: "\u2715"
                    color: root.textColor
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeClicked()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.borderColor
        }

        Flickable {
            id: contentFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: contentColumn.height + units.gu(1)
            clip: true

            ColumnLayout {
                id: contentColumn
                width: parent.width
                spacing: units.gu(0.8)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.borderColor
        }

        Repeater {
            model: root.bottomItems

            DrawerNavItem {
                Layout.fillWidth: true
                text: modelData.label || ""
                textColor: root.textColor
                framed: false
                onClicked: root.bottomItemClicked(modelData.page || "")
            }
        }
    }
}
