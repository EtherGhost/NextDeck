.pragma library

function pad2(value) {
    var number = Number(value || 0)
    return number < 10 ? "0" + number : "" + number
}

function monthShortName(monthIndex) {
    var names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return names[Math.max(0, Math.min(11, Number(monthIndex || 0)))]
}

function parseDate(value) {
    if (!value) return null
    if (value instanceof Date) return value
    var parsed = Date.parse(value)
    if (isNaN(parsed)) return null
    return new Date(parsed)
}

function formatShortDate(value) {
    var date = parseDate(value)
    if (!date) return ""
    return pad2(date.getDate()) + "-" + monthShortName(date.getMonth()) + "-" + date.getFullYear()
}

function formatIsoDate(value) {
    var date = parseDate(value)
    if (!date) return ""
    return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function relativeAge(value, nowValue) {
    var date = parseDate(value)
    if (!date) return ""
    var now = parseDate(nowValue) || new Date()
    var seconds = Math.max(0, Math.floor((now.getTime() - date.getTime()) / 1000))
    if (seconds < 60) return seconds + "s"
    var minutes = Math.floor(seconds / 60)
    if (minutes < 60) return minutes + "m"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h"
    var days = Math.floor(hours / 24)
    if (days < 7) return days + "d"
    return formatShortDate(date)
}
