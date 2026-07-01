import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

RowLayout {
    id: root

    signal actionClicked()

    property string text: ""
    property string title: text
    property string badgeText: count >= 0 ? String(count) : ""
    property int count: -1
    property string actionText: ""
    property real topPadding: units.gu(1.1)
    property color accentColor: "#2c7fb8"

    width: parent ? parent.width : implicitWidth
    height: Math.max(titleLabel.implicitHeight, actionButton.implicitHeight) + topPadding
    spacing: units.gu(0.8)

    Label {
        id: titleLabel
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignBottom
        text: root.title
        verticalAlignment: Text.AlignBottom
        font.bold: true
        opacity: 0.72
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    Rectangle {
        Layout.alignment: Qt.AlignBottom
        visible: root.badgeText.length > 0
        implicitWidth: badgeLabel.implicitWidth + units.gu(1)
        implicitHeight: Math.max(units.gu(2.2), badgeLabel.implicitHeight + units.gu(0.4))
        radius: implicitHeight / 2
        color: Qt.rgba(0.5, 0.5, 0.5, 0.14)

        Label {
            id: badgeLabel
            anchors.centerIn: parent
            text: root.badgeText
            font.bold: true
            font.pixelSize: units.gu(1.35)
            opacity: 0.72
        }
    }

    AppButton {
        id: actionButton
        Layout.alignment: Qt.AlignBottom
        visible: root.actionText.length > 0
        text: root.actionText
        variant: "primary"
        accentColor: root.accentColor
        onClicked: root.actionClicked()
    }
}
