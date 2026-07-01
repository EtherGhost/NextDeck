import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

Rectangle {
    id: root

    property string text: ""
    property string secondaryText: ""
    property string iconName: ""
    property url iconSource: ""
    property bool busy: false
    property color accentColor: "#2c7fb8"
    property color backgroundColor: Qt.rgba(0.17, 0.5, 0.72, 0.10)
    property real textOpacity: 0.82

    visible: root.text.length > 0 || root.busy
    radius: units.gu(0.6)
    color: root.backgroundColor
    implicitHeight: Math.max(units.gu(4.2), content.implicitHeight + units.gu(1.2))

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: units.gu(0.35)
        color: root.accentColor
        radius: units.gu(0.35)
    }

    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: units.gu(1.1)
            rightMargin: units.gu(1)
        }
        spacing: units.gu(0.8)

        ActivityIndicator {
            Layout.preferredWidth: units.gu(2.2)
            Layout.preferredHeight: units.gu(2.2)
            visible: root.busy
            running: root.busy
        }

        Icon {
            Layout.preferredWidth: units.gu(2.2)
            Layout.preferredHeight: units.gu(2.2)
            visible: !root.busy && (root.iconName.length > 0 || root.iconSource.toString().length > 0)
            name: root.iconName
            source: root.iconSource
            color: root.accentColor
            opacity: 0.9
        }

        Rectangle {
            Layout.preferredWidth: units.gu(1)
            Layout.preferredHeight: units.gu(1)
            radius: width / 2
            visible: !root.busy && root.iconName.length === 0 && root.iconSource.toString().length === 0
            color: root.accentColor
            opacity: 0.9
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: units.gu(0.15)

            Label {
                Layout.fillWidth: true
                text: root.text
                wrapMode: Text.WordWrap
                opacity: root.textOpacity
            }

            Label {
                Layout.fillWidth: true
                visible: root.secondaryText.length > 0
                text: root.secondaryText
                wrapMode: Text.WordWrap
                font.pixelSize: units.gu(1.45)
                opacity: 0.62
            }
        }
    }
}
