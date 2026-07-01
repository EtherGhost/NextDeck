import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

Page {
    id: page

    property string title: i18n.tr("Settings")
    property real horizontalMargin: units.gu(2)
    property real verticalMargin: units.gu(2)
    default property alias content: contentColumn.data

    header: PageHeader {
        id: header
        title: page.title
    }

    Flickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentWidth: width
        contentHeight: contentColumn.height + page.verticalMargin * 2
        clip: true

        ColumnLayout {
            id: contentColumn
            width: parent.width - page.horizontalMargin * 2
            x: page.horizontalMargin
            y: page.verticalMargin
            spacing: units.gu(1.4)
        }
    }
}
