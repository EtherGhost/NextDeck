import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Content 1.3

Page {
    id: page
    title: i18n.tr("Open attachment")

    property url fileUrl
    property string fileName: ""
    property string mimeType: "application/octet-stream"

    signal openFinished()
    signal openFailed(string message)

    ContentPeerPicker {
        id: picker
        anchors {
            fill: parent
            topMargin: page.header ? page.header.height : 0
        }
        visible: true
        showTitle: false
        contentType: ContentType.Documents
        handler: ContentHandler.Share

        onPeerSelected: page.sendToPeer(peer)
        onCancelPressed: page.openFinished()
    }

    Component {
        id: contentItemComponent

        ContentItem {
        }
    }

    function sendToPeer(peer) {
        if (!peer) {
            openFailed(i18n.tr("No app was selected."))
            return
        }
        if (!fileUrl || String(fileUrl).length === 0) {
            openFailed(i18n.tr("The attachment file is not available."))
            return
        }
        var transfer = peer.request()
        var item = contentItemComponent.createObject(page)
        item.name = fileName && fileName.length > 0 ? fileName : i18n.tr("Attachment")
        item.url = fileUrl
        transfer.items = [ item ]
        transfer.state = ContentTransfer.Charged
        page.openFinished()
    }
}
