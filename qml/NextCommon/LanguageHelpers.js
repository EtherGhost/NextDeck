.pragma library

function isSystemLanguage(code) {
    return String(code || "").length === 0
}

function displayLanguageName(code, fallbackName) {
    if (isSystemLanguage(code)) return fallbackName || "System language"
    return fallbackName || code
}
