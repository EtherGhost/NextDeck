.pragma library

function normalizeServerUrl(url) {
    var value = String(url || "").trim()
    return value.replace(/\/+$/, "")
}

function avatarUrl(serverUrl, userName, size) {
    var base = normalizeServerUrl(serverUrl)
    var user = String(userName || "").trim()
    if (base.length === 0 || user.length === 0) return ""
    return base + "/index.php/avatar/" + encodeURIComponent(user) + "/" + Number(size || 64)
}

function joinUrl(baseUrl, path) {
    var base = normalizeServerUrl(baseUrl)
    var suffix = String(path || "")
    if (suffix.length === 0) return base
    return base + "/" + suffix.replace(/^\/+/, "")
}
