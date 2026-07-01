import QtQuick 2.7
import Lomiri.Components 1.3

Rectangle {
    id: root

    property string text: ""
    property color badgeColor: "#2c7fb8"
    property color textColor: "white"

    visible: root.text.length > 0
    radius: units.gu(0.45)
    color: root.badgeColor
    implicitWidth: badgeLabel.implicitWidth + units.gu(1.2)
    implicitHeight: badgeLabel.implicitHeight + units.gu(0.55)

    Label {
        id: badgeLabel
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        fontSize: "x-small"
        font.bold: true
    }
}
