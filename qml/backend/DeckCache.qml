import QtQuick 2.7
import QtQuick.LocalStorage 2.0 as Sql

Item {
    id: cache

    readonly property string statusClean: ""
    readonly property string statusCreated: "LOCAL_CREATED"
    readonly property string statusEdited: "LOCAL_EDITED"
    readonly property string statusDeleted: "LOCAL_DELETED"

    property var database: null
    property string databaseName: "NextDeckSyncV1"

    function setScope(scopeKey) {
        var scopedName = "NextDeckSyncV1_" + safeScopeName(scopeKey)
        if (databaseName === scopedName) {
            return
        }
        database = null
        databaseName = scopedName
    }

    function safeScopeName(scopeKey) {
        var value = String(scopeKey || "default").replace(/[^A-Za-z0-9_]/g, "_")
        if (value.length === 0) return "default"
        return value.length > 96 ? value.slice(0, 96) : value
    }

    function db() {
        if (database) return database
        database = Sql.LocalStorage.openDatabaseSync(databaseName, "1.0", "NextDeck sync cache", 12 * 1024 * 1024)
        database.transaction(function(tx) {
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS boards (" +
                "id INTEGER PRIMARY KEY, title TEXT NOT NULL, color TEXT DEFAULT '', archived INTEGER DEFAULT 0, " +
                "raw_json TEXT DEFAULT '', updated_at INTEGER NOT NULL)"
            )
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS stacks (" +
                "id INTEGER PRIMARY KEY, board_id INTEGER NOT NULL, title TEXT NOT NULL, order_value INTEGER DEFAULT 0, " +
                "raw_json TEXT DEFAULT '', updated_at INTEGER NOT NULL)"
            )
            tx.executeSql(
                "CREATE TABLE IF NOT EXISTS cards (" +
                "local_key TEXT PRIMARY KEY, id INTEGER DEFAULT 0, board_id INTEGER NOT NULL, stack_id INTEGER NOT NULL, " +
                "stack_title TEXT DEFAULT '', title TEXT NOT NULL, description TEXT DEFAULT '', due_date TEXT DEFAULT '', " +
                "order_value INTEGER DEFAULT 0, type_raw TEXT DEFAULT 'plain', archived INTEGER DEFAULT 0, " +
                "owner_json TEXT DEFAULT '[]', labels_json TEXT DEFAULT '[]', assigned_users_json TEXT DEFAULT '[]', " +
                "attachments_json TEXT DEFAULT '[]', comments_json TEXT DEFAULT '[]', attachment_count INTEGER DEFAULT 0, " +
                "comments_unread INTEGER DEFAULT 0, done TEXT DEFAULT '', notified INTEGER DEFAULT 0, overdue INTEGER DEFAULT 0, " +
                "local_status TEXT DEFAULT '', local_modified INTEGER DEFAULT 0, conflict INTEGER DEFAULT 0, " +
                "server_json TEXT DEFAULT '', updated_at INTEGER NOT NULL)"
            )
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_cards_board_stack ON cards(board_id, stack_id)")
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_cards_status ON cards(local_status, local_modified)")
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_stacks_board ON stacks(board_id)")
        })
        return database
    }

    function cardKey(card) {
        if (card && Number(card.id || 0) > 0) {
            return "server:" + Number(card.id)
        }
        return String(card && card.localKey ? card.localKey : "")
    }

    function newLocalKey() {
        return "local:" + Date.now() + ":" + Math.floor(Math.random() * 1000000)
    }

    function loadBoards() {
        var entries = []
        db().readTransaction(function(tx) {
            var rows = tx.executeSql("SELECT id, title, archived, raw_json FROM boards ORDER BY title COLLATE NOCASE ASC")
            for (var i = 0; i < rows.rows.length; ++i) {
                var row = rows.rows.item(i)
                var board = {}
                try {
                    board = JSON.parse(row.raw_json || "{}")
                } catch (e) {
                    board = {}
                }
                board.id = Number(board.id || row.id)
                board.title = board.title || row.title || i18n.tr("Untitled board")
                board.subtitle = Number(row.archived || 0) === 1 ? i18n.tr("Archived board") : i18n.tr("Board")
                board.detail = board.detail || ""
                board.type = "board"
                entries.push(board)
            }
        })
        return entries
    }

    function loadBoardCardCounts() {
        var counts = {}
        db().readTransaction(function(tx) {
            var rows = tx.executeSql(
                "SELECT board_id, COUNT(*) AS c FROM cards WHERE local_status != ? AND archived = 0 GROUP BY board_id",
                [statusDeleted]
            )
            for (var i = 0; i < rows.rows.length; ++i) {
                var row = rows.rows.item(i)
                counts[String(Number(row.board_id || 0))] = Number(row.c || 0)
            }
        })
        return counts
    }

    function clearCleanServerDataForCurrentScope() {
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM boards")
            tx.executeSql("DELETE FROM stacks")
            tx.executeSql("DELETE FROM cards WHERE local_status IS NULL OR local_status = ''")
        })
    }

    function loadBoardEntries(boardId, boardTitle, includeArchived) {
        var entries = []
        db().readTransaction(function(tx) {
            var stackRows = tx.executeSql("SELECT * FROM stacks WHERE board_id = ? ORDER BY order_value ASC, title COLLATE NOCASE ASC", [boardId])
            for (var i = 0; i < stackRows.rows.length; ++i) {
                var stack = stackRows.rows.item(i)
                entries.push({
                    "boardId": Number(boardId),
                    "stackId": Number(stack.id),
                    "stackTitle": stack.title || i18n.tr("Untitled list"),
                    "title": stack.title || i18n.tr("Untitled list"),
                    "subtitle": i18n.tr("List"),
                    "detail": "",
                    "type": "stack"
                })
                var cardRows = tx.executeSql(
                    "SELECT * FROM cards WHERE board_id = ? AND stack_id = ? AND local_status != ? " +
                    (includeArchived === true ? "" : "AND archived = 0 ") +
                    "ORDER BY order_value ASC, updated_at DESC, title COLLATE NOCASE ASC",
                    [boardId, Number(stack.id), statusDeleted]
                )
                for (var j = 0; j < cardRows.rows.length; ++j) {
                    entries.push(rowToCard(cardRows.rows.item(j)))
                }
            }
        })
        return entries
    }

    function loadLocalChanges() {
        var result = []
        db().readTransaction(function(tx) {
            var rows = tx.executeSql(
                "SELECT * FROM cards WHERE local_status IN (?, ?, ?) AND conflict = 0 ORDER BY local_modified ASC",
                [statusCreated, statusEdited, statusDeleted]
            )
            for (var i = 0; i < rows.rows.length; ++i) {
                result.push(rowToCard(rows.rows.item(i)))
            }
        })
        return result
    }

    function countDirty() {
        var count = 0
        db().readTransaction(function(tx) {
            var rows = tx.executeSql("SELECT COUNT(*) AS c FROM cards WHERE local_status IN (?, ?, ?)", [statusCreated, statusEdited, statusDeleted])
            count = rows.rows.length > 0 ? Number(rows.rows.item(0).c || 0) : 0
        })
        return count
    }

    function countConflicts() {
        var count = 0
        db().readTransaction(function(tx) {
            var rows = tx.executeSql("SELECT COUNT(*) AS c FROM cards WHERE conflict = 1")
            count = rows.rows.length > 0 ? Number(rows.rows.item(0).c || 0) : 0
        })
        return count
    }

    function saveBoards(entries) {
        var now = Math.floor(Date.now() / 1000)
        var seen = {}
        db().transaction(function(tx) {
            for (var i = 0; i < (entries || []).length; ++i) {
                var board = entries[i]
                if (board.type !== "board" || !board.id) continue
                seen[String(board.id)] = true
                tx.executeSql(
                    "INSERT OR REPLACE INTO boards (id, title, archived, raw_json, updated_at) VALUES (?, ?, ?, ?, ?)",
                    [Number(board.id), board.title || i18n.tr("Untitled board"), board.archived === true ? 1 : 0, JSON.stringify(board), now]
                )
            }
            var rows = tx.executeSql("SELECT id FROM boards")
            for (var j = 0; j < rows.rows.length; ++j) {
                var id = Number(rows.rows.item(j).id)
                if (!seen[String(id)]) {
                    tx.executeSql("DELETE FROM boards WHERE id = ?", [id])
                    tx.executeSql("DELETE FROM stacks WHERE board_id = ?", [id])
                    tx.executeSql("DELETE FROM cards WHERE board_id = ? AND local_status = ?", [id, statusClean])
                }
            }
        })
    }

    function saveBoardEntries(boardId, entries) {
        var now = Math.floor(Date.now() / 1000)
        var seenStacks = {}
        var seenCards = {}
        db().transaction(function(tx) {
            for (var i = 0; i < (entries || []).length; ++i) {
                var entry = entries[i]
                if (entry.type === "stack") {
                    seenStacks[String(entry.stackId)] = true
                    tx.executeSql(
                        "INSERT OR REPLACE INTO stacks (id, board_id, title, order_value, raw_json, updated_at) VALUES (?, ?, ?, ?, ?, ?)",
                        [Number(entry.stackId), Number(boardId), entry.title || i18n.tr("Untitled list"), Number(entry.order || 0), JSON.stringify(entry), now]
                    )
                } else if (entry.type === "card") {
                    seenCards[String(entry.id)] = true
                    upsertServerCard(tx, entry, now)
                }
            }
            var stackRows = tx.executeSql("SELECT id FROM stacks WHERE board_id = ?", [boardId])
            for (var s = 0; s < stackRows.rows.length; ++s) {
                var stackId = Number(stackRows.rows.item(s).id)
                if (!seenStacks[String(stackId)]) {
                    tx.executeSql("DELETE FROM stacks WHERE id = ?", [stackId])
                    tx.executeSql("DELETE FROM cards WHERE stack_id = ? AND local_status = ?", [stackId, statusClean])
                }
            }
            var cardRows = tx.executeSql("SELECT local_key, id, local_status FROM cards WHERE board_id = ?", [boardId])
            for (var c = 0; c < cardRows.rows.length; ++c) {
                var row = cardRows.rows.item(c)
                if (Number(row.id || 0) > 0 && !seenCards[String(row.id)] && (row.local_status || statusClean) === statusClean) {
                    tx.executeSql("DELETE FROM cards WHERE local_key = ?", [row.local_key])
                }
            }
        })
    }

    function upsertServerCard(tx, card, now) {
        var key = cardKey(card)
        if (key.length === 0) return
        var existingRows = tx.executeSql("SELECT local_status, conflict, server_json FROM cards WHERE local_key = ?", [key])
        var existing = existingRows.rows.length > 0 ? existingRows.rows.item(0) : null
        var localStatus = existing ? (existing.local_status || statusClean) : statusClean
        var conflict = existing ? Number(existing.conflict || 0) : 0
        if (localStatus !== statusClean) {
            tx.executeSql("UPDATE cards SET server_json = ?, conflict = ?, updated_at = ? WHERE local_key = ?", [JSON.stringify(card), conflict, now, key])
            return
        }
        writeCard(tx, normalizeCard(card, statusClean, false), now)
    }

    function saveLocalCard(card, localStatus) {
        var now = Math.floor(Date.now() / 1000)
        db().transaction(function(tx) {
            writeCard(tx, normalizeCard(card, localStatus || statusEdited, false), now)
        })
    }

    function markClean(card) {
        var now = Math.floor(Date.now() / 1000)
        db().transaction(function(tx) {
            writeCard(tx, normalizeCard(card, statusClean, false), now)
        })
    }

    function markDeleted(card) {
        saveLocalCard(card, statusDeleted)
    }

    function removeCard(cardOrId) {
        var key = typeof cardOrId === "object" ? cardKey(cardOrId) : "server:" + Number(cardOrId || 0)
        if (key.length === 0) return
        db().transaction(function(tx) {
            tx.executeSql("DELETE FROM cards WHERE local_key = ?", [key])
        })
    }

    function markConflict(card, serverCard) {
        var key = cardKey(card)
        var now = Math.floor(Date.now() / 1000)
        if (key.length === 0) return
        db().transaction(function(tx) {
            tx.executeSql(
                "UPDATE cards SET conflict = 1, server_json = ?, local_status = ?, local_modified = ?, updated_at = ? WHERE local_key = ?",
                [JSON.stringify(serverCard || {}), card.localStatus || statusEdited, now, now, key]
            )
        })
    }

    function resolveConflictUseServer(card) {
        var server = {}
        try {
            server = JSON.parse(card.serverJson || "{}")
        } catch (e) {
            server = {}
        }
        markClean(server && server.id ? server : card)
    }

    function writeCard(tx, card, now) {
        var key = cardKey(card)
        if (key.length === 0) {
            key = newLocalKey()
            card.localKey = key
        }
        var localStatus = card.localStatus || statusClean
        tx.executeSql(
            "INSERT OR REPLACE INTO cards (" +
            "local_key, id, board_id, stack_id, stack_title, title, description, due_date, order_value, type_raw, archived, " +
            "owner_json, labels_json, assigned_users_json, attachments_json, comments_json, attachment_count, comments_unread, " +
            "done, notified, overdue, local_status, local_modified, conflict, server_json, updated_at) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [
                key, Number(card.id || 0), Number(card.boardId || 0), Number(card.stackId || 0),
                card.stackTitle || card.subtitle || i18n.tr("List"), card.title || i18n.tr("Untitled card"),
                card.description || "", card.duedate || card.detail || "", Number(card.order || 0),
                card.typeRaw || "plain", card.archived === true ? 1 : 0,
                JSON.stringify(card.owner || []), JSON.stringify(card.labels || []), JSON.stringify(card.assignedUsers || []),
                JSON.stringify(card.attachments || []), JSON.stringify(card.comments || []),
                Number(card.attachmentCount || 0), Number(card.commentsUnread || 0), card.done || "",
                card.notified === true ? 1 : 0, Number(card.overdue || 0), localStatus,
                localStatus === statusClean ? 0 : (Number(card.localModified || 0) || now),
                card.conflict === true ? 1 : 0, card.serverJson || JSON.stringify(card), now
            ]
        )
    }

    function normalizeCard(card, localStatus, conflict) {
        var copy = {}
        for (var key in (card || {})) copy[key] = card[key]
        copy.localKey = cardKey(copy) || copy.localKey || newLocalKey()
        copy.localStatus = localStatus || statusClean
        copy.dirty = copy.localStatus !== statusClean
        copy.conflict = conflict === true || copy.conflict === true
        return copy
    }

    function rowToCard(row) {
        var localStatus = row.local_status || statusClean
        return {
            "localKey": row.local_key || "",
            "id": Number(row.id || 0),
            "boardId": Number(row.board_id || 0),
            "stackId": Number(row.stack_id || 0),
            "stackTitle": row.stack_title || i18n.tr("List"),
            "title": row.title || i18n.tr("Untitled card"),
            "subtitle": row.stack_title || i18n.tr("List"),
            "detail": row.due_date || "",
            "description": row.description || "",
            "duedate": row.due_date || "",
            "order": Number(row.order_value || 0),
            "typeRaw": row.type_raw || "plain",
            "archived": Number(row.archived || 0) === 1,
            "owner": parseJsonArray(row.owner_json),
            "labels": parseJsonArray(row.labels_json),
            "assignedUsers": parseJsonArray(row.assigned_users_json),
            "attachments": parseJsonArray(row.attachments_json),
            "comments": parseJsonArray(row.comments_json),
            "attachmentCount": Number(row.attachment_count || 0),
            "commentsUnread": Number(row.comments_unread || 0),
            "done": row.done || "",
            "notified": Number(row.notified || 0) === 1,
            "overdue": Number(row.overdue || 0),
            "localStatus": localStatus,
            "dirty": localStatus !== statusClean,
            "conflict": Number(row.conflict || 0) === 1,
            "serverJson": row.server_json || "",
            "type": "card"
        }
    }

    function parseJsonArray(value) {
        try {
            var parsed = JSON.parse(value || "[]")
            return parsed && parsed.length !== undefined ? parsed : []
        } catch (e) {
            return []
        }
    }
}
