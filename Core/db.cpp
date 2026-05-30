#include "db.h"

#include <QJsonDocument>
#include <QDebug>
#include <QSettings>
#include <QDataStream>
#include <QIODevice>
#include <QSslError>
#include <QSslCipher>
#include <QSslConfiguration>



#include <QSysInfo>
#include <QHostInfo>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif


static QString deviceName();
static QString platformName();





Db* Db::get()
{
    static Db* db = new Db(nullptr, "192.168.0.102");
    return db;
}

Db::Db(QObject* parent, QString ip)
    : QObject(parent)
    , m_socket(new QSslSocket(this))
    , m_reconnectTimer(new QTimer(this))
    , m_ip(ip)
{
    m_reconnectTimer->setInterval(2000);

    configureTls();

    connect(m_reconnectTimer, &QTimer::timeout, this, &Db::tryReconnect);

    connect(m_socket, &QSslSocket::readyRead, this, &Db::onReadyRead);

    connect(m_socket, &QSslSocket::connected, this, [this]() {
        qDebug() << "TCP connected, waiting TLS handshake...";
    });

    connect(m_socket, &QSslSocket::encrypted, this, [this]() {
        qDebug() << "TLS connected!";
        qDebug() << "Cipher:" << m_socket->sessionCipher().name();

        m_connectionReadyEmitted = true;
        m_reconnectTimer->stop();

        emit connectedToServer();
    });

    connect(m_socket, &QSslSocket::disconnected, this, [this]() {
        qDebug() << "Отключено от сервера";

        const bool wasReady = m_connectionReadyEmitted;
        m_connectionReadyEmitted = false;

        if (wasReady)
            emit disconnectedFromServer();
        else
            emit disconnectedFromServer();

        if (!m_reconnectTimer->isActive()) {
            qDebug() << "Запускаем автопереподключение...";
            m_reconnectTimer->start();
        }
    });

    connect(m_socket, &QSslSocket::sslErrors, this, [this](const QList<QSslError>& errors) {
        for (const QSslError& error : errors)
            qWarning() << "TLS warning:" << error.errorString();

        /*
            ВАЖНО:

            Для настоящего продакшена лучше:
            1) купить/выпустить нормальный сертификат,
            или
            2) сделать certificate pinning.
        */
        m_socket->ignoreSslErrors();
    });

    connect(m_socket, &QSslSocket::errorOccurred, this,
            [this](QAbstractSocket::SocketError) {
                const QString error = m_socket ? m_socket->errorString() : "Ошибка сокета";

                qWarning() << "Ошибка сокета:" << error;
                emit connectionError(error);

                if (m_socket &&
                    m_socket->state() != QAbstractSocket::ConnectedState &&
                    m_socket->state() != QAbstractSocket::ConnectingState &&
                    !m_reconnectTimer->isActive()) {
                    qDebug() << "Ошибка соединения, запускаем автопереподключение...";
                    m_reconnectTimer->start();
                }
            });

    loadToken();
}

void Db::configureTls()
{
    if (!m_socket)
        return;

    QSslConfiguration config = m_socket->sslConfiguration();
    config.setProtocol(QSsl::TlsV1_2OrLater);

    /*
        Для локального self-signed сертификата.
        Сервер всё равно шифрует трафик TLS-ом, но клиент не проверяет доверенность сертификата.
        Когда будет домен и нормальный сертификат — можно вернуть VerifyPeer.
    */
    config.setPeerVerifyMode(QSslSocket::VerifyNone);

    m_socket->setSslConfiguration(config);
}

void Db::connectToServer()
{
    if (!m_socket)
        return;

    if (m_ip.trimmed().isEmpty()) {
        emit connectionError("IP сервера не указан.");
        return;
    }

    if (m_socket->state() == QAbstractSocket::ConnectedState && m_socket->isEncrypted())
        return;

    if (m_socket->state() == QAbstractSocket::ConnectingState)
        return;

    m_connectionReadyEmitted = false;

    qDebug() << "Пробуем TLS-подключение к серверу" << m_ip << m_port;

    configureTls();

    m_socket->connectToHostEncrypted(m_ip, m_port);
}

void Db::tryReconnect()
{
    if (isConnect()) {
        m_reconnectTimer->stop();
        return;
    }

    qDebug() << "Переподключение...";
    connectToServer();
}

bool Db::isConnect() const
{
    return m_socket &&
           m_socket->state() == QAbstractSocket::ConnectedState &&
           m_socket->isEncrypted();
}

bool Db::isAuthorized() const
{
    return !m_token.isEmpty();
}

bool Db::hasSavedToken() const
{
    return !m_token.isEmpty();
}

