import QtQuick 2.7
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

RowLayout {
    id: root

    property string searchText: ""
    property string searchPlaceholder: ""
    property bool filterActive: false
    property string filterIconKind: "filter"
    property string statusKind: "warning"
    property color statusColor: "#b37a2a"
    property bool statusAnimating: statusKind === "syncing"
    property string avatarUrl: ""
    property string accountInitial: "?"
    property color actionColor: "#2c7fb8"
    property color iconColor: theme.palette.normal.backgroundText
    property color inactiveBorderColor: "#7a7a7a"

    signal menuClicked()
    signal searchChanged(string text)
    signal clearSearchClicked()
    signal filterClicked()
    signal statusClicked()
    signal accountClicked()

    anchors {
        fill: parent
        leftMargin: units.gu(0.5)
        rightMargin: units.gu(0.5)
    }
    spacing: units.gu(0.75)

    Item {
        Layout.preferredWidth: units.gu(3.4)
        Layout.preferredHeight: units.gu(5)

        Label {
            anchors.centerIn: parent
            text: "\u2630"
            color: root.iconColor
            font.pixelSize: units.gu(2.6)
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.menuClicked()
        }
    }

    TextField {
        id: searchField
        Layout.fillWidth: true
        placeholderText: root.searchPlaceholder
        text: root.searchText
        onTextChanged: {
            if (root.searchText !== text) {
                root.searchChanged(text)
            }
        }
    }

    Item {
        Layout.preferredWidth: units.gu(5)
        Layout.preferredHeight: units.gu(5)
        visible: searchField.text.length > 0

        Label {
            anchors.centerIn: parent
            text: "\u2715"
            color: root.iconColor
            font.pixelSize: units.gu(2.2)
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.clearSearchClicked()
        }
    }

    Rectangle {
        Layout.preferredWidth: units.gu(5)
        Layout.preferredHeight: units.gu(5)
        radius: units.gu(2.5)
        color: root.filterActive ? Qt.rgba(0.17, 0.5, 0.72, 0.16) : "transparent"
        border.width: root.filterActive ? 2 : 1
        border.color: root.filterActive ? root.actionColor : root.inactiveBorderColor

        Canvas {
            id: filterCanvas
            anchors.centerIn: parent
            width: units.gu(2.7)
            height: units.gu(2.7)
            property color paintColor: root.filterActive ? root.actionColor : root.iconColor
            onPaintColorChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var h = height
                ctx.clearRect(0, 0, w, h)
                ctx.strokeStyle = paintColor
                ctx.fillStyle = paintColor
                ctx.lineWidth = Math.max(2.2, Math.min(w, h) * 0.13)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                if (root.filterIconKind === "sort") {
                    ctx.beginPath()
                    ctx.moveTo(w * 0.28, h * 0.22)
                    ctx.lineTo(w * 0.28, h * 0.76)
                    ctx.moveTo(w * 0.20, h * 0.66)
                    ctx.lineTo(w * 0.28, h * 0.78)
                    ctx.lineTo(w * 0.36, h * 0.66)
                    ctx.moveTo(w * 0.72, h * 0.78)
                    ctx.lineTo(w * 0.72, h * 0.24)
                    ctx.moveTo(w * 0.64, h * 0.34)
                    ctx.lineTo(w * 0.72, h * 0.22)
                    ctx.lineTo(w * 0.80, h * 0.34)
                    ctx.stroke()
                } else {
                    ctx.beginPath()
                    ctx.moveTo(w * 0.18, h * 0.24)
                    ctx.lineTo(w * 0.82, h * 0.24)
                    ctx.lineTo(w * 0.58, h * 0.52)
                    ctx.lineTo(w * 0.58, h * 0.80)
                    ctx.lineTo(w * 0.42, h * 0.70)
                    ctx.lineTo(w * 0.42, h * 0.52)
                    ctx.closePath()
                    ctx.stroke()
                }
                if (root.filterActive) {
                    ctx.beginPath()
                    ctx.arc(w * 0.78, h * 0.78, Math.min(w, h) * 0.13, 0, Math.PI * 2, false)
                    ctx.fill()
                }
            }

            Connections {
                target: root
                onFilterIconKindChanged: filterCanvas.requestPaint()
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.filterClicked()
        }
    }

    Rectangle {
        Layout.preferredWidth: units.gu(5)
        Layout.preferredHeight: units.gu(5)
        radius: units.gu(2.5)
        color: "transparent"
        border.width: 2
        border.color: root.statusColor

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
                running: root.statusAnimating
            }

            Connections {
                target: root
                onStatusAnimatingChanged: {
                    if (!root.statusAnimating) {
                        statusIcon.rotation = 0
                    }
                }
            }

            Canvas {
                id: statusCanvas
                anchors.fill: parent
                property string paintColor: root.statusColor
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

                    if (root.statusKind === "syncing") {
                        ctx.beginPath()
                        ctx.arc(w / 2, h / 2, s * 0.35, Math.PI * 0.15, Math.PI * 1.55, false)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(w * 0.77, h * 0.30)
                        ctx.lineTo(w * 0.82, h * 0.52)
                        ctx.lineTo(w * 0.62, h * 0.45)
                        ctx.stroke()
                    } else if (root.statusKind === "synced") {
                        ctx.beginPath()
                        ctx.moveTo(w * 0.22, h * 0.54)
                        ctx.lineTo(w * 0.42, h * 0.72)
                        ctx.lineTo(w * 0.78, h * 0.28)
                        ctx.stroke()
                    } else {
                        ctx.beginPath()
                        ctx.arc(w / 2, h / 2, s * 0.36, 0, Math.PI * 2, false)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(w / 2, h * 0.26)
                        ctx.lineTo(w / 2, h * 0.58)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(w / 2, h * 0.75, s * 0.035, 0, Math.PI * 2, false)
                        ctx.fill()
                    }
                }

                Connections {
                    target: root
                    onStatusKindChanged: statusCanvas.requestPaint()
                    onStatusColorChanged: statusCanvas.requestPaint()
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.statusClicked()
        }
    }

    AvatarButton {
        Layout.preferredWidth: units.gu(5)
        Layout.preferredHeight: units.gu(5)
        avatarUrl: root.avatarUrl
        fallbackText: root.accountInitial
        onClicked: root.accountClicked()
    }
}
