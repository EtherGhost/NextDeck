import QtQuick 2.7
import Ubuntu.Components 1.3
import Ubuntu.Content 1.3

Page {
    id: page
    title: i18n.tr("Attach file")

    signal fileSelected(url fileUrl, string fileName)
    signal importCanceled()
    signal importFailed(string message)

    property var activeTransfer: null

    ContentPeerPicker {
        id: picker
        anchors {
            fill: parent
            topMargin: page.header ? page.header.height : 0
        }
        visible: true
        showTitle: false
        contentType: ContentType.Documents
        handler: ContentHandler.Source

        onPeerSelected: page.requestFileFromPeer(peer)
        onCancelPressed: page.importCanceled()
    }

    Connections {
        target: page.activeTransfer
        onStateChanged: {
            if (!page.activeTransfer) {
                return
            }
            if (page.activeTransfer.state === ContentTransfer.Charged) {
                page.collectTransfer()
            } else if (page.activeTransfer.state === ContentTransfer.Aborted) {
                page.importCanceled()
            }
        }
    }

    function requestFileFromPeer(peer) {
        if (!peer) {
            importFailed(i18n.tr("No file provider was selected."))
            return
        }
        page.activeTransfer = peer.request()
        if (!page.activeTransfer) {
            importFailed(i18n.tr("The file provider did not start a transfer."))
        }
    }

    function collectTransfer() {
        var items = page.activeTransfer.items || []
        if (items.length === 0 || !items[0].url) {
            importFailed(i18n.tr("No file was selected."))
            return
        }
        var selectedUrl = items[0].url
        var selectedName = items[0].name || ""
        page.activeTransfer.state = ContentTransfer.Collected
        page.fileSelected(selectedUrl, selectedName)
    }
}
