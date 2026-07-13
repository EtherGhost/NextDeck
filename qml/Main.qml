import QtQuick 2.7
import Lomiri.Components 1.3
import "backend"

MainView {
    id: root
    objectName: "mainView"
    applicationName: "nextdeck.cloudsite"
    automaticOrientation: true

    width: desktopLarge ? units.gu(45) : units.gu(85)
    height: desktopLarge ? units.gu(80) : units.gu(80)

    Component.onCompleted: {
        if (desktopDarkMode) {
            theme.name = "Ubuntu.Components.Themes.SuruDark"
        }
    }

    AppController {
        id: appController
        appName: "NextDeck"
        appDescription: "Native Ubuntu Touch client for Nextcloud Deck."
        apiNote: "No boards found."
    }

    PageStack {
        id: pageStack
        anchors.fill: parent

        Component.onCompleted: push(Qt.resolvedUrl("pages/HomePage.qml"), {
            "appController": appController
        })
    }
}
