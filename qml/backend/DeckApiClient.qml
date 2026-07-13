import QtQuick 2.7
import "AuthCore.js" as AuthCore

Item {
    id: api
    property int requestGeneration: 0
    property int nativeRequestSerial: 0
    property var pendingNativeRequests: ({})

    signal boardsLoaded(var entries, int generation)
    signal cardsLoaded(int boardId, string boardTitle, var entries, int generation)
    signal cardCreated(var card, int generation)
    signal cardUpdated(var card, int generation)
    signal cardReordered(var card, int generation)
    signal cardDeleted(int cardId, int generation)
    signal cardArchived(var card, bool archived, int generation)
    signal cardConflict(var card, var serverCard, string message, int generation)
    signal cardDetailsLoaded(var card, int generation)
    signal attachmentUploaded(var card, var attachment, int generation)
    signal attachmentDeleted(var card, var attachment, int generation)
    signal attachmentDownloaded(var card, var attachment, string fileUrl, string fileName, string mimeType, int generation)
    signal commentDeleted(var card, var comment, int generation)
    signal activitiesLoaded(var card, int generation)
    signal boardCreated(var board, int generation)
    signal boardUpdated(var board, int generation)
    signal boardDeleted(int boardId, int generation)
    signal boardAccessUpdated(var board, string message, int generation)
    signal shareesLoaded(var sharees, int generation)
    signal stackCreated(var stack, int generation)
    signal stackUpdated(var stack, int generation)
    signal stackDeleted(int stackId, int generation)
    signal avatarLoaded(string userId, string dataUrl, int generation)
    signal avatarFailed(string userId, int generation)
    signal failed(string message, int generation)

    Connections {
        target: typeof deckNetwork !== "undefined" ? deckNetwork : null
        onRequestFinished: api.handleNativeRequestFinished(requestId, status, responseText, generation)
        onRequestFailed: api.handleNativeRequestFailed(requestId, message, generation)
        onDataUrlFinished: api.handleNativeDataUrlFinished(requestId, dataUrl, generation)
        onFileDownloaded: api.handleNativeFileDownloaded(requestId, fileUrl, fileName, mimeType, generation)
    }

    function loadBoards(serverUrl, userName, secret) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/index.php/apps/deck/api/v1.0/boards?details=true"
        requestJson(url, userName, secret, i18n.tr("boards"), function(data) {
            var entries = []
            var boards = data && data.length !== undefined ? data : []
            for (var i = 0; i < boards.length; ++i) {
                if (isDeletedEntity(boards[i])) {
                    continue
                }
                entries.push(boardEntryFromResponse(boards[i]))
            }
            boardsLoaded(entries, generation)
        }, generation)
    }

    function createBoard(serverUrl, userName, secret, title, color) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/index.php/apps/deck/api/v1.0/boards"
        var payload = {
            "title": title && String(title).trim().length > 0 ? String(title).trim() : i18n.tr("Untitled board"),
            "color": color || "0082c9"
        }
        requestJsonWithBody(url, userName, secret, "POST", payload, i18n.tr("board create"), function(data) {
            boardCreated(boardEntryFromResponse(data || payload), generation)
        }, generation)
    }

    function updateBoard(serverUrl, userName, secret, board) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = board && board.id ? board.id : 0
        if (!boardId) {
            failed(i18n.tr("Board update data is incomplete."), generation)
            return
        }
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
        requestJsonWithBody(url, userName, secret, "PUT", {
            "id": boardId,
            "title": board.title || i18n.tr("Untitled board"),
            "color": board.color || "0082c9",
            "archived": board.archived === true
        }, i18n.tr("board update"), function(data) {
            boardUpdated(boardEntryFromResponse(data || board), generation)
        }, generation)
    }

    function deleteBoard(serverUrl, userName, secret, boardId) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
        requestJsonWithBody(url, userName, secret, "DELETE", {}, i18n.tr("board delete"), function() {
            boardDeleted(Number(boardId), generation)
        }, generation)
    }

    function searchSharees(serverUrl, userName, secret, query) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/ocs/v2.php/core/autocomplete/get?format=json"
            + "&itemType=deck"
            + "&shareTypes%5B0%5D=0"
            + "&shareTypes%5B1%5D=1"
            + "&shareTypes%5B2%5D=6"
            + "&shareTypes%5B3%5D=7"
            + "&limit=20"
            + "&search=" + encodeURIComponent(query || "")
        requestJson(url, userName, secret, i18n.tr("share search"), function(data) {
            shareesLoaded(normalizeSharees(responseArray(data, "")), generation)
        }, generation)
    }

    function createAccessControl(serverUrl, userName, secret, board, sharee) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = board && board.id ? board.id : 0
        if (!boardId || !sharee) {
            failed(i18n.tr("Board share data is incomplete."), generation)
            return
        }
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId) + "/acl"
        var payload = {
            "type": Number(sharee.type || 0),
            "participant": sharee.id || sharee.user || sharee.label || "",
            "permissionEdit": false,
            "permissionShare": false,
            "permissionManage": false
        }
        requestJsonWithBody(url, userName, secret, "POST", payload, i18n.tr("board share"), function(data) {
            var updated = boardEntryFromResponse(board)
            updated.acl = updated.acl || []
            updated.acl.push(normalizeAcl(data || payload))
            boardAccessUpdated(updated, i18n.tr("Board share added."), generation)
        }, generation)
    }

    function updateAccessControl(serverUrl, userName, secret, board, acl) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = board && board.id ? board.id : 0
        var aclId = acl && acl.id ? acl.id : 0
        if (!boardId || !aclId) {
            failed(i18n.tr("Board share data is incomplete."), generation)
            return
        }
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId) + "/acl/" + encodeURIComponent(aclId)
        var payload = {
            "id": aclId,
            "type": Number(acl.type || 0),
            "participant": aclParticipantId(acl),
            "permissionEdit": acl.permissionEdit === true,
            "permissionShare": acl.permissionShare === true,
            "permissionManage": acl.permissionManage === true
        }
        requestJsonWithBody(url, userName, secret, "PUT", payload, i18n.tr("board share update"), function(data) {
            var updated = replaceBoardAcl(board, normalizeAcl(data || payload))
            boardAccessUpdated(updated, i18n.tr("Board share saved."), generation)
        }, generation)
    }

    function deleteAccessControl(serverUrl, userName, secret, board, acl) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = board && board.id ? board.id : 0
        var aclId = acl && acl.id ? acl.id : 0
        if (!boardId || !aclId) {
            failed(i18n.tr("Board share data is incomplete."), generation)
            return
        }
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId) + "/acl/" + encodeURIComponent(aclId)
        requestJsonWithBody(url, userName, secret, "DELETE", {}, i18n.tr("board share delete"), function() {
            boardAccessUpdated(removeBoardAcl(board, aclId), i18n.tr("Board share removed."), generation)
        }, generation)
    }

    function loadBoard(serverUrl, userName, secret, boardId, boardTitle, includeArchived) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId) + "/stacks"
        requestJson(url, userName, secret, i18n.tr("board stacks"), function(data) {
            var entries = stackEntriesFromResponse(data, boardId, false)
            if (includeArchived === true) {
                var archivedUrl = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId) + "/stacks/archived"
                requestJson(archivedUrl, userName, secret, i18n.tr("archived cards"), function(archivedData) {
                    var archivedEntries = stackEntriesFromResponse(archivedData, boardId, true)
                    cardsLoaded(boardId, boardTitle || i18n.tr("Board"), mergeStackEntries(entries, archivedEntries), generation)
                }, generation)
                return
            }
            cardsLoaded(boardId, boardTitle || i18n.tr("Board"), entries, generation)
        }, generation)
    }

    function loadAvatar(serverUrl, userName, secret, userId) {
        var generation = requestGeneration
        var id = String(userId || "")
        var base = AuthCore.normalizeServerUrl(serverUrl)
        if (id.length === 0 || base.length === 0) {
            avatarFailed(id, generation)
            return
        }
        var url = base + "/index.php/avatar/" + encodeURIComponent(id) + "/64"
        if (typeof deckNetwork !== "undefined") {
            var requestId = nextNativeRequestId("avatar")
            pendingNativeRequests[requestId] = {
                "kind": "avatar",
                "userId": id
            }
            deckNetwork.fetchDataUrl(generation, requestId, url, userName, secret)
            return
        }
        avatarFailed(id, generation)
    }

    function createStack(serverUrl, userName, secret, boardId, title) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId) + "/stacks"
        requestJsonWithBody(url, userName, secret, "POST", {
            "title": title && String(title).trim().length > 0 ? String(title).trim() : i18n.tr("Untitled list"),
            "order": 0
        }, i18n.tr("list create"), function(data) {
            stackCreated(stackEntryFromResponse(data || {}, boardId), generation)
        }, generation)
    }

    function updateStack(serverUrl, userName, secret, stack) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = stack && stack.boardId ? stack.boardId : 0
        var stackId = stack && stack.stackId ? stack.stackId : 0
        if (!boardId || !stackId) {
            failed(i18n.tr("List update data is incomplete."), generation)
            return
        }
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId) + "/stacks/" + encodeURIComponent(stackId)
        requestJsonWithBody(url, userName, secret, "PUT", {
            "id": stackId,
            "title": stack.title || i18n.tr("Untitled list"),
            "order": stack.order || 0
        }, i18n.tr("list update"), function(data) {
            stackUpdated(stackEntryFromResponse(data || stack, boardId), generation)
        }, generation)
    }

    function deleteStack(serverUrl, userName, secret, boardId, stackId) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId) + "/stacks/" + encodeURIComponent(stackId)
        requestJsonWithBody(url, userName, secret, "DELETE", {}, i18n.tr("list delete"), function() {
            stackDeleted(Number(stackId), generation)
        }, generation)
    }

    function createCard(serverUrl, userName, secret, boardId, stackId, stackTitle, title) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
            + "/stacks/" + encodeURIComponent(stackId)
            + "/cards"
        if (!boardId || !stackId) {
            failed(i18n.tr("Card create data is incomplete."), generation)
            return
        }
        var payload = {
            "title": title && String(title).trim().length > 0 ? String(title).trim() : i18n.tr("Untitled card"),
            "description": "",
            "stackId": stackId,
            "type": "plain",
            "order": 0,
            "archived": false
        }
        requestJsonWithBody(url, userName, secret, "POST", payload, i18n.tr("card create"), function(data) {
            cardCreated(cardEntryFromResponse(data || {}, boardId, stackId, stackTitle || i18n.tr("List"), payload), generation)
        }, generation)
    }

    function loadCardDetails(serverUrl, userName, secret, card) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base
            + "/index.php/apps/deck/api/v1.1/boards/" + encodeURIComponent(card.boardId || 0)
            + "/stacks/" + encodeURIComponent(card.stackId || 0)
            + "/cards/" + encodeURIComponent(card.id || 0)
        requestJson(url, userName, secret, i18n.tr("card details"), function(data) {
            cardDetailsLoaded(cardEntryFromResponse(data || {}, card.boardId || 0, card.stackId || 0, card.stackTitle || card.subtitle || i18n.tr("List"), card), generation)
        }, generation)
    }

    function updateCard(serverUrl, userName, secret, card) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = card && card.boardId ? card.boardId : 0
        var stackId = card && card.stackId ? card.stackId : 0
        var cardId = card && card.id ? card.id : 0
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
            + "/stacks/" + encodeURIComponent(stackId)
            + "/cards/" + encodeURIComponent(cardId)
        if (!boardId || !stackId || !cardId) {
            failed(i18n.tr("Card update data is incomplete."), generation)
            return
        }
        var payload = {
            "id": cardId,
            "title": card.title || "",
            "description": card.description || "",
            "duedate": card.duedate || null,
            "startdate": card.startdate || null,
            "done": card.done || null,
            "stackId": Number(stackId),
            "type": card.typeRaw || "plain",
            "archived": card.archived === true
        }
        var ownerValue = ownerUid(card.owner)
        if (ownerValue.length === 0) ownerValue = userName
        if (ownerValue.length > 0) payload.owner = ownerValue
        requestJsonWithBody(url, userName, secret, "PUT", payload, i18n.tr("card update"), function(data) {
            cardUpdated(cardEntryFromResponse(data || {}, boardId, stackId, card.stackTitle || card.subtitle || i18n.tr("List"), card), generation)
        }, generation, card)
    }

    function reorderCard(serverUrl, userName, secret, card, newPosition) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = card && card.boardId ? card.boardId : 0
        var stackId = card && card.stackId ? card.stackId : 0
        var cardId = card && card.id ? card.id : 0
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
            + "/stacks/" + encodeURIComponent(stackId)
            + "/cards/" + encodeURIComponent(cardId)
            + "/reorder"
        if (!boardId || !stackId || !cardId) {
            failed(i18n.tr("Card reorder data is incomplete."), generation)
            return
        }
        requestJsonWithBody(url, userName, secret, "PUT", {
            "order": Number(newPosition || 0),
            "stackId": Number(stackId)
        }, i18n.tr("card reorder"), function() {
            cardReordered(cardEntryFromResponse(card || {}, boardId, stackId, card.stackTitle || card.subtitle || i18n.tr("List"), card), generation)
        }, generation, card)
    }

    function deleteCard(serverUrl, userName, secret, card) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = card && card.boardId ? card.boardId : 0
        var stackId = card && card.stackId ? card.stackId : 0
        var cardId = card && card.id ? card.id : 0
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
            + "/stacks/" + encodeURIComponent(stackId)
            + "/cards/" + encodeURIComponent(cardId)
        if (!boardId || !stackId || !cardId) {
            failed(i18n.tr("Card delete data is incomplete."), generation)
            return
        }
        requestJsonWithBody(url, userName, secret, "DELETE", {}, i18n.tr("card delete"), function() {
            cardDeleted(cardId, generation)
        }, generation, card)
    }

    function archiveCard(serverUrl, userName, secret, card, archived) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = card && card.boardId ? card.boardId : 0
        var stackId = card && card.stackId ? card.stackId : 0
        var cardId = card && card.id ? card.id : 0
        if (!boardId || !stackId || !cardId) {
            failed(i18n.tr("Card archive data is incomplete."), generation)
            return
        }
        var action = archived === true ? "archive" : "unarchive"
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
            + "/stacks/" + encodeURIComponent(stackId)
            + "/cards/" + encodeURIComponent(cardId)
            + "/" + action
        requestJsonWithBody(url, userName, secret, "PUT", {}, archived === true ? i18n.tr("card archive") : i18n.tr("card unarchive"), function(data) {
            var updated = cardEntryFromResponse(data || card || {}, boardId, stackId, card.stackTitle || card.subtitle || i18n.tr("List"), card)
            updated.archived = archived === true
            cardArchived(updated, archived === true, generation)
        }, generation, card)
    }

    function assignLabel(serverUrl, userName, secret, card, labelId, assign) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var action = assign ? "assignLabel" : "removeLabel"
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(card.boardId || 0)
            + "/stacks/" + encodeURIComponent(card.stackId || 0)
            + "/cards/" + encodeURIComponent(card.id || 0)
            + "/" + action
        requestForm(url, userName, secret, "PUT", {"labelId": labelId}, i18n.tr("label assignment"), function() {
            loadCardDetails(serverUrl, userName, secret, card)
        }, generation)
    }

    function assignUser(serverUrl, userName, secret, card, userId, assign) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var action = assign ? "assignUser" : "unassignUser"
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(card.boardId || 0)
            + "/stacks/" + encodeURIComponent(card.stackId || 0)
            + "/cards/" + encodeURIComponent(card.id || 0)
            + "/" + action
        requestForm(url, userName, secret, "PUT", {"type": 0, "userId": userId || ""}, i18n.tr("user assignment"), function() {
            loadCardDetails(serverUrl, userName, secret, card)
        }, generation)
    }

    function assignDependent(serverUrl, userName, secret, card, dependentCardId, assign) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(card.boardId || 0)
            + "/stacks/" + encodeURIComponent(card.stackId || 0)
            + "/cards/" + encodeURIComponent(card.id || 0)
            + "/dependentCards/" + encodeURIComponent(dependentCardId)
        requestJsonWithBody(url, userName, secret, assign ? "POST" : "DELETE", {}, i18n.tr("dependent assignment"), function() {
            loadCardDetails(serverUrl, userName, secret, card)
        }, generation)
    }

    function createLabel(serverUrl, userName, secret, boardId, title, color) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId) + "/labels"
        requestJsonWithBody(url, userName, secret, "POST", {
            "title": title && String(title).trim().length > 0 ? String(title).trim() : i18n.tr("Label"),
            "color": color || "0082c9"
        }, i18n.tr("label create"), function() {
            loadBoards(serverUrl, userName, secret)
        }, generation)
    }

    function deleteLabel(serverUrl, userName, secret, boardId, labelId) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
            + "/labels/" + encodeURIComponent(labelId)
        requestJsonWithBody(url, userName, secret, "DELETE", {}, i18n.tr("label delete"), function() {
            loadBoards(serverUrl, userName, secret)
        }, generation)
    }

    function loadAttachments(serverUrl, userName, secret, card) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(card.boardId || 0)
            + "/stacks/" + encodeURIComponent(card.stackId || 0)
            + "/cards/" + encodeURIComponent(card.id || 0)
            + "/attachments"
        requestJson(url, userName, secret, i18n.tr("attachments"), function(data) {
            var updated = cardEntryFromResponse(card, card.boardId || 0, card.stackId || 0, card.stackTitle || card.subtitle || i18n.tr("List"), card)
            updated.attachments = mergeAttachments(card.attachments || [], normalizeAttachments(responseArray(data, "attachments")))
            updated.attachmentCount = updated.attachments.length
            cardDetailsLoaded(updated, generation)
        }, generation)
    }

    function uploadAttachment(serverUrl, userName, secret, card, fileUrl, fileName) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = card && card.boardId ? card.boardId : 0
        var stackId = card && card.stackId ? card.stackId : 0
        var cardId = card && card.id ? card.id : 0
        if (!boardId || !stackId || !cardId) {
            failed(i18n.tr("Attachment upload data is incomplete."), generation)
            return
        }
        if (typeof deckNetwork === "undefined") {
            failed(i18n.tr("Attachment upload requires the native network backend."), generation)
            return
        }
        if (typeof contentHubBridge === "undefined" || !contentHubBridge.isReadableLocalFile(fileUrl)) {
            failed(i18n.tr("The selected file could not be read."), generation)
            return
        }
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
            + "/stacks/" + encodeURIComponent(stackId)
            + "/cards/" + encodeURIComponent(cardId)
            + "/attachments"
        var requestId = nextNativeRequestId("attachment-upload")
        var resolvedFileName = String(fileName || "").trim()
        if (resolvedFileName.length === 0) {
            resolvedFileName = contentHubBridge.fileName(fileUrl)
        }
        pendingNativeRequests[requestId] = {
            "kind": "attachment",
            "method": "POST",
            "requestName": i18n.tr("attachment upload"),
            "callback": function(data) {
                var attachment = normalizeAttachment(data || {})
                attachmentUploaded(cardEntryFromResponse(card, boardId, stackId, card.stackTitle || card.subtitle || i18n.tr("List"), card), attachment, generation)
            },
            "payload": {"fileNamePresent": resolvedFileName.length > 0},
            "conflictCard": null
        }
        var size = contentHubBridge.fileSize(fileUrl)
        if (size <= 0) {
            failed(i18n.tr("The selected file is empty."), generation)
            return
        }
        deckNetwork.uploadFileMultipart(generation, requestId, url, userName, secret,
            fileUrl, resolvedFileName, contentHubBridge.mimeType(fileUrl), "file", true)
    }

    function deleteAttachment(serverUrl, userName, secret, card, attachment) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = card && card.boardId ? card.boardId : 0
        var stackId = card && card.stackId ? card.stackId : 0
        var cardId = card && card.id ? card.id : 0
        var attachmentId = attachment && attachment.id ? attachment.id : 0
        if (!boardId || !stackId || !cardId || !attachmentId) {
            failed(i18n.tr("Attachment delete data is incomplete."), generation)
            return
        }
        var type = String(attachment.type || "file").trim()
        if (type.length === 0) {
            type = "file"
        }
        var url = base
            + "/index.php/apps/deck/api/v1.0/boards/" + encodeURIComponent(boardId)
            + "/stacks/" + encodeURIComponent(stackId)
            + "/cards/" + encodeURIComponent(cardId)
            + "/attachments/" + encodeURIComponent(attachmentId)
            + "?type=" + encodeURIComponent(type)
        requestJsonWithBody(url, userName, secret, "DELETE", {}, i18n.tr("attachment delete"), function() {
            attachmentDeleted(cardEntryFromResponse(card, boardId, stackId, card.stackTitle || card.subtitle || i18n.tr("List"), card), attachment, generation)
        }, generation)
    }

    function downloadAttachment(serverUrl, userName, secret, card, attachment) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var boardId = card && card.boardId ? card.boardId : 0
        var stackId = card && card.stackId ? card.stackId : 0
        var cardId = card && card.id ? card.id : 0
        var attachmentId = attachment && attachment.id ? attachment.id : 0
        if (!boardId || !stackId || !cardId || !attachmentId) {
            failed(i18n.tr("Attachment download data is incomplete."), generation)
            return
        }
        if (typeof deckNetwork === "undefined") {
            failed(i18n.tr("Attachment download requires the native network backend."), generation)
            return
        }
        var type = String(attachment.type || "file").trim()
        if (type.length === 0) {
            type = "file"
        }
        var url = base
            + "/index.php/apps/deck/api/v1.1/boards/" + encodeURIComponent(boardId)
            + "/stacks/" + encodeURIComponent(stackId)
            + "/cards/" + encodeURIComponent(cardId)
            + "/attachments/" + encodeURIComponent(type)
            + "/" + encodeURIComponent(attachmentId)
        var requestId = nextNativeRequestId("attachment-download")
        pendingNativeRequests[requestId] = {
            "kind": "attachment-download",
            "method": "GET",
            "requestName": i18n.tr("attachment download"),
            "callback": function(fileUrl, fileName, mimeType) {
                attachmentDownloaded(cardEntryFromResponse(card, boardId, stackId, card.stackTitle || card.subtitle || i18n.tr("List"), card),
                    attachment, fileUrl, fileName, mimeType, generation)
            },
            "payload": {"attachmentIdPresent": attachmentId > 0, "type": type},
            "conflictCard": null
        }
        deckNetwork.downloadFileToCache(generation, requestId, url, userName, secret, attachmentFileName(attachment))
    }

    function loadComments(serverUrl, userName, secret, card) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/ocs/v2.php/apps/deck/api/v1.0/cards/" + encodeURIComponent(card.id || 0) + "/comments?format=json"
        requestJson(url, userName, secret, i18n.tr("comments"), function(data) {
            var updated = cardEntryFromResponse(card, card.boardId || 0, card.stackId || 0, card.stackTitle || card.subtitle || i18n.tr("List"), card)
            updated.comments = responseArray(data, "comments")
            updated.commentsCount = updated.comments.length
            cardDetailsLoaded(updated, generation)
        }, generation)
    }

    function addComment(serverUrl, userName, secret, card, message) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var url = base + "/ocs/v2.php/apps/deck/api/v1.0/cards/" + encodeURIComponent(card.id || 0) + "/comments?format=json"
        requestJsonWithBody(url, userName, secret, "POST", {"message": message || "", "parentId": null}, i18n.tr("comment create"), function() {
            loadComments(serverUrl, userName, secret, card)
        }, generation)
    }

    function deleteComment(serverUrl, userName, secret, card, comment) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var cardId = card && card.id ? card.id : 0
        var commentId = comment && comment.id ? comment.id : 0
        if (!cardId || !commentId) {
            failed(i18n.tr("Comment delete data is incomplete."), generation)
            return
        }
        var url = base + "/ocs/v2.php/apps/deck/api/v1.0/cards/" + encodeURIComponent(cardId)
            + "/comments/" + encodeURIComponent(commentId) + "?format=json"
        requestJsonWithBody(url, userName, secret, "DELETE", {}, i18n.tr("comment delete"), function() {
            commentDeleted(cardEntryFromResponse(card, card.boardId || 0, card.stackId || 0, card.stackTitle || card.subtitle || i18n.tr("List"), card),
                comment, generation)
        }, generation)
    }

    function loadActivities(serverUrl, userName, secret, card) {
        var generation = requestGeneration
        var base = AuthCore.normalizeServerUrl(serverUrl)
        var cardId = card && card.id ? card.id : 0
        if (!cardId) {
            failed(i18n.tr("Activity data is incomplete."), generation)
            return
        }
        var url = base + "/ocs/v2.php/apps/activity/api/v2/activity/filter"
            + "?format=json"
            + "&type=deck"
            + "&object_type=deck_card"
            + "&object_id=" + encodeURIComponent(cardId)
            + "&limit=50"
            + "&since=-1"
            + "&sort=asc"
        requestJson(url, userName, secret, i18n.tr("activity"), function(data) {
            var updated = cardEntryFromResponse(card, card.boardId || 0, card.stackId || 0, card.stackTitle || card.subtitle || i18n.tr("List"), card)
            updated.activities = normalizeActivities(responseArray(data, "activities"))
            activitiesLoaded(updated, generation)
        }, generation)
    }

    function boardEntryFromResponse(board) {
        return {
            "id": Number(board.id || 0),
            "title": board.title || board.name || i18n.tr("Untitled board"),
            "subtitle": board.archived ? i18n.tr("Archived board") : i18n.tr("Board"),
            "detail": board.lastModified || board.lastModifiedTimestamp || "",
            "color": board.color || "",
            "archived": board.archived === true,
            "labels": board.labels || [],
            "owner": board.owner || {},
            "acl": normalizeAcls(board.acl || []),
            "permissionEdit": board.permissionEdit === true,
            "permissionShare": board.permissionShare === true,
            "permissionManage": board.permissionManage === true,
            "cardCount": Number(board.cardCount || board.cardsCount || board.nbCards || board.count || boardStackCardCount(board)),
            "stackCount": Number(board.stackCount || board.stacksCount || 0),
            "deletedAt": board.deletedAt || board.deleted_at || "",
            "status": board.status || "",
            "type": "board"
        }
    }

    function boardStackCardCount(board) {
        var total = 0
        var stacks = board && board.stacks && board.stacks.length !== undefined ? board.stacks : []
        for (var i = 0; i < stacks.length; ++i) {
            var cards = stacks[i].cards && stacks[i].cards.length !== undefined ? stacks[i].cards : []
            for (var j = 0; j < cards.length; ++j) {
                if (!isDeletedEntity(cards[j]) && cards[j].archived !== true) {
                    total += 1
                }
            }
        }
        return total
    }

    function normalizeAcls(list) {
        var result = []
        for (var i = 0; i < (list || []).length; ++i) {
            result.push(normalizeAcl(list[i]))
        }
        return result
    }

    function normalizeAcl(acl) {
        var source = acl || {}
        var participant = source.participant || source.user || {}
        if (typeof participant === "string") {
            participant = {"uid": participant, "displayname": participant}
        }
        return {
            "id": Number(source.id || source.localId || 0),
            "type": Number(source.type || 0),
            "participant": participant,
            "permissionEdit": source.permissionEdit === true,
            "permissionShare": source.permissionShare === true,
            "permissionManage": source.permissionManage === true
        }
    }

    function replaceBoardAcl(board, acl) {
        var updated = boardEntryFromResponse(board)
        var result = []
        var replaced = false
        for (var i = 0; i < (updated.acl || []).length; ++i) {
            if (Number(updated.acl[i].id || 0) === Number(acl.id || 0)) {
                result.push(acl)
                replaced = true
            } else {
                result.push(updated.acl[i])
            }
        }
        if (!replaced) {
            result.push(acl)
        }
        updated.acl = result
        return updated
    }

    function removeBoardAcl(board, aclId) {
        var updated = boardEntryFromResponse(board)
        var result = []
        for (var i = 0; i < (updated.acl || []).length; ++i) {
            if (Number(updated.acl[i].id || 0) !== Number(aclId || 0)) {
                result.push(updated.acl[i])
            }
        }
        updated.acl = result
        return updated
    }

    function normalizeSharees(list) {
        var result = []
        for (var i = 0; i < (list || []).length; ++i) {
            var source = list[i] || {}
            var id = source.id || source.user || source.value || source.label || ""
            if (String(id).length === 0) continue
            result.push({
                "id": id,
                "label": source.label || source.displayName || source.displayname || source.name || id,
                "subline": source.subline || source.subname || source.shareWithDisplayNameUnique || id,
                "source": source.source || "",
                "type": shareeType(source)
            })
        }
        return result
    }

    function shareeType(sharee) {
        var source = String((sharee || {}).source || "")
        if (source === "groups") return 1
        if (source === "remotes") return 6
        if (source === "circles" || source === "teams") return 7
        return Number((sharee || {}).type || 0)
    }

    function aclParticipantId(acl) {
        var participant = (acl || {}).participant || {}
        if (typeof participant === "string") return participant
        return String(participant.uid || participant.id || participant.primaryKey || participant.displayname || "")
    }

    function stackEntryFromResponse(stack, boardId) {
        return {
            "boardId": Number(boardId || stack.boardId || 0),
            "stackId": Number(stack.id || stack.stackId || 0),
            "stackTitle": stack.title || i18n.tr("Untitled list"),
            "title": stack.title || i18n.tr("Untitled list"),
            "subtitle": i18n.tr("List"),
            "detail": "",
            "order": stack.order || 0,
            "deletedAt": stack.deletedAt || stack.deleted_at || "",
            "status": stack.status || "",
            "type": "stack"
        }
    }

    function stackEntriesFromResponse(data, boardId, includeArchivedCards) {
        var entries = []
        var stacks = data && data.length !== undefined ? data : []
        for (var i = 0; i < stacks.length; ++i) {
            var stack = stacks[i]
            if (isDeletedEntity(stack)) {
                continue
            }
            entries.push({
                "boardId": boardId,
                "stackId": stack.id,
                "stackTitle": stack.title || i18n.tr("Untitled list"),
                "title": stack.title || i18n.tr("Untitled list"),
                "subtitle": i18n.tr("List"),
                "detail": "",
                "deletedAt": stack.deletedAt || stack.deleted_at || "",
                "status": stack.status || "",
                "type": "stack"
            })
            var cards = stack.cards && stack.cards.length !== undefined ? stack.cards : []
            for (var j = 0; j < cards.length; ++j) {
                var card = cards[j]
                if (isDeletedEntity(card)) {
                    continue
                }
                if (card.archived && includeArchivedCards !== true) {
                    continue
                }
                var entry = cardEntryFromResponse(card, boardId, card.stackId || stack.id, stack.title || i18n.tr("List"), {})
                entry.archived = card.archived === true || includeArchivedCards === true
                entries.push(entry)
            }
        }
        return entries
    }

    function mergeStackEntries(activeEntries, archivedEntries) {
        var result = []
        var stackSeen = {}
        var cardSeen = {}
        function addEntry(entry) {
            if (!entry) return
            if (entry.type === "stack") {
                var stackKey = String(entry.stackId || 0)
                if (stackSeen[stackKey] === true) return
                stackSeen[stackKey] = true
            } else if (entry.type === "card") {
                var cardKey = String(entry.id || entry.localKey || JSON.stringify(entry))
                if (cardSeen[cardKey] === true) return
                cardSeen[cardKey] = true
            }
            result.push(entry)
        }
        for (var i = 0; i < (activeEntries || []).length; ++i) addEntry(activeEntries[i])
        for (var j = 0; j < (archivedEntries || []).length; ++j) addEntry(archivedEntries[j])
        return result
    }

    function responseArray(data, preferredKey) {
        if (data && data.length !== undefined) {
            return data
        }
        if (data && data.ocs && data.ocs.data) {
            return responseArray(data.ocs.data, preferredKey)
        }
        if (data && preferredKey && data[preferredKey] && data[preferredKey].length !== undefined) {
            return data[preferredKey]
        }
        if (data && data.data && data.data.length !== undefined) {
            return data.data
        }
        return []
    }

    function mergeAttachments(existing, incoming) {
        var result = []
        var seen = {}
        function keyFor(attachment) {
            var value = attachment || {}
            return String(value.id || value.attachmentId || value.basename || value.name || value.filename || value.fileName || JSON.stringify(value))
        }
        function addAll(list) {
            for (var i = 0; i < (list || []).length; ++i) {
                var key = keyFor(list[i])
                if (seen[key]) {
                    continue
                }
                seen[key] = true
                result.push(list[i])
            }
        }
        addAll(incoming)
        addAll(existing)
        return result
    }

    function normalizeAttachments(list) {
        var result = []
        for (var i = 0; i < (list || []).length; ++i) {
            result.push(normalizeAttachment(list[i]))
        }
        return result
    }

    function normalizeAttachment(attachment) {
        var source = attachment || {}
        var extended = source.extendedData || {}
        var info = extended.info || {}
        var normalized = {}
        for (var key in source) {
            normalized[key] = source[key]
        }
        normalized.basename = source.basename || info.basename || source.name || source.filename || source.fileName || ""
        normalized.filename = source.filename || info.filename || normalized.basename
        normalized.dirname = source.dirname || info.dirname || ""
        normalized.extension = source.extension || info.extension || ""
        normalized.filesize = source.filesize || extended.filesize || source.fileSize || source.size || 0
        normalized.mimetype = source.mimetype || extended.mimetype || source.mimeType || source.mime || ""
        normalized.fileid = source.fileid || extended.fileid || source.fileId || 0
        return normalized
    }

    function normalizeActivities(list) {
        var result = []
        for (var i = 0; i < (list || []).length; ++i) {
            result.push(normalizeActivity(list[i]))
        }
        return result
    }

    function normalizeActivity(activity) {
        var source = activity || {}
        var normalized = {}
        for (var key in source) {
            normalized[key] = source[key]
        }
        normalized.id = Number(source.activity_id || source.id || 0)
        normalized.subject = String(source.subject || source.subjectText || source.message || "")
        normalized.icon = String(source.icon || "")
        normalized.datetime = source.datetime || source.dateTime || source.timestamp || ""
        normalized.objectType = String(source.object_type || source.objectType || "")
        normalized.objectId = Number(source.object_id || source.objectId || 0)
        normalized.user = String(source.user || source.actorId || source.actor || "")
        normalized.type = String(source.type || "")
        return normalized
    }

    function attachmentFileName(attachment) {
        var source = attachment || {}
        var extended = source.extendedData || {}
        var info = extended.info || {}
        return String(source.basename || info.basename || source.filename || info.filename || source.name || source.data || i18n.tr("Attachment"))
    }

    function cardEntryFromResponse(card, boardId, stackId, stackTitle, fallback) {
        var source = card || {}
        var backup = fallback || {}
        var resolvedStackTitle = stackTitle || backup.stackTitle || backup.subtitle || i18n.tr("List")
        return {
            "boardId": boardId || backup.boardId || 0,
            "stackId": source.stackId || stackId || backup.stackId || 0,
            "stackTitle": resolvedStackTitle,
            "id": source.id || backup.id || 0,
            "title": source.title || backup.title || i18n.tr("Untitled card"),
            "subtitle": resolvedStackTitle,
            "detail": source.duedate || source.lastModified || source.lastModifiedTimestamp || backup.detail || "",
            "description": source.description || backup.description || "",
            "duedate": source.duedate || backup.duedate || "",
            "startdate": source.startdate || backup.startdate || "",
            "order": source.order || backup.order || 0,
            "typeRaw": source.type || backup.typeRaw || "plain",
            "archived": source.archived === true,
            "owner": nonEmptyArray(source.owner, backup.owner),
            "dependentCards": nonEmptyArray(source.dependentCards, backup.dependentCards),
            "labels": nonEmptyArray(source.labels, backup.labels),
            "_labelsAuthoritative": backup._labelsAuthoritative === true,
            "assignedUsers": nonEmptyArray(source.assignedUsers, backup.assignedUsers),
            "_assignedUsersAuthoritative": backup._assignedUsersAuthoritative === true,
            "attachments": nonEmptyArray(normalizeAttachments(source.attachments), normalizeAttachments(backup.attachments)),
            "comments": source.comments || backup.comments || [],
            "activities": source.activities || backup.activities || [],
            "attachmentCount": nonEmptyArray(normalizeAttachments(source.attachments), normalizeAttachments(backup.attachments)).length || source.attachmentCount || backup.attachmentCount || 0,
            "commentsCount": source.commentsCount || source.commentCount || backup.commentsCount || backup.commentCount || (source.comments && source.comments.length !== undefined ? source.comments.length : 0) || 0,
            "commentsUnread": source.commentsUnread || backup.commentsUnread || 0,
            "done": source.done || backup.done || null,
            "notified": source.notified === true || backup.notified === true,
            "overdue": source.overdue || backup.overdue || 0,
            "deletedAt": source.deletedAt || source.deleted_at || backup.deletedAt || "",
            "status": source.status || backup.status || "",
            "type": "card"
        }
    }

    function nonEmptyArray(primary, fallback) {
        if (primary && primary.length !== undefined && primary.length > 0) {
            return primary
        }
        if (fallback && fallback.length !== undefined) {
            return fallback
        }
        return []
    }

    function isDeletedEntity(value) {
        var entity = value || {}
        var deletedAt = entity.deletedAt || entity.deleted_at || ""
        if (deletedAt !== null && deletedAt !== undefined && String(deletedAt).length > 0 && String(deletedAt) !== "0") {
            return true
        }
        var status = String(entity.status || "").toUpperCase()
        return status === "3" || status === "DELETED" || status === "LOCAL_DELETED"
    }

    function ownerUid(owner) {
        if (!owner) return ""
        if (typeof owner === "string") return owner
        return String(owner.uid || owner.primaryKey || owner.id || owner.displayname || owner.displayName || "")
    }

    function requestJson(url, userName, secret, requestName, callback, generation) {
        if (url.indexOf("http") !== 0 || userName.length === 0 || secret.length === 0) {
            failed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof deckNetwork !== "undefined") {
            nativeRequest(url, userName, secret, "GET", "", "", requestName, callback, generation, null, null)
            return
        }
        var xhr = new XMLHttpRequest()
        xhr.open("GET", authenticatedUrl(url, userName))
        xhr.timeout = 15000
        applyAuthHeaders(xhr, userName, secret)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status < 200 || xhr.status >= 300) {
                failed(i18n.tr("Deck %1 request failed with HTTP %2.").arg(requestName).arg(xhr.status), generation)
                return
            }
            try {
                var parsed = JSON.parse(xhr.responseText)
                callback(parsed)
            } catch (e) {
                failed(i18n.tr("Deck response could not be parsed."), generation)
            }
        }
        xhr.onerror = function() {
            failed(i18n.tr("Deck request failed because the network request could not be completed."), generation)
        }
        xhr.ontimeout = function() {
            failed(i18n.tr("Deck request timed out."), generation)
        }
        xhr.send()
    }

    function requestJsonWithBody(url, userName, secret, method, payload, requestName, callback, generation, conflictCard) {
        if (url.indexOf("http") !== 0 || userName.length === 0 || secret.length === 0) {
            failed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        if (typeof deckNetwork !== "undefined") {
            nativeRequest(url, userName, secret, method, method === "DELETE" ? "" : JSON.stringify(payload || {}),
                "application/json", requestName, callback, generation, payload, conflictCard)
            return
        }
        var xhr = new XMLHttpRequest()
        xhr.open(method, authenticatedUrl(url, userName))
        xhr.timeout = 15000
        applyAuthHeaders(xhr, userName, secret)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status < 200 || xhr.status >= 300) {
                if ((xhr.status === 409 || xhr.status === 412) && conflictCard) {
                    cardConflict(conflictCard, {}, i18n.tr("Server version changed. Local card was not uploaded."), generation)
                    return
                }
                failed(i18n.tr("Deck %1 request failed with HTTP %2.").arg(requestName).arg(xhr.status), generation)
                return
            }
            try {
                var parsed = xhr.responseText && xhr.responseText.length > 0 ? JSON.parse(xhr.responseText) : {}
                callback(parsed)
            } catch (e) {
                failed(i18n.tr("Deck response could not be parsed."), generation)
            }
        }
        xhr.onerror = function() {
            failed(i18n.tr("Deck request failed because the network request could not be completed."), generation)
        }
        xhr.ontimeout = function() {
            failed(i18n.tr("Deck request timed out."), generation)
        }
        xhr.send(method === "DELETE" ? "" : JSON.stringify(payload || {}))
    }

    function requestForm(url, userName, secret, method, fields, requestName, callback, generation) {
        if (url.indexOf("http") !== 0 || userName.length === 0 || secret.length === 0) {
            failed(i18n.tr("Account credentials are incomplete."), generation)
            return
        }
        var body = []
        for (var key in (fields || {})) {
            body.push(encodeURIComponent(key) + "=" + encodeURIComponent(fields[key]))
        }
        if (typeof deckNetwork !== "undefined") {
            nativeRequest(url, userName, secret, method, body.join("&"),
                "application/x-www-form-urlencoded", requestName, callback, generation, fields, null, "form")
            return
        }
        var xhr = new XMLHttpRequest()
        xhr.open(method, authenticatedUrl(url, userName))
        xhr.timeout = 15000
        applyAuthHeaders(xhr, userName, secret)
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status < 200 || xhr.status >= 300) {
                failed(i18n.tr("Deck %1 request failed with HTTP %2.").arg(requestName).arg(xhr.status), generation)
                return
            }
            callback()
        }
        xhr.onerror = function() {
            failed(i18n.tr("Deck request failed because the network request could not be completed."), generation)
        }
        xhr.ontimeout = function() {
            failed(i18n.tr("Deck request timed out."), generation)
        }
        xhr.send(body.join("&"))
    }

    function nextNativeRequestId(kind) {
        nativeRequestSerial += 1
        return kind + "-" + nativeRequestSerial
    }

    function nativeRequest(url, userName, secret, method, body, contentType, requestName, callback, generation, payload, conflictCard, kind) {
        if (typeof deckNetwork === "undefined" || deckNetwork === null) {
            failed(i18n.tr("Native network backend is not available."), generation)
            return
        }
        var requestId = nextNativeRequestId(requestName)
        pendingNativeRequests[requestId] = {
            "kind": kind || "json",
            "method": method,
            "requestName": requestName,
            "callback": callback,
            "payload": payload,
            "conflictCard": conflictCard
        }
        deckNetwork.sendRequest(generation, requestId, method, url, userName, secret, body || "", contentType || "")
    }

    function takePendingNativeRequest(requestId) {
        var pending = pendingNativeRequests[requestId]
        if (!pending) {
            return null
        }
        delete pendingNativeRequests[requestId]
        return pending
    }

    function handleNativeRequestFinished(requestId, status, responseText, generation) {
        var pending = takePendingNativeRequest(requestId)
        if (!pending) {
            return
        }
        if (status < 200 || status >= 300) {
            if ((status === 409 || status === 412) && pending.conflictCard) {
                cardConflict(pending.conflictCard, {}, i18n.tr("Server version changed. Local card was not uploaded."), generation)
                return
            }
            failed(i18n.tr("Deck %1 request failed with HTTP %2.").arg(pending.requestName).arg(status), generation)
            return
        }
        if (pending.kind === "form") {
            pending.callback()
            return
        }
        try {
            var parsed = responseText && responseText.length > 0 ? JSON.parse(responseText) : {}
            pending.callback(parsed)
        } catch (e) {
            failed(i18n.tr("Deck response could not be parsed."), generation)
        }
    }

    function handleNativeRequestFailed(requestId, message, generation) {
        var pending = takePendingNativeRequest(requestId)
        if (!pending) {
            return
        }
        if (pending.kind === "avatar") {
            avatarFailed(pending.userId || "", generation)
            return
        }
        failed(message && message.length > 0 ? message : i18n.tr("Deck request failed because the network request could not be completed."), generation)
    }

    function handleNativeDataUrlFinished(requestId, dataUrl, generation) {
        var pending = takePendingNativeRequest(requestId)
        if (!pending) {
            return
        }
        if (pending.kind !== "avatar") {
            return
        }
        avatarLoaded(pending.userId || "", dataUrl || "", generation)
    }

    function handleNativeFileDownloaded(requestId, fileUrl, fileName, mimeType, generation) {
        var pending = takePendingNativeRequest(requestId)
        if (!pending) {
            return
        }
        if (pending.kind !== "attachment-download") {
            return
        }
        pending.callback(fileUrl || "", fileName || "", mimeType || "application/octet-stream")
    }

    function applyAuthHeaders(xhr, userName, secret) {
        xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(userName + ":" + secret))
        xhr.setRequestHeader("OCS-APIRequest", "true")
        xhr.setRequestHeader("Accept", "application/json")
        xhr.setRequestHeader("Cache-Control", "no-cache")
        xhr.setRequestHeader("Pragma", "no-cache")
        try {
            xhr.setRequestHeader("Cookie", "")
        } catch (e) {
        }
    }

    function authenticatedUrl(url, userName) {
        var value = String(url || "")
        var user = encodeURIComponent(String(userName || ""))
        if (value.length === 0 || user.length === 0 || value.indexOf("://") < 0) {
            return value
        }
        var schemeIndex = value.indexOf("://")
        var slashIndex = value.indexOf("/", schemeIndex + 3)
        var atIndex = value.indexOf("@", schemeIndex + 3)
        if (atIndex > schemeIndex && (slashIndex < 0 || atIndex < slashIndex)) {
            return value
        }
        return value.replace("://", "://" + user + "@")
    }
}
