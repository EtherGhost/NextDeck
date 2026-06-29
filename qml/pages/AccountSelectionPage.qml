import QtQuick 2.7
import "qrc:/NextCommon" as NextCommon

NextCommon.AccountPage {
    id: page

    property var appController

    appName: appController.appName
    logPrefix: "NextDeck"
    appApplicationId: "nextdeck.cloudsite_nextdeck"
    nextcloudServiceId: "nextdeck.cloudsite_nextdeck_nextcloud"
    owncloudServiceId: "nextdeck.cloudsite_nextdeck_owncloud"

    onAccountAuthorized: function(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl) {
        if (page.appController && page.appController.accountChanged) {
            page.appController.accountChanged(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl)
        }
    }
}
