#pragma once

#include <QTcpServer>
#include <QSslSocket>
#include <QVector>
#include <QSet>
#include <QString>
#include <QByteArray>
#include <QDateTime>
#include <tuple>

class QJsonObject;
class SessionManager;



class Server : public QTcpServer
{
    Q_OBJECT

public:
    Server();

protected:
    void incomingConnection(qintptr socketDescription) override;

private slots:
    void slotReadyRead();

private:
    QVector<QSslSocket*> m_sockets;
    SessionManager* m_sessions = nullptr;

    // Код восстановления действует 10 минут.
    // Храним не сам код, а hash(email + code).
    QVector<std::tuple<QDateTime, QString>> m_valid_hashes;

    void sendBytes(QSslSocket* client, const QByteArray& payload);
    void sendJson(QSslSocket* client, const QJsonObject& obj);

    static QString tlsCertificatePath();
    static QString tlsPrivateKeyPath();
    static bool setupTlsSocket(QSslSocket* socket, QString* errorText);

    static QByteArray resetSecretKey();
    static QByteArray hmacSha256(const QByteArray& data);

    void processCommand(const QJsonObject& json, QSslSocket* client);

    void handleLogin(const QJsonObject& params, QSslSocket* client);
    void handleLogout(const QJsonObject& json, QSslSocket* client);

    void handleGetTable(const QJsonObject& params, int userId, QSslSocket* client);
    void handleAddTableData(const QJsonObject& params, int userId, QSslSocket* client);
    void handleUpdateTableData(const QJsonObject& params, int userId, QSslSocket* client);
    void handleDeleteTableData(const QJsonObject& params, int userId, QSslSocket* client);

    void handleGetPhoto(const QJsonObject& params, int userId, QSslSocket* client);

    void handleGetMyProfile(const QJsonObject& params, int userId, QSslSocket* client);
    void handleGetMySessions(const QJsonObject& json, int userId, QSslSocket* client);

    void handleLogoutSession(const QJsonObject& params, int userId, QSslSocket* client);
    void handleLogoutOtherSessions(const QJsonObject& json, int userId, QSslSocket* client);

    void handleCreateUser(const QJsonObject& params, int userId, QSslSocket* client);

    void handleGetEmailCodeResetPassword(const QJsonObject& params, QSslSocket* client);
    void handleIsValidCode(const QJsonObject& params, QSslSocket* client);

    void cleanupExpiredResetCodes();
    QString makeResetCode() const;
    QString resetCodeHash(const QString& email, const QString& code) const;
    bool isResetCodeValid(const QString& email, const QString& code, bool removeIfValid);

    bool isAllowedReadTableName(const QString& tableName) const;
    bool isAllowedWriteTableName(const QString& tableName) const;

    QSet<QString> allowedColumnsForTable(const QString& tableName) const;

    QJsonObject prepareInsertData(
        const QString& tableName,
        const QJsonObject& data,
        int userId,
        QJsonObject* error
    );

    QJsonObject prepareUpdateData(
        const QString& tableName,
        const QJsonObject& data,
        int userId,
        QJsonObject* error
    );

    void handleChangePassword(const QJsonObject& params, int userId, QSslSocket* client);
    void handleResetPasswordByCode(const QJsonObject& params, QSslSocket* client);
};



