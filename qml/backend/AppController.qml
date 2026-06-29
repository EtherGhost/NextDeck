import QtQuick 2.7
import Qt.labs.settings 1.0

Item {
    visible: false
    property string appName: ""
    property string appDescription: ""
    property string apiNote: ""
    property bool openCardLinksDirectly: appSettings.openCardLinksDirectly

    signal accountChanged(int accountId, string displayName, string providerId, string serviceId, string serverUrl, string avatarUrl)

    Settings {
        id: appSettings
        category: "app"
        property bool openCardLinksDirectly: false
    }

    function setOpenCardLinksDirectly(value) {
        appSettings.openCardLinksDirectly = value === true
        openCardLinksDirectly = appSettings.openCardLinksDirectly
    }
}
