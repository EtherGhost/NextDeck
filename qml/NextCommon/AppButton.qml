import QtQuick 2.7
import Lomiri.Components 1.3

Rectangle {
    id: root

    signal clicked()

    property string text: ""
    property string variant: "neutral"
    property bool selected: false
    property color accentColor: "#2c7fb8"
    property color destructiveColor: "#c23b3b"
    property int horizontalAlignment: Text.AlignHCenter
    readonly property real buttonImplicitWidth: label.implicitWidth + units.gu(2.4)

    radius: units.gu(0.7)
    opacity: enabled ? 1.0 : 0.45
    color: mouse.pressed
        ? pressColor()
        : selected
        ? selectedColor()
        : "transparent"
    border.width: 0

    function isDestructive() {
        return variant === "destructive"
    }

    function isPrimary() {
        return variant === "primary"
    }

    function foregroundColor() {
        if (isDestructive()) return destructiveColor
        return theme.palette.normal.backgroundText
    }

    function pressColor() {
        if (isDestructive()) return Qt.rgba(0.76, 0.23, 0.23, 0.14)
        return Qt.rgba(0.5, 0.5, 0.5, 0.16)
    }

    function selectedColor() {
        if (isDestructive()) return Qt.rgba(0.76, 0.23, 0.23, 0.12)
        return Qt.rgba(0.5, 0.5, 0.5, 0.14)
    }

    Label {
        id: label
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: units.gu(1.2)
            rightMargin: units.gu(1.2)
        }
        text: root.text
        color: root.foregroundColor()
        opacity: root.variant === "neutral" && !root.selected ? 0.78 : 1.0
        font.bold: root.variant !== "neutral" || root.selected
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