void Db::setToken(const QString& token)
{
    const bool wasAuthorized = isAuthorized();

    m_token = token;
    saveToken();

    if (wasAuthorized != isAuthorized())
        emit authorizedChanged(isAuthorized());
}

QString Db::token() const
{
    return m_token;
}

static QSettings authSettings()
{
    return QSettings("SlotApp", "SlotApp");
}

void Db::saveToken()
{
    QSettings settings = authSettings();
    settings.setValue("auth/token", m_token);
    settings.sync();

    qDebug() << "Token saved. Length:" << m_token.length();
    qDebug() << "Settings file:" << settings.fileName();
}

void Db::loadToken()
{
    QSettings settings = authSettings();
    m_token = settings.value("auth/token").toString();

    qDebug() << "Token loaded. Length:" << m_token.length();
    qDebug() << "Settings file:" << settings.fileName();
}

void Db::clearToken()
{
    const bool wasAuthorized = isAuthorized();

    m_token.clear();

    QSettings settings = authSettings();
    settings.remove("auth/token");
    settings.sync();

    qDebug() << "Token cleared.";
    qDebug() << "Settings file:" << settings.fileName();

    if (wasAuthorized != isAuthorized())
        emit authorizedChanged(isAuthorized());
}

void Db::sendCommand(const QString &command, const QJsonObject &params)
{
    if (!isConnect()) {
        const QString error = "Нет защищённого подключения к серверу.";

        qWarning() << error << "Команда не отправлена:" << command;
        emit connectionError(error);

        if (m_socket &&
            m_socket->state() != QAbstractSocket::ConnectingState &&
            !m_reconnectTimer->isActive()) {
            m_reconnectTimer->start();
        }

        return;
    }

    QJsonObject json;
    json["command"] = command;
    json["parameters"] = params;

    const bool publicCommand =
        command == "login" ||
        command == "get_email_code_reset_password" ||
        command == "IsValidCode" ||
        command == "reset_password" ||
        command == "reset_password_by_code";

    if (!publicCommand && !m_token.isEmpty())
        json["token"] = m_token;

    const QByteArray payload = QJsonDocument(json).toJson(QJsonDocument::Compact);

    QByteArray block;

    QDataStream out(&block, QIODevice::WriteOnly);
    out.setVersion(QDataStream::Qt_6_5);
    out << payload;

    const qint64 written = m_socket->write(block);

    if (written == -1) {
        const QString error = m_socket->errorString();

        qWarning() << "Не удалось отправить команду:" << command << error;
        emit connectionError(error);
        return;
    }

    m_socket->flush();
}

void Db::onReadyRead()
{
    if (!m_socket)
        return;

    if (!m_socket->isEncrypted()) {
        qWarning() << "Получены данные до завершения TLS handshake.";
        return;
    }

    QDataStream in(m_socket);
    in.setVersion(QDataStream::Qt_6_5);

    while (true) {
        in.startTransaction();

        QByteArray payload;
        in >> payload;

        if (!in.commitTransaction())
            break;

        QJsonParseError parseError{};
        const QJsonDocument doc = QJsonDocument::fromJson(payload, &parseError);

        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            qWarning() << "Некорректный JSON от сервера:" << parseError.errorString();
            qWarning() << "Payload:" << payload;
            continue;
        }

        const QJsonObject obj = doc.object();

        if (obj.value("ok").toBool() && obj.contains("token")) {
            setToken(obj.value("token").toString());
        }

        if (obj.value("code").toString() == "unauthorized") {
            clearToken();
        }

        qDebug() << "Ответ:" << obj;
        emit responseReceived(obj);
    }
}

void Db::login(const QString& login, const QString& password)
{
    QJsonObject params;
    params["login"] = login;
    params["password"] = password;
    params["device_name"] = deviceName();
    params["platform"] = platformName();

    sendCommand("login", params);
}

void Db::logout()
{
    if (!m_token.isEmpty() && isConnect())
        sendCommand("logout");

    clearToken();
}

void Db::getMyProfile()
{
    sendCommand("get_my_profile", QJsonObject{});
}

void Db::getMySessions()
{
    sendCommand("get_my_sessions", QJsonObject{});
}

void Db::logoutSession(int sessionId)
{
    QJsonObject params;
    params["session_id"] = sessionId;

    sendCommand("logout_session", params);
}

void Db::logoutOtherSessions()
{
    sendCommand("logout_other_sessions", QJsonObject{});
}

void Db::getTable(const QString& tableName)
{
    QJsonObject params;
    params["table_name"] = tableName;

    sendCommand("get_table", params);
}

