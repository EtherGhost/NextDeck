#include "ContentHubBridge.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMimeDatabase>
#include <QRegExp>
#include <QStandardPaths>

ContentHubBridge::ContentHubBridge(QObject *parent)
    : QObject(parent)
{
}

QString ContentHubBridge::readTextFile(const QUrl &url) const
{
    if (!url.isLocalFile()) {
        return QString();
    }

    QFile file(url.toLocalFile());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return QString();
    }

    return QString::fromUtf8(file.readAll());
}

bool ContentHubBridge::isReadableLocalFile(const QUrl &url) const
{
    if (!url.isLocalFile()) {
        return false;
    }

    const QFileInfo info(url.toLocalFile());
    return info.exists() && info.isFile() && info.isReadable();
}

QString ContentHubBridge::fileName(const QUrl &url) const
{
    if (!url.isLocalFile()) {
        return QString();
    }

    const QFileInfo info(url.toLocalFile());
    return info.fileName();
}

qint64 ContentHubBridge::fileSize(const QUrl &url) const
{
    if (!url.isLocalFile()) {
        return -1;
    }

    const QFileInfo info(url.toLocalFile());
    return info.exists() && info.isFile() ? info.size() : -1;
}

QString ContentHubBridge::mimeType(const QUrl &url) const
{
    if (!url.isLocalFile()) {
        return QStringLiteral("application/octet-stream");
    }

    QMimeDatabase database;
    const QMimeType type = database.mimeTypeForFile(url.toLocalFile(), QMimeDatabase::MatchContent);
    return type.isValid() ? type.name() : QStringLiteral("application/octet-stream");
}

QUrl ContentHubBridge::copyImportedFileToCache(const QUrl &url, const QString &preferredFileName) const
{
    if (!url.isLocalFile()) {
        return QUrl();
    }

    QFile source(url.toLocalFile());
    if (!source.open(QIODevice::ReadOnly)) {
        return QUrl();
    }

    const QString basePath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (basePath.isEmpty()) {
        return QUrl();
    }

    QDir dir(basePath);
    if (!dir.mkpath(QStringLiteral("ContentHubIncoming"))) {
        return QUrl();
    }
    if (!dir.cd(QStringLiteral("ContentHubIncoming"))) {
        return QUrl();
    }

    QString safeName = preferredFileName.trimmed();
    if (safeName.isEmpty()) {
        safeName = QFileInfo(url.toLocalFile()).fileName();
    }
    safeName.replace(QRegExp(QStringLiteral("[\\\\/\\r\\n]+")), QStringLiteral("-"));
    if (safeName.trimmed().isEmpty()) {
        safeName = QStringLiteral("attachment");
    }

    const QByteArray digest = QCryptographicHash::hash(
                (safeName + QString::number(QDateTime::currentMSecsSinceEpoch())).toUtf8(),
                QCryptographicHash::Sha1).toHex().left(10);
    const QString filePath = dir.filePath(QStringLiteral("%1-%2").arg(QString::fromLatin1(digest), safeName));

    QFile target(filePath);
    if (!target.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return QUrl();
    }

    target.write(source.readAll());
    target.close();
    source.close();

    return QUrl::fromLocalFile(filePath);
}

QUrl ContentHubBridge::writeSharedTextFile(const QString &title, const QString &content) const
{
    if (content.isEmpty()) {
        return QUrl();
    }

    const QString basePath = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (basePath.isEmpty()) {
        return QUrl();
    }

    QDir dir(basePath);
    if (!dir.mkpath(QStringLiteral("ContentHubOutgoing"))) {
        return QUrl();
    }
    if (!dir.cd(QStringLiteral("ContentHubOutgoing"))) {
        return QUrl();
    }

    QString safeTitle = title.trimmed();
    if (safeTitle.isEmpty()) {
        safeTitle = QStringLiteral("shared-card");
    }
    safeTitle.replace(QRegExp(QStringLiteral("[^A-Za-z0-9._-]+")), QStringLiteral("-"));
    safeTitle = safeTitle.left(48).trimmed();
    if (safeTitle.isEmpty()) {
        safeTitle = QStringLiteral("shared-card");
    }

    const QByteArray digest = QCryptographicHash::hash(
                (content + QString::number(QDateTime::currentMSecsSinceEpoch())).toUtf8(),
                QCryptographicHash::Sha1).toHex().left(10);
    const QString filePath = dir.filePath(QStringLiteral("%1-%2.txt").arg(safeTitle, QString::fromLatin1(digest)));

    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        return QUrl();
    }

    file.write(content.toUtf8());
    file.close();

    return QUrl::fromLocalFile(filePath);
}
