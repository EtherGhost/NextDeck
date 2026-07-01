import QtQuick 2.7
import Lomiri.Components 1.3

Rectangle {
    id: root

    property string text: ""
    property color textColor: theme.palette.normal.backgroundText
    property color borderColor: "#7a7a7a"
    property color backgroundColor: "transparent"
    property bool compact: false
    property bool framed: true
    property int textHorizontalAlignment: Text.AlignLeft
    signal clicked()

    width: parent ? parent.width : implicitWidth
    height: compact ? units.gu(4.6) : units.gu(5.2)
    radius: units.gu(0.55)
    color: root.backgroundColor
    border.width: root.framed ? 1 : 0
    border.color: root.borderColor

    Label {
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: units.gu(1)
            rightMargin: units.gu(1)
        }
        text: root.text
        color: root.textColor
        font.bold: true
        elide: Text.ElideRight
        horizontalAlignment: root.textHorizontalAlignment
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
