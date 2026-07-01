import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import "qrc:/NextCommon" as NextCommon
import "qrc:/UTControls" as UTControls

Page {
    id: page

    property var appController
    property var deckController
    property var card: ({})
    property bool dirty: false
    property string activeTab: "home"
    property string newLabelTitle: ""
    property string assignmentUserId: ""
    property string newCommentText: ""
    property string dueDateText: ""
    property string dueTimeText: ""
    property date calendarMonth: new Date()
    property var selectedLabelForDelete: ({})
    property var selectedAttachments: ({})
    property var selectedComments: ({})
    property bool attachmentSelectionMode: false
    property bool commentSelectionMode: false
    property bool assignmentPickerVisible: false
    property string conflictChoice: "local"
    readonly property real pullRefreshThreshold: units.gu(7)
    readonly property real oskOverlap: Qt.inputMethod.visible && Qt.inputMethod.keyboardRectangle.height > 0
        ? Math.max(0, page.height - Qt.inputMethod.keyboardRectangle.y)
        : 0
    readonly property real commentComposerHeight: activeTab === "comments" ? units.gu(6.8) : 0
    readonly property string actionBlue: "#2c7fb8"

    Timer {
        id: autoSaveTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (page.dirty && deckController && !deckController.loading) {
                page.saveCard(false)
            }
        }
    }

    Timer {
        id: commentCommitTimer
        interval: 180
        repeat: false
        onTriggered: page.sendCommittedComment()
    }

    onActiveTabChanged: {
        if (activeTab !== "attachments") {
            clearAttachmentSelection()
        }
        if (activeTab !== "comments") {
            clearCommentSelection()
        }
        if (activeTab === "comments" && page.card.id > 0 && deckController) {
            deckController.loadComments(page.card)
        }
        if (activeTab === "activity" && page.card.id > 0 && deckController) {
            deckController.loadActivities(page.card)
        }
    }

    Connections {
        target: deckController
        onEntriesChanged: page.refreshFromController()
        onAttachmentReadyToOpen: page.openDownloadedAttachment(fileUrl, fileName, mimeType)
    }

    header: PageHeader {
        id: header
        title: ""

        contents: RowLayout {
            anchors {
                fill: parent
                leftMargin: units.gu(1)
                rightMargin: units.gu(1)
            }
            spacing: units.gu(0.75)

            TextField {
                id: headerTitleField
                Layout.fillWidth: true
                text: page.card.title || ""
                placeholderText: i18n.tr("Untitled card")
                inputMethodHints: Qt.ImhNoPredictiveText
                font.bold: true
                onTextChanged: {
                    if (!activeFocus) {
                        return
                    }
                    page.dirty = true
                    autoSaveTimer.restart()
                }
                onAccepted: {
                    Qt.inputMethod.commit()
                    focus = false
                    if (page.dirty && deckController && !deckController.loading) {
                        page.saveCard(false)
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: units.gu(5)
                Layout.preferredHeight: units.gu(5)
                radius: units.gu(2.5)
                color: "transparent"
                border.width: 2
                border.color: page.statusAccentColor()

                Item {
                    id: statusIcon
                    anchors.centerIn: parent
                    width: units.gu(2.8)
                    height: units.gu(2.8)

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: deckController && (deckController.loading || deckController.dirtySyncRunning)
                    }

                    Connections {
                        target: deckController
                        onLoadingChanged: page.resetStatusIconRotation()
                        onDirtySyncRunningChanged: page.resetStatusIconRotation()
                    }

                    Canvas {
                        id: statusCanvas
                        anchors.fill: parent
                        property string paintColor: page.statusAccentColor()
                        visible: page.statusIconKind() !== "dirty" && page.statusIconKind() !== "conflict"
                        onVisibleChanged: requestPaint()
                        onPaintColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            var w = width
                            var h = height
                            var s = Math.min(w, h)
                            ctx.clearRect(0, 0, w, h)
                            ctx.strokeStyle = paintColor
                            ctx.fillStyle = paintColor
                            ctx.lineWidth = Math.max(2.4, s * 0.13)
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"

                            if (deckController && (deckController.loading || deckController.dirtySyncRunning)) {
                                ctx.beginPath()
                                ctx.arc(w / 2, h / 2, s * 0.35, Math.PI * 0.15, Math.PI * 1.55, false)
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.moveTo(w * 0.77, h * 0.30)
                                ctx.lineTo(w * 0.82, h * 0.52)
                                ctx.lineTo(w * 0.62, h * 0.45)
                                ctx.stroke()
                            } else if (page.statusIconKind() === "failed") {
                                ctx.beginPath()
                                ctx.moveTo(w * 0.50, h * 0.22)
                                ctx.lineTo(w * 0.50, h * 0.62)
                                ctx.stroke()
                                ctx.beginPath()
                                ctx.arc(w * 0.50, h * 0.80, s * 0.06, 0, Math.PI * 2, false)
                                ctx.fill()
                            } else {
                                ctx.beginPath()
                                ctx.moveTo(w * 0.22, h * 0.54)
                                ctx.lineTo(w * 0.42, h * 0.72)
                                ctx.lineTo(w * 0.78, h * 0.28)
                                ctx.stroke()
                            }
                        }

                        Connections {
                            target: deckController
                            onLoadingChanged: statusCanvas.requestPaint()
                            onDirtySyncRunningChanged: statusCanvas.requestPaint()
                            onSyncStateTextChanged: statusCanvas.requestPaint()
                            onSyncStateColorChanged: statusCanvas.requestPaint()
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: units.gu(1.7)
                        height: width
                        radius: width / 2
                        visible: page.statusIconKind() === "dirty"
                        color: page.statusAccentColor()
                    }

                    Item {
                        anchors.fill: parent
                        visible: page.statusIconKind() === "conflict"

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height * 0.12
                            width: Math.max(3, parent.width * 0.16)
                            height: parent.height * 0.52
                            radius: width / 2
                            color: page.statusAccentColor()
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height * 0.76
                            width: Math.max(4, parent.width * 0.20)
                            height: width
                            radius: width / 2
                            color: page.statusAccentColor()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: page.openSyncStatus()
                }
            }
        }
    }

    Component {
        id: deleteCardDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete card?")
            text: i18n.tr("This card will be deleted from Nextcloud Deck.")

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete")
                variant: "destructive"
                enabled: !deckController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    page.deleteCard()
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: deleteLabelDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete label?")
            text: i18n.tr("The label will be removed from this board.")

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete")
                variant: "destructive"
                enabled: !deckController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    deckController.deleteLabel(page.selectedLabelForDelete.id)
                    page.selectedLabelForDelete = ({})
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: deleteAttachmentsDialog

        Dialog {
            id: dialog
            title: page.selectedAttachmentCount() === 1
                ? i18n.tr("Remove attachment?")
                : i18n.tr("Remove attachments?")
            text: page.selectedAttachmentCount() === 1
                ? i18n.tr("The selected attachment will be removed from this card.")
                : i18n.tr("The selected attachments will be removed from this card.")

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Remove")
                variant: "destructive"
                enabled: !deckController.loading && page.selectedAttachmentCount() > 0
                onClicked: {
                    PopupUtils.close(dialog)
                    page.deleteSelectedAttachments()
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: deleteCommentsDialog

        Dialog {
            id: dialog
            title: page.selectedCommentCount() === 1
                ? i18n.tr("Delete comment?")
                : i18n.tr("Delete comments?")
            text: page.selectedCommentCount() === 1
                ? i18n.tr("The selected comment will be deleted from this card.")
                : i18n.tr("The selected comments will be deleted from this card.")

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete")
                variant: "destructive"
                enabled: !deckController.loading && page.selectedCommentCount() > 0
                onClicked: {
                    PopupUtils.close(dialog)
                    page.deleteSelectedComments()
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: syncStatusDialog

        Dialog {
            id: dialog
            title: i18n.tr("Sync status")
            text: page.syncStatusDetailsText()

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: conflictDialog

        Dialog {
            id: dialog
            title: i18n.tr("Resolve conflict")
            text: i18n.tr("The server version changed while this card had local changes. Choose which version to keep.")

            Row {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(5)
                spacing: units.gu(0.6)

                UTControls.AppButton {
                    width: (parent.width - units.gu(0.6)) / 2
                    height: parent.height
                    text: page.conflictChoice === "server" ? "\u2713 " + i18n.tr("Server version") : i18n.tr("Server version")
                    selected: page.conflictChoice === "server"
                    variant: selected ? "primary" : "neutral"
                    accentColor: page.actionBlue
                    onClicked: page.conflictChoice = "server"
                }

                UTControls.AppButton {
                    width: (parent.width - units.gu(0.6)) / 2
                    height: parent.height
                    text: page.conflictChoice === "local" ? "\u2713 " + i18n.tr("Local version") : i18n.tr("Local version")
                    selected: page.conflictChoice === "local"
                    variant: selected ? "primary" : "neutral"
                    accentColor: page.actionBlue
                    onClicked: page.conflictChoice = "local"
                }
            }

            TextArea {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(20)
                readOnly: true
                text: page.conflictPreviewText()
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: page.conflictChoice === "server" ? i18n.tr("Use server version") : i18n.tr("Keep local version")
                variant: "primary"
                accentColor: page.actionBlue
                onClicked: {
                    PopupUtils.close(dialog)
                    page.resolveSelectedConflictVersion()
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Cancel")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: datePickerDialog

        Dialog {
            id: dateDialog
            width: Math.min(page.width - units.gu(4), units.gu(40))
            title: i18n.tr("Due date")

            UTControls.CalendarDatePicker {
                width: Math.min(dateDialog.width - units.gu(2), units.gu(34))
                value: page.dueDateText
                okText: i18n.tr("OK")
                todayTextLabel: i18n.tr("Today")
                clearText: i18n.tr("Clear due date")
                cancelText: i18n.tr("Cancel")
                onAccepted: {
                    page.applyDueDate(dateText)
                    PopupUtils.close(dateDialog)
                }
                onCleared: {
                    page.applyDueDate("")
                    PopupUtils.close(dateDialog)
                }
                onCanceled: PopupUtils.close(dateDialog)
            }
        }
    }

    Component {
        id: timePickerDialog

        Dialog {
            id: timeDialog
            title: i18n.tr("Time")

            UTControls.TimePicker {
                width: Math.min(timeDialog.width - units.gu(2), units.gu(34))
                value: page.dueTimeText
                okText: i18n.tr("OK")
                nowText: i18n.tr("Now")
                clearText: i18n.tr("Clear time")
                cancelText: i18n.tr("Cancel")
                onAccepted: {
                    var parts = String(timeText || "").split(":")
                    page.applyDueTime(parts.length > 0 ? parts[0] : "", parts.length > 1 ? parts[1] : "")
                    PopupUtils.close(timeDialog)
                }
                onCleared: {
                    page.applyDueTime("", "")
                    PopupUtils.close(timeDialog)
                }
                onCanceled: PopupUtils.close(timeDialog)
            }
        }
    }

    Flickable {
        id: detailFlickable
        anchors {
            fill: parent
            topMargin: page.header.height
            bottomMargin: page.oskOverlap + page.commentComposerHeight
        }
        contentWidth: width
        contentHeight: contentColumn.childrenRect.height + units.gu(3) + page.oskOverlap + page.commentComposerHeight
        clip: true
        boundsBehavior: Flickable.DragOverBounds

        MouseArea {
            anchors.fill: parent
            z: -1
            propagateComposedEvents: true
            onPressed: {
                Qt.inputMethod.commit()
                Qt.inputMethod.hide()
                mouse.accepted = false
            }
        }

        onContentYChanged: {
            if (contentY < -page.pullRefreshThreshold && !deckController.loading && page.card.id > 0) {
                deckController.loadCardDetails(page.card)
            }
        }

        ColumnLayout {
            id: contentColumn
            width: parent.width
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: units.gu(2)
            }
            spacing: units.gu(1.2)

            Label {
                Layout.fillWidth: true
                visible: detailFlickable.contentY < -units.gu(1.5)
                text: detailFlickable.contentY < -page.pullRefreshThreshold ? i18n.tr("Release to refresh") : i18n.tr("Pull to refresh")
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.72
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: units.gu(0.4)

                Repeater {
                    model: [
                        {"id": "home", "label": i18n.tr("Details"), "icon": "go-home", "symbol": ""},
                        {"id": "attachments", "label": i18n.tr("Attachments"), "icon": "", "symbol": "\uD83D\uDCCE"},
                        {"id": "comments", "label": i18n.tr("Comments"), "icon": "mail-message-new", "symbol": ""},
                        {"id": "activity", "label": i18n.tr("Activity"), "icon": "", "symbol": "\u26a1"}
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: units.gu(5)
                        color: "transparent"
                        border.width: 0

                        Icon {
                            anchors.centerIn: parent
                            width: units.gu(2.9)
                            height: units.gu(2.9)
                            visible: modelData.icon.length > 0
                            name: modelData.icon
                            color: page.activeTab === modelData.id ? page.actionBlue : theme.palette.normal.backgroundText
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: modelData.icon.length === 0
                            text: modelData.symbol
                            color: page.activeTab === modelData.id ? page.actionBlue : theme.palette.normal.backgroundText
                            font.pixelSize: units.gu(2.6)
                            font.bold: true
                        }

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: units.gu(0.25)
                            color: page.activeTab === modelData.id ? page.actionBlue : "transparent"
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.activeTab = modelData.id
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.activeTab === "home"
                spacing: units.gu(1.2)

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.palette.normal.base
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: conflictLabel.implicitHeight + units.gu(1.2)
                    radius: units.gu(0.6)
                    color: Qt.rgba(0.76, 0.23, 0.23, 0.16)
                    border.width: 1
                    border.color: "#c23b3b"
                    visible: page.card.conflict === true

                    Label {
                        id: conflictLabel
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: units.gu(1) }
                        text: i18n.tr("Conflict. Server version changed while local changes are waiting.")
                        wrapMode: Text.WordWrap
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Due")
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(1)

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: units.gu(5.2)
                        radius: units.gu(0.7)
                        color: theme.palette.normal.background
                        border.width: 1
                        border.color: theme.palette.normal.base

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: units.gu(1)
                                rightMargin: units.gu(1)
                            }
                            spacing: units.gu(0.8)

                            Label {
                                Layout.fillWidth: true
                                text: page.dueDateText.length > 0 ? page.dueDateText : i18n.tr("Due date")
                                opacity: page.dueDateText.length > 0 ? 1.0 : 0.55
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.openDueDateDialog()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: units.gu(5.2)
                        radius: units.gu(0.7)
                        color: theme.palette.normal.background
                        border.width: 1
                        border.color: theme.palette.normal.base

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: units.gu(1)
                                rightMargin: units.gu(1)
                            }
                            spacing: units.gu(0.8)

                            Label {
                                Layout.fillWidth: true
                                text: page.dueTimeText.length > 0 ? page.dueTimeText : i18n.tr("Time")
                                opacity: page.dueTimeText.length > 0 ? 1.0 : 0.55
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: PopupUtils.open(timePickerDialog)
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Labels")
                    font.bold: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: units.gu(0.6)

                    Repeater {
                        model: deckController.selectedBoardLabels || []

                        Rectangle {
                            property bool assigned: page.cardHasLabel(modelData.id)
                            property color accentColor: page.labelColor(modelData)

                            width: Math.min(labelChipLayout.implicitWidth + units.gu(1.2), page.width - units.gu(6))
                            height: units.gu(3.4)
                            radius: units.gu(1.7)
                            color: assigned ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22) : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
                            border.width: assigned ? 1 : 0
                            border.color: accentColor

                            RowLayout {
                                id: labelChipLayout
                                anchors.fill: parent
                                anchors.leftMargin: units.gu(0.9)
                                anchors.rightMargin: units.gu(0.25)
                                spacing: units.gu(0.35)

                                Label {
                                    Layout.maximumWidth: page.width - units.gu(12)
                                    text: modelData.title || i18n.tr("Label")
                                    color: assigned ? accentColor : theme.palette.normal.foregroundText
                                    font.bold: true
                                    fontSize: "small"
                                    elide: Text.ElideRight
                                }

                                Item {
                                    Layout.preferredWidth: units.gu(2.4)
                                    Layout.preferredHeight: parent.height

                                    Label {
                                        anchors.centerIn: parent
                                        text: "\u00d7"
                                        color: "#c23b3b"
                                        font.bold: true
                                        font.pixelSize: units.gu(1.75)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            page.selectedLabelForDelete = modelData
                                            PopupUtils.open(deleteLabelDialog)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                    bottom: parent.bottom
                                    right: parent.right
                                    rightMargin: units.gu(2.6)
                                }
                                onClicked: page.toggleLabel(modelData)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(1)

                    TextField {
                        Layout.fillWidth: true
                        placeholderText: i18n.tr("New label")
                        text: page.newLabelTitle
                        onTextChanged: page.newLabelTitle = text
                        onAccepted: {
                            Qt.inputMethod.commit()
                            page.createLabelFromInput()
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Assignments")
                    font.bold: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: units.gu(0.6)
                    visible: (page.card.assignedUsers || []).length > 0

                    Repeater {
                        model: page.card.assignedUsers || []

                        Rectangle {
                            property string assigneeId: page.userId(modelData)

                            width: Math.min(assignedChipLayout.implicitWidth + units.gu(1.0), page.width - units.gu(6))
                            height: units.gu(4.2)
                            radius: units.gu(2.1)
                            color: Qt.rgba(0.17, 0.5, 0.72, 0.13)
                            border.width: 1
                            border.color: Qt.rgba(0.17, 0.5, 0.72, 0.35)

                            RowLayout {
                                id: assignedChipLayout
                                anchors.fill: parent
                                anchors.leftMargin: units.gu(0.35)
                                anchors.rightMargin: units.gu(0.25)
                                spacing: units.gu(0.45)

                                NextCommon.AvatarButton {
                                    Layout.preferredWidth: units.gu(3.2)
                                    Layout.preferredHeight: units.gu(3.2)
                                    avatarUrl: deckController.avatarDataUrl(assigneeId)
                                    fallbackText: page.userInitial(modelData)
                                    backgroundColor: page.actionBlue
                                    borderColor: "transparent"

                                    Component.onCompleted: deckController.requestAvatar(assigneeId)
                                }

                                Label {
                                    Layout.maximumWidth: page.width - units.gu(14)
                                    text: page.userDisplayName(modelData)
                                    color: theme.palette.normal.foregroundText
                                    font.bold: true
                                    fontSize: "small"
                                    elide: Text.ElideRight
                                }

                                Item {
                                    Layout.preferredWidth: units.gu(2.4)
                                    Layout.preferredHeight: parent.height

                                    Label {
                                        anchors.centerIn: parent
                                        text: "\u00d7"
                                        color: "#c23b3b"
                                        font.bold: true
                                        font.pixelSize: units.gu(1.75)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: page.unassignUser(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                TextField {
                    id: assignmentField
                    Layout.fillWidth: true
                    placeholderText: i18n.tr("Assign users")
                    text: page.assignmentUserId
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            page.assignmentPickerVisible = true
                        }
                    }
                    onTextChanged: {
                        page.assignmentUserId = text
                        page.assignmentPickerVisible = true
                    }
                    onAccepted: {
                        var options = page.visibleUserOptions()
                        if (options.length > 0) {
                            Qt.inputMethod.commit()
                            page.assignUser(options[0])
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: units.gu(0.35)
                    visible: page.assignmentPickerVisible

                    Repeater {
                        model: page.visibleUserOptions()

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: units.gu(5)
                            radius: units.gu(0.6)
                            color: theme.palette.normal.background
                            border.width: 1
                            border.color: theme.palette.normal.base

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: units.gu(0.8)
                                spacing: units.gu(0.8)

                                NextCommon.AvatarButton {
                                    Layout.preferredWidth: units.gu(3.4)
                                    Layout.preferredHeight: units.gu(3.4)
                                    avatarUrl: page.userAvatarUrl(modelData)
                                    fallbackText: page.userInitial(modelData)
                                    backgroundColor: page.actionBlue
                                    borderColor: "transparent"
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: page.userDisplayName(modelData)
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: page.assignUser(modelData)
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: page.visibleUserOptions().length === 0
                        text: i18n.tr("No users available.")
                        opacity: 0.62
                    }
                }

                UTControls.AppButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: units.gu(24)
                    Layout.preferredHeight: units.gu(4.8)
                    text: page.cardDone() ? i18n.tr("Mark as not done") : i18n.tr("Mark as done")
                    variant: page.cardDone() ? "neutral" : "primary"
                    accentColor: "#3f8f45"
                    enabled: !deckController.loading
                    onClicked: page.setCardDone(!page.cardDone())
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Description")
                    font.bold: true
                }

                TextArea {
                    id: descriptionArea
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(units.gu(22), implicitHeight)
                    text: page.card.description || ""
                    autoSize: false
                    onTextChanged: {
                        if (!activeFocus) {
                            return
                        }
                        page.dirty = true
                        autoSaveTimer.restart()
                    }
                }

                UTControls.AppButton {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: units.gu(24)
                    Layout.preferredHeight: units.gu(4.8)
                    text: i18n.tr("Delete card")
                    variant: "destructive"
                    enabled: !deckController.loading
                    onClicked: PopupUtils.open(deleteCardDialog)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.activeTab === "comments"
                spacing: units.gu(1.2)

                RowLayout {
                    Layout.fillWidth: true
                    visible: page.commentSelectionMode
                    spacing: units.gu(1)

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("%1 selected").arg(page.selectedCommentCount())
                        font.bold: true
                    }

                    UTControls.AppButton {
                        Layout.preferredWidth: units.gu(12)
                        Layout.preferredHeight: units.gu(4.8)
                        text: i18n.tr("Delete")
                        variant: "destructive"
                        enabled: page.selectedCommentCount() > 0 && !deckController.loading
                        onClicked: PopupUtils.open(deleteCommentsDialog)
                    }

                    UTControls.AppButton {
                        Layout.preferredWidth: units.gu(12)
                        Layout.preferredHeight: units.gu(4.8)
                        text: i18n.tr("Cancel")
                        onClicked: page.clearCommentSelection()
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: (page.card.comments || []).length === 0 && !(deckController && deckController.loading)
                    text: i18n.tr("No comments yet.")
                    horizontalAlignment: Text.AlignHCenter
                    opacity: 0.68
                }

                Repeater {
                    model: page.commentRows()

                    Item {
                        property bool suppressNextClick: false
                        Layout.fillWidth: true
                        Layout.preferredHeight: modelData.type === "section"
                            ? commentSectionLabel.implicitHeight + units.gu(1)
                            : commentBubbleRow.implicitHeight + units.gu(0.8)

                        Label {
                            id: commentSectionLabel
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                top: parent.top
                            }
                            visible: modelData.type === "section"
                            text: modelData.title || ""
                            opacity: 0.7
                            font.bold: true
                            font.pixelSize: units.gu(1.45)
                        }

                        RowLayout {
                            id: commentBubbleRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                topMargin: units.gu(0.2)
                            }
                            visible: modelData.type === "comment"
                            spacing: units.gu(0.8)

                            NextCommon.AvatarButton {
                                Layout.preferredWidth: units.gu(4.2)
                                Layout.preferredHeight: units.gu(4.2)
                                avatarUrl: page.commentAvatarUrl(modelData.comment)
                                fallbackText: page.commentInitial(modelData.comment)
                                borderWidth: 0
                                Component.onCompleted: page.requestCommentAvatar(modelData.comment)
                            }

                            Rectangle {
                                Layout.preferredWidth: units.gu(3.2)
                                Layout.preferredHeight: units.gu(3.2)
                                radius: units.gu(1.6)
                                visible: page.commentSelectionMode
                                color: page.isCommentSelected(modelData.comment) ? page.actionBlue : "transparent"
                                border.width: 2
                                border.color: page.isCommentSelected(modelData.comment) ? page.actionBlue : theme.palette.normal.base

                                Label {
                                    anchors.centerIn: parent
                                    text: page.isCommentSelected(modelData.comment) ? "\u2713" : ""
                                    color: "white"
                                    font.bold: true
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: commentBubbleColumn.implicitHeight + units.gu(1.4)
                                radius: units.gu(1.1)
                                color: page.isCommentSelected(modelData.comment) ? Qt.rgba(0.17, 0.50, 0.72, 0.16) : theme.palette.normal.base
                                border.width: 1
                                border.color: page.isCommentSelected(modelData.comment) ? page.actionBlue : theme.palette.normal.backgroundText
                                opacity: 0.98

                                ColumnLayout {
                                    id: commentBubbleColumn
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        margins: units.gu(0.8)
                                    }
                                    spacing: units.gu(0.35)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: units.gu(0.8)

                                        Label {
                                            Layout.fillWidth: true
                                            text: page.commentAuthor(modelData.comment)
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            text: page.commentTime(modelData.comment)
                                            opacity: 0.62
                                            font.pixelSize: units.gu(1.35)
                                        }
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: page.commentText(modelData.comment)
                                        wrapMode: Text.WordWrap
                                        opacity: 0.9
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: modelData.type === "comment"
                            onClicked: {
                                if (parent.suppressNextClick) {
                                    parent.suppressNextClick = false
                                    return
                                }
                                if (page.commentSelectionMode) {
                                    page.toggleCommentSelection(modelData.comment)
                                }
                            }
                            onPressAndHold: {
                                parent.suppressNextClick = true
                                page.commentSelectionMode = true
                                page.toggleCommentSelection(modelData.comment)
                            }
                        }
                    }
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.activeTab === "attachments"
                spacing: units.gu(1.4)

                RowLayout {
                    Layout.fillWidth: true
                    visible: page.attachmentSelectionMode
                    spacing: units.gu(1)

                    Label {
                        Layout.fillWidth: true
                        text: i18n.tr("%1 selected").arg(page.selectedAttachmentCount())
                        font.bold: true
                    }

                    UTControls.AppButton {
                        Layout.preferredWidth: units.gu(12)
                        Layout.preferredHeight: units.gu(4.8)
                        text: i18n.tr("Remove")
                        variant: "destructive"
                        enabled: page.selectedAttachmentCount() > 0 && !deckController.loading
                        onClicked: PopupUtils.open(deleteAttachmentsDialog)
                    }

                    UTControls.AppButton {
                        Layout.preferredWidth: units.gu(12)
                        Layout.preferredHeight: units.gu(4.8)
                        text: i18n.tr("Cancel")
                        onClicked: page.clearAttachmentSelection()
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(units.gu(28), emptyAttachmentColumn.implicitHeight + units.gu(4))
                    visible: page.attachmentItems().length === 0

                    Column {
                        id: emptyAttachmentColumn
                        anchors.centerIn: parent
                        width: Math.min(parent.width - units.gu(4), units.gu(38))
                        spacing: units.gu(1)

                        Label {
                            width: parent.width
                            text: "\uD83D\uDCCE"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: units.gu(8)
                        }

                        Label {
                            width: parent.width
                            text: i18n.tr("Attachments")
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            font.pixelSize: units.gu(2.6)
                        }

                        Label {
                            width: parent.width
                            text: i18n.tr("There are no files attached to this card.")
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            opacity: 0.72
                        }
                    }
                }

                Repeater {
                    model: page.attachmentItems()

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: attachmentCardColumn.implicitHeight + units.gu(2)
                        radius: units.gu(0.9)
                        color: page.isAttachmentSelected(modelData) ? Qt.rgba(0.17, 0.50, 0.72, 0.16) : theme.palette.normal.background
                        border.width: 1
                        border.color: page.isAttachmentSelected(modelData) ? page.actionBlue : theme.palette.normal.base
                        property bool suppressNextClick: false

                        RowLayout {
                            id: attachmentCardColumn
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: units.gu(1)
                            }
                            spacing: units.gu(1)

                            Rectangle {
                                Layout.preferredWidth: units.gu(3.2)
                                Layout.preferredHeight: units.gu(3.2)
                                radius: units.gu(1.6)
                                visible: page.attachmentSelectionMode
                                color: page.isAttachmentSelected(modelData) ? page.actionBlue : "transparent"
                                border.width: 2
                                border.color: page.isAttachmentSelected(modelData) ? page.actionBlue : theme.palette.normal.base

                                Label {
                                    anchors.centerIn: parent
                                    text: page.isAttachmentSelected(modelData) ? "\u2713" : ""
                                    color: "white"
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: units.gu(0.35)

                                Label {
                                    Layout.fillWidth: true
                                    text: page.attachmentName(modelData)
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: page.attachmentMetadata(modelData)
                                    visible: text.length > 0
                                    opacity: 0.68
                                    fontSize: "small"
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (parent.suppressNextClick) {
                                    parent.suppressNextClick = false
                                    return
                                }
                                if (page.attachmentSelectionMode) {
                                    page.toggleAttachmentSelection(modelData)
                                } else {
                                    page.openAttachment(modelData)
                                }
                            }
                            onPressAndHold: {
                                parent.suppressNextClick = true
                                page.attachmentSelectionMode = true
                                page.toggleAttachmentSelection(modelData)
                            }
                        }
                    }
                }

            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.activeTab === "activity"
                spacing: units.gu(1.2)

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(units.gu(24), emptyActivityColumn.implicitHeight + units.gu(4))
                    visible: page.activityItems().length === 0 && !(deckController && deckController.loading)

                    Column {
                        id: emptyActivityColumn
                        anchors.centerIn: parent
                        width: Math.min(parent.width - units.gu(4), units.gu(38))
                        spacing: units.gu(1)

                        Label {
                            width: parent.width
                            text: "\u26A1"
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: units.gu(7)
                        }

                        Label {
                            width: parent.width
                            text: i18n.tr("Activity")
                            horizontalAlignment: Text.AlignHCenter
                            font.bold: true
                            font.pixelSize: units.gu(2.6)
                        }

                        Label {
                            width: parent.width
                            text: i18n.tr("No activity yet.")
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            opacity: 0.72
                        }
                    }
                }

                Repeater {
                    model: page.activityRows()

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: modelData.type === "section"
                            ? activitySectionLabel.implicitHeight + units.gu(1)
                            : activityRow.implicitHeight + units.gu(0.8)

                        Label {
                            id: activitySectionLabel
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                top: parent.top
                            }
                            visible: modelData.type === "section"
                            text: modelData.title || ""
                            opacity: 0.7
                            font.bold: true
                            font.pixelSize: units.gu(1.45)
                        }

                        RowLayout {
                            id: activityRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                topMargin: units.gu(0.2)
                            }
                            visible: modelData.type === "activity"
                            spacing: units.gu(1)

                            Rectangle {
                                Layout.preferredWidth: units.gu(3.7)
                                Layout.preferredHeight: units.gu(3.7)
                                radius: units.gu(1.85)
                                color: page.activityIconColor(modelData.activity)

                                Label {
                                    anchors.centerIn: parent
                                    text: page.activitySymbol(modelData.activity)
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: units.gu(2)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: units.gu(0.25)

                                Label {
                                    Layout.fillWidth: true
                                    text: page.activityText(modelData.activity)
                                    wrapMode: Text.WordWrap
                                    opacity: 0.92
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: page.activityTime(modelData.activity)
                                    opacity: 0.62
                                    font.pixelSize: units.gu(1.35)
                                }
                            }
                        }
                    }
                }
            }

        }
    }

    Rectangle {
        id: commentComposer
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            bottomMargin: page.oskOverlap
        }
        height: page.commentComposerHeight
        visible: page.activeTab === "comments"
        color: theme.palette.normal.background
        border.width: 1
        border.color: theme.palette.normal.base

        RowLayout {
            anchors {
                fill: parent
                leftMargin: units.gu(1.2)
                rightMargin: units.gu(1.2)
                topMargin: units.gu(0.8)
                bottomMargin: units.gu(0.8)
            }
            spacing: units.gu(0.8)

            NextCommon.AvatarButton {
                Layout.preferredWidth: units.gu(4.4)
                Layout.preferredHeight: units.gu(4.4)
                avatarUrl: deckController ? deckController.accountAvatarUrl : ""
                fallbackText: deckController && deckController.currentUserName.length > 0
                    ? deckController.currentUserName.substring(0, 1).toUpperCase()
                    : "?"
                borderWidth: 0
            }

            TextField {
                id: newCommentField
                Layout.fillWidth: true
                placeholderText: i18n.tr("Add comment")
                text: page.newCommentText
                onTextChanged: page.newCommentText = text
                onAccepted: page.sendComment()
            }

            Rectangle {
                Layout.preferredWidth: units.gu(4.6)
                Layout.preferredHeight: units.gu(4.6)
                radius: width / 2
                color: page.newCommentText.trim().length > 0 && !(deckController && deckController.loading)
                    ? page.actionBlue
                    : Qt.rgba(0.17, 0.50, 0.72, 0.45)

                Canvas {
                    anchors.centerIn: parent
                    width: units.gu(2.4)
                    height: units.gu(2.4)
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.fillStyle = "white"
                        ctx.strokeStyle = "white"
                        ctx.lineWidth = Math.max(2, width * 0.11)
                        ctx.lineJoin = "round"
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.moveTo(width * 0.13, height * 0.18)
                        ctx.lineTo(width * 0.86, height * 0.50)
                        ctx.lineTo(width * 0.13, height * 0.82)
                        ctx.lineTo(width * 0.28, height * 0.52)
                        ctx.lineTo(width * 0.13, height * 0.18)
                        ctx.fill()
                        ctx.beginPath()
                        ctx.moveTo(width * 0.28, height * 0.52)
                        ctx.lineTo(width * 0.86, height * 0.50)
                        ctx.stroke()
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !(deckController && deckController.loading)
                    preventStealing: true
                    onPressed: {
                        mouse.accepted = true
                        page.sendComment()
                    }
                }
            }
        }
    }

    Rectangle {
        id: attachFileAction
        width: units.gu(6.5)
        height: width
        radius: width / 2
        color: page.actionBlue
        visible: page.activeTab === "attachments" && !page.attachmentSelectionMode
        enabled: page.card.id > 0 && deckController && !deckController.loading
        opacity: enabled ? 1.0 : 0.45
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: units.gu(2)
            bottomMargin: units.gu(2) + page.oskOverlap
        }

        Canvas {
            anchors.centerIn: parent
            width: units.gu(3.4)
            height: units.gu(3.4)
            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var h = height
                ctx.clearRect(0, 0, w, h)
                ctx.strokeStyle = "white"
                ctx.lineWidth = Math.max(2.5, w * 0.12)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(w * 0.18, h * 0.78)
                ctx.lineTo(w * 0.82, h * 0.78)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(w * 0.50, h * 0.68)
                ctx.lineTo(w * 0.50, h * 0.22)
                ctx.moveTo(w * 0.30, h * 0.40)
                ctx.lineTo(w * 0.50, h * 0.20)
                ctx.lineTo(w * 0.70, h * 0.40)
                ctx.stroke()
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: attachFileAction.enabled
            onClicked: page.openAttachmentPicker()
        }
    }

    function saveCard(manageFocus) {
        Qt.inputMethod.commit()
        if (manageFocus !== false) {
            headerTitleField.focus = false
            descriptionArea.focus = false
        }
        var updated = {}
        for (var key in page.card) {
            updated[key] = page.card[key]
        }
        updated.title = headerTitleField.text.trim().length > 0 ? headerTitleField.text.trim() : i18n.tr("Untitled card")
        updated.description = descriptionArea.text
        updated.duedate = combinedDueDateTime()
        updated.detail = updated.duedate
        updated.done = page.card.done || null
        page.card = updated
        page.dirty = false
        deckController.saveCard(updated)
    }

    function discardChanges() {
        Qt.inputMethod.commit()
        headerTitleField.focus = false
        descriptionArea.focus = false
        headerTitleField.text = page.card.title || ""
        descriptionArea.text = page.card.description || ""
        applyDueFromCard(page.card)
        page.dirty = false
    }

    function deleteCard() {
        Qt.inputMethod.commit()
        headerTitleField.focus = false
        descriptionArea.focus = false
        deckController.deleteCard(page.card)
        pageStack.pop()
    }

    function attachmentItems() {
        return page.card.attachments || []
    }

    function attachmentKey(attachment) {
        var value = attachment || {}
        if (value.id) {
            return "id:" + String(value.id)
        }
        if (value.fileid) {
            return "fileid:" + String(value.fileid)
        }
        if (value.fileId) {
            return "fileid:" + String(value.fileId)
        }
        return "name:" + String(value.filename || value.basename || value.name || "")
    }

    function isAttachmentSelected(attachment) {
        return page.selectedAttachments[page.attachmentKey(attachment)] === true
    }

    function selectedAttachmentCount() {
        var count = 0
        for (var key in page.selectedAttachments) {
            if (page.selectedAttachments[key] === true) {
                count += 1
            }
        }
        return count
    }

    function toggleAttachmentSelection(attachment) {
        var key = page.attachmentKey(attachment)
        var selected = {}
        for (var existingKey in page.selectedAttachments) {
            selected[existingKey] = page.selectedAttachments[existingKey]
        }
        if (selected[key] === true) {
            delete selected[key]
        } else {
            selected[key] = true
        }
        page.selectedAttachments = selected
        page.attachmentSelectionMode = page.selectedAttachmentCount() > 0
    }

    function clearAttachmentSelection() {
        page.selectedAttachments = ({})
        page.attachmentSelectionMode = false
    }

    function selectedAttachmentItems() {
        var result = []
        var attachments = page.attachmentItems()
        for (var i = 0; i < attachments.length; ++i) {
            if (page.isAttachmentSelected(attachments[i])) {
                result.push(attachments[i])
            }
        }
        return result
    }

    function deleteSelectedAttachments() {
        var selected = page.selectedAttachmentItems()
        page.clearAttachmentSelection()
        deckController.deleteAttachments(page.card, selected)
    }

    function openAttachment(attachment) {
        if (!deckController || deckController.loading) {
            return
        }
        deckController.openAttachment(page.card, attachment)
    }

    function openDownloadedAttachment(fileUrl, fileName, mimeType) {
        var opener = null
        try {
            opener = pageStack.push(Qt.resolvedUrl("../backend/DeckAttachmentOpenPage.qml"))
        } catch (e) {
        }
        if (!opener) {
            try {
                opener = pageStack.push(Qt.resolvedUrl("../backend/DeckAttachmentOpenPageUbuntu.qml"))
            } catch (fallbackError) {
            }
        }
        if (!opener) {
            deckController.statusText = i18n.tr("No app picker is available.")
            return
        }
        opener.fileUrl = fileUrl
        opener.fileName = fileName
        opener.mimeType = mimeType
        opener.openFinished.connect(function() {
            pageStack.pop()
        })
        opener.openFailed.connect(function(message) {
            pageStack.pop()
            deckController.statusText = message
        })
    }

    function attachmentName(attachment) {
        var value = attachment || {}
        var extended = value.extendedData || {}
        var info = extended.info || {}
        return String(value.basename || info.basename || value.name || value.filename || info.filename || value.fileName || i18n.tr("Attachment"))
    }

    function attachmentMetadata(attachment) {
        var value = attachment || {}
        var extended = value.extendedData || {}
        var parts = []
        var sizeText = page.attachmentSizeText(value)
        var mimeText = String(value.mimetype || extended.mimetype || value.mimeType || value.mime || value.type || "").trim()
        var createdText = String(value.createdAt || value.lastModified || value.modified || value.timestamp || "").trim()
        if (sizeText.length > 0) {
            parts.push(sizeText)
        }
        if (mimeText.length > 0 && mimeText !== "file" && mimeText !== "deck_file") {
            parts.push(mimeText)
        }
        if (createdText.length > 0) {
            parts.push(createdText)
        }
        return parts.join(" · ")
    }

    function attachmentSizeText(attachment) {
        var extended = attachment.extendedData || {}
        var raw = attachment.filesize || extended.filesize || attachment.fileSize || attachment.size || attachment.extendedDataSize || 0
        var value = Number(raw || 0)
        if (!value || value < 0) {
            return ""
        }
        if (value < 1024) {
            return i18n.tr("%1 B").arg(value)
        }
        if (value < 1024 * 1024) {
            return i18n.tr("%1 KB").arg(Math.round(value / 1024))
        }
        return i18n.tr("%1 MB").arg((value / (1024 * 1024)).toFixed(1))
    }

    function openAttachmentPicker() {
        if (!page.card || !page.card.id) {
            deckController.statusText = i18n.tr("Save the card before attaching files.")
            return
        }
        var picker = null
        try {
            picker = pageStack.push(Qt.resolvedUrl("../backend/DeckAttachmentImportPage.qml"))
        } catch (e) {
        }
        if (!picker) {
            try {
                picker = pageStack.push(Qt.resolvedUrl("../backend/DeckAttachmentImportPageUbuntu.qml"))
            } catch (fallbackError) {
            }
        }
        if (!picker) {
            deckController.statusText = i18n.tr("No file picker is available.")
            return
        }
        picker.fileSelected.connect(function(fileUrl, fileName) {
            var uploadUrl = fileUrl
            if (typeof contentHubBridge !== "undefined") {
                uploadUrl = contentHubBridge.copyImportedFileToCache(fileUrl, fileName)
                if (!uploadUrl || String(uploadUrl).length === 0) {
                    pageStack.pop()
                    deckController.statusText = i18n.tr("The selected file could not be prepared for upload.")
                    return
                }
            }
            pageStack.pop()
            deckController.uploadAttachment(page.card, uploadUrl, fileName)
        })
        picker.importCanceled.connect(function() {
            pageStack.pop()
        })
        picker.importFailed.connect(function(message) {
            pageStack.pop()
            deckController.statusText = message
        })
    }

    function cardHasLabel(labelId) {
        var labels = page.card.labels || []
        for (var i = 0; i < labels.length; ++i) {
            if (Number(labels[i].id || 0) === Number(labelId || 0)) {
                return true
            }
        }
        return false
    }

    function toggleLabel(label) {
        var labelId = label && label.id ? label.id : 0
        if (!labelId) {
            return
        }
        var assign = !page.cardHasLabel(labelId)
        var updated = page.updateLabelLocal(label, assign)
        deckController.assignLabel(updated, labelId, assign)
    }

    function updateLabelLocal(label, assign) {
        var labelId = label && label.id ? label.id : 0
        var updated = {}
        for (var key in page.card) {
            updated[key] = page.card[key]
        }
        var current = page.card.labels || []
        var labels = []
        var found = false
        for (var i = 0; i < current.length; ++i) {
            var existing = current[i]
            if (Number(existing.id || 0) === Number(labelId || 0)) {
                found = true
                if (assign) {
                    labels.push(existing)
                }
            } else {
                labels.push(existing)
            }
        }
        if (assign && !found) {
            labels.push(label)
        }
        updated.labels = labels
        updated._labelsAuthoritative = true
        page.card = updated
        return updated
    }

    function labelColor(label) {
        var value = String(label && label.color ? label.color : "")
        if (value.length === 0) {
            return page.actionBlue
        }
        return value.charAt(0) === "#" ? value : "#" + value
    }

    function createLabelFromInput() {
        var title = page.newLabelTitle.trim()
        if (title.length === 0 || !deckController) {
            return
        }
        deckController.createLabel(title, "0082c9")
        page.newLabelTitle = ""
    }

    function refreshFromController() {
        var source = deckController.entries || []
        for (var i = 0; i < source.length; ++i) {
            var entry = source[i]
            if (entry.type === "card" && Number(entry.id || 0) === Number(page.card.id || 0) && Number(entry.id || 0) > 0) {
                page.card = entry
                headerTitleField.text = entry.title || ""
                descriptionArea.text = entry.description || ""
                page.applyDueFromCard(entry)
                page.dirty = false
                return
            }
            if (entry.type === "card" && entry.localKey && entry.localKey === page.card.localKey) {
                page.card = entry
                headerTitleField.text = entry.title || ""
                descriptionArea.text = entry.description || ""
                page.applyDueFromCard(entry)
                page.dirty = false
                return
            }
        }
    }

    function resetStatusIconRotation() {
        if (deckController && !deckController.loading && !deckController.dirtySyncRunning) {
            statusIcon.rotation = 0
        }
    }

    function statusIconKind() {
        if (deckController && (deckController.loading || deckController.dirtySyncRunning)) {
            return "syncing"
        }
        if (deckController && deckController.syncStateText === i18n.tr("Sync failed")) {
            return "failed"
        }
        if (page.card.conflict === true || (deckController && deckController.syncStateText === i18n.tr("Conflict"))) {
            return "conflict"
        }
        if (page.dirty || page.card.dirty === true || page.card.isNew === true) {
            return "dirty"
        }
        return "synced"
    }

    function statusAccentColor() {
        var kind = statusIconKind()
        if (kind === "syncing") {
            return page.actionBlue
        }
        if (kind === "conflict") {
            return "#c23b3b"
        }
        if (kind === "failed") {
            return "#c23b3b"
        }
        if (kind === "dirty") {
            return "#b37a2a"
        }
        return deckController ? deckController.syncStateColor : "#5a8f3c"
    }

    function syncStatusDetailsText() {
        var parts = []
        if (page.card.conflict === true) {
            parts.push(i18n.tr("This card has a conflict."))
        } else if (page.dirty || page.card.dirty === true || page.card.isNew === true) {
            parts.push(i18n.tr("This card has local changes waiting to sync."))
        }
        if (deckController && deckController.statusText.length > 0) {
            parts.push(deckController.statusText)
        }
        if (deckController && deckController.syncStateText.length > 0) {
            parts.push(i18n.tr("Sync: %1").arg(deckController.syncStateText))
        }
        return parts.length > 0 ? parts.join("\n") : i18n.tr("Up to date")
    }

    function openSyncStatus() {
        if (page.card.conflict === true) {
            page.conflictChoice = "local"
            PopupUtils.open(conflictDialog)
            return
        }
        PopupUtils.open(syncStatusDialog)
    }

    function conflictServerCard() {
        try {
            var server = JSON.parse(page.card.serverJson || "{}")
            return server || ({})
        } catch (e) {
            return ({})
        }
    }

    function conflictPreviewText() {
        var source = page.conflictChoice === "server" ? conflictServerCard() : page.card
        if (page.conflictChoice === "server" && (!source || !source.id)) {
            return i18n.tr("Server version is not available in the local cache yet. Pull to refresh and open this conflict again.")
        }
        var title = String((source && source.title) || i18n.tr("Untitled card"))
        var description = String((source && source.description) || "")
        var due = String((source && (source.duedate || source.detail)) || "")
        var parts = [i18n.tr("Title: %1").arg(title)]
        if (due.length > 0) {
            parts.push(i18n.tr("Due: %1").arg(due))
        }
        if (description.length > 0) {
            parts.push("")
            parts.push(description)
        }
        return parts.join("\n")
    }

    function resolveSelectedConflictVersion() {
        if (!deckController) {
            return
        }
        if (page.conflictChoice === "server") {
            deckController.resolveConflictUseServer(page.card)
        } else {
            deckController.resolveConflictKeepLocal(page.card)
        }
    }

    function applyDueFromCard(source) {
        var due = parseDueValue((source && (source.duedate || source.detail)) || "")
        dueDateText = due.date
        dueTimeText = due.time
    }

    function parseDueValue(value) {
        var text = String(value || "").trim()
        var result = {"date": "", "time": ""}
        if (text.length === 0) {
            return result
        }
        var match = text.match(/^(\d{4}-\d{2}-\d{2})(?:[T\s](\d{2}:\d{2}))?/)
        if (match) {
            result.date = match[1]
            result.time = match[2] || ""
            return result
        }
        if (/^\d{8}$/.test(text)) {
            result.date = text.substring(0, 4) + "-" + text.substring(4, 6) + "-" + text.substring(6, 8)
        }
        return result
    }

    function combinedDueDateTime() {
        if (dueDateText.length === 0) {
            return ""
        }
        if (dueTimeText.length === 0) {
            return dueDateText
        }
        return dueDateText + "T" + dueTimeText + ":00"
    }

    function openDueDateDialog() {
        calendarMonth = dueDateText.length > 0 ? dateFromText(dueDateText) : new Date()
        PopupUtils.open(datePickerDialog)
    }

    function applyDueDate(value) {
        dueDateText = normalizeDateText(value)
        page.dirty = true
        autoSaveTimer.restart()
    }

    function applyDueTime(hour, minute) {
        var normalized = normalizeTimeText(hour, minute)
        dueTimeText = normalized
        if (dueDateText.length === 0 && normalized.length > 0) {
            dueDateText = todayText()
        }
        page.dirty = true
        autoSaveTimer.restart()
    }

    function normalizeDateText(value) {
        var text = String(value || "").trim()
        if (text.length === 0) return ""
        if (/^\d{8}$/.test(text)) return text.substring(0, 4) + "-" + text.substring(4, 6) + "-" + text.substring(6, 8)
        return text
    }

    function normalizeTimeText(hour, minute) {
        var hText = String(hour || "").trim()
        var mText = String(minute || "").trim()
        if (hText.length === 0 && mText.length === 0) return ""
        var h = parseInt(hText, 10)
        var m = parseInt(mText, 10)
        if (isNaN(h)) h = 0
        if (isNaN(m)) m = 0
        if (h < 0) h = 0
        if (h > 23) h = 23
        if (m < 0) m = 0
        if (m > 59) m = 59
        return pad(h) + ":" + pad(m)
    }

    function todayText() {
        return formatDate(new Date())
    }

    function formatDate(date) {
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
    }

    function dateFromText(value) {
        var text = normalizeDateText(value)
        if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return new Date()
        return new Date(parseInt(text.substring(0, 4), 10), parseInt(text.substring(5, 7), 10) - 1, parseInt(text.substring(8, 10), 10))
    }

    function shiftCalendarMonth(delta) {
        calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + delta, 1)
    }

    function monthTitle(date) {
        var names = [i18n.tr("January"), i18n.tr("February"), i18n.tr("March"), i18n.tr("April"), i18n.tr("May"), i18n.tr("June"), i18n.tr("July"), i18n.tr("August"), i18n.tr("September"), i18n.tr("October"), i18n.tr("November"), i18n.tr("December")]
        return names[date.getMonth()] + " " + date.getFullYear()
    }

    function calendarCellDate(index) {
        var first = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1)
        var mondayOffset = (first.getDay() + 6) % 7
        return new Date(calendarMonth.getFullYear(), calendarMonth.getMonth(), 1 - mondayOffset + index)
    }

    function calendarCellDay(index) {
        return String(calendarCellDate(index).getDate())
    }

    function calendarCellText(index) {
        return formatDate(calendarCellDate(index))
    }

    function calendarCellInMonth(index) {
        return calendarCellDate(index).getMonth() === calendarMonth.getMonth()
    }

    function calendarCellToday(index) {
        return calendarCellText(index) === todayText()
    }

    function calendarCellSelected(index) {
        return dueDateText === calendarCellText(index)
    }

    function pad(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function userDisplayName(user) {
        if (user && user.participant) {
            return userDisplayName(user.participant)
        }
        return String(user.displayName || user.displayname || user.uid || user.id || user.userId || i18n.tr("User"))
    }

    function userId(user) {
        if (user && user.participant) {
            return userId(user.participant)
        }
        return String(user.uid || user.userId || user.primaryKey || user.id || user.displayName || user.displayname || "")
    }

    function userInitial(user) {
        var text = userDisplayName(user)
        return text.length > 0 ? text.substring(0, 1).toUpperCase() : "?"
    }

    function userAvatarUrl(user) {
        var id = userId(user)
        if (id.length === 0 || !deckController) {
            return ""
        }
        return deckController.avatarDataUrl(id)
    }

    function commentRows() {
        var comments = (page.card && page.card.comments && page.card.comments.length !== undefined)
            ? page.card.comments.slice(0)
            : []
        comments.sort(function(a, b) {
            var at = commentDate(a).getTime()
            var bt = commentDate(b).getTime()
            if (at !== bt) {
                return at - bt
            }
            return Number(a && a.id ? a.id : 0) - Number(b && b.id ? b.id : 0)
        })

        var rows = []
        var lastKey = ""
        for (var i = 0; i < comments.length; ++i) {
            var comment = comments[i] || {}
            var key = commentDateKey(comment)
            if (key !== lastKey) {
                rows.push({"type": "section", "title": commentSectionTitle(comment), "key": key})
                lastKey = key
            }
            rows.push({"type": "comment", "comment": comment})
        }
        return rows
    }

    function commentKey(comment) {
        var value = comment || {}
        if (value.id) {
            return "id:" + String(value.id)
        }
        return "text:" + String(value.creationDateTime || "") + ":" + commentText(value)
    }

    function isCommentSelected(comment) {
        return page.selectedComments[page.commentKey(comment)] === true
    }

    function selectedCommentCount() {
        var count = 0
        for (var key in page.selectedComments) {
            if (page.selectedComments[key] === true) {
                count += 1
            }
        }
        return count
    }

    function toggleCommentSelection(comment) {
        var key = page.commentKey(comment)
        var selected = {}
        for (var existingKey in page.selectedComments) {
            selected[existingKey] = page.selectedComments[existingKey]
        }
        if (selected[key] === true) {
            delete selected[key]
        } else {
            selected[key] = true
        }
        page.selectedComments = selected
        page.commentSelectionMode = page.selectedCommentCount() > 0
    }

    function clearCommentSelection() {
        page.selectedComments = ({})
        page.commentSelectionMode = false
    }

    function selectedCommentItems() {
        var result = []
        var comments = page.card.comments || []
        for (var i = 0; i < comments.length; ++i) {
            if (page.isCommentSelected(comments[i])) {
                result.push(comments[i])
            }
        }
        return result
    }

    function deleteSelectedComments() {
        var selected = page.selectedCommentItems()
        page.clearCommentSelection()
        deckController.deleteComments(page.card, selected)
    }

    function commentText(comment) {
        var value = String((comment && (comment.message || comment.comment || comment.text)) || "")
        return value.replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
    }

    function commentAuthor(comment) {
        return String((comment && (comment.actorDisplayName || comment.displayName || comment.actorId || comment.userId || comment.uid)) || i18n.tr("User"))
    }

    function commentUserId(comment) {
        return String((comment && (comment.actorId || comment.userId || comment.uid || comment.actorDisplayName || comment.displayName)) || "")
    }

    function commentInitial(comment) {
        var text = commentAuthor(comment)
        return text.length > 0 ? text.substring(0, 1).toUpperCase() : "?"
    }

    function commentAvatarUrl(comment) {
        var id = commentUserId(comment)
        return deckController && id.length > 0 ? deckController.avatarDataUrl(id) : ""
    }

    function requestCommentAvatar(comment) {
        var id = commentUserId(comment)
        if (deckController && id.length > 0) {
            deckController.requestAvatar(id)
        }
    }

    function commentDate(comment) {
        var value = comment && (comment.creationDateTime || comment.creationDate || comment.datetime || comment.dateTime || comment.timestamp || comment.createdAt)
        if (typeof value === "number") {
            return new Date(value > 100000000000 ? value : value * 1000)
        }
        if (value) {
            var parsed = new Date(String(value))
            if (!isNaN(parsed.getTime())) {
                return parsed
            }
        }
        return new Date()
    }

    function commentDateKey(comment) {
        var date = commentDate(comment)
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
    }

    function commentSectionTitle(comment) {
        var date = commentDate(comment)
        var today = new Date()
        var yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1)
        var current = new Date(date.getFullYear(), date.getMonth(), date.getDate())
        var todayOnly = new Date(today.getFullYear(), today.getMonth(), today.getDate())
        if (current.getTime() === todayOnly.getTime()) {
            return i18n.tr("Today")
        }
        if (current.getTime() === yesterday.getTime()) {
            return i18n.tr("Yesterday")
        }
        var months = [i18n.tr("Jan"), i18n.tr("Feb"), i18n.tr("Mar"), i18n.tr("Apr"), i18n.tr("May"), i18n.tr("Jun"), i18n.tr("Jul"), i18n.tr("Aug"), i18n.tr("Sep"), i18n.tr("Oct"), i18n.tr("Nov"), i18n.tr("Dec")]
        return pad(date.getDate()) + " " + months[date.getMonth()] + " " + date.getFullYear()
    }

    function commentTime(comment) {
        var date = commentDate(comment)
        return pad(date.getHours()) + ":" + pad(date.getMinutes())
    }

    function activityItems() {
        return (page.card && page.card.activities && page.card.activities.length !== undefined)
            ? page.card.activities
            : []
    }

    function activityRows() {
        var activities = page.activityItems().slice(0)
        activities.sort(function(a, b) {
            var at = page.activityDate(a).getTime()
            var bt = page.activityDate(b).getTime()
            if (at !== bt) {
                return bt - at
            }
            return Number(b && (b.id || b.activity_id) ? (b.id || b.activity_id) : 0)
                - Number(a && (a.id || a.activity_id) ? (a.id || a.activity_id) : 0)
        })

        var rows = []
        var lastKey = ""
        for (var i = 0; i < activities.length; ++i) {
            var activity = activities[i] || {}
            var key = page.activityDateKey(activity)
            if (key !== lastKey) {
                rows.push({"type": "section", "title": page.activitySectionTitle(activity), "key": key})
                lastKey = key
            }
            rows.push({"type": "activity", "activity": activity})
        }
        return rows
    }

    function activityText(activity) {
        var text = String((activity && (activity.subject || activity.subjectText || activity.message)) || "")
        return text.replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]*>/g, "")
    }

    function activityDate(activity) {
        var value = activity && (activity.datetime || activity.dateTime || activity.timestamp || activity.createdAt)
        if (typeof value === "number") {
            return new Date(value > 100000000000 ? value : value * 1000)
        }
        if (value) {
            var parsed = new Date(String(value))
            if (!isNaN(parsed.getTime())) {
                return parsed
            }
        }
        return new Date()
    }

    function activityDateKey(activity) {
        var date = page.activityDate(activity)
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
    }

    function activitySectionTitle(activity) {
        var date = page.activityDate(activity)
        var today = new Date()
        var yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1)
        var current = new Date(date.getFullYear(), date.getMonth(), date.getDate())
        var todayOnly = new Date(today.getFullYear(), today.getMonth(), today.getDate())
        if (current.getTime() === todayOnly.getTime()) {
            return i18n.tr("Today")
        }
        if (current.getTime() === yesterday.getTime()) {
            return i18n.tr("Yesterday")
        }
        var months = [i18n.tr("Jan"), i18n.tr("Feb"), i18n.tr("Mar"), i18n.tr("Apr"), i18n.tr("May"), i18n.tr("Jun"), i18n.tr("Jul"), i18n.tr("Aug"), i18n.tr("Sep"), i18n.tr("Oct"), i18n.tr("Nov"), i18n.tr("Dec")]
        return pad(date.getDate()) + " " + months[date.getMonth()] + " " + date.getFullYear()
    }

    function activityTime(activity) {
        var date = page.activityDate(activity)
        return pad(date.getHours()) + ":" + pad(date.getMinutes())
    }

    function activitySymbol(activity) {
        var icon = String((activity && activity.icon) || "").toLowerCase()
        if (icon.indexOf("comment") >= 0) return "\uD83D\uDCAC"
        if (icon.indexOf("files") >= 0 || icon.indexOf("attachment") >= 0) return "\uD83D\uDCCE"
        if (icon.indexOf("delete") >= 0) return "\u2212"
        if (icon.indexOf("add") >= 0) return "+"
        if (icon.indexOf("tag") >= 0) return "\u25CF"
        if (icon.indexOf("archive") >= 0) return "\u25A3"
        return "\u26A1"
    }

    function activityIconColor(activity) {
        var icon = String((activity && activity.icon) || "").toLowerCase()
        if (icon.indexOf("delete") >= 0) return "#c23b3b"
        if (icon.indexOf("add") >= 0) return "#3f8f45"
        if (icon.indexOf("comment") >= 0) return "#2c7fb8"
        if (icon.indexOf("files") >= 0 || icon.indexOf("attachment") >= 0) return "#7a5fb5"
        if (icon.indexOf("tag") >= 0) return "#b37a2a"
        return "#5a6670"
    }

    function sendComment() {
        if (!deckController || deckController.loading) {
            return
        }
        Qt.inputMethod.commit()
        newCommentField.focus = false
        commentCommitTimer.restart()
    }

    function sendCommittedComment() {
        if (!deckController || deckController.loading) {
            return
        }
        var text = String(newCommentField.text || page.newCommentText || "").trim()
        if (text.length === 0) {
            return
        }
        page.newCommentText = ""
        deckController.addComment(page.card, text)
    }

    function objectKeys(object) {
        var result = []
        for (var key in (object || {})) {
            result.push(key)
        }
        return result
    }

    function visibleUserOptions() {
        var query = assignmentUserId.trim().toLowerCase()
        var all = knownUsers()
        var result = []
        for (var i = 0; i < all.length; ++i) {
            var id = userId(all[i]).toLowerCase()
            var label = userDisplayName(all[i]).toLowerCase()
            if (query.length === 0 || id.indexOf(query) >= 0 || label.indexOf(query) >= 0) {
                result.push(all[i])
            }
        }
        return result.slice(0, 8)
    }

    function userSuggestions() {
        return visibleUserOptions()
    }

    function assignUser(user) {
        var id = userId(user)
        if (id.length === 0) {
            return
        }
        var updated = page.updateAssignedUserLocal(user, true)
        deckController.assignUser(updated, id, true)
        assignmentUserId = ""
        assignmentPickerVisible = false
        assignmentField.focus = false
    }

    function unassignUser(user) {
        var id = userId(user)
        if (id.length === 0) {
            return
        }
        var updated = page.updateAssignedUserLocal(user, false)
        deckController.assignUser(updated, id, false)
    }

    function updateAssignedUserLocal(user, assign) {
        var id = userId(user)
        var updated = {}
        for (var key in page.card) {
            updated[key] = page.card[key]
        }
        var current = page.card.assignedUsers || []
        var users = []
        var found = false
        for (var i = 0; i < current.length; ++i) {
            var existing = current[i]
            if (userId(existing) === id) {
                found = true
                if (assign) {
                    users.push(existing)
                }
            } else {
                users.push(existing)
            }
        }
        if (assign && !found) {
            users.push(user)
        }
        updated.assignedUsers = users
        updated._assignedUsersAuthoritative = true
        page.card = updated
        return updated
    }

    function knownUsers() {
        var seen = {}
        var result = []
        function addUser(user) {
            var id = page.userId(user)
            if (id.length === 0 || seen[id]) return
            seen[id] = true
            result.push(user)
        }
        if (deckController && String(deckController.currentUserName || "").length > 0) {
            addUser({"uid": deckController.currentUserName, "displayName": deckController.currentUserName})
        }
        var owner = page.card.owner || []
        if (owner.length !== undefined) {
            for (var o = 0; o < owner.length; ++o) addUser(owner[o])
        } else {
            addUser(owner)
        }
        var current = page.card.assignedUsers || []
        for (var c = 0; c < current.length; ++c) {
            addUser(current[c])
        }
        if (!deckController) return result
        var entries = deckController.entries || []
        for (var i = 0; i < entries.length; ++i) {
            var users = entries[i].assignedUsers || []
            for (var u = 0; u < users.length; ++u) {
                addUser(users[u])
            }
        }
        return result
    }

    function cardDone() {
        var value = page.card.done
        return value !== null && value !== undefined && String(value).length > 0 && String(value) !== "0"
    }

    function setCardDone(done) {
        var updated = {}
        for (var key in page.card) {
            updated[key] = page.card[key]
        }
        updated.title = headerTitleField.text.trim().length > 0 ? headerTitleField.text.trim() : i18n.tr("Untitled card")
        updated.description = descriptionArea.text
        updated.duedate = combinedDueDateTime()
        updated.detail = updated.duedate
        updated.done = done ? currentIsoDateTime() : null
        page.card = updated
        deckController.saveCard(updated)
    }

    function currentIsoDateTime() {
        var now = new Date()
        return now.getFullYear() + "-" + pad(now.getMonth() + 1) + "-" + pad(now.getDate())
            + "T" + pad(now.getHours()) + ":" + pad(now.getMinutes()) + ":" + pad(now.getSeconds())
    }

    Component.onCompleted: {
        headerTitleField.text = page.card.title || ""
        applyDueFromCard(page.card)
        if (page.card && page.card.id) {
            deckController.loadCardDetails(page.card)
        }
    }

    Component.onDestruction: {
        if (deckController && deckController.selectedBoardId > 0) {
            deckController.refresh()
        }
    }
}
