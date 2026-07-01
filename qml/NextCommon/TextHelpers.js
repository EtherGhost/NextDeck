.pragma library

function firstNonEmptyLine(text) {
    var lines = String(text || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; ++i) {
        var line = lines[i].trim()
        if (line.length > 0) return line
    }
    return ""
}

function truncate(text, maxLength) {
    var value = String(text || "")
    var limit = Number(maxLength || 0)
    if (limit <= 0 || value.length <= limit) return value
    if (limit <= 3) return value.substring(0, limit)
    return value.substring(0, limit - 3) + "..."
}

function initials(displayName, fallback) {
    var text = String(displayName || "").trim()
    if (text.length === 0) return fallback || "?"
    var parts = text.split(/\s+/)
    if (parts.length === 1) return parts[0].charAt(0).toUpperCase()
    return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase()
}

function firstValue(value, names) {
    if (!value) return ""
    for (var i = 0; i < names.length; ++i) {
        if (value[names[i]] !== undefined && value[names[i]] !== null && String(value[names[i]]).length > 0) {
            return String(value[names[i]])
        }
    }
    return ""
}

function objectKeys(value) {
    var keys = []
    if (!value) return keys
    for (var key in value) {
        keys.push(key)
    }
    return keys.sort()
}

function hasValue(value) {
    return value !== undefined && value !== null && String(value).length > 0 ? "true" : "false"
}
