#include "DeckNetwork.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QNetworkAccessManager>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

namespace {

const int kRequestTimeoutMs = 30000;

// Qt 5.12 has no QNetworkRequest transfer timeout, so a stalled reply (e.g. a
// mobile connection that drops mid-request) never finishes on its own and
// wedges any state machine gated on the request completing. Aborting after a
// timeout makes the reply's finished handler run with an error status, which
// existing failure handling already covers.
void armTimeout(QNetworkReply *reply, int timeoutMs = kRequestTimeoutMs)
{
    QTimer *timer = new QTimer(reply);
    timer->setSingleShot(true);
    QObject::connect(timer, &QTimer::timeout, reply, &QNetworkReply::abort);
    QObject::connect(reply, &QNetworkReply::finished, timer, &QTimer::stop);
    timer->start(timeoutMs);
}

QString safeMultipartFileName(const QString &value)
{
    QString result = value;
    result.replace(QLatin1Char('"'), QLatin1Char('_'));
    result.replace(QLatin1Char('\r'), QLatin1Char('_'));
    result.replace(QLatin1Char('\n'), QLatin1Char('_'));
    if (result.trimmed().isEmpty()) {
        result = QStringLiteral("attachment");
    }
    return result;
}

QString safeCacheFileName(const QString &value)
{
    QString result = value.trimmed();
    result.replace(QRegularExpression(QStringLiteral("[\\\\/\\r\\n]+")), QStringLiteral("-"));
    result.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9._ -]+")), QStringLiteral("-"));
    result = result.left(96).trimmed();
    if (result.isEmpty() || result == QStringLiteral(".") || result == QStringLiteral("..")) {
        result = QStringLiteral("attachment");
    }
    return result;
}

QString contentDispositionFileName(const QByteArray &header)
{
    const QString value = QString::fromUtf8(header);
    const QRegularExpression fileNameStar(QStringLiteral("filename\\*=UTF-8''([^;]+)"), QRegularExpression::CaseInsensitiveOption);
    QRegularExpressionMatch match = fileNameStar.match(value);
    if (match.hasMatch()) {
        return QUrl::fromPercentEncoding(match.captured(1).trimmed().toUtf8());
    }
    const QRegularExpression fileNameQuoted(QStringLiteral("filename=\"([^\"]+)\""), QRegularExpression::CaseInsensitiveOption);
    match = fileNameQuoted.match(value);
    if (match.hasMatch()) {
        return match.captured(1).trimmed();
    }
    const QRegularExpression fileNamePlain(QStringLiteral("filename=([^;]+)"), QRegularExpression::CaseInsensitiveOption);
    match = fileNamePlain.match(value);
    if (match.hasMatch()) {
        return match.captured(1).trimmed();
    }
    return QString();
}
}

DeckNetwork::DeckNetwork(QObject *parent)
    : QObject(parent)
{
}

void DeckNetwork::sendRequest(int generation,
                              const QString &requestId,
                              const QString &method,
                              const QString &url,
                              const QString &userName,
                              const QString &secret,
                              const QString &body,
                              const QString &contentType)
{
    if (url.trimmed().isEmpty() || userName.isEmpty() || secret.isEmpty()) {
        emit requestFailed(requestId, tr("Account credentials are incomplete."), generation);
        return;
    }

    QNetworkAccessManager *requestManager = isolatedManager();
    QNetworkRequest request = authorizedRequest(url, userName, secret, contentType);
    const QByteArray verb = method.trimmed().toUpper().toUtf8();
    QNetworkReply *reply = nullptr;

    if (verb == QByteArrayLiteral("GET")) {
        reply = requestManager->get(request);
    } else if (verb == QByteArrayLiteral("POST")) {
        reply = requestManager->post(request, body.toUtf8());
    } else if (verb == QByteArrayLiteral("PUT")) {
        reply = requestManager->put(request, body.toUtf8());
    } else if (verb == QByteArrayLiteral("DELETE")) {
        reply = requestManager->sendCustomRequest(request, QByteArrayLiteral("DELETE"), body.toUtf8());
    } else {
        reply = requestManager->sendCustomRequest(request, verb, body.toUtf8());
    }
    armTimeout(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestManager, requestId, generation]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray responseBody = reply->readAll();
        reply->deleteLater();
        requestManager->deleteLater();

        if (status > 0) {
            emit requestFinished(requestId, status, QString::fromUtf8(responseBody), generation);
            return;
        }
        emit requestFailed(requestId, tr("Deck request failed because the network request could not be completed."), generation);
    });
}

