import QtQuick 2.7
import "qrc:/NextCommon" as NextCommon

NextCommon.AboutPage {
    id: page

    property var appController
    readonly property string resolvedVersion: typeof nextdeckAppVersion !== "undefined" ? nextdeckAppVersion : "development"

    appName: appController.appName
    appVersion: resolvedVersion
    appDescription: appController.appDescription
}
