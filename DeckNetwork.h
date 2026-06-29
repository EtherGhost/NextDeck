#ifndef DECKNETWORK_H
#define DECKNETWORK_H

#include <QObject>
#include <QString>
#include <QUrl>

class QNetworkAccessManager;
class QNetworkRequest;

class DeckNetwork : public QObject
{
    Q_OBJECT

public:
    explicit DeckNetwork(QObject *parent = nullptr);

    Q_INVOKABLE void sendRequest(int generation,
                                 const QString &requestId,
                                 const QString &method,
                                 const QString &url,
                                 const QString &userName,
                                 const QString &secret,
                                 const QString &body,
                                 const QString &contentType);
    Q_INVOKABLE void fetchDataUrl(int generation,
                                  const QString &requestId,
                                  const QString &url,
                                  const QString &userName,
                                  const QString &secret);
    Q_INVOKABLE void uploadFileMultipart(int generation,
                                         const QString &requestId,
                                         const QString &url,
                                         const QString &userName,
                                         const QString &secret,
                                         const QUrl &fileUrl,
                                         const QString &fileName,
                                         const QString &mimeType,
                                         const QString &attachmentType,
                                         bool includeEmptyDataPart);
    Q_INVOKABLE void downloadFileToCache(int generation,
                                         const QString &requestId,
                                         const QString &url,
                                         const QString &userName,
                                         const QString &secret,
                                         const QString &preferredFileName);

signals:
    void requestFinished(const QString &requestId, int status, const QString &responseText, int generation);
    void requestFailed(const QString &requestId, const QString &message, int generation);
    void dataUrlFinished(const QString &requestId, const QString &dataUrl, int generation);
    void fileDownloaded(const QString &requestId, const QString &fileUrl, const QString &fileName, const QString &mimeType, int generation);

private:
    QNetworkAccessManager *isolatedManager();
    QNetworkRequest authorizedRequest(const QString &url,
                                      const QString &userName,
                                      const QString &secret,
                                      const QString &contentType) const;
};

#endif