void DeckNetwork::fetchDataUrl(int generation,
                               const QString &requestId,
                               const QString &url,
                               const QString &userName,
                               const QString &secret)
{
    if (url.trimmed().isEmpty() || userName.isEmpty() || secret.isEmpty()) {
        emit requestFailed(requestId, tr("Account credentials are incomplete."), generation);
        return;
    }

    QNetworkAccessManager *requestManager = isolatedManager();
    QNetworkRequest request = authorizedRequest(url, userName, secret, QString());
    QNetworkReply *reply = requestManager->get(request);
    armTimeout(reply);

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestManager, requestId, generation]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray responseBody = reply->readAll();
        const QByteArray contentType = reply->header(QNetworkRequest::ContentTypeHeader).toByteArray();
        reply->deleteLater();
        requestManager->deleteLater();

        if (status >= 200 && status < 300 && !responseBody.isEmpty()) {
            const QByteArray mimeType = contentType.isEmpty() ? QByteArrayLiteral("image/png") : contentType;
            const QString dataUrl = QStringLiteral("data:%1;base64,%2")
                .arg(QString::fromLatin1(mimeType.split(';').first().trimmed()),
                     QString::fromLatin1(responseBody.toBase64()));
            emit dataUrlFinished(requestId, dataUrl, generation);
            return;
        }
        emit requestFailed(requestId, tr("Deck image request failed because the server returned HTTP %1.").arg(status), generation);
    });
}

void DeckNetwork::uploadFileMultipart(int generation,
                                      const QString &requestId,
                                      const QString &url,
                                      const QString &userName,
                                      const QString &secret,
                                      const QUrl &fileUrl,
                                      const QString &fileName,
                                      const QString &mimeType,
                                      const QString &attachmentType,
                                      bool includeEmptyDataPart)
{
    if (url.trimmed().isEmpty() || userName.isEmpty() || secret.isEmpty()) {
        emit requestFailed(requestId, tr("Account credentials are incomplete."), generation);
        return;
    }
    if (!fileUrl.isLocalFile()) {
        emit requestFailed(requestId, tr("Only local files from Content Hub can be attached."), generation);
        return;
    }

    const QFileInfo fileInfo(fileUrl.toLocalFile());
    if (!fileInfo.exists() || !fileInfo.isFile() || !fileInfo.isReadable()) {
        emit requestFailed(requestId, tr("The selected file could not be read."), generation);
        return;
    }

    QFile *file = new QFile(fileInfo.absoluteFilePath());
    if (!file->open(QIODevice::ReadOnly)) {
        delete file;
        emit requestFailed(requestId, tr("The selected file could not be opened."), generation);
        return;
    }

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    QHttpPart typePart;
    typePart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant(QStringLiteral("form-data; name=\"type\"")));
    const QString typeValue = attachmentType.trimmed().isEmpty() ? QStringLiteral("file") : attachmentType.trimmed();
    typePart.setBody(typeValue.toUtf8());
    multiPart->append(typePart);

    QHttpPart filePart;
    const QString resolvedFileName = safeMultipartFileName(fileName.trimmed().isEmpty() ? fileInfo.fileName() : fileName.trimmed());
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QVariant(QStringLiteral("form-data; name=\"file\"; filename=\"%1\"").arg(resolvedFileName)));
    const QString resolvedMimeType = mimeType.trimmed().isEmpty() ? QStringLiteral("application/octet-stream") : mimeType.trimmed();
    filePart.setHeader(QNetworkRequest::ContentTypeHeader, QVariant(resolvedMimeType));
    filePart.setBodyDevice(file);
    file->setParent(multiPart);
    multiPart->append(filePart);

    if (includeEmptyDataPart) {
        QHttpPart dataPart;
        dataPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant(QStringLiteral("form-data; name=\"data\"")));
        dataPart.setBody(QByteArray());
        multiPart->append(dataPart);
    }

    QNetworkAccessManager *requestManager = isolatedManager();
    QNetworkRequest request = authorizedRequest(url, userName, secret, QString());
    QNetworkReply *reply = requestManager->post(request, multiPart);
    multiPart->setParent(reply);
    // Attachment uploads can be larger and slower than the JSON API calls
    // elsewhere in this file, so they get a longer timeout before being
    // treated as stalled.
    armTimeout(reply, kRequestTimeoutMs * 4);

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestManager, requestId, generation]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray responseBody = reply->readAll();
        reply->deleteLater();
        requestManager->deleteLater();

        if (status > 0) {
            emit requestFinished(requestId, status, QString::fromUtf8(responseBody), generation);
            return;
        }
        emit requestFailed(requestId, tr("Deck attachment upload failed because the network request could not be completed."), generation);
    });
}

