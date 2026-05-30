#pragma once

#include <QObject>
#include <QSslSocket>
#include <QJsonObject>
#include <QTimer>
#include <QVariantMap>
#include <QString>
#include <QByteArray>

class Db : public QObject
{
    Q_OBJECT

public:
    static Db* get();

    explicit Db(QObject *parent = nullptr, QString ip = "");

    Q_INVOKABLE void connectToServer();
    Q_INVOKABLE void sendCommand(const QString &command, const QJsonObject &params = {});

    Q_INVOKABLE void login(const QString& login, const QString& password);
    Q_INVOKABLE void logout();

    Q_INVOKABLE bool isConnect() const;
    Q_INVOKABLE bool isAuthorized() const;
    Q_INVOKABLE bool hasSavedToken() const;

    Q_INVOKABLE void setToken(const QString& token);
    Q_INVOKABLE QString token() const;
    Q_INVOKABLE void clearToken();

    void saveToken();
    void loadToken();

    Q_INVOKABLE void getMyProfile();
    Q_INVOKABLE void getMySessions();

    Q_INVOKABLE void logoutSession(int sessionId);
    Q_INVOKABLE void logoutOtherSessions();

    Q_INVOKABLE void getTable(const QString& tableName);
    Q_INVOKABLE void addTableData(const QString& tableName, const QVariantMap& data);
    Q_INVOKABLE void updateTableData(const QString& tableName, int id, const QVariantMap& data);
    Q_INVOKABLE void deleteTableData(const QString& tableName, int id);

    Q_INVOKABLE void getAppointments();
    Q_INVOKABLE void getTeachers();
    Q_INVOKABLE void getSchedule();

    Q_INVOKABLE void cancelAppointment(int appointmentId);
    Q_INVOKABLE void rateAppointment(int appointmentId, int rating);

    Q_INVOKABLE void createUser(const QVariantMap& userData,
                                const QVariantMap& studentData = {},
                                const QVariantMap& teacherData = {});

    Q_INVOKABLE void getEmailCodeResetPassword(const QString& email);
    Q_INVOKABLE void isValidResetCode(const QString& email, const QString& code);

    Q_INVOKABLE void isValidCode(const QString& email, const QString& code);
    Q_INVOKABLE void resetPassword(const QString& email, const QString& code, const QString& newPassword);

    Q_INVOKABLE void resetPasswordByCode(const QString& email, const QString& code, const QString& newPassword);
    Q_INVOKABLE void changePassword(const QString& oldPassword, const QString& newPassword);

signals:
    void responseReceived(const QJsonObject &response);
    void authorizedChanged(bool authorized);
    void connectedToServer();
    void disconnectedFromServer();
    void connectionError(const QString &error);

private slots:
    void onReadyRead();
    void tryReconnect();

private:
    QSslSocket* m_socket = nullptr;
    QTimer* m_reconnectTimer = nullptr;

    QString m_ip;
    int m_port = 2323;

    QString m_token;

    bool m_connectionReadyEmitted = false;

    void configureTls();
};



