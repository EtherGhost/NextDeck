import QtQuick 2.7
import Lomiri.Components 1.3
import QtGraphicalEffects 1.0

Item {
    id: root

    property string avatarUrl: ""
    property string fallbackText: "?"
    property color backgroundColor: "#2c7fb8"
    property color borderColor: "#7a7a7a"
    property color textColor: "white"
    property int borderWidth: 1
    signal clicked()

    implicitWidth: units.gu(5)
    implicitHeight: units.gu(5)

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.backgroundColor
        border.width: root.borderWidth
        border.color: root.borderColor
    }

    Image {
        id: avatarSource
        anchors.fill: parent
        source: root.avatarUrl
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    Rectangle {
        id: avatarMask
        anchors.fill: parent
        radius: width / 2
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        source: avatarSource
        maskSource: avatarMask
        visible: avatarSource.status === Image.Ready
    }

    Label {
        anchors.centerIn: parent
        text: root.fallbackText
        color: root.textColor
        font.bold: true
        visible: avatarSource.status !== Image.Ready
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
