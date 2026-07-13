import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
import QtGraphicalEffects 1.0
import Qt.labs.settings 1.0
import "../backend"
import "qrc:/NextCommon" as NextCommon
import "qrc:/UTControls" as UTControls

Page {
    id: page
    property var appController
    property bool drawerOpen: false
    property string searchQuery: ""
    property string newCardTitle: ""
    property string newBoardTitle: ""
    property string newListTitle: ""
    property string shareSearchQuery: ""
    property var selectedList: ({})
    property var selectedCard: ({})
    property var selectedBoard: ({})
    property var selectedArchiveItem: ({})
    property var selectedCards: []
    property int selectedCardsRevision: 0
    property var bulkCardsQueue: []
    property string bulkCardsOperation: ""
    property var bulkCardsStack: ({})
    property bool bulkCardsRunning: false
    property bool selectionMode: false
    property var filteredEntries: []
    property var visibleCardEntries: []
    property var visibleBoardEntries: []
    property int activeStackId: 0
    property string filterTab: "tags"
    property string filterDueMode: "all"
    property string filterDoneMode: "all"
    property bool filterNoLabel: false
    property bool filterNoUser: false
    property var filterLabelIds: []
    property var filterUserIds: []
    property string draftFilterDueMode: "all"
    property string draftFilterDoneMode: "all"
    property bool draftFilterNoLabel: false
    property bool draftFilterNoUser: false
    property var draftFilterLabelIds: []
    property var draftFilterUserIds: []
    property bool showArchivedCardsMode: false
    property bool archiveOverviewMode: false
    property bool cardPullToRefreshEnabled: appController ? appController.pullToRefreshEnabled : true
    onShowArchivedCardsModeChanged: updateVisibleCardEntries()
    readonly property string actionBlue: "#2c7fb8"
    readonly property real pullRefreshThreshold: units.gu(7)
    readonly property string accountInitial: accountSettings.displayName.length > 0
        ? accountSettings.displayName.charAt(0).toUpperCase()
        : "?"

    Settings {
        id: accountSettings
        category: "account"
        property string displayName: ""
    }

    Settings {
        id: uiSettings
        category: "deck-ui"
        property string lastStackByBoardJson: "{}"
    }

    function openPage(url) {
        drawerOpen = false
        pageStack.push(Qt.resolvedUrl(url), {"appController": appController})
    }

    function openCard(card) {
        archiveOverviewMode = false
        if (appController && appController.openCardLinksDirectly) {
            var link = cardShareLink(card)
            if (link.length > 0) {
                Qt.openUrlExternally(link)
                return
            }
        }
        pageStack.push(Qt.resolvedUrl("CardDetailPage.qml"), {"appController": appController, "deckController": dataController, "card": card})
    }

    function stackOptions() {
        var options = []
        var seen = {}
        var source = dataController.entries || []
        for (var i = 0; i < source.length; ++i) {
            var entry = source[i]
            if (entry.type === "stack") {
                var id = Number(entry.stackId || 0)
                if (seen[id]) {
                    continue
                }
                seen[id] = true
                options.push({
                    "boardId": entry.boardId,
                    "stackId": id,
                    "stackTitle": entry.stackTitle || entry.title || i18n.tr("List"),
                    "order": Number(entry.order || 0),
                    "__seq": options.length
                })
            }
        }
        for (var c = 0; c < source.length; ++c) {
            var card = source[c]
            if (card.type !== "card") {
                continue
            }
            var stackId = Number(card.stackId || 0)
            if (stackId > 0 && !seen[stackId]) {
                seen[stackId] = true
                options.push({
                    "boardId": card.boardId,
                    "stackId": stackId,
                    "stackTitle": card.stackTitle || i18n.tr("List"),
                    "order": 0,
                    "__seq": options.length
                })
            }
        }
        options.sort(function(a, b) {
            if (a.order !== b.order) return a.order - b.order
            return a.__seq - b.__seq
        })
        return options
    }

    function showCreateCardDialog() {
        newCardTitle = ""
        ensureActiveStack()
        if (stackEntries().length === 0) {
            showCreateListDialog()
            return
        }
        if (activeStackId > 0) {
            PopupUtils.open(createCardDialog)
        }
    }

    function showCreateBoardDialog() {
        newBoardTitle = ""
        PopupUtils.open(createBoardDialog)
    }

    function showCreateListDialog() {
        newListTitle = ""
        PopupUtils.open(createListDialog)
    }

    function showBoardShareDialog(board) {
        selectedBoard = board || dataController.currentBoardEntry()
        shareSearchQuery = ""
        dataController.sharees = []
        PopupUtils.open(boardShareDialog)
        dataController.searchSharees("")
    }

    function showBoardOptionsDialog(board) {
        selectedBoard = board || dataController.currentBoardEntry()
        PopupUtils.open(boardOptionsDialog)
    }

    function archiveSelectedBoard(archived) {
        if (!selectedBoard || !selectedBoard.id) {
            return
        }
        var updated = {}
        for (var key in selectedBoard) updated[key] = selectedBoard[key]
        updated.archived = archived === true
        dataController.updateBoard(updated)
    }

    function showListOptions(listEntry) {
        selectedList = listEntry || ({})
        newListTitle = selectedList.title || ""
        PopupUtils.open(listOptionsDialog)
    }

    function stackEntries() {
        var result = []
        var source = dataController.entries || []
        for (var i = 0; i < source.length; ++i) {
            if (source[i].type === "stack") {
                result.push(source[i])
            }
        }
        result.sort(function(a, b) {
            var orderA = Number(a.order || 0)
            var orderB = Number(b.order || 0)
            if (orderA !== orderB) return orderA - orderB
            return Number(a.stackId || 0) - Number(b.stackId || 0)
        })
        return result
    }

    function activeStackEntry() {
        var stacks = stackEntries()
        for (var i = 0; i < stacks.length; ++i) {
            if (Number(stacks[i].stackId || 0) === Number(activeStackId || 0)) {
                return stacks[i]
            }
        }
        return stacks.length > 0 ? stacks[0] : ({})
    }

    function ensureActiveStack() {
        if (dataController.viewMode !== "cards") {
            activeStackId = 0
            return
        }
        var stacks = stackEntries()
        if (stacks.length === 0) {
            activeStackId = 0
            return
        }
        for (var i = 0; i < stacks.length; ++i) {
            if (Number(stacks[i].stackId || 0) === Number(activeStackId || 0)) {
                return
            }
        }
        var savedStackId = lastStackForCurrentBoard()
        if (savedStackId > 0) {
            for (var j = 0; j < stacks.length; ++j) {
                if (Number(stacks[j].stackId || 0) === savedStackId) {
                    activeStackId = savedStackId
                    return
                }
            }
        }
        activeStackId = Number(stacks[0].stackId || 0)
    }

    function selectStack(stackId) {
        archiveOverviewMode = false
        showArchivedCardsMode = false
        activeStackId = Number(stackId || 0)
        saveLastStackForCurrentBoard(activeStackId)
        updateFilteredEntries()
    }

    function stackStateKey() {
        if (!dataController || dataController.selectedBoardId <= 0) {
            return ""
        }
        return dataController.accountKey() + "|board:" + Number(dataController.selectedBoardId || 0)
    }

    function lastStackMap() {
        try {
            return JSON.parse(uiSettings.lastStackByBoardJson || "{}")
        } catch (e) {
            return {}
        }
    }

    function saveLastStackForCurrentBoard(stackId) {
        var key = stackStateKey()
        if (key.length === 0 || Number(stackId || 0) <= 0) {
            return
        }
        var map = lastStackMap()
        map[key] = Number(stackId)
        uiSettings.lastStackByBoardJson = JSON.stringify(map)
    }

    function lastStackForCurrentBoard() {
        var key = stackStateKey()
        if (key.length === 0) {
            return 0
        }
        var map = lastStackMap()
        return Number(map[key] || 0)
    }

    function activeCards() {
        var cards = []
        for (var i = 0; i < filteredEntries.length; ++i) {
            if (filteredEntries[i].type === "card" && filteredEntries[i].archived !== true) {
                cards.push(filteredEntries[i])
            }
        }
        return cards
    }

    function archivedCards() {
        var cards = []
        var source = dataController.entries || []
        for (var i = 0; i < source.length; ++i) {
            if (source[i].type === "card" && source[i].archived === true) {
                cards.push(source[i])
            }
        }
        return cards
    }

    function visibleCards() {
        return showArchivedCardsMode ? archivedCards() : activeCards()
    }

    function cardsForStack(stack, archived) {
        var result = []
        var stackId = Number((stack || {}).stackId || 0)
        if (stackId <= 0) {
            return result
        }
        var source = dataController.entries || []
        for (var i = 0; i < source.length; ++i) {
            var entry = source[i] || {}
            if (entry.type === "card"
                    && Number(entry.stackId || 0) === stackId
                    && (entry.archived === true) === (archived === true)) {
                result.push(entry)
            }
        }
        return result
    }

    function updateVisibleCardEntries() {
        visibleCardEntries = visibleCards()
    }

    function reorderableCardModel() {
        var result = []
        for (var i = 0; i < visibleCardEntries.length; ++i) {
            var card = visibleCardEntries[i] || {}
            result.push({
                "__sourceIndex": i,
                "type": "card",
                "id": card.id || 0,
                "localKey": card.localKey || "",
                "boardId": card.boardId || 0,
                "stackId": card.stackId || 0,
                "stackTitle": card.stackTitle || "",
                "title": card.title || "",
                "archived": card.archived === true,
                "done": card.done || "",
                "order": card.order || 0
            })
        }
        return result
    }

    function cardForVisualItem(item) {
        if (!item) {
            return ({})
        }
        if (item.item) {
            item = item.item
        }
        var index = Number(item.__sourceIndex)
        if (!isNaN(index) && index >= 0 && index < visibleCardEntries.length) {
            return visibleCardEntries[index]
        }
        var id = Number(item.id || 0)
        var key = String(item.localKey || "")
        for (var i = 0; i < visibleCardEntries.length; ++i) {
            var card = visibleCardEntries[i]
            if (id > 0 && Number(card.id || 0) === id) {
                return card
            }
            if (key.length > 0 && String(card.localKey || "") === key) {
                return card
            }
        }
        return item
    }

    function showCardOptions(card) {
        selectedCard = card || ({})
        PopupUtils.open(cardOptionsDialog)
    }

    function selectedCardItems() {
        var ignored = selectedCardsRevision
        var output = []
        var source = selectedCards || []
        for (var i = 0; i < source.length; ++i) {
            var item = source[i] && source[i].itemData ? source[i].itemData : source[i]
            if (item && item.item) {
                item = item.item
            }
            item = cardForVisualItem(item)
            if (item && item.type === "card") {
                output.push(item)
            }
        }
        return output
    }

    function selectedCardCount() {
        return selectedCardItems().length
    }

    function clearCardSelection() {
        selectedCards = []
        selectedCardsRevision += 1
        selectionMode = false
        if (reorderableCards) {
            reorderableCards.clearSelection()
        }
    }

    function startBulkCardOperation(operation, cards, stack) {
        bulkCardsQueue = (cards || []).slice(0)
        bulkCardsOperation = operation || ""
        bulkCardsStack = stack || ({})
        bulkCardsRunning = bulkCardsQueue.length > 0
        page.clearCardSelection()
        processNextBulkCard()
    }

    function processNextBulkCard() {
        if (!bulkCardsRunning || dataController.loading) {
            return
        }
        if (bulkCardsQueue.length === 0) {
            bulkCardsRunning = false
            bulkCardsOperation = ""
            bulkCardsStack = ({})
            dataController.statusText = i18n.tr("Bulk action finished.")
            return
        }
        var cards = bulkCardsQueue.slice(0)
        var card = cards.shift()
        bulkCardsQueue = cards
        if (bulkCardsOperation === "archive") {
            dataController.archiveCard(card, true)
        } else if (bulkCardsOperation === "restore") {
            dataController.archiveCard(card, false)
        } else if (bulkCardsOperation === "delete") {
            dataController.deleteCard(card)
        } else if (bulkCardsOperation === "move") {
            dataController.moveCardToStack(card, bulkCardsStack)
        }
        Qt.callLater(processNextBulkCard)
    }

    function archiveSelectedCards(archived) {
        var cards = selectedCardItems()
        if (cards.length > 0) {
            startBulkCardOperation(archived === true ? "archive" : "restore", cards, ({}))
        }
    }

    function archiveCardsInList(stack) {
        var cards = cardsForStack(stack, false)
        if (cards.length === 0) {
            dataController.statusText = i18n.tr("No active cards to archive.")
            return
        }
        startBulkCardOperation("archive", cards, ({}))
    }

    function deleteSelectedCards() {
        var cards = selectedCardItems()
        if (cards.length > 0) {
            startBulkCardOperation("delete", cards, ({}))
        }
    }

    function moveSelectedCardsToStack(stack) {
        var cards = selectedCardItems()
        if (cards.length > 0) {
            startBulkCardOperation("move", cards, stack)
        }
    }

    function availableMoveStacksForCards(cards) {
        var ignored = selectedCardsRevision
        var selected = cards || []
        var stacks = []
        var source = dataController.entries || []
        for (var s = 0; s < source.length; ++s) {
            if (source[s].type === "stack") {
                stacks.push({
                    "boardId": source[s].boardId,
                    "stackId": source[s].stackId,
                    "stackTitle": source[s].stackTitle || source[s].title || i18n.tr("List")
                })
            }
        }
        if (stacks.length === 0) {
            stacks = stackOptions()
        }
        var result = []
        for (var i = 0; i < stacks.length; ++i) {
            var stack = stacks[i]
            var stackId = Number(stack.stackId || 0)
            var canMoveAny = false
            for (var j = 0; j < selected.length; ++j) {
                if (Number(selected[j].stackId || 0) !== stackId) {
                    canMoveAny = true
                    break
                }
            }
            if (canMoveAny) {
                result.push(stack)
            }
        }
        return result
    }

    function selectedCardsMoveTargets() {
        return availableMoveStacksForCards(selectedCardItems())
    }

    function cardShareLink(card) {
        if (!card || !card.id || !dataController.selectedBoardId) {
            return ""
        }
        return String(dataController.accountServerUrl || "")
            + "/index.php/apps/deck/#/board/" + encodeURIComponent(dataController.selectedBoardId)
            + "/card/" + encodeURIComponent(card.id)
    }

    function cardShareContent(card) {
        var parts = []
        var title = String(card && card.title ? card.title : "")
        if (title.length > 0) parts.push(title)
        var description = String(card && card.description ? card.description : "")
        if (description.length > 0) parts.push(description)
        var link = cardShareLink(card)
        if (link.length > 0) parts.push(link)
        return parts.join("\n\n")
    }

    function shareText(title, text) {
        var content = String(text || "")
        if (content.length === 0) {
            dataController.statusText = i18n.tr("There is no card text to share.")
            return
        }
        var sharePage = pageStack.push(Qt.resolvedUrl("../backend/DeckShareExportPage.qml"), {
            "shareTitle": title || i18n.tr("Shared card"),
            "shareText": content
        })
        if (!sharePage) {
            sharePage = pageStack.push(Qt.resolvedUrl("../backend/DeckShareExportPageUbuntu.qml"), {
                "shareTitle": title || i18n.tr("Shared card"),
                "shareText": content
            })
        }
        if (!sharePage) {
            dataController.statusText = i18n.tr("Sharing is not available.")
            return
        }
        sharePage.shareFinished.connect(function() {
            pageStack.pop()
        })
        sharePage.shareFailed.connect(function(message) {
            dataController.statusText = message
            pageStack.pop()
        })
    }

    function shareSelectedCardLink() {
        var link = cardShareLink(selectedCard)
        shareText(selectedCard.title || i18n.tr("Shared card"), link)
    }

    function shareSelectedCardContent() {
        shareText(selectedCard.title || i18n.tr("Shared card"), cardShareContent(selectedCard))
    }

    function archiveSelectedCard() {
        dataController.archiveCard(selectedCard, selectedCard.archived !== true)
    }

    function assignSelectedCardToMe() {
        var id = String(dataController.currentUserName || "")
        if (id.length === 0) {
            return
        }
        var updated = {}
        for (var key in (selectedCard || {})) updated[key] = selectedCard[key]
        var users = []
        var current = selectedCard.assignedUsers || []
        var found = false
        for (var i = 0; i < current.length; ++i) {
            var existing = current[i]
            users.push(existing)
            if (page.userId(existing) === id) {
                found = true
            }
        }
        if (!found) {
            users.push({"uid": id, "id": id, "displayName": id, "displayname": id})
        }
        updated.assignedUsers = users
        updated._assignedUsersAuthoritative = true
        selectedCard = updated
        dataController.requestAvatar(id)
        dataController.assignUser(updated, id, true)
    }

    function moveSelectedCardToStack(stack) {
        dataController.moveCardToStack(selectedCard, stack)
    }

    function cardKey(card) {
        if (!card) {
            return ""
        }
        if (card.id) {
            return "id:" + String(card.id)
        }
        if (card.localKey) {
            return "local:" + String(card.localKey)
        }
        return ""
    }

    function reorderVisibleCards(fromIndex, toIndex) {
        var cards = visibleCards()
        if (fromIndex < 0 || fromIndex >= cards.length || toIndex < 0 || toIndex >= cards.length || fromIndex === toIndex) {
            return
        }
        var moved = cards[fromIndex]
        cards.splice(fromIndex, 1)
        cards.splice(toIndex, 0, moved)
        visibleCardEntries = cards.slice(0)
        dataController.applyCardOrder(cards)
        dataController.saveCardOrder(moved, toIndex)
    }

    function activeStackIndex() {
        var stacks = stackEntries()
        for (var i = 0; i < stacks.length; ++i) {
            if (Number(stacks[i].stackId || 0) === Number(activeStackId || 0)) {
                return i
            }
        }
        return -1
    }

    function canMoveActiveStackRight() {
        var index = activeStackIndex()
        return index >= 0 && index < stackEntries().length - 1
    }

    function moveActiveStackRight() {
        var stacks = stackEntries()
        var index = activeStackIndex()
        if (index < 0 || index >= stacks.length - 1) {
            return
        }
        var current = stacks[index]
        var next = stacks[index + 1]
        var nextOrder = Number(next.order || ((index + 2) * 1000))
        var newOrder
        if (index + 2 < stacks.length) {
            var afterNext = Number(stacks[index + 2].order || ((index + 3) * 1000))
            newOrder = afterNext > nextOrder ? Math.floor((nextOrder + afterNext) / 2) : nextOrder + 1
            if (newOrder <= nextOrder) {
                newOrder = nextOrder + 1
            }
        } else {
            newOrder = nextOrder + 1000
        }
        var updated = {}
        for (var key in current) updated[key] = current[key]
        updated.order = newOrder
        updated._isReorder = true
        dataController.applyStackOrderLocally(current.stackId, newOrder)
        dataController.updateStack(updated)
    }

    function boardEntries() {
        var result = []
        var source = dataController.viewMode === "boards" ? (dataController.entries || []) : (dataController.cachedBoards || [])
        for (var i = 0; i < source.length; ++i) {
            if (source[i].type === "board" && source[i].archived !== true) {
                result.push(source[i])
            }
        }
        return result
    }

    function boardCardCount(board) {
        var boardId = Number(board && board.id ? board.id : 0)
        if (boardId <= 0) {
            return 0
        }
        var directCount = Number(board.cardCount || board.cardsCount || board.nbCards || 0)
        if (directCount > 0) {
            return directCount
        }
        if (Number(dataController.selectedBoardId || 0) === boardId) {
            var visibleCount = 0
            var source = dataController.entries || []
            for (var i = 0; i < source.length; ++i) {
                if (source[i].type === "card" && source[i].archived !== true) {
                    visibleCount += 1
                }
            }
            if (visibleCount > 0) {
                return visibleCount
            }
        }
        var counts = dataController.boardCardCounts || {}
        return Number(counts[String(boardId)] || 0)
    }

    function archivedCardCount() {
        var count = 0
        for (var i = 0; i < filteredEntries.length; ++i) {
            if (filteredEntries[i].type === "card" && filteredEntries[i].archived === true) {
                count += 1
            }
        }
        return count
    }

    function showActiveCards() {
        archiveOverviewMode = false
        showArchivedCardsMode = false
        drawerOpen = false
        updateVisibleCardEntries()
    }

    function showArchivedCards() {
        showArchivedCardsMode = true
        drawerOpen = false
        updateVisibleCardEntries()
    }

    function showArchiveOverview() {
        archiveOverviewMode = true
        showArchivedCardsMode = false
        drawerOpen = false
        updateVisibleCardEntries()
    }

    function archiveOverviewItems() {
        var result = []
        var boards = dataController.cachedBoards || []
        for (var i = 0; i < boards.length; ++i) {
            if (boards[i].type === "board" && boards[i].archived === true) {
                var board = {}
                for (var boardKey in boards[i]) board[boardKey] = boards[i][boardKey]
                board.archiveType = "board"
                result.push(board)
            }
        }
        var cards = archivedCards()
        for (var j = 0; j < cards.length; ++j) {
            var card = {}
            for (var cardKey in cards[j]) card[cardKey] = cards[j][cardKey]
            card.archiveType = "card"
            result.push(card)
        }
        return result
    }

    function archiveOverviewCount() {
        return archiveOverviewItems().length
    }

    function restoreArchiveItem(item) {
        if (!item) {
            return
        }
        if (item.archiveType === "board") {
            selectedBoard = item
            archiveSelectedBoard(false)
        } else if (item.archiveType === "card") {
            dataController.archiveCard(item, false)
        }
    }

    function deleteArchiveItem(item) {
        if (!item) {
            return
        }
        if (item.archiveType === "board") {
            dataController.deleteBoard(item)
        } else if (item.archiveType === "card") {
            dataController.deleteCard(item)
        }
    }

    function requestDeleteArchiveItem(item) {
        selectedArchiveItem = item || ({})
        PopupUtils.open(deleteArchiveItemConfirmDialog)
    }

    function updateVisibleBoardEntries() {
        visibleBoardEntries = boardEntries()
    }

    function boardColor(board) {
        var color = String(board && board.color ? board.color : "").replace("#", "")
        if (color.length === 6) {
            return "#" + color
        }
        return page.actionBlue
    }

    function boardOwnerDisplay(board) {
        var owner = (board || {}).owner || {}
        if (typeof owner === "string") return owner
        return owner.displayname || owner.displayName || owner.uid || owner.id || dataController.currentUserName || i18n.tr("Owner")
    }

    function aclParticipantDisplay(acl) {
        var participant = (acl || {}).participant || {}
        if (typeof participant === "string") return participant
        var suffix = ""
        if (Number((acl || {}).type || 0) === 1) suffix = " " + i18n.tr("(Group)")
        if (Number((acl || {}).type || 0) === 7) suffix = " " + i18n.tr("(Team)")
        if (Number((acl || {}).type || 0) === 6) suffix = " " + i18n.tr("(Remote)")
        return (participant.displayname || participant.displayName || participant.uid || participant.id || i18n.tr("Shared user")) + suffix
    }

    function toggleAclPermission(acl, permissionName) {
        var updated = {}
        for (var key in (acl || {})) updated[key] = acl[key]
        updated[permissionName] = updated[permissionName] !== true
        dataController.updateAccessControl(selectedBoard, updated)
    }

    function filterActive() {
        return filterDueMode !== "all"
            || filterDoneMode !== "all"
            || filterNoLabel
            || filterNoUser
            || filterLabelIds.length > 0
            || filterUserIds.length > 0
    }

    function selectedFilterCount() {
        var count = 0
        if (filterDueMode !== "all") count += 1
        if (filterDoneMode !== "all") count += 1
        if (filterNoLabel) count += 1
        if (filterNoUser) count += 1
        count += filterLabelIds.length
        count += filterUserIds.length
        return count
    }

    function resetFilters() {
        filterDueMode = "all"
        filterDoneMode = "all"
        filterNoLabel = false
        filterNoUser = false
        filterLabelIds = []
        filterUserIds = []
        updateFilteredEntries()
    }

    function resetAccountLocalState() {
        activeStackId = 0
        archiveOverviewMode = false
        showArchivedCardsMode = false
        filteredEntries = []
        visibleCardEntries = []
        visibleBoardEntries = []
        selectedList = ({})
        selectedCard = ({})
        resetFilters()
    }

    function beginFilterDraft() {
        filterTab = "tags"
        draftFilterDueMode = filterDueMode
        draftFilterDoneMode = filterDoneMode
        draftFilterNoLabel = filterNoLabel
        draftFilterNoUser = filterNoUser
        draftFilterLabelIds = filterLabelIds.slice(0)
        draftFilterUserIds = filterUserIds.slice(0)
        PopupUtils.open(filterDialog)
    }

    function resetFilterDraft() {
        draftFilterDueMode = "all"
        draftFilterDoneMode = "all"
        draftFilterNoLabel = false
        draftFilterNoUser = false
        draftFilterLabelIds = []
        draftFilterUserIds = []
    }

    function applyFilterDraft() {
        filterDueMode = draftFilterDueMode
        filterDoneMode = draftFilterDoneMode
        filterNoLabel = draftFilterNoLabel
        filterNoUser = draftFilterNoUser
        filterLabelIds = draftFilterLabelIds.slice(0)
        filterUserIds = draftFilterUserIds.slice(0)
        updateFilteredEntries()
    }

    function labelOptions() {
        var labels = []
        var seen = {}
        var boardLabels = dataController.selectedBoardLabels || []
        for (var i = 0; i < boardLabels.length; ++i) {
            var label = boardLabels[i]
            var id = Number(label.id || 0)
            if (id > 0 && !seen[id]) {
                seen[id] = true
                labels.push(label)
            }
        }
        var entries = dataController.entries || []
        for (var e = 0; e < entries.length; ++e) {
            var cardLabels = entries[e].labels || []
            for (var j = 0; j < cardLabels.length; ++j) {
                var cardLabel = cardLabels[j]
                var cardLabelId = Number(cardLabel.id || 0)
                if (cardLabelId > 0 && !seen[cardLabelId]) {
                    seen[cardLabelId] = true
                    labels.push(cardLabel)
                }
            }
        }
        return labels
    }

    function userOptions() {
        var users = []
        var seen = {}
        var entries = dataController.entries || []
        for (var e = 0; e < entries.length; ++e) {
            var cardUsers = entries[e].assignedUsers || []
            for (var i = 0; i < cardUsers.length; ++i) {
                var user = cardUsers[i]
                var id = String(user.uid || user.id || user.primaryKey || user.displayName || "")
                if (id.length > 0 && !seen[id]) {
                    seen[id] = true
                    users.push(user)
                }
            }
        }
        return users
    }

    function optionSelected(list, value) {
        var key = String(value)
        for (var i = 0; i < list.length; ++i) {
            if (String(list[i]) === key) return true
        }
        return false
    }

    function toggleOption(list, value) {
        var key = String(value)
        var next = []
        var removed = false
        for (var i = 0; i < list.length; ++i) {
            if (String(list[i]) === key) {
                removed = true
            } else {
                next.push(list[i])
            }
        }
        if (!removed) next.push(value)
        return next
    }

    function labelColor(label) {
        var color = String(label && label.color ? label.color : "").replace("#", "")
        if (color.length === 6) return "#" + color
        return page.actionBlue
    }

    function cardLabels(card) {
        return (card && card.labels && card.labels.length !== undefined) ? card.labels : []
    }

    function cardAssignedUsers(card) {
        return (card && card.assignedUsers && card.assignedUsers.length !== undefined) ? card.assignedUsers : []
    }

    function cardHasDescription(card) {
        return String(card && card.description ? card.description : "").trim().length > 0
    }

    function cardAttachmentCount(card) {
        var count = Number(card && card.attachmentCount ? card.attachmentCount : 0)
        if (count > 0) {
            return count
        }
        var attachments = card && card.attachments && card.attachments.length !== undefined ? card.attachments : []
        return attachments.length
    }

    function cardCommentCount(card) {
        var count = Number(card && card.commentsCount ? card.commentsCount : (card && card.commentCount ? card.commentCount : 0))
        if (count > 0) {
            return count
        }
        var comments = card && card.comments && card.comments.length !== undefined ? card.comments : []
        if (comments.length > 0) {
            return comments.length
        }
        return Number(card && card.commentsUnread ? card.commentsUnread : 0)
    }

    function cardInfoBadges(card) {
        var badges = []
        if (cardHasDescription(card)) {
            badges.push({"kind": "description", "icon": "\u2630", "count": 0})
        }
        var attachments = cardAttachmentCount(card)
        if (attachments > 0) {
            badges.push({"kind": "attachments", "icon": "\uD83D\uDCCE", "count": attachments})
        }
        var comments = cardCommentCount(card)
        if (comments > 0) {
            badges.push({"kind": "comments", "icon": "\uD83D\uDCAC", "count": comments})
        }
        return badges
    }

    function effectiveCard(card, sourceEntries) {
        if (!card || card.type !== "card") {
            return card || ({})
        }
        var source = sourceEntries || dataController.entries || []
        var cardId = Number(card && card.id ? card.id : 0)
        var localKey = String(card && card.localKey ? card.localKey : "")
        for (var i = 0; i < source.length; ++i) {
            var entry = source[i]
            if (!entry || entry.type !== "card") {
                continue
            }
            if (cardId > 0 && Number(entry.id || 0) === cardId) {
                return entry
            }
            if (localKey.length > 0 && String(entry.localKey || "") === localKey) {
                return entry
            }
        }
        return card || ({})
    }

    function cardRowHeight(card) {
        var title = String(card && card.title ? card.title : i18n.tr("Untitled"))
        var titleAreaWidth = Math.max(1, page.width - units.gu(11))
        var approxCharsPerLine = Math.max(14, Math.floor(titleAreaWidth / units.gu(0.75)))
        var titleLines = Math.min(6, Math.max(1, Math.ceil(title.length / approxCharsPerLine)))
        var labelCount = cardLabels(card).length
        var userCount = cardAssignedUsers(card).length
        var metaRows = labelCount > 0 ? Math.max(1, Math.ceil(labelCount / 2)) : 0
        if (userCount > 0) {
            metaRows = Math.max(metaRows, 1)
        }
        return units.gu(3.0) + titleLines * units.gu(2.05) + metaRows * units.gu(2.7)
    }

    function userDisplayName(user) {
        if (user && user.participant) {
            return userDisplayName(user.participant)
        }
        return String(user.displayName || user.displayname || user.uid || user.userId || user.id || i18n.tr("User"))
    }

    function userId(user) {
        if (user && user.participant) {
            return userId(user.participant)
        }
        return String(user.uid || user.userId || user.primaryKey || user.id || user.displayName || user.displayname || "")
    }

    function userInitial(user) {
        var name = userDisplayName(user)
        return name.length > 0 ? name.charAt(0).toUpperCase() : "?"
    }

    function userAvatarUrl(user) {
        var id = userId(user)
        if (id.length === 0 || !dataController) {
            return ""
        }
        return dataController.avatarDataUrl(id)
    }

    function cardDone(card) {
        return String(card && card.done ? card.done : "").length > 0
    }

    function formatDoneDate(value) {
        var text = String(value || "")
        var parsed = Date.parse(text)
        if (isNaN(parsed)) {
            return text
        }
        var date = new Date(parsed)
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return pad2(date.getDate()) + "-" + months[date.getMonth()] + "-" + date.getFullYear()
            + " " + pad2(date.getHours()) + ":" + pad2(date.getMinutes())
    }

    function pad2(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function parseDueDate(value) {
        var text = String(value || "")
        if (text.length === 0) return null
        var parsed = Date.parse(text)
        if (isNaN(parsed)) return null
        return new Date(parsed)
    }

    function dueModeMatches(card) {
        if (filterDueMode === "all") return true
        var due = parseDueDate(card.duedate || card.detail || "")
        if (!due) return filterDueMode === "none"

        var now = new Date()
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
        var tomorrow = new Date(today.getTime() + 24 * 60 * 60 * 1000)
        var dayAfterTomorrow = new Date(today.getTime() + 2 * 24 * 60 * 60 * 1000)
        var nextWeek = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000)
        var nextMonth = new Date(today.getTime() + 30 * 24 * 60 * 60 * 1000)

        if (filterDueMode === "overdue") return due < today && !cardDone(card)
        if (filterDueMode === "today") return due >= today && due < tomorrow
        if (filterDueMode === "tomorrow") return due >= tomorrow && due < dayAfterTomorrow
        if (filterDueMode === "week") return due >= today && due < nextWeek
        if (filterDueMode === "month") return due >= today && due < nextMonth
        if (filterDueMode === "later") return due >= nextMonth
        return true
    }

    function doneModeMatches(card) {
        if (filterDoneMode === "done") return cardDone(card)
        if (filterDoneMode === "undone") return !cardDone(card)
        return true
    }

    function labelsMatch(card) {
        var labels = card.labels || []
        if (filterNoLabel && labels.length !== 0) return false
        if (filterLabelIds.length === 0) return true
        for (var i = 0; i < labels.length; ++i) {
            if (optionSelected(filterLabelIds, Number(labels[i].id || 0))) return true
        }
        return false
    }

    function usersMatch(card) {
        var users = card.assignedUsers || []
        if (filterNoUser && users.length !== 0) return false
        if (filterUserIds.length === 0) return true
        for (var i = 0; i < users.length; ++i) {
            if (optionSelected(filterUserIds, userId(users[i]))) return true
        }
        return false
    }

    function cardMatchesSearch(entry, query) {
        if (query.length === 0) return true
        var text = String(entry.title || "") + " " + String(entry.subtitle || "") + " " + String(entry.detail || "")
        return text.toLowerCase().indexOf(query) >= 0
    }

    function cardMatchesFilters(entry, query) {
        if (entry.type !== "card") return cardMatchesSearch(entry, query)
        return cardMatchesSearch(entry, query)
            && dueModeMatches(entry)
            && doneModeMatches(entry)
            && labelsMatch(entry)
            && usersMatch(entry)
    }

    function updateFilteredEntries() {
        ensureActiveStack()
        var query = String(searchQuery || "").toLowerCase()
        var filtersEnabled = filterActive()
        var source = dataController.entries || []
        if (dataController.viewMode === "boards") {
            filteredEntries = []
            visibleCardEntries = []
            return
        }
        if (query.length === 0 && !filtersEnabled) {
            if (dataController.viewMode === "cards" && activeStackId > 0) {
                var stackCards = []
                for (var s = 0; s < source.length; ++s) {
                    if (source[s].type === "card" && Number(source[s].stackId || 0) === activeStackId) {
                        stackCards.push(source[s])
                    }
                }
                filteredEntries = stackCards
                updateVisibleCardEntries()
            } else {
                filteredEntries = source
                updateVisibleCardEntries()
            }
            return
        }

        var result = []
        for (var i = 0; i < source.length; ++i) {
            var entry = source[i]
            if (dataController.viewMode === "cards" && entry.type !== "card") {
                continue
            }
            if (cardMatchesFilters(entry, query)) {
                if (dataController.viewMode === "cards" && Number(entry.stackId || 0) !== activeStackId) {
                    continue
                }
                result.push(entry)
            }
        }
        filteredEntries = result
        updateVisibleCardEntries()
    }

    onSearchQueryChanged: updateFilteredEntries()
    onFilterDueModeChanged: updateFilteredEntries()
    onFilterDoneModeChanged: updateFilteredEntries()
    onFilterNoLabelChanged: updateFilteredEntries()
    onFilterNoUserChanged: updateFilteredEntries()
    onFilterLabelIdsChanged: updateFilteredEntries()
    onFilterUserIdsChanged: updateFilteredEntries()
    onActiveStackIdChanged: updateFilteredEntries()

    function statusIconKind() {
        if (dataController.loading) {
            return "syncing"
        }
        if (dataController.syncStateText === i18n.tr("Sync failed")) {
            return "warning"
        }
        if (dataController.syncStateText === i18n.tr("Up to date")) {
            return "synced"
        }
        return "warning"
    }

    function statusAccentColor() {
        if (dataController.loading) {
            return "#2c7fb8"
        }
        return dataController.syncStateColor
    }

    function statusDetailsText() {
        var parts = []
        if (dataController.statusText.length > 0) {
            parts.push(dataController.statusText)
        }
        if (dataController.syncStateText.length > 0) {
            parts.push(i18n.tr("Sync: %1").arg(dataController.syncStateText))
        }
        return parts.length > 0 ? parts.join("\n") : i18n.tr("No status message.")
    }

    header: PageHeader {
        id: header
        title: ""

        contents: Item {
            anchors.fill: parent

            NextCommon.MainTopBar {
                visible: !page.selectionMode
                searchText: page.searchQuery
                searchPlaceholder: dataController.viewMode === "cards"
                    ? i18n.tr("Search in %1").arg(dataController.selectedBoardTitle)
                    : i18n.tr("Search")
                filterActive: page.filterActive()
                statusKind: page.statusIconKind()
                statusColor: page.statusAccentColor()
                statusAnimating: dataController.loading
                avatarUrl: dataController.accountAvatarUrl
                accountInitial: page.accountInitial
                actionColor: page.actionBlue
                iconColor: theme.palette.normal.backgroundText

                onMenuClicked: page.drawerOpen = true
                onSearchChanged: page.searchQuery = text
                onClearSearchClicked: page.searchQuery = ""
                onFilterClicked: page.beginFilterDraft()
                onStatusClicked: PopupUtils.open(statusDetailsDialog)
                onAccountClicked: page.openPage("AccountSelectionPage.qml")
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: units.gu(0.5)
                    rightMargin: units.gu(0.5)
                }
                visible: page.selectionMode
                spacing: units.gu(0.75)

                Item {
                    Layout.preferredWidth: units.gu(3.4)
                    Layout.preferredHeight: units.gu(5)

                    Label {
                        anchors.centerIn: parent
                        text: "\u2715"
                        color: theme.palette.normal.backgroundText
                        font.pixelSize: units.gu(2.6)
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.clearCardSelection()
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("%1 selected").arg(page.selectedCardCount())
                    font.bold: true
                    elide: Text.ElideRight
                }

                UTControls.AppButton {
                    Layout.preferredWidth: units.gu(9)
                    Layout.preferredHeight: units.gu(5)
                    text: page.showArchivedCardsMode ? i18n.tr("Restore") : i18n.tr("Archive")
                    enabled: page.selectedCardCount() > 0 && !dataController.loading
                    onClicked: page.archiveSelectedCards(!page.showArchivedCardsMode)
                }

                UTControls.AppButton {
                    Layout.preferredWidth: units.gu(8.5)
                    Layout.preferredHeight: units.gu(5)
                    text: i18n.tr("Move")
                    enabled: page.selectedCardCount() > 0 && !dataController.loading
                    onClicked: PopupUtils.open(moveSelectedCardsDialog)
                }

                UTControls.AppButton {
                    Layout.preferredWidth: units.gu(8.5)
                    Layout.preferredHeight: units.gu(5)
                    text: i18n.tr("Delete")
                    variant: "destructive"
                    enabled: page.selectedCardCount() > 0 && !dataController.loading
                    onClicked: PopupUtils.open(deleteSelectedCardsDialog)
                }
            }
        }
    }

    Component {
        id: statusDetailsDialog

        Dialog {
            id: dialog
            title: i18n.tr("Sync status")
            text: page.statusDetailsText()

            Row {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(5)
                spacing: units.gu(0.8)

                UTControls.AppButton {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    enabled: !dataController.loading
                    text: i18n.tr("Refresh")
                    variant: "primary"
                    accentColor: page.actionBlue
                    onClicked: {
                        PopupUtils.close(dialog)
                        dataController.refresh()
                    }
                }

                UTControls.AppButton {
                    width: (parent.width - parent.spacing) / 2
                    height: parent.height
                    text: i18n.tr("Close")
                    onClicked: PopupUtils.close(dialog)
                }
            }
        }
    }

    Component {
        id: filterDialog

        Dialog {
            id: dialog
            title: i18n.tr("Filter")

            Flickable {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(5)
                contentWidth: filterTabsRow.width
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: filterTabsRow
                    height: parent.height
                    spacing: units.gu(0.6)

                    Repeater {
                        model: [
                            {"value": "tags", "label": i18n.tr("Tags")},
                            {"value": "users", "label": i18n.tr("Users")},
                            {"value": "done", "label": i18n.tr("Done")},
                            {"value": "due", "label": i18n.tr("Due date")}
                        ]

                        UTControls.AppButton {
                            width: Math.max(units.gu(10), String(modelData.label || "").length * units.gu(0.75) + units.gu(2.4))
                            height: units.gu(4.6)
                            text: modelData.label
                            selected: page.filterTab === modelData.value
                            accentColor: page.actionBlue

                            onClicked: page.filterTab = modelData.value
                        }
                    }
                }
            }

            Column {
                width: parent ? parent.width : units.gu(34)
                spacing: units.gu(0.35)
                visible: page.filterTab === "tags"

                Column {
                    id: tagFilterRow
                    width: parent.width
                    spacing: units.gu(0.35)

                    UTControls.AppButton {
                        width: parent.width
                        height: units.gu(4.4)
                        text: page.draftFilterNoLabel ? "\u2713 " + i18n.tr("No assigned tag") : i18n.tr("No assigned tag")
                        selected: page.draftFilterNoLabel
                        accentColor: page.actionBlue
                        horizontalAlignment: Text.AlignLeft
                        onClicked: page.draftFilterNoLabel = !page.draftFilterNoLabel

                    }

                    Repeater {
                        model: page.labelOptions()

                        UTControls.AppButton {
                            width: tagFilterRow.width
                            height: units.gu(4.4)
                            selected: page.optionSelected(page.draftFilterLabelIds, Number(modelData.id || 0))
                            text: (selected ? "\u2713 " : "") + (modelData.title || i18n.tr("Tag"))
                            accentColor: page.labelColor(modelData)
                            horizontalAlignment: Text.AlignLeft
                            onClicked: page.draftFilterLabelIds = page.toggleOption(page.draftFilterLabelIds, Number(modelData.id || 0))

                        }
                    }
                }
            }

            Label {
                visible: page.filterTab === "tags" && page.labelOptions().length === 0
                text: i18n.tr("No tags available.")
                opacity: 0.62
            }

            Column {
                width: parent ? parent.width : units.gu(34)
                spacing: units.gu(0.35)
                visible: page.filterTab === "users"

                Column {
                    id: userFilterRow
                    width: parent.width
                    spacing: units.gu(0.35)

                    UTControls.AppButton {
                        width: parent.width
                        height: units.gu(4.4)
                        text: page.draftFilterNoUser ? "\u2713 " + i18n.tr("Unassigned") : i18n.tr("Unassigned")
                        selected: page.draftFilterNoUser
                        accentColor: page.actionBlue
                        horizontalAlignment: Text.AlignLeft
                        onClicked: page.draftFilterNoUser = !page.draftFilterNoUser

                    }

                    Repeater {
                        model: page.userOptions()

                        UTControls.AppButton {
                            width: userFilterRow.width
                            height: units.gu(4.4)
                            selected: page.optionSelected(page.draftFilterUserIds, page.userId(modelData))
                            text: (selected ? "\u2713 " : "") + page.userDisplayName(modelData)
                            accentColor: page.actionBlue
                            horizontalAlignment: Text.AlignLeft
                            onClicked: page.draftFilterUserIds = page.toggleOption(page.draftFilterUserIds, page.userId(modelData))

                        }
                    }
                }
            }

            Label {
                visible: page.filterTab === "users" && page.userOptions().length === 0
                text: i18n.tr("No users available.")
                opacity: 0.62
            }

            Column {
                width: parent ? parent.width : units.gu(34)
                spacing: units.gu(0.35)
                visible: page.filterTab === "done"

                Column {
                    id: doneFilterRow
                    width: parent.width
                    spacing: units.gu(0.35)

                    Repeater {
                        model: [
                            {"value": "all", "label": i18n.tr("All")},
                            {"value": "done", "label": i18n.tr("Done")},
                            {"value": "undone", "label": i18n.tr("Not done")}
                        ]

                        UTControls.AppButton {
                            width: doneFilterRow.width
                            height: units.gu(4.4)
                            selected: page.draftFilterDoneMode === modelData.value
                            text: (selected ? "\u2713 " : "") + modelData.label
                            accentColor: page.actionBlue
                            horizontalAlignment: Text.AlignLeft
                            onClicked: page.draftFilterDoneMode = modelData.value

                        }
                    }
                }
            }

            Column {
                width: parent ? parent.width : units.gu(34)
                spacing: units.gu(0.35)
                visible: page.filterTab === "due"

                Column {
                    id: dueFilterRow
                    width: parent.width
                    spacing: units.gu(0.35)

                    Repeater {
                        model: [
                            {"value": "all", "label": i18n.tr("All")},
                            {"value": "overdue", "label": i18n.tr("Overdue")},
                            {"value": "today", "label": i18n.tr("Today")},
                            {"value": "tomorrow", "label": i18n.tr("Tomorrow")},
                            {"value": "week", "label": i18n.tr("Next 7 days")},
                            {"value": "month", "label": i18n.tr("Next 30 days")},
                            {"value": "none", "label": i18n.tr("No due date")},
                            {"value": "later", "label": i18n.tr("Later")}
                        ]

                        UTControls.AppButton {
                            width: dueFilterRow.width
                            height: units.gu(4.4)
                            selected: page.draftFilterDueMode === modelData.value
                            text: (selected ? "\u2713 " : "") + modelData.label
                            accentColor: page.actionBlue
                            horizontalAlignment: Text.AlignLeft
                            onClicked: page.draftFilterDueMode = modelData.value

                        }
                    }
                }
            }

            Row {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(5)
                spacing: units.gu(0.6)

                UTControls.AppButton {
                    width: (parent.width - units.gu(1.2)) / 3
                    height: parent.height
                    text: i18n.tr("Cancel")
                    onClicked: PopupUtils.close(dialog)
                }

                UTControls.AppButton {
                    width: (parent.width - units.gu(1.2)) / 3
                    height: parent.height
                    text: i18n.tr("Reset")
                    onClicked: page.resetFilterDraft()
                }

                UTControls.AppButton {
                    width: (parent.width - units.gu(1.2)) / 3
                    height: parent.height
                    text: i18n.tr("Filter")
                    variant: "primary"
                    accentColor: page.actionBlue
                    onClicked: {
                        page.applyFilterDraft()
                        PopupUtils.close(dialog)
                    }
                }
            }
        }
    }

    Component {
        id: createCardDialog

        Dialog {
            id: dialog
            title: i18n.tr("New card")
            text: i18n.tr("Create a card in %1.").arg(page.activeStackEntry().stackTitle || i18n.tr("List"))

            TextField {
                placeholderText: i18n.tr("Card title")
                text: page.newCardTitle
                inputMethodHints: Qt.ImhNoPredictiveText
                onTextChanged: page.newCardTitle = text
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Create")
                enabled: !dataController.loading && page.activeStackId > 0
                variant: "primary"
                accentColor: page.actionBlue
                onClicked: {
                    Qt.inputMethod.commit()
                    var stack = page.activeStackEntry()
                    var title = page.newCardTitle.trim().length > 0
                        ? page.newCardTitle.trim()
                        : i18n.tr("Untitled card")
                    PopupUtils.close(dialog)
                    dataController.createCard(stack.boardId, stack.stackId, stack.stackTitle, title)
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
        id: createBoardDialog

        Dialog {
            id: dialog
            title: i18n.tr("New board")

            TextField {
                placeholderText: i18n.tr("Board title")
                text: page.newBoardTitle
                inputMethodHints: Qt.ImhNoPredictiveText
                onTextChanged: page.newBoardTitle = text
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Create")
                variant: "primary"
                accentColor: page.actionBlue
                enabled: page.newBoardTitle.trim().length > 0 && !dataController.loading
                onClicked: {
                    Qt.inputMethod.commit()
                    PopupUtils.close(dialog)
                    page.drawerOpen = false
                    dataController.createBoard(page.newBoardTitle.trim(), "0082c9")
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
        id: createListDialog

        Dialog {
            id: dialog
            title: i18n.tr("New list")

            TextField {
                placeholderText: i18n.tr("List title")
                text: page.newListTitle
                inputMethodHints: Qt.ImhNoPredictiveText
                onTextChanged: page.newListTitle = text
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Create")
                variant: "primary"
                accentColor: page.actionBlue
                enabled: page.newListTitle.trim().length > 0 && !dataController.loading
                onClicked: {
                    Qt.inputMethod.commit()
                    PopupUtils.close(dialog)
                    dataController.createStack(page.newListTitle.trim())
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
        id: boardShareDialog

        Dialog {
            id: dialog
            title: i18n.tr("Share board")

            TextField {
                placeholderText: i18n.tr("Search users, groups or teams")
                text: page.shareSearchQuery
                inputMethodHints: Qt.ImhNoPredictiveText
                onTextChanged: {
                    page.shareSearchQuery = text
                    dataController.searchSharees(text)
                }
            }

            Label {
                text: i18n.tr("Owner: %1").arg(page.boardOwnerDisplay(page.selectedBoard))
                font.bold: true
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: dataController.sharees || []

                UTControls.AppButton {
                    width: parent ? parent.width : units.gu(34)
                    height: units.gu(4.8)
                    text: i18n.tr("Add %1").arg(modelData.label || modelData.id)
                    variant: "primary"
                    accentColor: page.actionBlue
                    enabled: !dataController.loading
                    onClicked: {
                        dataController.createAccessControl(page.selectedBoard, modelData)
                        page.shareSearchQuery = ""
                    }
                }
            }

            Label {
                text: i18n.tr("Shared with")
                font.bold: true
                visible: (page.selectedBoard.acl || []).length > 0
            }

            Repeater {
                model: page.selectedBoard.acl || []

                Column {
                    width: parent ? parent.width : units.gu(34)
                    spacing: units.gu(0.5)

                    Label {
                        text: page.aclParticipantDisplay(modelData)
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Flickable {
                        width: parent.width
                        height: units.gu(4.8)
                        contentWidth: aclButtons.width
                        contentHeight: height
                        clip: true

                        Row {
                            id: aclButtons
                            height: parent.height
                            spacing: units.gu(0.5)

                            UTControls.AppButton {
                                width: units.gu(12)
                                height: parent.height
                                text: modelData.permissionEdit ? "\u2713 " + i18n.tr("Edit") : i18n.tr("Edit")
                                selected: modelData.permissionEdit === true
                                variant: selected ? "primary" : "neutral"
                                accentColor: page.actionBlue
                                onClicked: page.toggleAclPermission(modelData, "permissionEdit")
                            }

                            UTControls.AppButton {
                                width: units.gu(12)
                                height: parent.height
                                text: modelData.permissionShare ? "\u2713 " + i18n.tr("Share") : i18n.tr("Share")
                                selected: modelData.permissionShare === true
                                variant: selected ? "primary" : "neutral"
                                accentColor: page.actionBlue
                                onClicked: page.toggleAclPermission(modelData, "permissionShare")
                            }

                            UTControls.AppButton {
                                width: units.gu(13)
                                height: parent.height
                                text: modelData.permissionManage ? "\u2713 " + i18n.tr("Manage") : i18n.tr("Manage")
                                selected: modelData.permissionManage === true
                                variant: selected ? "primary" : "neutral"
                                accentColor: page.actionBlue
                                onClicked: page.toggleAclPermission(modelData, "permissionManage")
                            }

                            UTControls.AppButton {
                                width: units.gu(13)
                                height: parent.height
                                text: i18n.tr("Remove")
                                variant: "destructive"
                                onClicked: dataController.deleteAccessControl(page.selectedBoard, modelData)
                            }
                        }
                    }
                }
            }

            Label {
                visible: (page.selectedBoard.acl || []).length === 0
                text: i18n.tr("This board is not shared with anyone else.")
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Close")
                onClicked: PopupUtils.close(dialog)
            }
        }
    }

    Component {
        id: boardOptionsDialog

        Dialog {
            id: dialog
            title: page.selectedBoard.title || i18n.tr("Board")

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Share board")
                enabled: page.selectedBoard && page.selectedBoard.id
                onClicked: {
                    var board = page.selectedBoard
                    PopupUtils.close(dialog)
                    page.showBoardShareDialog(board)
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: page.selectedBoard.archived === true ? i18n.tr("Restore board") : i18n.tr("Archive board")
                enabled: page.selectedBoard && page.selectedBoard.id && !dataController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    page.archiveSelectedBoard(page.selectedBoard.archived !== true)
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete board")
                variant: "destructive"
                enabled: page.selectedBoard && page.selectedBoard.id && !dataController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    PopupUtils.open(deleteBoardConfirmDialog)
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
        id: deleteBoardConfirmDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete board")
            text: i18n.tr("Delete this board and its cards?")

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete")
                variant: "destructive"
                enabled: page.selectedBoard && page.selectedBoard.id && !dataController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    dataController.deleteBoard(page.selectedBoard)
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
        id: listOptionsDialog

        Dialog {
            id: dialog
            readonly property bool hasList: Number(page.selectedList.stackId || 0) > 0

            title: hasList
                ? (page.selectedList.stackTitle || page.selectedList.title || i18n.tr("List"))
                : i18n.tr("Board options")

            TextField {
                visible: dialog.hasList
                placeholderText: i18n.tr("List title")
                text: page.newListTitle
                inputMethodHints: Qt.ImhNoPredictiveText
                onTextChanged: page.newListTitle = text
            }

            UTControls.AppButton {
                visible: dialog.hasList
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Save")
                variant: "primary"
                accentColor: page.actionBlue
                enabled: page.newListTitle.trim().length > 0 && !dataController.loading
                onClicked: {
                    Qt.inputMethod.commit()
                    var updated = {}
                    for (var key in page.selectedList) updated[key] = page.selectedList[key]
                    updated.title = page.newListTitle.trim()
                    updated.stackTitle = updated.title
                    PopupUtils.close(dialog)
                    dataController.updateStack(updated)
                }
            }

            UTControls.AppButton {
                visible: dialog.hasList
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Add card")
                variant: "primary"
                accentColor: page.actionBlue
                enabled: !dataController.loading && page.activeStackId > 0
                onClicked: {
                    PopupUtils.close(dialog)
                    page.showCreateCardDialog()
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Add list")
                variant: "primary"
                accentColor: page.actionBlue
                enabled: !dataController.loading && dataController.selectedBoardId > 0
                onClicked: {
                    PopupUtils.close(dialog)
                    page.showCreateListDialog()
                }
            }

            UTControls.AppButton {
                visible: dialog.hasList
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Move list right")
                enabled: !dataController.loading && page.canMoveActiveStackRight()
                onClicked: {
                    PopupUtils.close(dialog)
                    page.moveActiveStackRight()
                }
            }

            UTControls.AppButton {
                visible: dialog.hasList
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Archive cards in list")
                enabled: !dataController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    page.archiveCardsInList(page.selectedList)
                }
            }

            UTControls.AppButton {
                visible: dialog.hasList
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete list")
                variant: "destructive"
                enabled: !dataController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    dataController.deleteStack(page.selectedList)
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
        id: cardOptionsDialog

        Dialog {
            id: dialog
            title: page.selectedCard.title || i18n.tr("Card")

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Share link")
                enabled: page.cardShareLink(page.selectedCard).length > 0
                onClicked: {
                    PopupUtils.close(dialog)
                    page.shareSelectedCardLink()
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Share content")
                enabled: page.cardShareContent(page.selectedCard).length > 0
                onClicked: {
                    PopupUtils.close(dialog)
                    page.shareSelectedCardContent()
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Assign card to me")
                enabled: dataController.currentUserName.length > 0 && page.selectedCard.id
                onClicked: {
                    PopupUtils.close(dialog)
                    page.assignSelectedCardToMe()
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Move card")
                enabled: page.stackOptions().length > 1
                onClicked: {
                    PopupUtils.close(dialog)
                    PopupUtils.open(moveCardDialog)
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: page.selectedCard.archived === true ? i18n.tr("Restore card") : i18n.tr("Archive card")
                enabled: page.selectedCard.id
                onClicked: {
                    PopupUtils.close(dialog)
                    page.archiveSelectedCard()
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete card")
                variant: "destructive"
                onClicked: {
                    PopupUtils.close(dialog)
                    PopupUtils.open(deleteCardConfirmDialog)
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
        id: moveCardDialog

        Dialog {
            id: dialog
            title: i18n.tr("Move card")
            text: i18n.tr("Choose destination list.")

            Repeater {
                model: page.stackOptions()

                UTControls.AppButton {
                    visible: Number(modelData.stackId || 0) !== Number(page.selectedCard.stackId || 0)
                    width: visible ? (parent ? parent.width : units.gu(34)) : 0
                    height: visible ? units.gu(4.8) : 0
                    text: modelData.stackTitle
                    enabled: visible && !dataController.loading
                    variant: "primary"
                    accentColor: page.actionBlue
                    onClicked: {
                        PopupUtils.close(dialog)
                        page.moveSelectedCardToStack(modelData)
                    }
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
        id: deleteCardConfirmDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete card")
            text: i18n.tr("Delete this card?")

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete")
                variant: "destructive"
                enabled: page.selectedCard && page.selectedCard.id && !dataController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    dataController.deleteCard(page.selectedCard)
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
        id: moveSelectedCardsDialog

        Dialog {
            id: dialog
            title: i18n.tr("Move selected cards")
            text: i18n.tr("Choose destination list.")

            Repeater {
                model: page.selectedCardsMoveTargets()

                UTControls.AppButton {
                    width: parent ? parent.width : units.gu(34)
                    height: units.gu(4.8)
                    text: modelData.stackTitle
                    enabled: page.selectedCardCount() > 0 && !dataController.loading
                    variant: "primary"
                    accentColor: page.actionBlue
                    onClicked: {
                        PopupUtils.close(dialog)
                        page.moveSelectedCardsToStack(modelData)
                    }
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
        id: deleteSelectedCardsDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete selected cards")
            text: i18n.tr("Delete %1 selected card(s)?").arg(page.selectedCardCount())

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete")
                variant: "destructive"
                enabled: page.selectedCardCount() > 0 && !dataController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    page.deleteSelectedCards()
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
        id: deleteArchiveItemConfirmDialog

        Dialog {
            id: dialog
            title: i18n.tr("Delete archived item")
            text: i18n.tr("Delete this archived item?")

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Delete")
                variant: "destructive"
                enabled: page.selectedArchiveItem && (page.selectedArchiveItem.id || page.selectedArchiveItem.localKey) && !dataController.loading
                onClicked: {
                    PopupUtils.close(dialog)
                    page.deleteArchiveItem(page.selectedArchiveItem)
                    page.selectedArchiveItem = ({})
                }
            }

            UTControls.AppButton {
                width: parent ? parent.width : units.gu(34)
                height: units.gu(4.8)
                text: i18n.tr("Cancel")
                onClicked: {
                    PopupUtils.close(dialog)
                    page.selectedArchiveItem = ({})
                }
            }
        }
    }

    DeckController {
        id: dataController
        onLoadingChanged: {
            if (!loading) {
                page.processNextBulkCard()
            }
        }
        onEntriesChanged: {
            page.updateFilteredEntries()
            page.updateVisibleBoardEntries()
        }
        onCachedBoardsChanged: {
            page.updateVisibleBoardEntries()
            if (!page.selectedBoard || !page.selectedBoard.id) return
            var boards = dataController.cachedBoards || []
            for (var i = 0; i < boards.length; ++i) {
                if (Number(boards[i].id || 0) === Number(page.selectedBoard.id || 0)) {
                    page.selectedBoard = boards[i]
                    return
                }
            }
        }
    }

    Connections {
        target: appController
        onAccountChanged: function(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl) {
            page.resetAccountLocalState()
            dataController.applyAccountSelection(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl)
        }
    }

    Component {
        id: reorderCardDelegate

        Rectangle {
            id: reorderCard
            property var itemData: ({})
            property int itemIndex: -1
            property bool placeholder: false
            property bool dragging: false
            property bool selected: false
            property bool selectionMode: false
            readonly property var cardData: page.cardForVisualItem(itemData)
            readonly property var labelsData: page.cardLabels(cardData)
            readonly property var infoBadgesData: page.cardInfoBadges(cardData)
            readonly property var assignedUsersData: page.cardAssignedUsers(cardData)
            readonly property real metaContentGap: units.gu(1)
            readonly property real labelBlockHeight: labelsData.length > 0 ? Math.max(compactLabelFlow.childrenRect.height, units.gu(1.5)) : 0
            readonly property real infoBlockHeight: infoBadgesData.length > 0 ? Math.max(compactInfoFlow.childrenRect.height, units.gu(1.5)) : 0
            readonly property real metaBlockHeight: Math.max(
                labelBlockHeight
                    + (labelBlockHeight > 0 && infoBlockHeight > 0 ? metaContentGap : 0)
                    + infoBlockHeight,
                assignedUsersData.length > 0 ? units.gu(2.8) : 0
            )
            readonly property bool hasMetaData: labelsData.length > 0 || infoBadgesData.length > 0 || assignedUsersData.length > 0

            implicitHeight: Math.max(
                units.gu(7.8),
                units.gu(2.2)
                    + titleRowNew.height
                    + (hasMetaData ? metaContentGap + metaBlockHeight : 0)
            )
            height: implicitHeight
            radius: units.gu(0.7)
            color: theme.palette.normal.background
            border.width: placeholder || selected ? 2 : 1
            border.color: placeholder || selected ? page.actionBlue : theme.palette.normal.base

            Item {
                id: cardMenuButtonNew
                anchors {
                    top: parent.top
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: units.gu(0.2)
                }
                width: units.gu(4.8)
                z: 2

                Label {
                    anchors.centerIn: parent
                    text: "\u22ee"
                    color: theme.palette.normal.backgroundText
                    font.pixelSize: units.gu(2.3)
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: false
                }
            }

            Item {
                id: reorderCardContent
                anchors {
                    left: parent.left
                    right: cardMenuButtonNew.left
                    top: parent.top
                    bottom: parent.bottom
                    leftMargin: units.gu(1)
                    rightMargin: units.gu(0.5)
                    topMargin: units.gu(1)
                    bottomMargin: units.gu(1)
                }

                Item {
                    id: titleRowNew
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    width: parent.width
                    height: Math.max(titleLabelNew.paintedHeight, doneBadgeNew.visible ? doneBadgeNew.height : 0)

                    Label {
                        id: titleLabelNew
                        anchors {
                            left: parent.left
                            right: doneBadgeNew.visible ? doneBadgeNew.left : parent.right
                            top: parent.top
                            rightMargin: doneBadgeNew.visible ? units.gu(0.8) : 0
                        }
                        text: reorderCard.cardData.title || i18n.tr("Untitled")
                        font.bold: !page.cardDone(reorderCard.cardData)
                        fontSize: "small"
                        wrapMode: Text.WordWrap
                        maximumLineCount: 6
                        elide: Text.ElideNone
                        opacity: placeholder ? 0.55 : 1.0
                    }

                    Rectangle {
                        id: doneBadgeNew
                        anchors {
                            top: parent.top
                            right: parent.right
                        }
                        width: doneBadgeLabelNew.implicitWidth + units.gu(1.1)
                        height: doneBadgeLabelNew.implicitHeight + units.gu(0.35)
                        visible: page.cardDone(reorderCard.cardData)
                        radius: units.gu(0.45)
                        color: Qt.rgba(0.35, 0.56, 0.24, 0.18)
                        border.width: 1
                        border.color: "#5a8f3c"

                        Label {
                            id: doneBadgeLabelNew
                            anchors.centerIn: parent
                            text: "\u2713 " + page.formatDoneDate(reorderCard.cardData.done)
                            color: "#5a8f3c"
                            font.bold: true
                            fontSize: "x-small"
                        }
                    }
                }

                Item {
                    id: compactMetaRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: titleRowNew.bottom
                        topMargin: reorderCard.metaContentGap
                    }
                    height: reorderCard.metaBlockHeight
                    visible: reorderCard.hasMetaData
                    z: 5

                    Item {
                        id: compactMetaLeft
                        anchors {
                            left: parent.left
                            right: compactAssignees.left
                            top: parent.top
                            bottom: parent.bottom
                            rightMargin: compactAssignees.visible ? units.gu(0.8) : 0
                        }

                        Flow {
                            id: compactLabelFlow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                            }
                            height: childrenRect.height
                            spacing: units.gu(0.35)
                            visible: reorderCard.labelsData.length > 0

                            Repeater {
                                model: reorderCard.labelsData.length

                                Rectangle {
                                    property var labelData: reorderCard.labelsData[index] || ({})

                                    width: Math.min(labelTextCompact.implicitWidth + units.gu(1.0), Math.max(units.gu(7), (compactLabelFlow.width - compactLabelFlow.spacing) / 2))
                                    height: labelTextCompact.implicitHeight + units.gu(0.35)
                                    radius: units.gu(0.45)
                                    color: Qt.rgba(0.17, 0.5, 0.72, 0.16)
                                    border.width: 1
                                    border.color: page.labelColor(labelData)

                                    Label {
                                        id: labelTextCompact
                                        anchors.centerIn: parent
                                        width: parent.width - units.gu(0.8)
                                        text: labelData.title || i18n.tr("Label")
                                        color: page.labelColor(labelData)
                                        font.bold: true
                                        fontSize: "x-small"
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Flow {
                            id: compactInfoFlow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: compactLabelFlow.visible ? compactLabelFlow.bottom : parent.top
                                topMargin: compactLabelFlow.visible ? reorderCard.metaContentGap : 0
                            }
                            height: childrenRect.height
                            spacing: units.gu(0.8)
                            visible: reorderCard.infoBadgesData.length > 0

                            Repeater {
                                model: reorderCard.infoBadgesData.length

                                Row {
                                    property var badgeData: reorderCard.infoBadgesData[index] || ({})

                                    height: Math.max(infoIconCompact.implicitHeight, infoCountCompact.implicitHeight)
                                    spacing: units.gu(0.25)

                                    Label {
                                        id: infoIconCompact
                                        text: badgeData.icon
                                        color: theme.palette.normal.backgroundText
                                        opacity: 0.62
                                        font.pixelSize: units.gu(1.65)
                                        font.bold: badgeData.kind === "description"
                                    }

                                    Label {
                                        id: infoCountCompact
                                        visible: Number(badgeData.count || 0) > 0
                                        text: String(badgeData.count)
                                        color: theme.palette.normal.backgroundText
                                        opacity: 0.62
                                        fontSize: "x-small"
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        id: compactAssignees
                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: units.gu(2.8)
                        spacing: units.gu(0.25)
                        visible: reorderCard.assignedUsersData.length > 0

                        Repeater {
                            model: Math.min(3, reorderCard.assignedUsersData.length)

                            NextCommon.AvatarButton {
                                property var assigneeData: reorderCard.assignedUsersData[index] || ({})
                                property string assigneeId: page.userId(assigneeData)

                                width: units.gu(2.8)
                                height: width
                                anchors.verticalCenter: parent.verticalCenter
                                avatarUrl: dataController.avatarDataUrl(assigneeId)
                                fallbackText: page.userInitial(assigneeData)
                                backgroundColor: page.actionBlue
                                borderColor: Qt.rgba(1, 1, 1, 0.45)

                                Component.onCompleted: dataController.requestAvatar(assigneeId)
                            }
                        }
                    }
                }
            }
        }
    }

    Flickable {
        id: contentFlickable
        anchors { fill: parent; topMargin: page.header.height }
        contentWidth: width
        contentHeight: contentColumn.height + units.gu(3)
        clip: true
        boundsBehavior: dataController.viewMode === "cards" && !page.archiveOverviewMode
            ? Flickable.StopAtBounds
            : Flickable.DragOverBounds
        interactive: dataController.viewMode !== "cards" || page.archiveOverviewMode
        property bool pullRefreshArmed: false

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
            if ((dataController.viewMode !== "cards" || page.archiveOverviewMode)
                    && contentY < -page.pullRefreshThreshold && !dataController.loading) {
                pullRefreshArmed = true
            }
        }

        onMovementEnded: {
            if ((dataController.viewMode !== "cards" || page.archiveOverviewMode)
                    && pullRefreshArmed && !dataController.loading) {
                dataController.refreshAll()
            }
            pullRefreshArmed = false
        }

        Rectangle {
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: units.gu(0.6)
            }
            width: refreshPullLabel.implicitWidth + units.gu(2)
            height: units.gu(3.2)
            radius: units.gu(1.6)
            color: page.actionBlue
            opacity: (dataController.viewMode !== "cards" || page.archiveOverviewMode)
                && (contentFlickable.contentY < -units.gu(2) || dataController.loading) ? 0.92 : 0
            visible: opacity > 0
            z: 4

            Label {
                id: refreshPullLabel
                anchors.centerIn: parent
                text: dataController.loading
                    ? i18n.tr("Refreshing...")
                    : contentFlickable.contentY < -page.pullRefreshThreshold
                    ? i18n.tr("Release to refresh")
                    : i18n.tr("Pull to refresh")
                color: "white"
            }
        }

        ColumnLayout {
            id: contentColumn
            width: parent.width
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(2) }
            spacing: units.gu(1.2)

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: units.gu(5.8)
                visible: dataController.viewMode === "cards" && !page.archiveOverviewMode
                spacing: units.gu(0.6)

                Flickable {
                    id: stackTabs
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: stackTabsRow.width
                    contentHeight: height
                    clip: true

                    Row {
                        id: stackTabsRow
                        height: parent.height
                        spacing: units.gu(0.6)

                        Repeater {
                            model: page.stackOptions()

                            Rectangle {
                                width: Math.min(stackTabs.width, Math.max(units.gu(14), String(modelData.stackTitle || "").length * units.gu(0.85) + units.gu(3.2)))
                                height: units.gu(5)
                                radius: 0
                                color: "transparent"
                                border.width: 0
                                anchors.verticalCenter: parent.verticalCenter

                                Label {
                                    id: tabLabel
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        leftMargin: units.gu(1)
                                        rightMargin: units.gu(1)
                                    }
                                    text: modelData.stackTitle
                                    color: theme.palette.normal.backgroundText
                                    font.bold: page.activeStackId === Number(modelData.stackId || 0)
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Rectangle {
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                    }
                                    height: units.gu(0.25)
                                    color: page.activeStackId === Number(modelData.stackId || 0) ? page.actionBlue : "transparent"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: page.selectStack(modelData.stackId)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: units.gu(5)
                    Layout.fillHeight: true
                    radius: 0
                    color: "transparent"
                    border.width: 0

                    Label {
                        anchors.centerIn: parent
                        text: "\u22ee"
                        color: theme.palette.normal.backgroundText
                        font.pixelSize: units.gu(2.4)
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.showListOptions(page.activeStackEntry())
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.archiveOverviewMode
                spacing: units.gu(1)

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Archive")
                    font.bold: true
                    font.pixelSize: units.gu(2.4)
                    color: theme.palette.normal.backgroundText
                }

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Archived boards and cards are shown here.")
                    wrapMode: Text.WordWrap
                    opacity: 0.68
                    color: theme.palette.normal.backgroundText
                }

                Repeater {
                    model: page.archiveOverviewItems()

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: units.gu(9.6)
                        radius: units.gu(0.7)
                        color: theme.palette.normal.background
                        border.width: 1
                        border.color: theme.palette.normal.base

                        RowLayout {
                            anchors {
                                fill: parent
                                margins: units.gu(1.2)
                            }
                            spacing: units.gu(1)

                            Rectangle {
                                Layout.preferredWidth: units.gu(4.4)
                                Layout.preferredHeight: units.gu(4.4)
                                Layout.alignment: Qt.AlignVCenter
                                radius: width / 2
                                color: modelData.archiveType === "board"
                                    ? page.boardColor(modelData)
                                    : Qt.rgba(theme.palette.normal.backgroundText.r,
                                              theme.palette.normal.backgroundText.g,
                                              theme.palette.normal.backgroundText.b,
                                              0.12)

                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.archiveType === "board" ? "\u2630"
                                        : "\u25a1"
                                    color: modelData.archiveType === "board"
                                        ? "white"
                                        : theme.palette.normal.backgroundText
                                    font.bold: true
                                    font.pixelSize: units.gu(2.1)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: units.gu(0.45)

                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.title || (modelData.archiveType === "board" ? i18n.tr("Untitled board")
                                        : i18n.tr("Untitled card"))
                                    font.bold: true
                                    color: theme.palette.normal.backgroundText
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: units.gu(0.6)

                                    Rectangle {
                                        Layout.preferredHeight: units.gu(2.4)
                                        Layout.preferredWidth: archiveTypeLabel.implicitWidth + units.gu(1.4)
                                        radius: units.gu(1.2)
                                        color: Qt.rgba(theme.palette.normal.backgroundText.r,
                                                       theme.palette.normal.backgroundText.g,
                                                       theme.palette.normal.backgroundText.b,
                                                       0.10)

                                        Label {
                                            id: archiveTypeLabel
                                            anchors.centerIn: parent
                                            text: modelData.archiveType === "board" ? i18n.tr("Board")
                                                : i18n.tr("Card")
                                            textSize: Label.Small
                                            font.bold: true
                                            color: theme.palette.normal.backgroundText
                                            opacity: 0.78
                                        }
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.archiveType === "card" ? (modelData.stackTitle || "")
                                            : (modelData.subtitle || i18n.tr("Archived board"))
                                        textSize: Label.Small
                                        opacity: 0.68
                                        color: theme.palette.normal.backgroundText
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }

                            UTControls.AppButton {
                                Layout.preferredWidth: units.gu(9.2)
                                Layout.preferredHeight: units.gu(4.4)
                                text: i18n.tr("Restore")
                                enabled: !dataController.loading
                                onClicked: page.restoreArchiveItem(modelData)
                            }

                            UTControls.AppButton {
                                Layout.preferredWidth: units.gu(8.6)
                                Layout.preferredHeight: units.gu(4.4)
                                text: i18n.tr("Delete")
                                variant: "destructive"
                                enabled: !dataController.loading
                                onClicked: page.requestDeleteArchiveItem(modelData)
                            }
                        }
                    }
                }

                UTControls.EmptyState {
                    Layout.fillWidth: true
                    visible: page.archiveOverviewItems().length === 0 && !dataController.loading
                    title: i18n.tr("Archive is empty.")
                    message: i18n.tr("Archived boards and cards appear here after their board has been loaded.")
                }
            }

            UTControls.ReorderableListView {
                id: reorderableCards
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(units.gu(28), page.height - page.header.height - stackTabs.height - units.gu(7))
                visible: dataController.viewMode === "cards"
                    && !page.archiveOverviewMode
                    && page.visibleCardEntries.length > 0
                model: page.reorderableCardModel()
                delegate: reorderCardDelegate
                reorderEnabled: !dataController.loading && !page.showArchivedCardsMode && (!appController || appController.dragForMoveEnabled)
                secondaryActionRightWidth: units.gu(6.4)
                refreshing: dataController.loading
                dragAreaRightMargin: units.gu(5.4)
                pullRefreshThreshold: page.pullRefreshThreshold
                pullToRefreshEnabled: page.cardPullToRefreshEnabled
                refreshIndicatorColor: page.actionBlue
                pullToRefreshText: i18n.tr("Pull to refresh")
                releaseToRefreshText: i18n.tr("Release to refresh")
                refreshingText: i18n.tr("Refreshing...")
                swipeActionsEnabled: appController ? appController.swipeActionsEnabled : true
                swipeRightEnabled: appController ? appController.swipeActionsEnabled : true
                swipeLeftEnabled: appController ? appController.swipeActionsEnabled : true
                swipeActionsReversed: appController ? appController.swipeActionsReversed : false
                swipeRightText: i18n.tr("Delete")
                swipeLeftText: page.showArchivedCardsMode ? i18n.tr("Restore") : i18n.tr("Archive")
                swipeRightColor: "#c23b3b"
                swipeLeftColor: page.actionBlue
                selectionEnabled: appController ? appController.multiSelectEnabled : true

                onMoveRequested: function(fromIndex, toIndex) {
                    page.reorderVisibleCards(fromIndex, toIndex)
                }

                onItemClicked: function(index, itemData) {
                    page.openCard(page.cardForVisualItem(itemData))
                }
                onSecondaryActionRequested: function(index, itemData) {
                    page.showCardOptions(page.cardForVisualItem(itemData))
                }
                onRefreshRequested: dataController.refreshAll()
                onSwipeRightRequested: function(index, itemData) {
                    page.selectedCard = page.cardForVisualItem(itemData)
                    PopupUtils.open(deleteCardConfirmDialog)
                }
                onSwipeLeftRequested: function(index, itemData) {
                    dataController.archiveCard(page.cardForVisualItem(itemData), !page.showArchivedCardsMode)
                }
                onSelectionChanged: function(selectedItems) {
                    page.selectedCards = selectedItems || []
                    page.selectedCardsRevision += 1
                    page.selectionMode = page.selectedCardCount() > 0
                }
                onSelectionCleared: {
                    page.selectedCards = []
                    page.selectedCardsRevision += 1
                    page.selectionMode = false
                }
            }

            Repeater {
                id: cardRepeater
                model: dataController.viewMode === "cards" ? [] : page.filteredEntries
                delegate: Item {
                    id: cardItem
                    Layout.fillWidth: true
                    width: parent ? parent.width : page.width
                    property var cardData: page.effectiveCard(modelData, dataController.entries)
                    property string itemKey: page.cardKey(cardData)
                    property real computedHeight: Math.max(
                        units.gu(7.8),
                        units.gu(2.2)
                            + titleRow.height
                            + (metaRow.visible ? units.gu(0.65) + metaRow.height : 0)
                    )
                    Layout.preferredHeight: computedHeight
                    Layout.minimumHeight: computedHeight
                    height: computedHeight

                    Item {
                        id: cardVisual
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            bottom: parent.bottom
                        }
                        opacity: 1.0

                    Rectangle {
                        anchors { fill: parent; margins: units.gu(0.35) }
                        radius: units.gu(0.7)
                        color: theme.palette.normal.background
                        border.width: 1
                        border.color: theme.palette.normal.base
                    }

                    Item {
                        id: cardContentColumn
                        anchors {
                            left: parent.left
                            right: cardMenuButton.left
                            top: parent.top
                            bottom: parent.bottom
                            leftMargin: units.gu(1)
                            rightMargin: units.gu(0.5)
                            topMargin: units.gu(1)
                            bottomMargin: units.gu(1)
                        }
                        Item {
                            id: titleRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                            }
                            width: parent.width
                            height: Math.max(titleLabel.paintedHeight, doneBadge.visible ? doneBadge.height : 0)

                            Label {
                                id: titleLabel
                                anchors {
                                    left: parent.left
                                    right: doneBadge.visible ? doneBadge.left : parent.right
                                    top: parent.top
                                    rightMargin: doneBadge.visible ? units.gu(0.8) : 0
                                }
                                text: cardItem.cardData.title || i18n.tr("Untitled")
                                font.bold: !page.cardDone(cardItem.cardData)
                                fontSize: "small"
                                wrapMode: Text.WordWrap
                                maximumLineCount: 6
                                elide: Text.ElideNone
                                opacity: 1.0
                            }

                            Rectangle {
                                id: doneBadge
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                }
                                width: doneBadgeLabel.implicitWidth + units.gu(1.1)
                                height: doneBadgeLabel.implicitHeight + units.gu(0.35)
                                visible: page.cardDone(cardItem.cardData)
                                radius: units.gu(0.45)
                                color: Qt.rgba(0.35, 0.56, 0.24, 0.18)
                                border.width: 1
                                border.color: "#5a8f3c"

                                Label {
                                    id: doneBadgeLabel
                                    anchors.centerIn: parent
                                    text: "\u2713 " + page.formatDoneDate(cardItem.cardData.done)
                                    color: "#5a8f3c"
                                    font.bold: true
                                    fontSize: "x-small"
                                }
                            }
                        }

                        Item {
                            id: metaRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: titleRow.bottom
                                topMargin: units.gu(0.65)
                            }
                            width: parent.width
                            height: visible ? Math.max(leftMetaColumn.height, assigneeFlow.visible ? assigneeFlow.height : 0) : 0
                            visible: labelFlow.visible || cardInfoFlow.visible || assigneeFlow.visible

                            Item {
                                id: leftMetaColumn
                                anchors.left: parent.left
                                anchors.top: parent.top
                                width: assigneeFlow.visible ? Math.max(units.gu(8), parent.width - assigneeFlow.width - units.gu(0.8)) : parent.width
                                height: (labelFlow.visible ? labelFlow.height : 0)
                                    + (labelFlow.visible && cardInfoFlow.visible ? units.gu(0.35) : 0)
                                    + (cardInfoFlow.visible ? cardInfoFlow.height : 0)

                                Flow {
                                    id: labelFlow
                                    property int expectedRows: Math.max(1, Math.ceil(page.cardLabels(cardItem.cardData).length / 2))
                                    property real expectedHeight: visible ? Math.max(childrenRect.height, expectedRows * units.gu(2.2)) : 0
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: expectedHeight
                                    spacing: units.gu(0.35)
                                    visible: page.cardLabels(cardItem.cardData).length > 0

                                    Repeater {
                                        model: page.cardLabels(cardItem.cardData)

                                        Rectangle {
                                            width: Math.min(labelText.implicitWidth + units.gu(1.0), Math.max(units.gu(7), (labelFlow.width - labelFlow.spacing) / 2))
                                            height: labelText.implicitHeight + units.gu(0.35)
                                            radius: units.gu(0.45)
                                            color: Qt.rgba(0.17, 0.5, 0.72, 0.16)
                                            border.width: 1
                                            border.color: page.labelColor(modelData)

                                            Label {
                                                id: labelText
                                                anchors.centerIn: parent
                                                width: parent.width - units.gu(0.8)
                                                text: modelData.title || i18n.tr("Label")
                                                color: page.labelColor(modelData)
                                                font.bold: true
                                                fontSize: "x-small"
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                Flow {
                                    id: cardInfoFlow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: labelFlow.visible ? labelFlow.bottom : parent.top
                                    anchors.topMargin: labelFlow.visible ? units.gu(0.35) : 0
                                    height: visible ? childrenRect.height : 0
                                    spacing: units.gu(0.8)
                                    visible: page.cardInfoBadges(cardItem.cardData).length > 0

                                    Repeater {
                                        model: page.cardInfoBadges(cardItem.cardData)

                                        Row {
                                            spacing: units.gu(0.25)
                                            height: Math.max(infoIcon.implicitHeight, infoCount.implicitHeight)

                                            Label {
                                                id: infoIcon
                                                text: modelData.icon
                                                color: theme.palette.normal.backgroundText
                                                opacity: 0.62
                                                font.pixelSize: units.gu(1.65)
                                                font.bold: modelData.kind === "description"
                                            }

                                            Label {
                                                id: infoCount
                                                visible: Number(modelData.count || 0) > 0
                                                text: String(modelData.count)
                                                color: theme.palette.normal.backgroundText
                                                opacity: 0.62
                                                fontSize: "x-small"
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }

                            Flow {
                                id: assigneeFlow
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: visible ? Math.min(units.gu(9.2), page.cardAssignedUsers(cardItem.cardData).slice(0, 3).length * units.gu(3.05)) : 0
                                height: visible ? childrenRect.height : 0
                                spacing: units.gu(0.25)
                                visible: page.cardAssignedUsers(cardItem.cardData).length > 0

                                Repeater {
                                    model: page.cardAssignedUsers(cardItem.cardData).slice(0, 3)

                                    NextCommon.AvatarButton {
                                        property string assigneeId: page.userId(modelData)

                                        width: units.gu(2.8)
                                        height: width
                                        avatarUrl: dataController.avatarDataUrl(assigneeId)
                                        fallbackText: page.userInitial(modelData)
                                        backgroundColor: page.actionBlue
                                        borderColor: Qt.rgba(1, 1, 1, 0.45)

                                        Component.onCompleted: dataController.requestAvatar(assigneeId)
                                    }
                                }
                            }
                        }
                    }
                    Item {
                        id: cardMenuButton
                        anchors {
                            top: parent.top
                            right: parent.right
                            bottom: parent.bottom
                            rightMargin: units.gu(0.2)
                        }
                        width: units.gu(4.8)

                        Label {
                            anchors.centerIn: parent
                            text: "\u22ee"
                            color: theme.palette.normal.backgroundText
                            font.pixelSize: units.gu(2.3)
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: page.showCardOptions(cardItem.cardData)
                        }
                    }
                    MouseArea {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            right: cardMenuButton.left
                        }
                        enabled: cardItem.cardData.type === "board" || cardItem.cardData.type === "card"
                        onClicked: {
                            if (cardItem.cardData.type === "board") {
                                dataController.openBoard(cardItem.cardData.id, cardItem.cardData.title, cardItem.cardData.labels || [])
                            } else if (cardItem.cardData.type === "card") {
                                page.openCard(cardItem.cardData)
                            }
                        }
                    }
                }
                }
            }

            UTControls.EmptyState {
                Layout.fillWidth: true
                visible: page.filteredEntries.length === 0 && dataController.viewMode === "cards" && !page.archiveOverviewMode && !dataController.loading && page.searchQuery.length === 0
                message: i18n.tr("No cards found.")
            }

            UTControls.EmptyState {
                Layout.fillWidth: true
                visible: page.filteredEntries.length === 0 && !page.archiveOverviewMode && !dataController.loading && (page.searchQuery.length > 0 || dataController.viewMode === "boards")
                message: page.searchQuery.length > 0 ? i18n.tr("No matching items") : i18n.tr("Open the menu and choose a board.")
            }
        }
    }

    Rectangle {
        visible: dataController.viewMode === "cards"
            && !page.archiveOverviewMode
            && !page.showArchivedCardsMode
            && dataController.selectedBoardId > 0
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: units.gu(2)
            bottomMargin: units.gu(2)
        }
        width: units.gu(6.2)
        height: units.gu(6.2)
        radius: width / 2
        color: page.actionBlue
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.35)
        z: 6

        Label {
            anchors.centerIn: parent
            text: "+"
            color: "white"
            font.pixelSize: units.gu(3.2)
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: page.showCreateCardDialog()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: page.drawerOpen ? 0.36 : 0
        visible: page.drawerOpen
        z: 8
        MouseArea {
            anchors.fill: parent
            onClicked: page.drawerOpen = false
        }
    }

    NextCommon.DrawerShell {
        id: drawer
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        visible: page.drawerOpen
        z: 9
        appName: appController.appName
        bottomItems: [
            {"label": i18n.tr("Language"), "page": "LanguageSelectionPage.qml"},
            {"label": i18n.tr("Account"), "page": "AccountSelectionPage.qml"},
            {"label": i18n.tr("Settings"), "page": "SettingsPage.qml"},
            {"label": i18n.tr("About"), "page": "AboutPage.qml"}
        ]
        onCloseClicked: page.drawerOpen = false
        onBottomItemClicked: page.openPage(pageUrl)

        Label {
            Layout.fillWidth: true
            text: i18n.tr("Boards")
            font.bold: true
            opacity: 0.72
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: units.gu(5.2)
            visible: dataController.selectedBoardId > 0 || page.archiveOverviewCount() > 0
            radius: units.gu(0.55)
            color: page.archiveOverviewMode
                ? Qt.rgba(0.17, 0.5, 0.72, 0.16)
                : "transparent"
            border.width: 1
            border.color: page.archiveOverviewMode
                ? page.actionBlue
                : "#7a7a7a"

            RowLayout {
                anchors.fill: parent
                anchors.margins: units.gu(1)
                spacing: units.gu(1)

                Label {
                    Layout.fillWidth: true
                    text: i18n.tr("Archive")
                    color: theme.palette.normal.backgroundText
                    font.bold: true
                    elide: Text.ElideRight
                }

                Label {
                    text: String(page.archiveOverviewCount())
                    color: theme.palette.normal.backgroundText
                    opacity: 0.72
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: page.showArchiveOverview()
            }
        }

        Repeater {
            model: page.visibleBoardEntries

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: units.gu(5.4)
                    radius: units.gu(0.55)
                    color: dataController.selectedBoardId === Number(modelData.id || 0)
                        ? Qt.rgba(0.17, 0.5, 0.72, 0.16)
                        : "transparent"
                    border.width: 1
                    border.color: dataController.selectedBoardId === Number(modelData.id || 0)
                        ? page.actionBlue
                        : "#7a7a7a"

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: units.gu(1)
                    spacing: units.gu(1)

                        Rectangle {
                            Layout.preferredWidth: units.gu(1.35)
                            Layout.preferredHeight: units.gu(1.35)
                            radius: width / 2
                            color: page.boardColor(modelData)
                        }

                    Label {
                        Layout.fillWidth: true
                        text: modelData.title || i18n.tr("Untitled board")
                        color: theme.palette.normal.backgroundText
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Label {
                        text: String(page.boardCardCount(modelData))
                        color: theme.palette.normal.backgroundText
                        opacity: 0.72
                        font.bold: true
                    }

                    Rectangle {
                        Layout.preferredWidth: units.gu(3.8)
                        Layout.preferredHeight: units.gu(3.8)
                        radius: width / 2
                        color: "transparent"
                        z: 3

                        Label {
                            anchors.centerIn: parent
                            text: "\u22ee"
                            color: theme.palette.normal.backgroundText
                            font.pixelSize: units.gu(2.4)
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                page.selectedBoard = modelData
                                page.showBoardOptionsDialog(modelData)
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: units.gu(4.8)
                    onClicked: {
                        page.drawerOpen = false
                        page.archiveOverviewMode = false
                        page.showArchivedCardsMode = false
                        dataController.openBoard(modelData.id, modelData.title, modelData.labels || [])
                    }
                    }
                }
            }

        NextCommon.DrawerNavItem {
            Layout.fillWidth: true
            text: i18n.tr("Create board")
            textColor: theme.palette.normal.backgroundText
            framed: false
            textHorizontalAlignment: Text.AlignHCenter
            onClicked: page.showCreateBoardDialog()
        }
    }
}
