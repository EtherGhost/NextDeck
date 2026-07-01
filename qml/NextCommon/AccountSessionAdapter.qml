import QtQuick 2.7
import Ubuntu.OnlineAccounts 0.1
import Qt.labs.settings 1.0

Item {
    id: adapter

    property string logPrefix: "NextApp"
    property bool pendingServiceHandle: false
    property int cachedAccountId: 0
    property string cachedServiceId: ""
    property string cachedServerUrl: ""
    property string cachedUserName: ""
    property string cachedSecret: ""
    property int currentAccountId: 0
    property string currentProviderId: ""
    property string currentServiceId: ""
    property string currentServerUrl: ""
    property int pendingAuthAccountId: 0
    property string pendingAuthServiceId: ""
    property string pendingAuthServerUrl: ""
    property var pendingCallback: null
    property bool authenticationRetryPending: false
    property int authenticationRetryCount: 0
    readonly property int maxAuthenticationRetries: 1
    property bool accountModelRefreshPending: false
    property bool envTestAuthEnabled: typeof desktopTestAuthEnabled !== "undefined" && desktopTestAuthEnabled
    property string envTestServerUrl: typeof desktopTestServerUrl !== "undefined" ? desktopTestServerUrl : ""
    property string envTestUserName: typeof desktopTestUserName !== "undefined" ? desktopTestUserName : ""
    property string envTestSecret: typeof desktopTestSecret !== "undefined" ? desktopTestSecret : ""

    signal authenticated(string userName, string secret, string serverUrl, int accountId, string serviceId)
    signal failed(string message)

    Settings {
        id: accountSettings
        category: "account"
        property int accountId: 0
        property string displayName: ""
        property string providerId: ""
        property string serviceId: ""
        property string serverUrl: ""
    }

    AccountServiceModel {
        id: accountServices
        includeDisabled: true

        onCountChanged: {
            if (adapter.pendingServiceHandle) {
                adapter.authenticate()
            }
        }
    }

    AccountService {
        id: accountService

        onAuthenticated: {
            var data = reply && reply.data ? reply.data : reply
            var userName = adapter.firstValue(data, ["UserName", "Username", "userName", "username"])
            var secret = adapter.firstValue(data, ["Secret", "Password", "password", "secret"])
            var token = adapter.firstValue(data, ["AccessToken", "Token", "token"])

            if (!userName || !secret) {
                adapter.failed(i18n.tr("Authentication succeeded, but the required Online Accounts credentials were not available."))
                return
            }

            if (!adapter.pendingAuthMatchesCurrent()) {
                return
            }

            adapter.cachedAccountId = adapter.pendingAuthAccountId
            adapter.cachedServiceId = adapter.pendingAuthServiceId
            adapter.cachedServerUrl = adapter.pendingAuthServerUrl
            adapter.cachedUserName = userName
            adapter.cachedSecret = secret
            adapter.authenticationRetryPending = false
            adapter.authenticationRetryCount = 0

            adapter.authenticated(userName, secret, adapter.cachedServerUrl, adapter.cachedAccountId, adapter.cachedServiceId)
            if (adapter.pendingCallback) {
                var callback = adapter.pendingCallback
                adapter.pendingCallback = null
                callback(userName, secret, adapter.cachedServerUrl, adapter.cachedAccountId, adapter.cachedServiceId)
            }
        }

        onAuthenticationError: {
            var message = error && error.message ? error.message : JSON.stringify(error)
            if (!adapter.pendingAuthMatchesCurrent()) {
                return
            }
            if (adapter.retryAuthenticationBeforeFail(message)) {
                return
            }
            adapter.failed(i18n.tr("Authentication failed: %1").arg(message))
        }
    }

    Timer {
        id: authenticateAfterHandleTimer
        interval: 80
        repeat: false
        onTriggered: accountService.authenticate({})
    }

    Timer {
        id: authenticationRetryTimer
        interval: 650
        repeat: false
        onTriggered: adapter.retryAuthenticationAfterStaleFailure()
    }

    Timer {
        id: accountModelRefreshTimer
        interval: 120
        repeat: false
        onTriggered: adapter.finishAccountModelRefreshBeforeRetry()
    }

    function authenticate() {
        if (envTestAuthEnabled) {
            var testServerUrl = normalizeServerUrl(envTestServerUrl)
            if (testServerUrl.length === 0 || envTestUserName.length === 0 || envTestSecret.length === 0) {
                failed(i18n.tr("Desktop test credentials are incomplete."))
                return
            }

            cachedAccountId = -1
            cachedServiceId = "desktop-test-env"
            cachedServerUrl = testServerUrl
            cachedUserName = envTestUserName
            cachedSecret = envTestSecret
            authenticated(cachedUserName, cachedSecret, cachedServerUrl, cachedAccountId, cachedServiceId)
            if (pendingCallback) {
                var callback = pendingCallback
                pendingCallback = null
                callback(cachedUserName, cachedSecret, cachedServerUrl, cachedAccountId, cachedServiceId)
            }
            return
        }

        if (effectiveAccountId() <= 0 || effectiveServiceId().length === 0) {
            failed(i18n.tr("No account selected. Open Account first and authorize a Nextcloud account."))
            return
        }

        var serverUrl = normalizeServerUrl(effectiveServerUrl())
        if (serverUrl.length === 0) {
            failed(i18n.tr("No server URL configured. Open Account and authorize the OS account."))
            return
        }

        if (hasCachedCredentials(serverUrl)) {
            authenticated(cachedUserName, cachedSecret, cachedServerUrl, cachedAccountId, cachedServiceId)
            if (pendingCallback) {
                var callback = pendingCallback
                pendingCallback = null
                callback(cachedUserName, cachedSecret, cachedServerUrl, cachedAccountId, cachedServiceId)
            }
            return
        }

        var handle = findSelectedAccountService()
        if (!handle) {
            if (accountServices.count === 0) {
                pendingServiceHandle = true
                failed(i18n.tr("Waiting for Online Accounts..."))
            } else {
                failed(i18n.tr("Selected Online Accounts service was not found. Open Account and verify the account again."))
            }
            return
        }

        pendingServiceHandle = false
        accountService.objectHandle = handle
        pendingAuthAccountId = effectiveAccountId()
        pendingAuthServiceId = effectiveServiceId()
        pendingAuthServerUrl = serverUrl
        authenticateAfterHandleTimer.restart()
    }

    function withCredentials(callback) {
        pendingCallback = callback
        authenticate()
    }

    function setAccount(accountId, providerId, serviceId, serverUrl) {
        var normalizedServerUrl = normalizeServerUrl(serverUrl)
        var accountChanged = currentAccountId !== accountId
            || currentProviderId !== (providerId || "")
            || currentServiceId !== (serviceId || "")
            || currentServerUrl !== normalizedServerUrl

        if (accountChanged) {
            pendingServiceHandle = false
            pendingCallback = null
            authenticationRetryPending = false
            authenticationRetryCount = 0
            cachedAccountId = 0
            cachedServiceId = ""
            cachedServerUrl = ""
            cachedUserName = ""
            cachedSecret = ""
            pendingAuthAccountId = 0
            pendingAuthServiceId = ""
            pendingAuthServerUrl = ""
            authenticateAfterHandleTimer.stop()
            accountService.objectHandle = null
        }

        currentAccountId = accountId
        currentProviderId = providerId || ""
        currentServiceId = serviceId || ""
        currentServerUrl = normalizedServerUrl
    }

    function hasCachedCredentials(serverUrl) {
        return cachedAccountId === effectiveAccountId()
            && cachedServiceId === effectiveServiceId()
            && cachedServerUrl === serverUrl
            && cachedUserName.length > 0
            && cachedSecret.length > 0
    }

    function pendingAuthMatchesCurrent() {
        return pendingAuthAccountId === effectiveAccountId()
            && pendingAuthServiceId === effectiveServiceId()
            && pendingAuthServerUrl === normalizeServerUrl(effectiveServerUrl())
    }

    function findSelectedAccountService() {
        var accountId = effectiveAccountId()
        var providerIdSetting = effectiveProviderId()
        var serviceIdSetting = effectiveServiceId()
        for (var i = 0; i < accountServices.count; ++i) {
            if (accountServices.get(i, "accountId") === accountId) {
                var handle = accountServices.get(i, "accountServiceHandle")
                accountService.objectHandle = handle
                var provider = accountService.provider || {}
                var service = accountService.service || {}
                var providerId = provider.id || accountServices.get(i, "providerName")
                var serviceId = service.id || accountServices.get(i, "serviceName")
                if (providerId === providerIdSetting && serviceId === serviceIdSetting) {
                    return handle
                }
            }
        }
        return null
    }

    function retryAuthenticationBeforeFail(message) {
        if (authenticationRetryCount >= maxAuthenticationRetries) {
            return false
        }

        authenticationRetryCount += 1
        authenticationRetryPending = true
        accountModelRefreshPending = true
        cachedAccountId = 0
        cachedServiceId = ""
        cachedServerUrl = ""
        cachedUserName = ""
        cachedSecret = ""
        accountService.objectHandle = null
        accountServices.includeDisabled = false
        accountModelRefreshTimer.restart()
        return true
    }

    function finishAccountModelRefreshBeforeRetry() {
        accountServices.includeDisabled = true
        authenticationRetryTimer.restart()
    }

    function retryAuthenticationAfterStaleFailure() {
        if (!authenticationRetryPending) {
            return
        }
        authenticationRetryPending = false
        accountModelRefreshPending = false
        authenticate()
    }

    function effectiveAccountId() {
        return currentAccountId > 0 ? currentAccountId : accountSettings.accountId
    }

    function effectiveProviderId() {
        return currentProviderId.length > 0 ? currentProviderId : accountSettings.providerId
    }

    function effectiveServiceId() {
        return currentServiceId.length > 0 ? currentServiceId : accountSettings.serviceId
    }

    function effectiveServerUrl() {
        return currentServerUrl.length > 0 ? currentServerUrl : accountSettings.serverUrl
    }

    function normalizeServerUrl(value) {
        if (!value) {
            return ""
        }
        var url = String(value).trim()
        while (url.length > 0 && url.charAt(url.length - 1) === "/") {
            url = url.slice(0, -1)
        }
        if (url.length === 0) {
            return ""
        }
        if (url.indexOf("http://") === 0 || url.indexOf("https://") === 0) {
            return url
        }
        return "https://" + url
    }

    function firstValue(value, names) {
        if (!value) {
            return ""
        }
        for (var i = 0; i < names.length; ++i) {
            if (value[names[i]] !== undefined && value[names[i]] !== null && String(value[names[i]]).length > 0) {
                return String(value[names[i]])
            }
        }
        return ""
    }

    function objectKeys(value) {
        var keys = []
        if (!value) {
            return keys
        }
        for (var key in value) {
            keys.push(key)
        }
        return keys.sort()
    }

    function hasValue(value) {
        return value !== undefined && value !== null && String(value).length > 0 ? "true" : "false"
    }

    function maskedIdentity(value) {
        var text = String(value || "")
        if (text.length === 0) {
            return "<none>"
        }
        if (text.indexOf("@") > 0) {
            var parts = text.split("@")
            return maskPart(parts[0]) + "@" + maskPart(parts.slice(1).join("@"))
        }
        return maskPart(text)
    }

    function maskPart(value) {
        var text = String(value || "")
        if (text.length <= 2) {
            return "**"
        }
        return text.charAt(0) + "***" + text.charAt(text.length - 1) + "(" + text.length + ")"
    }

}
