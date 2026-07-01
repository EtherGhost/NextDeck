import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

ColumnLayout {
    id: root

    signal actionClicked()

    property string iconName: ""
    property url iconSource: ""
    property string symbol: ""
    property string title: ""
    property string message: ""
    property string actionText: ""
    property color accentColor: "#2c7fb8"
    property real textOpacity: 0.72

    width: parent ? parent.width : implicitWidth
    spacing: units.gu(0.8)

    Icon {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: units.gu(4)
        Layout.preferredHeight: units.gu(4)
        visible: root.iconName.length > 0 || root.iconSource.toString().length > 0
        name: root.iconName
        source: root.iconSource
        color: theme.palette.normal.backgroundText
        opacity: 0.42
    }

    Label {
        Layout.alignment: Qt.AlignHCenter
        visible: root.symbol.length > 0 && !root.iconName.length && !root.iconSource.toString().length
        text: root.symbol
        font.pixelSize: units.gu(3.4)
        opacity: 0.42
    }

    Label {
        Layout.fillWidth: true
        visible: root.title.length > 0
        text: root.title
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        opacity: root.textOpacity
    }

    Label {
        Layout.fillWidth: true
        visible: root.message.length > 0
        text: root.message
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        opacity: root.textOpacity
    }

    AppButton {
        Layout.alignment: Qt.AlignHCenter
        visible: root.actionText.length > 0
        text: root.actionText
        variant: "primary"
        accentColor: root.accentColor
        onClicked: root.actionClicked()
    }
}
