import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3

Dialog {
    id: root

    property string message: ""
    property string confirmText: i18n.tr("Confirm")
    property string cancelText: i18n.tr("Cancel")
    property string confirmVariant: destructive ? "destructive" : "primary"
    property bool destructive: false
    property real maxBodyHeight: units.gu(34)

    signal confirmed()
    signal cancelled()

    Flickable {
        width: parent ? parent.width : units.gu(32)
        height: Math.min(messageLabel.implicitHeight, root.maxBodyHeight)
        visible: root.message.length > 0
        contentWidth: width
        contentHeight: messageLabel.implicitHeight
        clip: true

        Label {
            id: messageLabel
            width: parent.width
            text: root.message
            wrapMode: Text.WordWrap
            opacity: 0.82
        }
    }

    RowLayout {
        width: parent ? parent.width : units.gu(32)
        spacing: units.gu(0.8)

        AppButton {
            Layout.fillWidth: true
            text: root.cancelText
            variant: "subtle"
            onClicked: {
                root.cancelled()
                PopupUtils.close(root)
            }
        }

        AppButton {
            Layout.fillWidth: true
            text: root.confirmText
            variant: root.confirmVariant
            onClicked: {
                root.confirmed()
                PopupUtils.close(root)
            }
        }
    }
}
