#ifndef CONTENTHUBBRIDGE_H
#define CONTENTHUBBRIDGE_H

#include <QObject>
#include <QString>
#include <QUrl>

class ContentHubBridge : public QObject
{
    Q_OBJECT

public:
    explicit ContentHubBridge(QObject *parent = nullptr);

    Q_INVOKABLE QString readTextFile(const QUrl &url) const;
    Q_INVOKABLE bool isReadableLocalFile(const QUrl &url) const;
    Q_INVOKABLE QString fileName(const QUrl &url) const;
    Q_INVOKABLE qint64 fileSize(const QUrl &url) const;
    Q_INVOKABLE QString mimeType(const QUrl &url) const;
    Q_INVOKABLE QUrl copyImportedFileToCache(const QUrl &url, const QString &preferredFileName) const;
    Q_INVOKABLE QUrl writeSharedTextFile(const QString &title, const QString &content) const;
};

#endif