void DeckNetwork::downloadFileToCache(int generation,
                                      const QString &requestId,
                                      const QString &url,
                                      const QString &userName,
                                      const QString &secret,
                                      const QString &preferredFileName)
{
    if (url.trimmed().isEmpty() || userName.isEmpty() || secret.isEmpty()) {
        emit requestFailed(requestId, tr("Account credentials are incomplete."), generation);
        return;
    }

    QNetworkAccessManager *requestManager = isolatedManager();
    QNetworkRequest request = authorizedRequest(url, userName, secret, QString());
    QNetworkReply *reply = requestManager->get(request);
    // Attachment downloads can be larger and slower than the JSON API calls
    // elsewhere in this file, so they get a longer timeout before being
    // treated as stalled.
    armTimeout(reply, kRequestTimeoutMs * 4);

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestManager, requestId, generation, preferredFileName]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray responseBody = reply->readAll();
        const QByteArray contentType = reply->header(QNetworkRequest::ContentTypeHeader).toByteArray();
        const QByteArray disposition = reply->rawHeader("Content-Disposition");
        reply->deleteLater();
        requestManager->deleteLater();

        if (status < 200 || status >= 300) {
            emit requestFailed(requestId, tr("Deck attachment download failed with HTTP %1.").arg(status), generation);
            return;
        }
        if (responseBody.isEmpty()) {
            emit requestFailed(requestId, tr("The downloaded attachment is empty."), generation);
            return;
        }

        const QString basePath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
        if (basePath.isEmpty()) {
            emit requestFailed(requestId, tr("Attachment cache is not available."), generation);
            return;
        }
        QDir dir(basePath);
        if (!dir.mkpath(QStringLiteral("AttachmentDownloads")) || !dir.cd(QStringLiteral("AttachmentDownloads"))) {
            emit requestFailed(requestId, tr("Attachment cache could not be prepared."), generation);
            return;
        }

        QString fileName = contentDispositionFileName(disposition);
        if (fileName.trimmed().isEmpty()) {
            fileName = preferredFileName;
        }
        fileName = safeCacheFileName(fileName);

        const QByteArray digest = QCryptographicHash::hash(
                    (fileName + QString::number(QDateTime::currentMSecsSinceEpoch())).toUtf8(),
                    QCryptographicHash::Sha1).toHex().left(10);
        const QString filePath = dir.filePath(QStringLiteral("%1-%2").arg(QString::fromLatin1(digest), fileName));

        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            emit requestFailed(requestId, tr("The downloaded attachment could not be saved."), generation);
            return;
        }
        file.write(responseBody);
        file.close();

        const QString mimeType = QString::fromLatin1(contentType.split(';').first().trimmed());
        emit fileDownloaded(requestId,
                            QUrl::fromLocalFile(filePath).toString(),
                            fileName,
                            mimeType.isEmpty() ? QStringLiteral("application/octet-stream") : mimeType,
                            generation);
    });
}

QNetworkAccessManager *DeckNetwork::isolatedManager()
{
    return new QNetworkAccessManager(this);
}

QNetworkRequest DeckNetwork::authorizedRequest(const QString &url,
                                               const QString &userName,
                                               const QString &secret,
                                               const QString &contentType) const
{
    QUrl requestUrl(url);
    if (!userName.isEmpty()) {
        requestUrl.setUserName(userName);
    }

    QNetworkRequest request(requestUrl);
    request.setRawHeader("Authorization", "Basic " + QByteArray(QString(userName + QStringLiteral(":") + secret).toUtf8()).toBase64());
    request.setRawHeader("OCS-APIRequest", "true");
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Cache-Control", "no-cache");
    request.setRawHeader("Pragma", "no-cache");
    request.setRawHeader("Connection", "close");
    // Without this, a server behind an http->https or path redirect fails
    // every request outright (Qt does not follow redirects by default).
    // Qt strips the Authorization header on cross-origin redirects, so this
    // only helps same-origin redirects - but that covers the common case.
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    if (!contentType.trimmed().isEmpty()) {
        request.setHeader(QNetworkRequest::ContentTypeHeader, contentType.trimmed());
    }
    return request;
}