void Db::addTableData(const QString& tableName, const QVariantMap& data)
{
    QJsonObject params;
    params["table_name"] = tableName;
    params["data"] = QJsonObject::fromVariantMap(data);

    sendCommand("add_table_data", params);
}

void Db::updateTableData(const QString& tableName, int id, const QVariantMap& data)
{
    QJsonObject params;
    params["table_name"] = tableName;
    params["id"] = id;
    params["data"] = QJsonObject::fromVariantMap(data);

    sendCommand("update_table_data", params);
}

void Db::deleteTableData(const QString& tableName, int id)
{
    QJsonObject params;
    params["table_name"] = tableName;
    params["id"] = id;

    sendCommand("delete_table_data", params);
}

void Db::getAppointments()
{
    getTable("Appointments");
}

void Db::getTeachers()
{
    getTable("Teacher");
}

void Db::getSchedule()
{
    getTable("ScheduleView");
}

void Db::cancelAppointment(int appointmentId)
{
    QVariantMap data;
    data["status"] = 3;

    updateTableData("Appointments", appointmentId, data);
}

void Db::rateAppointment(int appointmentId, int rating)
{
    QVariantMap data;
    data["rating"] = rating;

    updateTableData("Appointments", appointmentId, data);
}

void Db::createUser(const QVariantMap& userData,
                    const QVariantMap& studentData,
                    const QVariantMap& teacherData)
{
    QJsonObject params;

    params["user"] = QJsonObject::fromVariantMap(userData);
    params["student"] = QJsonObject::fromVariantMap(studentData);
    params["teacher"] = QJsonObject::fromVariantMap(teacherData);

    sendCommand("create_user", params);
}

void Db::getEmailCodeResetPassword(const QString& email)
{
    QJsonObject params;
    params["email"] = email;

    sendCommand("get_email_code_reset_password", params);
}

void Db::isValidResetCode(const QString& email, const QString& code)
{
    QJsonObject params;
    params["email"] = email;
    params["code"] = code;

    sendCommand("IsValidCode", params);
}

void Db::isValidCode(const QString& email, const QString& code)
{
    QJsonObject params;
    params["email"] = email;
    params["code"] = code;

    sendCommand("IsValidCode", params);
}

void Db::resetPassword(const QString& email, const QString& code, const QString& newPassword)
{
    QJsonObject params;
    params["email"] = email;
    params["code"] = code;
    params["new_password"] = newPassword;

    sendCommand("reset_password_by_code", params);
}

void Db::resetPasswordByCode(const QString& email, const QString& code, const QString& newPassword)
{
    QJsonObject params;
    params["email"] = email;
    params["code"] = code;
    params["new_password"] = newPassword;

    sendCommand("reset_password_by_code", params);
}

void Db::changePassword(const QString& oldPassword, const QString& newPassword)
{
    QJsonObject params;
    params["old_password"] = oldPassword;
    params["new_password"] = newPassword;

    sendCommand("change_password", params);
}








static QString platformName()
{
#if defined(Q_OS_ANDROID)
    return "Android";
#elif defined(Q_OS_IOS)
    return "iOS";
#elif defined(Q_OS_WIN)
    return "Windows";
#elif defined(Q_OS_MACOS)
    return "macOS";
#elif defined(Q_OS_LINUX)
    return "Linux";
#else
    QString type = QSysInfo::productType();
    return type.isEmpty() ? "Unknown" : type;
#endif
}

static QString deviceName()
{
#ifdef Q_OS_ANDROID
    QString manufacturer;
    QString model;

    QJniObject manufacturerObj =
        QJniObject::getStaticObjectField<jstring>(
            "android/os/Build",
            "MANUFACTURER"
            );

    QJniObject modelObj =
        QJniObject::getStaticObjectField<jstring>(
            "android/os/Build",
            "MODEL"
            );

    manufacturer = manufacturerObj.toString().trimmed();
    model = modelObj.toString().trimmed();

    if (!manufacturer.isEmpty() && !model.isEmpty()) {
        if (model.toLower().startsWith(manufacturer.toLower()))
            return model;

        return manufacturer + " " + model;
    }

    if (!model.isEmpty())
        return model;

    if (!manufacturer.isEmpty())
        return manufacturer;
#endif

    QString host = QHostInfo::localHostName().trimmed();
    QString os = QSysInfo::prettyProductName().trimmed();
    QString arch = QSysInfo::currentCpuArchitecture().trimmed();

    if (!host.isEmpty() && host.toLower() != "localhost") {
        if (!os.isEmpty())
            return host + " · " + os;

        return host;
    }

    if (!os.isEmpty() && !arch.isEmpty())
        return os + " · " + arch;

    if (!os.isEmpty())
        return os;

    return "Unknown device";
}

