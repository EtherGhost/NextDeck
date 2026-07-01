import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

Rectangle {
    id: root

    property color borderColor: "#7a7a7a"
    property color backgroundColor: "transparent"
    property real contentMargin: units.gu(1)
    default property alias content: contentColumn.data

    Layout.fillWidth: true
    Layout.preferredHeight: contentColumn.implicitHeight + root.contentMargin * 2
    radius: units.gu(0.6)
    color: root.backgroundColor
    border.width: 1
    border.color: root.borderColor

    ColumnLayout {
        id: contentColumn
        anchors {
            fill: parent
            margins: root.contentMargin
        }
        spacing: units.gu(1)
    }
}
