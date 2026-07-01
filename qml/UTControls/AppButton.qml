import QtQuick 2.7
import Lomiri.Components 1.3

Rectangle {
    id: root

    signal clicked()

    property string text: ""
    property string variant: "normal"
    property bool selected: false
    property bool bold: variant === "primary" || variant === "destructive" || selected
    property color accentColor: "#2c7fb8"
    property color destructiveColor: "#c23b3b"
    property int horizontalAlignment: Text.AlignHCenter
    readonly property real buttonImplicitWidth: label.implicitWidth + units.gu(2.4)

    implicitWidth: buttonImplicitWidth
    implicitHeight: Math.max(units.gu(4), label.implicitHeight + units.gu(1.3))
    radius: units.gu(0.6)
    opacity: enabled ? 1.0 : 0.45
    color: mouse.pressed ? root.pressedColor()
        : root.selected ? root.selectedColor()
        : root.backgroundColor()
    border.width: 0

    function isPrimary() {
        return variant === "primary"
    }

    function isDestructive() {
        return variant === "destructive"
    }

    function isSubtle() {
        return variant === "subtle" || variant === "neutral"
    }

    function foregroundColor() {
        if (isDestructive()) return destructiveColor
        if (isPrimary()) return accentColor
        return theme.palette.normal.backgroundText
    }

    function backgroundColor() {
        if (isPrimary() && selected) return Qt.rgba(0.17, 0.5, 0.72, 0.14)
        if (isDestructive() && selected) return Qt.rgba(0.76, 0.23, 0.23, 0.12)
        if (variant === "normal" && selected) return Qt.rgba(0.5, 0.5, 0.5, 0.14)
        return "transparent"
    }

    function pressedColor() {
        if (isDestructive()) return Qt.rgba(0.76, 0.23, 0.23, 0.16)
        if (isPrimary()) return Qt.rgba(0.17, 0.5, 0.72, 0.18)
        return Qt.rgba(0.5, 0.5, 0.5, 0.16)
    }

    function selectedColor() {
        if (isDestructive()) return Qt.rgba(0.76, 0.23, 0.23, 0.12)
        if (isPrimary()) return Qt.rgba(0.17, 0.5, 0.72, 0.14)
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
        opacity: root.isSubtle() && !root.selected ? 0.72 : 1.0
        font.bold: root.bold
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
