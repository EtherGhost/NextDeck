import QtQuick 2.7
import Qt.labs.settings 1.0

Item {
    visible: false
    property string appName: ""
    property string appDescription: ""
    property string apiNote: ""
    property bool openCardLinksDirectly: appSettings.openCardLinksDirectly
    property bool syncOnStartup: appSettings.syncOnStartup
    property bool swipeActionsEnabled: appSettings.swipeActionsEnabled
    property bool swipeActionsReversed: appSettings.swipeActionsReversed
    property bool pullToRefreshEnabled: appSettings.pullToRefreshEnabled
    property bool dragForMoveEnabled: appSettings.dragForMoveEnabled
    property bool multiSelectEnabled: appSettings.multiSelectEnabled

    signal accountChanged(int accountId, string displayName, string providerId, string serviceId, string serverUrl, string avatarUrl)

    Settings {
        id: appSettings
        category: "app"
        property bool openCardLinksDirectly: false
        property bool syncOnStartup: true
        property bool swipeActionsEnabled: true
        property bool swipeActionsReversed: false
        property bool pullToRefreshEnabled: true
        property bool dragForMoveEnabled: true
        property bool multiSelectEnabled: true
    }

    function setOpenCardLinksDirectly(value) {
        appSettings.openCardLinksDirectly = value === true
        openCardLinksDirectly = appSettings.openCardLinksDirectly
    }

    function setSyncOnStartup(value) {
        appSettings.syncOnStartup = value === true
        syncOnStartup = appSettings.syncOnStartup
    }

    function setListControlSetting(key, value) {
        var enabled = value === true
        if (key === "swipeActionsEnabled") {
            appSettings.swipeActionsEnabled = enabled
            swipeActionsEnabled = appSettings.swipeActionsEnabled
        } else if (key === "swipeActionsReversed") {
            appSettings.swipeActionsReversed = enabled
            swipeActionsReversed = appSettings.swipeActionsReversed
        } else if (key === "pullToRefreshEnabled") {
            appSettings.pullToRefreshEnabled = enabled
            pullToRefreshEnabled = appSettings.pullToRefreshEnabled
        } else if (key === "dragForMoveEnabled") {
            appSettings.dragForMoveEnabled = enabled
            dragForMoveEnabled = appSettings.dragForMoveEnabled
        } else if (key === "multiSelectEnabled") {
            appSettings.multiSelectEnabled = enabled
            multiSelectEnabled = appSettings.multiSelectEnabled
        }
    }
}
