import QtQuick 2.7
import Qt.labs.settings 1.0
import "qrc:/NextCommon" as NextCommon

Item {
    id: controller
    property bool loading: false
    property string statusText: i18n.tr("Select an account to load Deck boards.")
    property string syncStateText: i18n.tr("No account")
    property string syncStateColor: "#b37a2a"
    property string accountAvatarUrl: accountSettings.avatarUrl || ""
    property string accountServerUrl: accountSettings.serverUrl || ""
    property var entries: []
    property var cachedBoards: []
    property string viewMode: "boards"
    property string titleText: i18n.tr("Boards")
    property int selectedBoardId: 0
    property string selectedBoardTitle: ""
    property var selectedBoardLabels: []
    property string activeAccountKey: ""
    property string currentUserName: ""
    property bool applyingAccountSelection: false
    property bool settingsReady: false
    property int accountRequestGeneration: 0
    property bool skipNextCachedLoad: false
    property int dirtyCount: 0
    property int conflictCount: 0
    property bool dirtySyncRunning: false
    property var dirtySyncQueue: []
    property var activeDirtyCard: ({})
    property string pendingOperation: ""
    property bool refreshBoardsFirst: false
    property var pendingCardUpdate: ({})
    property var pendingCardCreate: ({})
    property var pendingCardDelete: ({})
    property var pendingCardReorder: ({})
    property var pendingCardArchive: ({})
    property var pendingBoardOperation: ({})
    property var pendingStackOperation: ({})
    property var pendingAccessControlOperation: ({})
    property var pendingCardDetails: ({})
    property var pendingLabelOperation: ({})
    property var pendingUserOperation: ({})
    property var pendingAttachmentOperation: ({})
    property var pendingAttachmentDeleteQueue: []
    property var pendingCommentOperation: ({})
    property var pendingCommentDeleteQueue: []
    property var avatarDataUrls: ({})
    property var avatarRequests: ({})
    property var sharees: []

    signal attachmentReadyToOpen(string fileUrl, string fileName, string mimeType)

    Settings {
        id: accountSettings
        category: "account"
        property int accountId: 0
        property string displayName: ""
        property string providerId: ""
        property string serviceId: ""
        property string serverUrl: ""
        property string avatarUrl: ""
        property int lastBoardId: 0
        property string lastBoardTitle: ""
        property string lastBoardByAccountJson: "{}"

        onAccountIdChanged: if (controller.settingsReady && !controller.applyingAccountSelection) controller.handleAccountChanged()
        onProviderIdChanged: if (controller.settingsReady && !controller.applyingAccountSelection) controller.handleAccountChanged()
        onServiceIdChanged: if (controller.settingsReady && !controller.applyingAccountSelection) controller.handleAccountChanged()
        onServerUrlChanged: if (controller.settingsReady && !controller.applyingAccountSelection) controller.handleAccountChanged()
    }

    NextCommon.AccountSessionAdapter {
        id: session
        logPrefix: "NextDeck"
        onAuthenticated: function(userName, secret, serverUrl, accountId, serviceId) {
            if (!controller.isCurrentAccountResponse(accountId, serviceId, serverUrl)) {
                return
            }
            controller.accountAvatarUrl = avatarUrl(serverUrl, userName)
            controller.currentUserName = userName
            if (controller.accountAvatarUrl.length > 0) {
                accountSettings.avatarUrl = controller.accountAvatarUrl
            }
            controller.activeAccountKey = controller.accountKey()
            if (controller.dirtySyncRunning) {
                controller.uploadNextDirty(userName, secret, serverUrl)
            } else if (controller.pendingOperation === "createBoard" && controller.pendingBoardOperation && controller.pendingBoardOperation.title) {
                var boardCreate = controller.pendingBoardOperation
                controller.pendingOperation = ""
                controller.pendingBoardOperation = ({})
                api.createBoard(serverUrl, userName, secret, boardCreate.title, boardCreate.color)
            } else if (controller.pendingOperation === "updateBoard" && controller.pendingBoardOperation && controller.pendingBoardOperation.id) {
                var boardUpdate = controller.pendingBoardOperation
                controller.pendingOperation = ""
                controller.pendingBoardOperation = ({})
                api.updateBoard(serverUrl, userName, secret, boardUpdate)
            } else if (controller.pendingOperation === "deleteBoard" && controller.pendingBoardOperation && controller.pendingBoardOperation.id) {
                var boardDelete = controller.pendingBoardOperation
                controller.pendingOperation = ""
                controller.pendingBoardOperation = ({})
                api.deleteBoard(serverUrl, userName, secret, boardDelete.id)
            } else if (controller.pendingOperation === "createStack" && controller.pendingStackOperation && controller.pendingStackOperation.boardId) {
                var stackCreate = controller.pendingStackOperation
                controller.pendingOperation = ""
                controller.pendingStackOperation = ({})
                api.createStack(serverUrl, userName, secret, stackCreate.boardId, stackCreate.title)
            } else if (controller.pendingOperation === "updateStack" && controller.pendingStackOperation && controller.pendingStackOperation.stackId) {
                var stackUpdate = controller.pendingStackOperation
                controller.pendingOperation = ""
                controller.pendingStackOperation = ({})
                api.updateStack(serverUrl, userName, secret, stackUpdate)
            } else if (controller.pendingOperation === "deleteStack" && controller.pendingStackOperation && controller.pendingStackOperation.stackId) {
                var stackDelete = controller.pendingStackOperation
                controller.pendingOperation = ""
                controller.pendingStackOperation = ({})
                api.deleteStack(serverUrl, userName, secret, stackDelete.boardId, stackDelete.stackId)
            } else if (controller.pendingOperation === "searchSharees") {
                var shareeSearch = controller.pendingAccessControlOperation
                controller.pendingOperation = ""
                controller.pendingAccessControlOperation = ({})
                api.searchSharees(serverUrl, userName, secret, shareeSearch.query || "")
            } else if (controller.pendingOperation === "createAccessControl") {
                var createAcl = controller.pendingAccessControlOperation
                controller.pendingOperation = ""
                controller.pendingAccessControlOperation = ({})
                api.createAccessControl(serverUrl, userName, secret, createAcl.board, createAcl.sharee)
            } else if (controller.pendingOperation === "updateAccessControl") {
                var updateAcl = controller.pendingAccessControlOperation
                controller.pendingOperation = ""
                controller.pendingAccessControlOperation = ({})
                api.updateAccessControl(serverUrl, userName, secret, updateAcl.board, updateAcl.acl)
            } else if (controller.pendingOperation === "deleteAccessControl") {
                var deleteAcl = controller.pendingAccessControlOperation
                controller.pendingOperation = ""
                controller.pendingAccessControlOperation = ({})
                api.deleteAccessControl(serverUrl, userName, secret, deleteAcl.board, deleteAcl.acl)
            } else if (controller.pendingOperation === "loadCardDetails" && controller.pendingCardDetails && controller.pendingCardDetails.id) {
                var details = controller.pendingCardDetails
                controller.pendingOperation = ""
                controller.pendingCardDetails = ({})
                api.loadCardDetails(serverUrl, userName, secret, details)
            } else if (controller.pendingOperation === "loadComments" && controller.pendingCardDetails && controller.pendingCardDetails.id) {
                var comments = controller.pendingCardDetails
                controller.pendingOperation = ""
                controller.pendingCardDetails = ({})
                api.loadComments(serverUrl, userName, secret, comments)
            } else if (controller.pendingOperation === "loadActivities" && controller.pendingCardDetails && controller.pendingCardDetails.id) {
                var activities = controller.pendingCardDetails
                controller.pendingOperation = ""
                controller.pendingCardDetails = ({})
                api.loadActivities(serverUrl, userName, secret, activities)
            } else if (controller.pendingOperation === "loadAttachments" && controller.pendingCardDetails && controller.pendingCardDetails.id) {
                var attachments = controller.pendingCardDetails
                controller.pendingOperation = ""
                controller.pendingCardDetails = ({})
                api.loadAttachments(serverUrl, userName, secret, attachments)
            } else if (controller.pendingOperation === "uploadAttachment" && controller.pendingAttachmentOperation && controller.pendingAttachmentOperation.card) {
                var attachmentOp = controller.pendingAttachmentOperation
                controller.pendingOperation = ""
                controller.pendingAttachmentOperation = ({})
                api.uploadAttachment(serverUrl, userName, secret, attachmentOp.card, attachmentOp.fileUrl, attachmentOp.fileName || "")
            } else if (controller.pendingOperation === "deleteAttachment" && controller.pendingAttachmentOperation && controller.pendingAttachmentOperation.card) {
                var deleteAttachmentOp = controller.pendingAttachmentOperation
                controller.pendingOperation = ""
                controller.pendingAttachmentOperation = ({})
                api.deleteAttachment(serverUrl, userName, secret, deleteAttachmentOp.card, deleteAttachmentOp.attachment)
            } else if (controller.pendingOperation === "downloadAttachment" && controller.pendingAttachmentOperation && controller.pendingAttachmentOperation.card) {
                var downloadAttachmentOp = controller.pendingAttachmentOperation
                controller.pendingOperation = ""
                controller.pendingAttachmentOperation = ({})
                api.downloadAttachment(serverUrl, userName, secret, downloadAttachmentOp.card, downloadAttachmentOp.attachment)
            } else if (controller.pendingOperation === "addComment" && controller.pendingCardDetails && controller.pendingCardDetails.id) {
                var commentCard = controller.pendingCardDetails
                controller.pendingOperation = ""
                controller.pendingCardDetails = ({})
                api.addComment(serverUrl, userName, secret, commentCard, commentCard.newComment || "")
            } else if (controller.pendingOperation === "deleteComment" && controller.pendingCommentOperation && controller.pendingCommentOperation.card) {
                var deleteCommentOp = controller.pendingCommentOperation
                controller.pendingOperation = ""
                controller.pendingCommentOperation = ({})
                api.deleteComment(serverUrl, userName, secret, deleteCommentOp.card, deleteCommentOp.comment)
            } else if (controller.pendingOperation === "assignLabel" && controller.pendingLabelOperation && controller.pendingLabelOperation.card) {
                var labelOp = controller.pendingLabelOperation
                controller.pendingOperation = ""
                controller.pendingLabelOperation = ({})
                api.assignLabel(serverUrl, userName, secret, labelOp.card, labelOp.labelId, labelOp.assign)
            } else if (controller.pendingOperation === "createLabel" && controller.pendingLabelOperation && controller.pendingLabelOperation.boardId) {
                var createLabelOp = controller.pendingLabelOperation
                controller.pendingOperation = ""
                controller.pendingLabelOperation = ({})
                api.createLabel(serverUrl, userName, secret, createLabelOp.boardId, createLabelOp.title, createLabelOp.color)
            } else if (controller.pendingOperation === "deleteLabel" && controller.pendingLabelOperation && controller.pendingLabelOperation.boardId) {
                var deleteLabelOp = controller.pendingLabelOperation
                controller.pendingOperation = ""
                controller.pendingLabelOperation = ({})
                api.deleteLabel(serverUrl, userName, secret, deleteLabelOp.boardId, deleteLabelOp.labelId)
            } else if (controller.pendingOperation === "assignUser" && controller.pendingUserOperation && controller.pendingUserOperation.card) {
                var userOp = controller.pendingUserOperation
                controller.pendingOperation = ""
                controller.pendingUserOperation = ({})
                api.assignUser(serverUrl, userName, secret, userOp.card, userOp.userId, userOp.assign)
            } else if (controller.pendingOperation === "createCard" && controller.pendingCardCreate && controller.pendingCardCreate.stackId) {
                var create = controller.pendingCardCreate
                controller.pendingOperation = ""
                controller.pendingCardCreate = ({})
                controller.activeDirtyCard = create
                api.createCard(serverUrl, userName, secret, create.boardId, create.stackId, create.stackTitle, create.title)
            } else if (controller.pendingOperation === "updateCard" && controller.pendingCardUpdate && controller.pendingCardUpdate.id) {
                var update = controller.pendingCardUpdate
                controller.pendingOperation = ""
                controller.pendingCardUpdate = ({})
                controller.activeDirtyCard = update
                api.updateCard(serverUrl, userName, secret, update)
            } else if (controller.pendingOperation === "deleteCard" && controller.pendingCardDelete && controller.pendingCardDelete.id) {
                var remove = controller.pendingCardDelete
                controller.pendingOperation = ""
                controller.pendingCardDelete = ({})
                controller.activeDirtyCard = remove
                api.deleteCard(serverUrl, userName, secret, remove)
            } else if (controller.pendingOperation === "archiveCard" && controller.pendingCardArchive && controller.pendingCardArchive.card) {
                var archive = controller.pendingCardArchive
                controller.pendingOperation = ""
                controller.pendingCardArchive = ({})
                api.archiveCard(serverUrl, userName, secret, archive.card, archive.archived)
            } else if (controller.pendingOperation === "reorderCard" && controller.pendingCardReorder && controller.pendingCardReorder.card) {
                var reorder = controller.pendingCardReorder
                controller.pendingOperation = ""
                controller.pendingCardReorder = ({})
                api.reorderCard(serverUrl, userName, secret, reorder.card, reorder.newPosition)
            } else if (controller.refreshBoardsFirst) {
                controller.refreshBoardsFirst = false
                api.loadBoards(serverUrl, userName, secret)
            } else if (controller.viewMode === "cards" && controller.selectedBoardId > 0) {
                api.loadBoard(serverUrl, userName, secret, controller.selectedBoardId, controller.selectedBoardTitle, true)
            } else {
                api.loadBoards(serverUrl, userName, secret)
            }
        }
        onFailed: {
            controller.loading = false
            controller.statusText = message
            controller.syncStateText = i18n.tr("Authentication failed")
            controller.syncStateColor = "#b37a2a"
        }
    }

    DeckApiClient {
        id: api
        onBoardsLoaded: function(entries, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.entries = entries
            cache.saveBoards(entries)
            controller.cachedBoards = entries
            controller.loading = false
            controller.statusText = entries.length > 0 ? i18n.tr("Loaded %1 item(s).").arg(entries.length) : i18n.tr("No items found.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
            controller.syncDirtySoon()
            controller.openPreferredBoard(entries)
        }
        onCardsLoaded: function(boardTitle, entries, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.entries = entries
            cache.saveBoardEntries(controller.selectedBoardId, entries)
            controller.viewMode = "cards"
            controller.titleText = boardTitle
            controller.loading = false
            controller.statusText = entries.length > 0 ? i18n.tr("Loaded %1 item(s).").arg(entries.length) : i18n.tr("No cards found.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
            controller.syncDirtySoon()
        }
        onBoardCreated: function(board, generation) {
            if (!controller.isCurrentApiGeneration(generation)) return
            controller.loading = false
            controller.statusText = i18n.tr("Board created.")
            controller.replaceBoardEntry(board)
            cache.saveBoards(controller.cachedBoards)
            controller.openBoard(board.id, board.title || i18n.tr("Board"), board.labels || [])
            refreshTimer.restart()
        }
        onBoardUpdated: function(board, generation) {
            if (!controller.isCurrentApiGeneration(generation)) return
            controller.loading = false
            controller.statusText = i18n.tr("Board saved.")
            var updatedBoard = board || ({})
            if (controller.pendingBoardOperation && controller.pendingBoardOperation.id) {
                if (controller.pendingBoardOperation.archived === true || controller.pendingBoardOperation.archived === false) {
                    updatedBoard.archived = controller.pendingBoardOperation.archived === true
                }
            }
            controller.replaceBoardEntry(updatedBoard)
            cache.saveBoards(controller.cachedBoards)
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            refreshTimer.restart()
        }
        onBoardDeleted: function(boardId, generation) {
            if (!controller.isCurrentApiGeneration(generation)) return
            controller.loading = false
            controller.statusText = i18n.tr("Board deleted.")
            controller.removeBoardEntry(boardId)
            cache.saveBoards(controller.cachedBoards)
            if (Number(controller.selectedBoardId || 0) === Number(boardId || 0)) {
                controller.goBackToBoards()
            }
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            refreshTimer.restart()
        }
        onBoardAccessUpdated: function(board, message, generation) {
            if (!controller.isCurrentApiGeneration(generation)) return
            controller.loading = false
            controller.replaceBoardEntry(board)
            cache.saveBoards(controller.cachedBoards)
            controller.statusText = message || i18n.tr("Board sharing updated.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
        }
        onShareesLoaded: function(sharees, generation) {
            if (!controller.isCurrentApiGeneration(generation)) return
            controller.loading = false
            controller.sharees = sharees || []
            controller.statusText = controller.sharees.length > 0
                ? i18n.tr("Found %1 share recipient(s).").arg(controller.sharees.length)
                : i18n.tr("No share recipients found.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
        }
        onStackCreated: function(stack, generation) {
            if (!controller.isCurrentApiGeneration(generation)) return
            controller.loading = false
            controller.statusText = i18n.tr("List created.")
            controller.openBoard(controller.selectedBoardId, controller.selectedBoardTitle)
        }
        onStackUpdated: function(stack, generation) {
            if (!controller.isCurrentApiGeneration(generation)) return
            controller.loading = false
            controller.statusText = i18n.tr("List saved.")
            controller.openBoard(controller.selectedBoardId, controller.selectedBoardTitle)
        }
        onStackDeleted: function(stackId, generation) {
            if (!controller.isCurrentApiGeneration(generation)) return
            controller.loading = false
            controller.statusText = i18n.tr("List deleted.")
            controller.openBoard(controller.selectedBoardId, controller.selectedBoardTitle)
        }
        onAvatarLoaded: function(userId, dataUrl, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var id = String(userId || "")
            if (id.length === 0 || String(dataUrl || "").length === 0) {
                return
            }
            var updatedUrls = controller.cloneObject(controller.avatarDataUrls)
            updatedUrls[id] = dataUrl
            controller.avatarDataUrls = updatedUrls
            var updatedRequests = controller.cloneObject(controller.avatarRequests)
            updatedRequests[id] = "loaded"
            controller.avatarRequests = updatedRequests
        }
        onAvatarFailed: function(userId, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var id = String(userId || "")
            if (id.length === 0) {
                return
            }
            var updatedRequests = controller.cloneObject(controller.avatarRequests)
            updatedRequests[id] = "failed"
            controller.avatarRequests = updatedRequests
        }
        onCardCreated: function(card, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            if (controller.activeDirtyCard && controller.activeDirtyCard.localKey) {
                cache.removeCard(controller.activeDirtyCard)
                controller.removeCardEntryByKey(controller.activeDirtyCard.localKey)
            }
            cache.markClean(card)
            controller.insertCardEntry(card)
            controller.loading = false
            controller.statusText = i18n.tr("Card created.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
            controller.continueDirtySyncIfNeeded()
        }
        onCardUpdated: function(card, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            cache.markClean(card)
            controller.replaceCardEntry(card)
            controller.loading = false
            controller.statusText = i18n.tr("Card saved.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
            controller.continueDirtySyncIfNeeded()
        }
        onCardReordered: function(card, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.loading = false
            controller.statusText = i18n.tr("Card order saved.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
        }
        onCardDeleted: function(cardId, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            cache.removeCard(cardId)
            controller.removeCardEntry(cardId)
            controller.loading = false
            controller.statusText = i18n.tr("Card deleted.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
            controller.continueDirtySyncIfNeeded()
        }
        onCardArchived: function(card, archived, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var updated = controller.mergeCardWithExisting(card)
            updated.archived = archived === true
            cache.markClean(updated)
            controller.replaceCardEntry(updated)
            controller.loading = false
            controller.statusText = updated.archived ? i18n.tr("Card archived.") : i18n.tr("Card restored.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
        }
        onCardDetailsLoaded: function(card, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var merged = controller.mergeCardWithExisting(card)
            cache.markClean(merged)
            controller.replaceCardEntry(merged)
            controller.loading = false
            controller.statusText = i18n.tr("Card loaded.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
        }
        onAttachmentUploaded: function(card, attachment, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var updated = controller.mergeCardWithExisting(card)
            var attachments = updated.attachments || []
            attachments = attachments.slice(0)
            attachments.unshift(attachment || {})
            updated.attachments = attachments
            updated.attachmentCount = attachments.length
            cache.markClean(updated)
            controller.replaceCardEntry(updated)
            controller.loading = false
            controller.statusText = i18n.tr("Attachment uploaded.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
        }
        onAttachmentDeleted: function(card, attachment, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var updated = controller.mergeCardWithExisting(card)
            var attachments = []
            var deletedKey = controller.attachmentKey(attachment)
            var current = updated.attachments || []
            for (var i = 0; i < current.length; ++i) {
                if (controller.attachmentKey(current[i]) !== deletedKey) {
                    attachments.push(current[i])
                }
            }
            updated.attachments = attachments
            updated.attachmentCount = attachments.length
            cache.markClean(updated)
            controller.replaceCardEntry(updated)
            controller.statusText = i18n.tr("Attachment removed.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
            controller.deleteNextAttachmentIfNeeded(updated)
        }
        onAttachmentDownloaded: function(card, attachment, fileUrl, fileName, mimeType, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            controller.loading = false
            controller.statusText = i18n.tr("Attachment ready.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.attachmentReadyToOpen(fileUrl, fileName, mimeType)
        }
        onCommentDeleted: function(card, comment, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var updated = controller.mergeCardWithExisting(card)
            var comments = []
            var deletedKey = controller.commentKey(comment)
            var current = updated.comments || []
            for (var i = 0; i < current.length; ++i) {
                if (controller.commentKey(current[i]) !== deletedKey) {
                    comments.push(current[i])
                }
            }
            updated.comments = comments
            updated.commentsCount = comments.length
            cache.markClean(updated)
            controller.replaceCardEntry(updated)
            controller.statusText = i18n.tr("Comment deleted.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
            controller.deleteNextCommentIfNeeded(updated)
        }
        onActivitiesLoaded: function(card, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            var updated = controller.mergeCardWithExisting(card)
            cache.markClean(updated)
            controller.replaceCardEntry(updated)
            controller.loading = false
            controller.statusText = i18n.tr("Activity loaded.")
            controller.syncStateText = i18n.tr("Up to date")
            controller.syncStateColor = "#5a8f3c"
            controller.updateLocalCounts()
        }
        onCardConflict: function(card, serverCard, message, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            cache.markConflict(card, serverCard)
            controller.replaceCardEntry(markCardConflict(card, serverCard))
            controller.loading = false
            controller.statusText = message
            controller.syncStateText = i18n.tr("Conflict")
            controller.syncStateColor = "#c23b3b"
            controller.updateLocalCounts()
            controller.continueDirtySyncIfNeeded()
        }
        onFailed: function(message, generation) {
            if (!controller.isCurrentApiGeneration(generation)) {
                return
            }
            if (controller.pendingAttachmentDeleteQueue.length > 0) {
                controller.pendingAttachmentDeleteQueue = []
            }
            if (controller.pendingCommentDeleteQueue.length > 0) {
                controller.pendingCommentDeleteQueue = []
            }
            controller.loading = false
            controller.statusText = message
            controller.syncStateText = i18n.tr("Sync failed")
            controller.syncStateColor = "#c23b3b"
            controller.updateLocalCounts()
        }
    }

    DeckCache {
        id: cache
    }

    function refresh() {
        if (!hasCompleteAccountSettings()) {
            clearAccountData()
            return
        }
        refreshBoardsFirst = false
        session.setAccount(effectiveAccountId(), effectiveProviderId(), effectiveServiceId(), effectiveServerUrl())
        api.requestGeneration = accountRequestGeneration
        var key = accountKey()
        cache.setScope(key)
        if (key !== activeAccountKey) {
            clearAccountData()
            activeAccountKey = key
            skipNextCachedLoad = true
        }
        if (skipNextCachedLoad) {
            cache.clearCleanServerDataForCurrentScope()
            skipNextCachedLoad = false
            entries = []
            cachedBoards = []
            statusText = i18n.tr("Account changed. Refreshing...")
        } else {
            if (viewMode === "cards" && selectedBoardId > 0) {
                var cachedCards = cache.loadBoardEntries(selectedBoardId, selectedBoardTitle, true)
                if (cachedCards.length > 0) {
                    entries = cachedCards
                    statusText = i18n.tr("Showing cached cards. Refreshing...")
                }
            } else {
                var cachedBoards = cache.loadBoards()
                if (cachedBoards.length > 0) {
                    controller.cachedBoards = cachedBoards
                    entries = cachedBoards
                    statusText = i18n.tr("Showing cached boards. Refreshing...")
                }
            }
        }
        updateLocalCounts()
        loading = true
        if (statusText.length === 0 || statusText === i18n.tr("Select an account to load Deck boards.")) {
            statusText = i18n.tr("Loading...")
        }
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        session.authenticate()
    }

    function refreshAll() {
        if (!hasCompleteAccountSettings()) {
            clearAccountData()
            return
        }
        refreshBoardsFirst = true
        session.setAccount(effectiveAccountId(), effectiveProviderId(), effectiveServiceId(), effectiveServerUrl())
        api.requestGeneration = accountRequestGeneration
        var key = accountKey()
        cache.setScope(key)
        if (key !== activeAccountKey) {
            clearAccountData()
            activeAccountKey = key
            skipNextCachedLoad = true
        }
        if (skipNextCachedLoad) {
            cache.clearCleanServerDataForCurrentScope()
            skipNextCachedLoad = false
            entries = []
            cachedBoards = []
            statusText = i18n.tr("Account changed. Refreshing...")
        } else {
            var cachedBoardsForMenu = cache.loadBoards()
            if (cachedBoardsForMenu.length > 0) {
                cachedBoards = cachedBoardsForMenu
                if (viewMode !== "cards") {
                    entries = cachedBoardsForMenu
                }
                statusText = i18n.tr("Showing cached boards. Refreshing...")
            }
        }
        updateLocalCounts()
        loading = true
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        session.authenticate()
    }

    function openBoard(boardId, boardTitle, labels) {
        selectedBoardId = boardId || 0
        selectedBoardTitle = boardTitle || i18n.tr("Board")
        selectedBoardLabels = labels || []
        if (selectedBoardId > 0) {
            saveLastBoardForCurrentAccount(selectedBoardId, selectedBoardTitle)
        }
        viewMode = "cards"
        titleText = selectedBoardTitle
        cache.setScope(accountKey())
        entries = cache.loadBoardEntries(selectedBoardId, selectedBoardTitle, true)
        loading = true
        statusText = entries.length > 0 ? i18n.tr("Showing cached cards. Refreshing...") : i18n.tr("Loading...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function openPreferredBoard(boards) {
        var source = boards || cachedBoards || []
        if (!source || source.length === 0) {
            viewMode = "boards"
            titleText = i18n.tr("Boards")
            entries = []
            return
        }
        var fallback = ({})
        var preferred = ({})
        var scopedLastBoard = lastBoardForCurrentAccount()
        for (var i = 0; i < source.length; ++i) {
            var board = source[i]
            if (board.type !== "board") continue
            if (!fallback.id) fallback = board
            if (Number(board.id || 0) === Number(scopedLastBoard.id || 0)) {
                preferred = board
                break
            }
        }
        var selected = preferred.id ? preferred : fallback
        if (selected && selected.id) {
            openBoard(selected.id, selected.title || scopedLastBoard.title || i18n.tr("Board"), selected.labels || [])
        }
    }

    function lastBoardMap() {
        try {
            return JSON.parse(accountSettings.lastBoardByAccountJson || "{}")
        } catch (e) {
            return {}
        }
    }

    function saveLastBoardForCurrentAccount(boardId, boardTitle) {
        var key = accountKey()
        if (key.length === 0 || Number(boardId || 0) <= 0) {
            return
        }
        var map = lastBoardMap()
        map[key] = {
            "id": Number(boardId),
            "title": String(boardTitle || "")
        }
        accountSettings.lastBoardByAccountJson = JSON.stringify(map)
    }

    function lastBoardForCurrentAccount() {
        var map = lastBoardMap()
        var value = map[accountKey()] || {}
        return {
            "id": Number(value.id || 0),
            "title": String(value.title || "")
        }
    }

    function goBackToBoards() {
        selectedBoardId = 0
        selectedBoardTitle = ""
        selectedBoardLabels = []
        viewMode = "boards"
        titleText = i18n.tr("Boards")
        refresh()
    }

    function saveCard(card) {
        if (!card || (!card.id && !card.localKey)) {
            statusText = i18n.tr("Card update data is incomplete.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        var status = Number(card.id || 0) > 0 ? cache.statusEdited : cache.statusCreated
        card.localStatus = status
        card.dirty = true
        cache.saveLocalCard(card, status)
        replaceCardEntry(card)
        updateLocalCounts()
        pendingOperation = "updateCard"
        pendingCardUpdate = card
        loading = true
        statusText = i18n.tr("Saving card...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function resolveConflictUseServer(card) {
        if (!card || (!card.id && !card.localKey)) {
            statusText = i18n.tr("Conflict data is incomplete.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        cache.resolveConflictUseServer(card)
        var resolved = cloneObject(card)
        try {
            var server = JSON.parse(card.serverJson || "{}")
            if (server && server.id) {
                resolved = server
            }
        } catch (e) {
            resolved = cloneObject(card)
        }
        resolved.conflict = false
        resolved.dirty = false
        resolved.localStatus = cache.statusClean
        replaceCardEntry(resolved)
        loading = false
        statusText = i18n.tr("Server version kept.")
        syncStateText = i18n.tr("Up to date")
        syncStateColor = "#5a8f3c"
        updateLocalCounts()
    }

    function resolveConflictKeepLocal(card) {
        if (!card || (!card.id && !card.localKey)) {
            statusText = i18n.tr("Conflict data is incomplete.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        var local = cloneObject(card)
        local.conflict = false
        local.serverJson = ""
        local.localStatus = Number(local.id || 0) > 0 ? cache.statusEdited : cache.statusCreated
        local.dirty = true
        cache.saveLocalCard(local, local.localStatus)
        replaceCardEntry(local)
        saveCard(local)
    }

    function createCard(boardId, stackId, stackTitle, title) {
        if (!boardId || !stackId) {
            statusText = i18n.tr("Choose a list before creating a card.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        var localCard = {
            "localKey": cache.newLocalKey(),
            "boardId": boardId,
            "stackId": stackId,
            "stackTitle": stackTitle || i18n.tr("List"),
            "subtitle": stackTitle || i18n.tr("List"),
            "title": title || i18n.tr("Untitled card"),
            "description": "",
            "localStatus": cache.statusCreated,
            "dirty": true,
            "type": "card"
        }
        cache.saveLocalCard(localCard, cache.statusCreated)
        insertCardEntry(localCard)
        updateLocalCounts()
        pendingOperation = "createCard"
        pendingCardCreate = localCard
        loading = true
        statusText = i18n.tr("Creating card...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function deleteCard(card) {
        if (!card || (!card.id && !card.localKey)) {
            statusText = i18n.tr("Card delete data is incomplete.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        if (!card.id) {
            cache.removeCard(card)
            removeCardEntryByKey(card.localKey)
            statusText = i18n.tr("Local card deleted.")
            updateLocalCounts()
            return
        }
        card.localStatus = cache.statusDeleted
        card.dirty = true
        cache.markDeleted(card)
        removeCardEntry(card.id)
        updateLocalCounts()
        pendingOperation = "deleteCard"
        pendingCardDelete = card
        loading = true
        statusText = i18n.tr("Deleting card...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function archiveCard(card, archived) {
        if (!card || !card.id) {
            statusText = i18n.tr("Card archive data is incomplete.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        pendingOperation = "archiveCard"
        pendingCardArchive = {"card": card, "archived": archived === true}
        loading = true
        statusText = archived === true ? i18n.tr("Archiving card...") : i18n.tr("Restoring card...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function createBoard(title, color) {
        pendingOperation = "createBoard"
        pendingBoardOperation = {"title": title || i18n.tr("Untitled board"), "color": color || "0082c9"}
        loading = true
        statusText = i18n.tr("Creating board...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function updateBoard(board) {
        pendingOperation = "updateBoard"
        pendingBoardOperation = board || ({})
        loading = true
        statusText = i18n.tr("Saving board...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function deleteBoard(board) {
        pendingOperation = "deleteBoard"
        pendingBoardOperation = board || ({})
        loading = true
        statusText = i18n.tr("Deleting board...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function createStack(title) {
        pendingOperation = "createStack"
        pendingStackOperation = {"boardId": selectedBoardId, "title": title || i18n.tr("Untitled list")}
        loading = true
        statusText = i18n.tr("Creating list...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function updateStack(stack) {
        pendingOperation = "updateStack"
        pendingStackOperation = stack || ({})
        loading = true
        statusText = i18n.tr("Saving list...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function deleteStack(stack) {
        pendingOperation = "deleteStack"
        pendingStackOperation = stack || ({})
        loading = true
        statusText = i18n.tr("Deleting list...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function searchSharees(query) {
        pendingOperation = "searchSharees"
        pendingAccessControlOperation = {"query": query || ""}
        loading = true
        statusText = i18n.tr("Searching share recipients...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function createAccessControl(board, sharee) {
        pendingOperation = "createAccessControl"
        pendingAccessControlOperation = {"board": board || currentBoardEntry(), "sharee": sharee || ({})}
        loading = true
        statusText = i18n.tr("Adding board share...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function updateAccessControl(board, acl) {
        pendingOperation = "updateAccessControl"
        pendingAccessControlOperation = {"board": board || currentBoardEntry(), "acl": acl || ({})}
        loading = true
        statusText = i18n.tr("Saving board share...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function deleteAccessControl(board, acl) {
        pendingOperation = "deleteAccessControl"
        pendingAccessControlOperation = {"board": board || currentBoardEntry(), "acl": acl || ({})}
        loading = true
        statusText = i18n.tr("Removing board share...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function loadCardDetails(card) {
        if (!card || !card.id) return
        pendingOperation = "loadCardDetails"
        pendingCardDetails = card
        loading = true
        statusText = i18n.tr("Loading card...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function avatarDataUrl(userId) {
        var id = String(userId || "")
        return id.length > 0 ? String(avatarDataUrls[id] || "") : ""
    }

    function requestAvatar(userId) {
        var id = String(userId || "")
        if (id.length === 0) {
            return
        }
        if (String(avatarDataUrls[id] || "").length > 0) {
            return
        }
        var state = String(avatarRequests[id] || "")
        if (state === "loading" || state === "failed") {
            return
        }
        var requests = cloneObject(avatarRequests)
        requests[id] = "loading"
        avatarRequests = requests
        api.requestGeneration = accountRequestGeneration
        session.withCredentials(function(userName, secret, serverUrl) {
            api.loadAvatar(serverUrl, userName, secret, id)
        })
    }

    function loadComments(card) {
        pendingOperation = "loadComments"
        pendingCardDetails = card
        loading = true
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function loadActivities(card) {
        pendingOperation = "loadActivities"
        pendingCardDetails = card
        loading = true
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function loadAttachments(card) {
        pendingOperation = "loadAttachments"
        pendingCardDetails = card
        loading = true
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function uploadAttachment(card, fileUrl, fileName) {
        if (!card || !card.id) {
            statusText = i18n.tr("Save the card before attaching files.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        pendingOperation = "uploadAttachment"
        pendingAttachmentOperation = {"card": card, "fileUrl": fileUrl, "fileName": fileName || ""}
        loading = true
        statusText = i18n.tr("Uploading attachment...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function deleteAttachments(card, attachments) {
        var queue = []
        for (var i = 0; i < (attachments || []).length; ++i) {
            if (attachments[i] && attachments[i].id) {
                queue.push(attachments[i])
            }
        }
        if (!card || !card.id || queue.length === 0) {
            statusText = i18n.tr("No removable attachments selected.")
            return
        }
        pendingAttachmentDeleteQueue = queue
        deleteNextAttachmentIfNeeded(card)
    }

    function deleteNextAttachmentIfNeeded(card) {
        if (pendingAttachmentDeleteQueue.length === 0) {
            loading = false
            return
        }
        var queue = pendingAttachmentDeleteQueue.slice(0)
        var next = queue.shift()
        pendingAttachmentDeleteQueue = queue
        pendingOperation = "deleteAttachment"
        pendingAttachmentOperation = {"card": card, "attachment": next}
        loading = true
        statusText = queue.length > 0
            ? i18n.tr("Removing attachment...")
            : i18n.tr("Removing attachment...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function openAttachment(card, attachment) {
        if (!card || !card.id || !attachment || !attachment.id) {
            statusText = i18n.tr("Attachment data is incomplete.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        pendingOperation = "downloadAttachment"
        pendingAttachmentOperation = {"card": card, "attachment": attachment}
        loading = true
        statusText = i18n.tr("Opening attachment...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
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

    function addComment(card, message) {
        var updated = {}
        for (var key in (card || {})) updated[key] = card[key]
        updated.newComment = message || ""
        pendingOperation = "addComment"
        pendingCardDetails = updated
        loading = true
        statusText = i18n.tr("Adding comment...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function deleteComments(card, comments) {
        var queue = []
        for (var i = 0; i < (comments || []).length; ++i) {
            if (comments[i] && comments[i].id) {
                queue.push(comments[i])
            }
        }
        if (!card || !card.id || queue.length === 0) {
            statusText = i18n.tr("No removable comments selected.")
            return
        }
        pendingCommentDeleteQueue = queue
        deleteNextCommentIfNeeded(card)
    }

    function deleteNextCommentIfNeeded(card) {
        if (pendingCommentDeleteQueue.length === 0) {
            loading = false
            return
        }
        var queue = pendingCommentDeleteQueue.slice(0)
        var next = queue.shift()
        pendingCommentDeleteQueue = queue
        pendingOperation = "deleteComment"
        pendingCommentOperation = {"card": card, "comment": next}
        loading = true
        statusText = i18n.tr("Deleting comment...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function commentKey(comment) {
        var value = comment || {}
        if (value.id) {
            return "id:" + String(value.id)
        }
        return "text:" + String(value.creationDateTime || "") + ":" + String(value.message || value.comment || value.text || "")
    }

    function assignLabel(card, labelId, assign) {
        pendingOperation = "assignLabel"
        pendingLabelOperation = {"card": card, "labelId": labelId, "assign": assign === true}
        loading = true
        statusText = i18n.tr("Updating labels...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function createLabel(title, color) {
        pendingOperation = "createLabel"
        pendingLabelOperation = {"boardId": selectedBoardId, "title": title || i18n.tr("Label"), "color": color || "0082c9"}
        loading = true
        statusText = i18n.tr("Creating label...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function deleteLabel(labelId) {
        if (!selectedBoardId || !labelId) {
            statusText = i18n.tr("Label delete data is incomplete.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        pendingOperation = "deleteLabel"
        pendingLabelOperation = {"boardId": selectedBoardId, "labelId": labelId}
        loading = true
        statusText = i18n.tr("Deleting label...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function assignUser(card, userId, assign) {
        if (card && card.id) {
            replaceCardEntry(card)
        }
        pendingOperation = "assignUser"
        pendingUserOperation = {"card": card, "userId": userId || "", "assign": assign === true}
        loading = true
        statusText = i18n.tr("Updating assignment...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function moveCardToStack(card, stack) {
        if (!card || !stack || !stack.stackId) {
            statusText = i18n.tr("Card move data is incomplete.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        var updated = {}
        for (var key in card) updated[key] = card[key]
        updated.stackId = stack.stackId
        updated.stackTitle = stack.stackTitle || stack.title || i18n.tr("List")
        updated.subtitle = updated.stackTitle
        saveCard(updated)
    }

    function applyCardOrder(cards) {
        var orderedCards = []
        var targetStackId = 0
        for (var i = 0; i < (cards || []).length; ++i) {
            var card = cards[i]
            if (!card) continue
            var updated = {}
            for (var key in card) updated[key] = card[key]
            updated.order = i + 1
            if (!targetStackId) {
                targetStackId = Number(updated.stackId || 0)
            }
            orderedCards.push(updated)
        }

        var updatedEntries = []
        var insertedOrderedCards = false
        for (var j = 0; j < entries.length; ++j) {
            var entry = entries[j]
            if (entry.type === "card" && Number(entry.stackId || 0) === targetStackId) {
                continue
            }
            updatedEntries.push(entry)
            if (!insertedOrderedCards && entry.type === "stack" && Number(entry.stackId || 0) === targetStackId) {
                for (var c = 0; c < orderedCards.length; ++c) {
                    updatedEntries.push(orderedCards[c])
                }
                insertedOrderedCards = true
            }
        }
        if (!insertedOrderedCards) {
            for (var tail = 0; tail < orderedCards.length; ++tail) {
                updatedEntries.push(orderedCards[tail])
            }
        }
        entries = updatedEntries
        if (selectedBoardId > 0) {
            cache.saveBoardEntries(selectedBoardId, entries)
        }
        updateLocalCounts()
        statusText = i18n.tr("Card order changed.")
    }

    function saveCardOrder(card, newPosition) {
        if (!card || !card.id) {
            statusText = i18n.tr("Card reorder data is incomplete.")
            syncStateText = i18n.tr("Sync failed")
            syncStateColor = "#c23b3b"
            return
        }
        pendingOperation = "reorderCard"
        pendingCardReorder = {"card": card, "newPosition": newPosition}
        statusText = i18n.tr("Saving card order...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function syncDirtySoon() {
        if (dirtySyncRunning || loading) return
        var queue = cache.loadLocalChanges()
        if (queue.length === 0) return
        dirtySyncQueue = queue
        dirtySyncRunning = true
        statusText = i18n.tr("Uploading local changes...")
        syncStateText = i18n.tr("Syncing")
        syncStateColor = "#2c7fb8"
        api.requestGeneration = accountRequestGeneration
        session.authenticate()
    }

    function uploadNextDirty(userName, secret, serverUrl) {
        if (!dirtySyncRunning) return
        if (dirtySyncQueue.length === 0) {
            dirtySyncRunning = false
            loading = false
            updateLocalCounts()
            statusText = dirtyCount > 0 ? i18n.tr("Some local changes could not be uploaded.") : i18n.tr("All local changes uploaded.")
            syncStateText = conflictCount > 0 ? i18n.tr("Conflict") : (dirtyCount > 0 ? i18n.tr("Unsynced") : i18n.tr("Up to date"))
            syncStateColor = conflictCount > 0 ? "#c23b3b" : (dirtyCount > 0 ? "#b37a2a" : "#5a8f3c")
            return
        }
        var card = dirtySyncQueue.shift()
        api.requestGeneration = accountRequestGeneration
        if (card.localStatus === cache.statusCreated) {
            api.createCard(serverUrl, userName, secret, card.boardId, card.stackId, card.stackTitle, card.title)
        } else if (card.localStatus === cache.statusDeleted) {
            api.deleteCard(serverUrl, userName, secret, card)
        } else {
            api.updateCard(serverUrl, userName, secret, card)
        }
    }

    function insertCardEntry(card) {
        var updated = []
        var inserted = false
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i]
            updated.push(entry)
            if (!inserted && entry.type === "stack" && Number(entry.stackId || 0) === Number(card.stackId || 0)) {
                updated.push(card)
                inserted = true
            }
        }
        if (!inserted) {
            updated.push(card)
        }
        entries = updated
    }

    function replaceCardEntry(card) {
        var updated = []
        var replaced = false
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i]
            if (entry.type === "card" && Number(entry.id || 0) === Number(card.id || 0)) {
                updated.push(card)
                replaced = true
            } else {
                updated.push(entry)
            }
        }
        if (!replaced) {
            updated.push(card)
        }
        entries = updated
    }

    function mergeCardWithExisting(card) {
        var merged = {}
        var existing = ({})
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i]
            if (entry.type === "card" && Number(entry.id || 0) === Number(card.id || 0)) {
                existing = entry
                break
            }
        }
        for (var oldKey in (existing || {})) {
            merged[oldKey] = existing[oldKey]
        }
        for (var newKey in (card || {})) {
            merged[newKey] = card[newKey]
        }
        if ((!card.labels || card.labels.length === 0) && card._labelsAuthoritative !== true) {
            merged.labels = existing.labels || []
        }
        if ((!card.assignedUsers || card.assignedUsers.length === 0) && card._assignedUsersAuthoritative !== true) {
            merged.assignedUsers = existing.assignedUsers || []
        }
        if (!card.owner || card.owner.length === 0) {
            merged.owner = existing.owner || []
        }
        if (!card.stackTitle && existing.stackTitle) {
            merged.stackTitle = existing.stackTitle
            merged.subtitle = existing.subtitle || existing.stackTitle
        }
        merged.type = "card"
        return merged
    }

    function removeCardEntry(cardId) {
        var updated = []
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i]
            if (entry.type === "card" && Number(entry.id || 0) === Number(cardId || 0)) {
                continue
            }
            updated.push(entry)
        }
        entries = updated
    }

    function removeCardEntryByKey(localKey) {
        var updated = []
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i]
            if (entry.type === "card" && String(entry.localKey || "") === String(localKey || "")) {
                continue
            }
            updated.push(entry)
        }
        entries = updated
    }

    function currentBoardEntry() {
        for (var i = 0; i < (cachedBoards || []).length; ++i) {
            if (Number(cachedBoards[i].id || 0) === Number(selectedBoardId || 0)) {
                return cachedBoards[i]
            }
        }
        return {"id": selectedBoardId, "title": selectedBoardTitle, "labels": selectedBoardLabels, "type": "board"}
    }

    function replaceBoardEntry(board) {
        if (!board || !board.id) {
            return
        }
        var updated = []
        var replaced = false
        for (var i = 0; i < (cachedBoards || []).length; ++i) {
            if (Number(cachedBoards[i].id || 0) === Number(board.id || 0)) {
                updated.push(board)
                replaced = true
            } else {
                updated.push(cachedBoards[i])
            }
        }
        if (!replaced && board && board.id) {
            updated.push(board)
        }
        cachedBoards = updated
        if (viewMode !== "cards") {
            entries = updated
        }
        if (Number(board.id || 0) === Number(selectedBoardId || 0)) {
            selectedBoardTitle = board.title || selectedBoardTitle
            selectedBoardLabels = board.labels || selectedBoardLabels
        }
    }

    function removeBoardEntry(boardId) {
        var updated = []
        for (var i = 0; i < (cachedBoards || []).length; ++i) {
            if (Number(cachedBoards[i].id || 0) === Number(boardId || 0)) {
                continue
            }
            updated.push(cachedBoards[i])
        }
        cachedBoards = updated
        if (viewMode !== "cards") {
            entries = updated
        }
    }

    function markCardConflict(card, serverCard) {
        var updated = {}
        for (var key in (card || {})) updated[key] = card[key]
        updated.conflict = true
        updated.dirty = true
        updated.localStatus = updated.localStatus || cache.statusEdited
        updated.serverJson = JSON.stringify(serverCard || {})
        return updated
    }

    function cloneObject(source) {
        var result = {}
        for (var key in (source || {})) {
            result[key] = source[key]
        }
        return result
    }

    function updateLocalCounts() {
        cache.setScope(accountKey())
        dirtyCount = cache.countDirty()
        conflictCount = cache.countConflicts()
        if (conflictCount > 0) {
            syncStateText = i18n.tr("Conflict")
            syncStateColor = "#c23b3b"
        } else if (dirtyCount > 0 && !loading) {
            syncStateText = i18n.tr("Unsynced")
            syncStateColor = "#b37a2a"
        }
    }

    function continueDirtySyncIfNeeded() {
        activeDirtyCard = ({})
        if (!dirtySyncRunning) {
            return
        }
        loading = true
        session.authenticate()
    }

    function applyAccountSelection(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl) {
        accountRequestGeneration += 1
        var newKey = accountKeyFor(accountId, providerId, serviceId, serverUrl)
        stopAccountActivity()
        applyingAccountSelection = true
        accountSettings.accountId = accountId
        accountSettings.displayName = displayName || ""
        accountSettings.providerId = providerId || ""
        accountSettings.serviceId = serviceId || ""
        accountSettings.serverUrl = serverUrl || ""
        accountSettings.avatarUrl = avatarUrl || ""
        applyingAccountSelection = false

        session.setAccount(accountId, providerId || "", serviceId || "", serverUrl || "")
        clearAccountData()
        cache.setScope(newKey)
        skipNextCachedLoad = true
        activeAccountKey = newKey
        refreshTimer.restart()
    }

    function handleAccountChanged() {
        if (applyingAccountSelection) {
            return
        }

        if (!hasCompleteAccountSettings()) {
            return
        }

        var key = accountKey()
        if (key === activeAccountKey) {
            return
        }

        accountRequestGeneration += 1
        stopAccountActivity()
        clearAccountData()
        cache.setScope(key)
        skipNextCachedLoad = true
        activeAccountKey = key
        if (desktopTestAuthActive()) {
            Qt.callLater(controller.refresh)
        } else if (accountSettings.accountId > 0 && accountSettings.serviceId.length > 0 && accountSettings.serverUrl.length > 0) {
            refreshTimer.restart()
        }
    }

    function stopAccountActivity() {
        refreshTimer.stop()
        pendingOperation = ""
        pendingCardUpdate = ({})
        pendingCardCreate = ({})
        pendingCardDelete = ({})
        pendingBoardOperation = ({})
        pendingStackOperation = ({})
        pendingCardDetails = ({})
        pendingLabelOperation = ({})
        pendingUserOperation = ({})
        pendingAttachmentOperation = ({})
        pendingAttachmentDeleteQueue = []
        pendingCommentOperation = ({})
        pendingCommentDeleteQueue = []
        activeDirtyCard = ({})
        loading = false
        session.setAccount(accountSettings.accountId, accountSettings.providerId, accountSettings.serviceId, accountSettings.serverUrl)
        api.requestGeneration = accountRequestGeneration
    }

    function clearAccountData() {
        entries = []
        cachedBoards = []
        viewMode = "boards"
        titleText = i18n.tr("Boards")
        selectedBoardId = 0
        selectedBoardTitle = ""
        selectedBoardLabels = []
        currentUserName = ""
        accountAvatarUrl = accountSettings.avatarUrl || ""
        avatarDataUrls = ({})
        avatarRequests = ({})
        loading = false
        statusText = hasCompleteAccountSettings()
            ? i18n.tr("Account changed. Refreshing...")
            : i18n.tr("Select an account to load Deck boards.")
        syncStateText = hasCompleteAccountSettings()
            ? i18n.tr("Refreshing")
            : i18n.tr("No account")
        syncStateColor = "#b37a2a"
    }

    function accountKey() {
        return accountKeyFor(effectiveAccountId(), effectiveProviderId(), effectiveServiceId(), effectiveServerUrl())
    }

    function hasCompleteAccountSettings() {
        return desktopTestAuthActive()
            || (accountSettings.accountId > 0
            && accountSettings.providerId.length > 0
            && accountSettings.serviceId.length > 0
            && accountSettings.serverUrl.length > 0)
    }

    function desktopTestAuthActive() {
        return typeof desktopTestAuthEnabled !== "undefined" && desktopTestAuthEnabled
            && typeof desktopTestServerUrl !== "undefined" && String(desktopTestServerUrl || "").length > 0
    }

    function effectiveAccountId() {
        return desktopTestAuthActive() ? -1 : accountSettings.accountId
    }

    function effectiveProviderId() {
        return desktopTestAuthActive() ? "desktop-test" : accountSettings.providerId
    }

    function effectiveServiceId() {
        return desktopTestAuthActive() ? "desktop-test-env" : accountSettings.serviceId
    }

    function effectiveServerUrl() {
        return desktopTestAuthActive() ? String(desktopTestServerUrl || "").replace(/\/+$/, "") : accountSettings.serverUrl
    }

    function accountKeyFor(accountId, providerId, serviceId, serverUrl) {
        return String(accountId)
            + "|" + String(providerId || "")
            + "|" + String(serviceId || "")
            + "|" + String(serverUrl || "")
    }

    function isCurrentAccountResponse(accountId, serviceId, serverUrl) {
        if (typeof desktopTestAuthEnabled !== "undefined" && desktopTestAuthEnabled
                && Number(accountId || 0) === -1
                && String(serviceId || "") === "desktop-test-env") {
            return true
        }
        return Number(accountId || 0) === Number(accountSettings.accountId || 0)
            && String(serviceId || "") === String(accountSettings.serviceId || "")
            && String(serverUrl || "").replace(/\/+$/, "") === String(accountSettings.serverUrl || "").replace(/\/+$/, "")
    }

    function isCurrentApiGeneration(generation) {
        return Number(generation || 0) === Number(accountRequestGeneration || 0)
    }

    function avatarUrl(serverUrl, userName) {
        if (!serverUrl || !userName) return ""
        return String(serverUrl).replace(/\/+$/, "") + "/index.php/avatar/" + encodeURIComponent(userName) + "/64"
    }

    Timer {
        id: refreshTimer
        interval: 150
        repeat: false
        onTriggered: controller.refresh()
    }

    Component.onCompleted: {
        settingsReady = true
        if (hasCompleteAccountSettings()) {
            handleAccountChanged()
        } else {
            clearAccountData()
        }
    }
}
