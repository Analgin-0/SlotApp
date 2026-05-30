#include "Server.h"

#include <QDataStream>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QHostAddress>
#include <QDateTime>
#include <QSet>
#include <QStringList>
#include <QIODevice>
#include <QCryptographicHash>
#include <QMessageAuthenticationCode>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QPointer>
#include <QCoreApplication>
#include <QFile>
#include <QSslSocket>
#include <QSslCertificate>
#include <QSslKey>
#include <QSslConfiguration>
#include <QSslError>
#include <QSslCipher>

#include <map>
#include <functional>

#include "Db.h"
#include "SessionManager.h"
#include "Constants.hpp"
#include "EmailSender.h"

Server::Server()
	: m_sessions(new SessionManager(this))
{
	if (!QSslSocket::supportsSsl()) {
		qCritical() << "[SSL] OpenSSL is not available."
			<< "Build version:" << QSslSocket::sslLibraryBuildVersionString()
			<< "| Runtime version:" << QSslSocket::sslLibraryVersionString();
	}

	qDebug() << "[SSL] Build version:" << QSslSocket::sslLibraryBuildVersionString()
		<< "| Runtime version:" << QSslSocket::sslLibraryVersionString();

	if (listen(QHostAddress::Any, 2323))
		qDebug() << "[Server] TLS server started on port 2323";
	else
		qCritical() << "[Server] Failed to start server:" << errorString();
}

QString Server::tlsCertificatePath()
{
	return QCoreApplication::applicationDirPath() + "/server.crt";
}

QString Server::tlsPrivateKeyPath()
{
	return QCoreApplication::applicationDirPath() + "/server.key";
}

bool Server::setupTlsSocket(QSslSocket* socket, QString* errorText)
{
	if (!socket) {
		if (errorText)
			*errorText = "socket is null";
		return false;
	}

	QFile certFile(tlsCertificatePath());

	if (!certFile.open(QIODevice::ReadOnly)) {
		if (errorText)
			*errorText = "cannot open certificate: " + tlsCertificatePath();
		return false;
	}

	const QSslCertificate certificate(&certFile, QSsl::Pem);
	certFile.close();

	if (certificate.isNull()) {
		if (errorText)
			*errorText = "bad certificate file: " + tlsCertificatePath();
		return false;
	}

	QFile keyFile(tlsPrivateKeyPath());

	if (!keyFile.open(QIODevice::ReadOnly)) {
		if (errorText)
			*errorText = "cannot open private key: " + tlsPrivateKeyPath();
		return false;
	}

	const QSslKey privateKey(&keyFile, QSsl::Rsa, QSsl::Pem);
	keyFile.close();

	if (privateKey.isNull()) {
		if (errorText)
			*errorText = "bad private key file: " + tlsPrivateKeyPath();
		return false;
	}

	QSslConfiguration config = socket->sslConfiguration();
	config.setProtocol(QSsl::TlsV1_2OrLater);
	config.setLocalCertificate(certificate);
	config.setPrivateKey(privateKey);

	socket->setSslConfiguration(config);

	return true;
}

QByteArray Server::resetSecretKey()
{
	return QByteArray::fromHex(QByteArrayLiteral(
		"7d2c9a4f1b8e3560c31a0f9e2d4b6c8890ab12cd34ef56789988776655443322"
	));
}

QByteArray Server::hmacSha256(const QByteArray& data)
{
	return QMessageAuthenticationCode::hash(
		data,
		resetSecretKey(),
		QCryptographicHash::Sha256
	);
}

void Server::incomingConnection(qintptr socketDescription)
{
	auto* s = new QSslSocket(this);

	if (!s->setSocketDescriptor(socketDescription)) {
		qWarning() << "[Server] Failed to set socket descriptor:" << s->errorString();
		delete s;
		return;
	}

	QString tlsError;

	if (!setupTlsSocket(s, &tlsError)) {
		qWarning() << "[TLS] Failed to configure TLS for socket" << socketDescription << ":" << tlsError;
		s->disconnectFromHost();
		s->deleteLater();
		return;
	}

	connect(s, &QSslSocket::encrypted, this, [s]() {
		qDebug() << "[TLS] Connection encrypted."
			<< "IP:" << s->peerAddress().toString()
			<< "| Port:" << s->peerPort()
			<< "| Cipher:" << s->sessionCipher().name()
			<< "| Protocol:" << s->sessionCipher().protocolString();
		});

	connect(s, &QSslSocket::sslErrors, this, [s](const QList<QSslError>& errors) {
		qWarning() << "[TLS] SSL errors for" << s->peerAddress().toString() << ":";
		for (const QSslError& error : errors)
			qWarning() << "  -" << error.errorString();

		s->disconnectFromHost();
		});

	connect(s, &QSslSocket::errorOccurred, this, [s](QAbstractSocket::SocketError socketError) {
		qWarning() << "[Socket] Socket error from" << s->peerAddress().toString()
			<< "| Code:" << socketError
			<< "| Description:" << s->errorString();
		});

	connect(s, &QSslSocket::readyRead, this, &Server::slotReadyRead);

	connect(s, &QSslSocket::disconnected, this, [this, s]() {
		qDebug() << "[Server] Client disconnected. IP:" << s->peerAddress().toString()
			<< "| Port:" << s->peerPort()
			<< "| Active connections:" << m_sockets.size() - 1;

		m_sockets.removeAll(s);
		s->disconnect();
		s->deleteLater();
		});

	m_sockets.push_back(s);

	qDebug() << "[Server] Incoming TCP connection. Descriptor:" << socketDescription
		<< "| IP:" << s->peerAddress().toString()
		<< "| Port:" << s->peerPort()
		<< "| Total connections:" << m_sockets.size()
		<< "| Starting TLS handshake...";

	s->startServerEncryption();
}

void Server::slotReadyRead()
{
	auto* client = qobject_cast<QSslSocket*>(sender());

	if (!client)
		return;

	if (!client->isEncrypted()) {
		qWarning() << "[Server] Data received before TLS handshake was completed from"
			<< client->peerAddress().toString()
			<< ". Closing connection.";

		client->disconnectFromHost();
		return;
	}

	QDataStream in(client);
	in.setVersion(QDataStream::Qt_6_5);

	while (true) {
		in.startTransaction();

		QByteArray payload;
		in >> payload;

		if (!in.commitTransaction())
			break;

		QJsonParseError pe{};
		const QJsonDocument doc = QJsonDocument::fromJson(payload, &pe);

		if (doc.isNull() || !doc.isObject()) {
			qWarning() << "[Server] Invalid JSON from" << client->peerAddress().toString()
				<< "| Error:" << pe.errorString()
				<< "| Offset:" << pe.offset;

			QJsonObject err;
			err["ok"] = false;
			err["code"] = "bad_json";
			err["error"] = pe.errorString();

			sendJson(client, err);
			continue;
		}

		processCommand(doc.object(), client);
	}
}

void Server::sendBytes(QSslSocket* client, const QByteArray& payload)
{
	if (!client)
		return;

	if (!client->isEncrypted()) {
		qWarning() << "[Server] Attempted to send data before TLS handshake was completed.";
		return;
	}

	QByteArray block;

	QDataStream out(&block, QIODevice::WriteOnly);
	out.setVersion(QDataStream::Qt_6_5);
	out << payload;

	client->write(block);
	client->flush();
}

void Server::sendJson(QSslSocket* client, const QJsonObject& obj)
{
	const QByteArray payload = QJsonDocument(obj).toJson(QJsonDocument::Compact);
	sendBytes(client, payload);
}

void Server::processCommand(const QJsonObject& json, QSslSocket* client)
{

	const QString command = json.value("command").toString();
	const QJsonObject params = json.value("parameters").toObject();

	std::map<
		QString,
		std::function<void()>> publicCommandHandlers =
	{
		{"get_email_code_reset_password",[&]() {handleGetEmailCodeResetPassword(params, client); }},
		{"IsValidCode" ,				 [&]() {handleIsValidCode(params, client); }},
		{"login",						 [&]() {handleLogin(params, client); }},
		{"reset_password_by_code",		 [&]() {handleResetPasswordByCode(params, client); }},
	};




	qDebug() << "[CMD] Command:" << command
		<< "| From:" << client->peerAddress().toString()
		<< "| Port:" << client->peerPort();

	if (publicCommandHandlers.contains(command)) {
		publicCommandHandlers[command]();
		return;
	}

	const QString token = json.value("token").toString();
	int userId = -1;

	if (!m_sessions->validateToken(token, &userId)) {
		qWarning() << "[Auth] Invalid or expired token for command:" << command
			<< "| IP:" << client->peerAddress().toString();

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "unauthorized";
		err["error"] = "invalid or expired token";

		sendJson(client, err);
		return;
	}

	qDebug() << "[CMD] Authorized. userId:" << userId << "| Command:" << command;

	std::map<QString, std::function<void()>> privateCommand = {
		{"logout",                [&]() { handleLogout(json, client); }},
		{"get_table",             [&]() { handleGetTable(params, userId, client); }},
		{"add_table_data",        [&]() { handleAddTableData(params, userId, client); }},
		{"update_table_data",     [&]() { handleUpdateTableData(params, userId, client); }},
		{"delete_table_data",     [&]() { handleDeleteTableData(params, userId, client); }},
		{"get_my_profile",        [&]() { handleGetMyProfile(params, userId, client); }},
		{"get_my_sessions",       [&]() { handleGetMySessions(json, userId, client); }},
		{"send_jerboa",           [&]() { handleGetPhoto(params, userId, client); }},
		{"logout_session",        [&]() { handleLogoutSession(params, userId, client); }},
		{"logout_other_sessions", [&]() { handleLogoutOtherSessions(json, userId, client); }},
		{"create_user",           [&]() { handleCreateUser(params, userId, client); }},
		{"change_password",       [&]() { handleChangePassword(params, userId, client); }}
	};

	

	if (privateCommand.contains(command))
	{
		privateCommand[command]();
		return;
	}

	qWarning() << "[CMD] Unknown command:" << command
		<< "| userId:" << userId
		<< "| IP:" << client->peerAddress().toString();

	QJsonObject err;
	err["ok"] = false;
	err["code"] = "unknown_command";
	err["error"] = "Unknown command";

	sendJson(client, err);

}

void Server::handleLogin(const QJsonObject& params, QSslSocket* client)
{
	const QString login = params.value("login").toString().trimmed();
	const QString password = params.value("password").toString();

	qDebug() << "[Login] Login attempt. Login:" << login
		<< "| IP:" << client->peerAddress().toString();

	if (login.isEmpty() || password.isEmpty()) {
		qWarning() << "[Login] Login or password is missing. IP:" << client->peerAddress().toString();

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "bad_request";
		err["error"] = "login/password required";

		sendJson(client, err);
		return;
	}

	int userId = -1;

	if (!Db::get()->checkUserCredentials(login, password, &userId)) {
		qWarning() << "[Login] Invalid login or password. Login:" << login
			<< "| IP:" << client->peerAddress().toString();

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "auth_failed";
		err["error"] = "invalid login or password";

		sendJson(client, err);
		return;
	}

	const QString token = m_sessions->createSession(userId, 24 * 60 * 60);

	const QString deviceName = params.value("device_name").toString();
	const QString platform = params.value("platform").toString();
	const QString ipAddress = client ? client->peerAddress().toString() : "";

	Db::get()->createUserSession(
		userId,
		token,
		deviceName,
		platform,
		ipAddress,
		24 * 60 * 60
	);

	qDebug() << "[Login] Login successful. userId:" << userId
		<< "| Login:" << login
		<< "| Device:" << deviceName
		<< "| Platform:" << platform
		<< "| IP:" << ipAddress;

	QJsonObject resp;
	resp["ok"] = true;
	resp["token"] = token;
	resp["user_id"] = userId;
	resp["expires_in"] = 24 * 60 * 60;

	sendJson(client, resp);
}

void Server::handleLogout(const QJsonObject& json, QSslSocket* client)
{
	const QString token = json.value("token").toString();

	if (!token.isEmpty()) {
		m_sessions->removeSession(token);
		Db::get()->revokeUserSessionByToken(token);

		qDebug() << "[Logout] Session closed. IP:" << client->peerAddress().toString();
	}
	else {
		qWarning() << "[Logout] Token was not provided. IP:" << client->peerAddress().toString();
	}

	QJsonObject resp;
	resp["ok"] = true;
	resp["msg"] = "logged out";

	sendJson(client, resp);
}

bool Server::isAllowedReadTableName(const QString& tableName) const
{
	static const QSet<QString> kAllowedTables = {
		"Appointments",
		"Teacher",
		"Student",
		"User",
		"Schedule",
		"Subject",
		"Subjects",
		"ScheduleView",
		"LessonTime"
	};

	return kAllowedTables.contains(tableName);
}

bool Server::isAllowedWriteTableName(const QString& tableName) const
{
	static const QSet<QString> kAllowedTables = {
		"Appointments",
		"UserSession",
		"Schedule"
	};

	return kAllowedTables.contains(tableName);
}

QSet<QString> Server::allowedColumnsForTable(const QString& tableName) const
{
	if (tableName == "Appointments") {
		return {
			"user_id",
			"teacher_id",
			"teacher_name",
			"student_name",
			"title",
			"description",
			"appointment_date",
			"appointment_time",
			"duration_minutes",
			"cabinet",
			"status",
			"cancelled_by_role",
			"cancelled_by_text",
			"cancelled_at",
			"rating",
			"created_at",
			"updated_at"
		};
	}

	if (tableName == "Schedule") {
		return {
			"group_name",
			"subject_id",
			"teacher_id",
			"day_of_week",
			"week_type",
			"lesson_number",
			"cabinet",
			"subgroup",
			"note",
			"is_active",
			"created_at",
			"updated_at"
		};
	}

	return {};
}

QJsonObject Server::prepareInsertData(
	const QString& tableName,
	const QJsonObject& data,
	int userId,
	QJsonObject* error
)
{
	QJsonObject result;

	if (!error)
		return result;

	if (tableName == "Appointments") {
		const int role = Db::get()->getUserRole(userId);

		if (role != 1) {
			qWarning() << "[AddTableData] Appointment creation denied. userId:" << userId
				<< "| role:" << role
				<< "| required role: student (1)";

			(*error)["ok"] = false;
			(*error)["code"] = "forbidden";
			(*error)["error"] = "only student can create appointment";
			return {};
		}

		const int teacherId = data.value("teacher_id").toInt();

		if (teacherId <= 0) {
			(*error)["ok"] = false;
			(*error)["code"] = "bad_request";
			(*error)["error"] = "teacher_id is required";
			return {};
		}

		const QString title = data.value("title").toString().trimmed();

		if (title.isEmpty()) {
			(*error)["ok"] = false;
			(*error)["code"] = "bad_request";
			(*error)["error"] = "title is required";
			return {};
		}

		const QString appointmentDate = data.value("appointment_date").toString().trimmed();

		if (appointmentDate.isEmpty()) {
			(*error)["ok"] = false;
			(*error)["code"] = "bad_request";
			(*error)["error"] = "appointment_date is required";
			return {};
		}

		const QString appointmentTime = data.value("appointment_time").toString().trimmed();

		if (appointmentTime.isEmpty()) {
			(*error)["ok"] = false;
			(*error)["code"] = "bad_request";
			(*error)["error"] = "appointment_time is required";
			return {};
		}

		const QJsonObject teacher = Db::get()->getTeacherShortInfo(teacherId);

		if (teacher.isEmpty()) {
			qWarning() << "[AddTableData] Teacher not found. teacherId:" << teacherId;

			(*error)["ok"] = false;
			(*error)["code"] = "not_found";
			(*error)["error"] = "teacher not found";
			return {};
		}

		const QString studentName = Db::get()->getUserFullName(userId);

		if (studentName.trimmed().isEmpty()) {
			qWarning() << "[AddTableData] Student not found. userId:" << userId;

			(*error)["ok"] = false;
			(*error)["code"] = "not_found";
			(*error)["error"] = "student not found";
			return {};
		}

		int duration = data.value("duration_minutes").toInt();

		if (duration <= 0)
			duration = 30;

		QString cabinet = data.value("cabinet").toString().trimmed();

		if (cabinet.isEmpty())
			cabinet = teacher.value("cabinet").toString();

		result["user_id"] = userId;
		result["teacher_id"] = teacherId;
		result["teacher_name"] = teacher.value("fullName").toString();
		result["student_name"] = studentName;
		result["title"] = title;
		result["description"] = data.value("description").toString();
		result["appointment_date"] = appointmentDate;
		result["appointment_time"] = appointmentTime;
		result["duration_minutes"] = duration;
		result["cabinet"] = cabinet;
		result["status"] = 1;
		result["rating"] = 0;
		result["created_at"] = QDateTime::currentDateTime().toString(Qt::ISODate);

		qDebug() << "[AddTableData] Appointment prepared. userId:" << userId
			<< "| teacherId:" << teacherId
			<< "| Student:" << studentName
			<< "| Date:" << appointmentDate
			<< "| Time:" << appointmentTime
			<< "| Duration:" << duration << "min.";

		return result;
	}

	if (tableName == "Schedule") {
		const int role = Db::get()->getUserRole(userId);

		if (role != 3) {
			qWarning() << "[AddTableData] Schedule creation denied. userId:" << userId
				<< "| role:" << role
				<< "| required role: admin (3)";

			(*error)["ok"] = false;
			(*error)["code"] = "forbidden";
			(*error)["error"] = "only admin can create schedule row";
			return {};
		}

		const QString groupName = data.value("group_name").toString().trimmed();
		const int subjectId = data.value("subject_id").toInt();
		const int dayOfWeek = data.value("day_of_week").toInt();
		const int weekType = data.value("week_type").toInt();
		const int lessonNumber = data.value("lesson_number").toInt();

		if (groupName.isEmpty()) {
			(*error)["ok"] = false;
			(*error)["code"] = "bad_request";
			(*error)["error"] = "group_name is required";
			return {};
		}

		if (subjectId <= 0) {
			(*error)["ok"] = false;
			(*error)["code"] = "bad_request";
			(*error)["error"] = "subject_id is required";
			return {};
		}

		if (dayOfWeek < 1 || dayOfWeek > 7) {
			(*error)["ok"] = false;
			(*error)["code"] = "bad_request";
			(*error)["error"] = "day_of_week must be between 1 and 7";
			return {};
		}

		if (weekType < 0 || weekType > 2) {
			(*error)["ok"] = false;
			(*error)["code"] = "bad_request";
			(*error)["error"] = "week_type must be 0, 1 or 2";
			return {};
		}

		if (lessonNumber < 1 || lessonNumber > 10) {
			(*error)["ok"] = false;
			(*error)["code"] = "bad_request";
			(*error)["error"] = "lesson_number must be between 1 and 10";
			return {};
		}

		result["group_name"] = groupName;
		result["subject_id"] = subjectId;

		if (data.contains("teacher_id") && data.value("teacher_id").toInt() > 0)
			result["teacher_id"] = data.value("teacher_id").toInt();

		result["day_of_week"] = dayOfWeek;
		result["week_type"] = weekType;
		result["lesson_number"] = lessonNumber;
		result["cabinet"] = data.value("cabinet").toString().trimmed();
		result["subgroup"] = data.value("subgroup").toString().trimmed();
		result["note"] = data.value("note").toString().trimmed();
		result["is_active"] = data.contains("is_active") ? data.value("is_active").toInt(1) : 1;
		result["created_at"] = QDateTime::currentDateTime().toString(Qt::ISODate);

		qDebug() << "[AddTableData] Schedule row prepared. userId:" << userId
			<< "| group:" << groupName
			<< "| subjectId:" << subjectId
			<< "| day:" << dayOfWeek
			<< "| weekType:" << weekType
			<< "| lesson:" << lessonNumber;

		return result;
	}

	result = data;
	return result;
}

QJsonObject Server::prepareUpdateData(
	const QString& tableName,
	const QJsonObject& data,
	int userId,
	QJsonObject* error
)
{
	QJsonObject result;

	if (!error)
		return result;

	if (tableName == "Appointments") {
		const int role = Db::get()->getUserRole(userId);

		const QSet<QString> allowedClientColumns = {
			"title",
			"description",
			"appointment_date",
			"appointment_time",
			"duration_minutes",
			"cabinet",
			"status",
			"rating"
		};

		for (auto it = data.begin(); it != data.end(); ++it) {
			if (allowedClientColumns.contains(it.key()))
				result[it.key()] = it.value();
		}

		if (result.contains("rating")) {
			const int rating = result.value("rating").toInt();

			if (rating < 0 || rating > 5) {
				qWarning() << "[UpdateTableData] Invalid rating:" << rating
					<< "| userId:" << userId;

				(*error)["ok"] = false;
				(*error)["code"] = "bad_request";
				(*error)["error"] = "rating must be between 0 and 5";
				return {};
			}
		}

		if (result.contains("duration_minutes")) {
			const int duration = result.value("duration_minutes").toInt();

			if (duration <= 0) {
				qWarning() << "[UpdateTableData] Invalid duration:" << duration
					<< "| userId:" << userId;

				(*error)["ok"] = false;
				(*error)["code"] = "bad_request";
				(*error)["error"] = "duration_minutes must be positive";
				return {};
			}
		}

		if (result.contains("status")) {
			const int status = result.value("status").toInt();

			if (status < 1 || status > 3) {
				qWarning() << "[UpdateTableData] Invalid status:" << status
					<< "| userId:" << userId;

				(*error)["ok"] = false;
				(*error)["code"] = "bad_request";
				(*error)["error"] = "status must be 1, 2 or 3";
				return {};
			}

			if (status == 3) {
				QString cancelledBy = "пользователь";

				if (role == 1)
					cancelledBy = "студент";
				else if (role == 2)
					cancelledBy = "преподаватель";
				else if (role == 3)
					cancelledBy = "админ";

				result["cancelled_by_role"] = role;
				result["cancelled_by_text"] = cancelledBy;
				result["cancelled_at"] = QDateTime::currentDateTime().toString(Qt::ISODate);

				qDebug() << "[UpdateTableData] Appointment cancelled. userId:" << userId
					<< "| Cancelled by:" << cancelledBy;
			}
		}

		result["updated_at"] = QDateTime::currentDateTime().toString(Qt::ISODate);

		return result;
	}

	if (tableName == "Schedule") {
		const int role = Db::get()->getUserRole(userId);

		if (role != 3) {
			qWarning() << "[UpdateTableData] Schedule update denied. userId:" << userId
				<< "| role:" << role
				<< "| required role: admin (3)";

			(*error)["ok"] = false;
			(*error)["code"] = "forbidden";
			(*error)["error"] = "only admin can update schedule row";
			return {};
		}

		const QSet<QString> allowedClientColumns = {
			"group_name",
			"subject_id",
			"teacher_id",
			"day_of_week",
			"week_type",
			"lesson_number",
			"cabinet",
			"subgroup",
			"note",
			"is_active"
		};

		for (auto it = data.begin(); it != data.end(); ++it) {
			if (allowedClientColumns.contains(it.key()))
				result[it.key()] = it.value();
		}

		if (result.contains("day_of_week")) {
			const int day = result.value("day_of_week").toInt();

			if (day < 1 || day > 7) {
				(*error)["ok"] = false;
				(*error)["code"] = "bad_request";
				(*error)["error"] = "day_of_week must be between 1 and 7";
				return {};
			}
		}

		if (result.contains("week_type")) {
			const int weekType = result.value("week_type").toInt();

			if (weekType < 0 || weekType > 2) {
				(*error)["ok"] = false;
				(*error)["code"] = "bad_request";
				(*error)["error"] = "week_type must be 0, 1 or 2";
				return {};
			}
		}

		if (result.contains("lesson_number")) {
			const int lesson = result.value("lesson_number").toInt();

			if (lesson < 1 || lesson > 10) {
				(*error)["ok"] = false;
				(*error)["code"] = "bad_request";
				(*error)["error"] = "lesson_number must be between 1 and 10";
				return {};
			}
		}

		result["updated_at"] = QDateTime::currentDateTime().toString(Qt::ISODate);

		return result;
	}

	result = data;
	return result;
}

void Server::handleGetTable(const QJsonObject& params, int userId, QSslSocket* client)
{
	const QString tableName = params.value("table_name").toString().trimmed();

	qDebug() << "[GetTable] userId:" << userId << "| Table:" << tableName;

	if (tableName.isEmpty()) {
		qWarning() << "[GetTable] Table name is missing. userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "bad_request";
		err["error"] = "table_name is required";

		sendJson(client, err);
		return;
	}

	if (!isAllowedReadTableName(tableName)) {
		qWarning() << "[GetTable] Table is not allowed for reading:" << tableName
			<< "| userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "forbidden";
		err["error"] = "table is not allowed";

		sendJson(client, err);
		return;
	}

	if (!Db::get()->isValidTable(tableName)) {
		qWarning() << "[GetTable] Table does not exist in database:" << tableName
			<< "| userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "not_found";
		err["error"] = "table does not exist";

		sendJson(client, err);
		return;
	}

	QJsonObject response = Db::get()->getTableForClient(tableName, userId);
	response["ok"] = true;
	response["command"] = "get_table";
	response["table_name"] = tableName;

	qDebug() << "[GetTable] Success. userId:" << userId << "| Table:" << tableName;

	sendJson(client, response);
}

void Server::handleAddTableData(const QJsonObject& params, int userId, QSslSocket* client)
{
	const QString tableName = params.value("table_name").toString().trimmed();
	const QJsonObject data = params.value("data").toObject();

	qDebug() << "[AddTableData] userId:" << userId << "| Table:" << tableName;

	if (tableName.isEmpty() || data.isEmpty()) {
		qWarning() << "[AddTableData] table_name or data was not provided. userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "bad_request";
		err["error"] = "table_name and data are required";

		sendJson(client, err);
		return;
	}

	if (!isAllowedWriteTableName(tableName)) {
		qWarning() << "[AddTableData] Writing to table is forbidden:" << tableName
			<< "| userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "forbidden";
		err["error"] = "write to this table is not allowed";

		sendJson(client, err);
		return;
	}

	QJsonObject prepareError;
	const QJsonObject preparedData = prepareInsertData(tableName, data, userId, &prepareError);

	if (!prepareError.isEmpty()) {
		sendJson(client, prepareError);
		return;
	}

	const QSet<QString> allowedColumns = allowedColumnsForTable(tableName);

	QJsonObject filteredData;

	for (auto it = preparedData.begin(); it != preparedData.end(); ++it) {
		if (allowedColumns.contains(it.key()))
			filteredData[it.key()] = it.value();
	}

	if (filteredData.isEmpty()) {
		qWarning() << "[AddTableData] No allowed columns after filtering. userId:" << userId
			<< "| Table:" << tableName;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "bad_request";
		err["error"] = "no allowed columns";

		sendJson(client, err);
		return;
	}

	const QJsonObject result = Db::get()->addTableData(tableName, filteredData);

	qDebug() << "[AddTableData] Result. userId:" << userId
		<< "| Table:" << tableName
		<< "| ok:" << result.value("ok").toBool();

	QJsonObject resp = result;
	resp["command"] = "add_table_data";
	resp["table_name"] = tableName;

	sendJson(client, resp);
}

void Server::handleUpdateTableData(const QJsonObject& params, int userId, QSslSocket* client)
{
	const QString tableName = params.value("table_name").toString().trimmed();
	const int id = params.value("id").toInt();
	const QJsonObject data = params.value("data").toObject();

	qDebug() << "[UpdateTableData] userId:" << userId
		<< "| Table:" << tableName
		<< "| id:" << id;

	if (tableName.isEmpty() || id <= 0 || data.isEmpty()) {
		qWarning() << "[UpdateTableData] Required parameters are missing. userId:" << userId
			<< "| Table:" << tableName
			<< "| id:" << id;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "bad_request";
		err["error"] = "table_name, id and data are required";

		sendJson(client, err);
		return;
	}

	if (!isAllowedWriteTableName(tableName)) {
		qWarning() << "[UpdateTableData] Writing to table is forbidden:" << tableName
			<< "| userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "forbidden";
		err["error"] = "write to this table is not allowed";

		sendJson(client, err);
		return;
	}

	if (!Db::get()->canUserAccessRow(tableName, id, userId)) {
		qWarning() << "[UpdateTableData] Row access denied. userId:" << userId
			<< "| Table:" << tableName
			<< "| id:" << id;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "forbidden";
		err["error"] = "row access denied";

		sendJson(client, err);
		return;
	}

	QJsonObject prepareError;
	const QJsonObject preparedData = prepareUpdateData(tableName, data, userId, &prepareError);

	if (!prepareError.isEmpty()) {
		sendJson(client, prepareError);
		return;
	}

	const QSet<QString> allowedColumns = allowedColumnsForTable(tableName);

	QJsonObject filteredData;

	for (auto it = preparedData.begin(); it != preparedData.end(); ++it) {
		if (it.key() == "id")
			continue;

		if (allowedColumns.contains(it.key()))
			filteredData[it.key()] = it.value();
	}

	if (filteredData.isEmpty()) {
		qWarning() << "[UpdateTableData] No allowed columns after filtering. userId:" << userId
			<< "| Table:" << tableName
			<< "| id:" << id;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "bad_request";
		err["error"] = "no allowed columns";

		sendJson(client, err);
		return;
	}

	const QJsonObject result = Db::get()->updateTableData(tableName, id, filteredData);

	qDebug() << "[UpdateTableData] Result. userId:" << userId
		<< "| Table:" << tableName
		<< "| id:" << id
		<< "| ok:" << result.value("ok").toBool();

	QJsonObject resp = result;
	resp["command"] = "update_table_data";
	resp["table_name"] = tableName;
	resp["id"] = id;

	sendJson(client, resp);
}

void Server::handleDeleteTableData(const QJsonObject& params, int userId, QSslSocket* client)
{
	const QString tableName = params.value("table_name").toString().trimmed();
	const int id = params.value("id").toInt();

	qDebug() << "[DeleteTableData] Delete request. userId:" << userId
		<< "| Table:" << tableName
		<< "| id:" << id;

	if (tableName.isEmpty() || id <= 0) {
		qWarning() << "[DeleteTableData] table_name or id was not provided. userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["command"] = "delete_table_data";
		err["table_name"] = tableName;
		err["id"] = id;
		err["code"] = "bad_request";
		err["error"] = "table_name and id are required";

		sendJson(client, err);
		return;
	}

	if (!isAllowedWriteTableName(tableName)) {
		qWarning() << "[DeleteTableData] Delete from table is forbidden:" << tableName
			<< "| userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["command"] = "delete_table_data";
		err["table_name"] = tableName;
		err["id"] = id;
		err["code"] = "forbidden";
		err["error"] = "delete from this table is not allowed";

		sendJson(client, err);
		return;
	}

	if (tableName == "Schedule" && Db::get()->getUserRole(userId) != 3) {
		qWarning() << "[DeleteTableData] Schedule delete denied. userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["command"] = "delete_table_data";
		err["table_name"] = tableName;
		err["id"] = id;
		err["code"] = "forbidden";
		err["error"] = "only admin can delete schedule row";

		sendJson(client, err);
		return;
	}

	if (!Db::get()->canUserAccessRow(tableName, id, userId)) {
		qWarning() << "[DeleteTableData] Row access denied. userId:" << userId
			<< "| Table:" << tableName
			<< "| id:" << id;

		QJsonObject err;
		err["ok"] = false;
		err["command"] = "delete_table_data";
		err["table_name"] = tableName;
		err["id"] = id;
		err["code"] = "forbidden";
		err["error"] = "row access denied";

		sendJson(client, err);
		return;
	}

	const QJsonObject result = Db::get()->deleteTableData(tableName, id);

	qDebug() << "[DeleteTableData] Result. userId:" << userId
		<< "| Table:" << tableName
		<< "| id:" << id
		<< "| ok:" << result.value("ok").toBool();

	QJsonObject resp = result;
	resp["command"] = "delete_table_data";
	resp["table_name"] = tableName;
	resp["id"] = id;

	sendJson(client, resp);
}

void Server::handleGetMyProfile(const QJsonObject& params, int userId, QSslSocket* client)
{
	Q_UNUSED(params);

	qDebug() << "[GetMyProfile] userId:" << userId;

	QJsonObject profile = Db::get()->getMyProfile(userId);

	if (profile.isEmpty()) {
		qWarning() << "[GetMyProfile] Profile not found. userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "not_found";
		err["error"] = "profile not found";

		sendJson(client, err);
		return;
	}

	profile["ok"] = true;
	profile["command"] = "get_my_profile";

	qDebug() << "[GetMyProfile] Profile sent. userId:" << userId;

	sendJson(client, profile);
}

void Server::handleGetMySessions(const QJsonObject& json, int userId, QSslSocket* client)
{
	const QString currentToken = json.value("token").toString();

	qDebug() << "[GetMySessions] userId:" << userId;

	QJsonObject resp;
	resp["ok"] = true;
	resp["command"] = "get_my_sessions";
	resp["sessions"] = Db::get()->getUserSessions(userId, currentToken);

	sendJson(client, resp);
}

void Server::handleGetPhoto(const QJsonObject& params, int userId, QSslSocket* client)
{
	Q_UNUSED(params);
	Q_UNUSED(userId);

	qDebug() << "[SendJerboa] Function is not implemented. userId:" << userId;

	QJsonObject resp;
	resp["ok"] = true;
	resp["msg"] = "jerboa requested (not implemented)";

	sendJson(client, resp);
}

void Server::handleLogoutSession(const QJsonObject& params, int userId, QSslSocket* client)
{
	const int sessionId = params.value("session_id").toInt();

	qDebug() << "[LogoutSession] userId:" << userId << "| sessionId:" << sessionId;

	if (sessionId <= 0) {
		qWarning() << "[LogoutSession] Invalid session_id:" << sessionId
			<< "| userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "bad_request";
		err["error"] = "invalid session_id";

		sendJson(client, err);
		return;
	}

	const QString token = Db::get()->getUserSessionTokenById(userId, sessionId);

	if (token.isEmpty()) {
		qWarning() << "[LogoutSession] Session not found. userId:" << userId
			<< "| sessionId:" << sessionId;

		QJsonObject err;
		err["ok"] = false;
		err["code"] = "not_found";
		err["error"] = "session not found";

		sendJson(client, err);
		return;
	}

	if (!Db::get()->revokeUserSessionById(userId, sessionId)) {
		qWarning() << "[LogoutSession] Failed to revoke session. userId:" << userId
			<< "| sessionId:" << sessionId;

		QJsonObject err;
		err["ok"] = false;
		err["error"] = "failed to revoke session";

		sendJson(client, err);
		return;
	}

	m_sessions->removeSession(token);

	qDebug() << "[LogoutSession] Session revoked successfully. userId:" << userId
		<< "| sessionId:" << sessionId;

	QJsonObject resp;
	resp["ok"] = true;
	resp["command"] = "logout_session";

	sendJson(client, resp);
}

void Server::handleLogoutOtherSessions(const QJsonObject& json, int userId, QSslSocket* client)
{
	const QString currentToken = json.value("token").toString();

	qDebug() << "[LogoutOtherSessions] userId:" << userId;

	const QStringList tokens = Db::get()->getOtherUserSessionTokens(userId, currentToken);

	if (!Db::get()->revokeOtherUserSessions(userId, currentToken)) {
		qWarning() << "[LogoutOtherSessions] Failed to revoke other sessions. userId:" << userId;

		QJsonObject err;
		err["ok"] = false;
		err["error"] = "failed to revoke other sessions";

		sendJson(client, err);
		return;
	}

	for (const QString& token : tokens)
		m_sessions->removeSession(token);

	qDebug() << "[LogoutOtherSessions] Revoked sessions:" << tokens.size()
		<< "| userId:" << userId;

	QJsonObject resp;
	resp["ok"] = true;
	resp["command"] = "logout_other_sessions";

	sendJson(client, resp);
}

void Server::handleCreateUser(const QJsonObject& params, int userId, QSslSocket* client)
{
	QJsonObject resp;
	resp["command"] = "create_user";

	const int role = Db::get()->getUserRole(userId);

	qDebug() << "[CreateUser] userId:" << userId << "| role:" << role;

	if (role != 3) {
		qWarning() << "[CreateUser] Access denied. userId:" << userId
			<< "| role:" << role
			<< "| required role: admin (3)";

		resp["ok"] = false;
		resp["code"] = "forbidden";
		resp["error"] = "Only admin can create users";

		sendJson(client, resp);
		return;
	}

	const QJsonObject user = params.value("user").toObject();
	const QJsonObject student = params.value("student").toObject();
	const QJsonObject teacher = params.value("teacher").toObject();

	resp = Db::get()->createUserWithRoleData(user, student, teacher);
	resp["command"] = "create_user";

	qDebug() << "[CreateUser] Result. userId:" << userId
		<< "| ok:" << resp.value("ok").toBool();

	sendJson(client, resp);
}

void Server::cleanupExpiredResetCodes()
{
	const QDateTime now = QDateTime::currentDateTimeUtc();
	int removed = 0;

	for (int i = m_valid_hashes.size() - 1; i >= 0; --i) {
		const QDateTime expiresAt = std::get<0>(m_valid_hashes[i]);

		if (expiresAt <= now) {
			m_valid_hashes.removeAt(i);
			++removed;
		}
	}

	if (removed > 0) {
		qDebug() << "[ResetCode] Removed expired codes:" << removed
			<< "| Active codes left:" << m_valid_hashes.size();
	}
}

QString Server::makeResetCode() const
{
	const int value = QRandomGenerator::global()->bounded(100000, 1000000);
	return QString::number(value);
}

QString Server::resetCodeHash(const QString& email, const QString& code) const
{
	const QString normalizedEmail = email.trimmed().toLower();
	const QByteArray data = (normalizedEmail + ":" + code.trimmed()).toUtf8();

	return QString::fromLatin1(hmacSha256(data).toHex());
}

bool Server::isResetCodeValid(const QString& email, const QString& code, bool removeIfValid)
{
	cleanupExpiredResetCodes();

	const QString normalizedEmail = email.trimmed().toLower();
	const QString normalizedCode = code.trimmed();

	if (normalizedEmail.isEmpty() || normalizedCode.isEmpty())
		return false;

	const QString hash = resetCodeHash(normalizedEmail, normalizedCode);
	const QDateTime now = QDateTime::currentDateTimeUtc();

	for (int i = 0; i < m_valid_hashes.size(); ++i) {
		const QDateTime expiresAt = std::get<0>(m_valid_hashes[i]);
		const QString storedHash = std::get<1>(m_valid_hashes[i]);

		if (storedHash == hash && expiresAt > now) {
			if (removeIfValid)
				m_valid_hashes.removeAt(i);

			return true;
		}
	}

	return false;
}

void Server::handleGetEmailCodeResetPassword(const QJsonObject& params, QSslSocket* client)
{
	cleanupExpiredResetCodes();

	const QString email = params.value("email").toString().trimmed().toLower();

	qDebug() << "[ResetPassword] Password reset code requested. Email:" << email;

	QJsonObject resp;
	resp["command"] = "get_email_code_reset_password";

	if (email.isEmpty()) {
		qWarning() << "[ResetPassword] Email was not provided.";

		resp["ok"] = false;
		resp["code"] = "bad_request";
		resp["error"] = "email is required";

		sendJson(client, resp);
		return;
	}

	static const QRegularExpression emailRegex(
		R"(^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$)",
		QRegularExpression::CaseInsensitiveOption
	);

	if (!emailRegex.match(email).hasMatch()) {
		qWarning() << "[ResetPassword] Invalid email format:" << email;

		resp["ok"] = false;
		resp["code"] = "bad_request";
		resp["error"] = "invalid email";

		sendJson(client, resp);
		return;
	}

	const QString code = makeResetCode();
	const QString hash = resetCodeHash(email, code);
	const QDateTime expiresAt = QDateTime::currentDateTimeUtc().addSecs(10 * 60);

	qDebug() << "[ResetPassword] Code generated. Email:" << email
		<< "| Expires at:" << expiresAt.toString(Qt::ISODate);

	EmailSender::Config mailConfig;
	mailConfig.host = "smtp.yandex.ru";
	mailConfig.port = 465;
	mailConfig.username = EmailAddress;
	mailConfig.password = EmailPassword;
	mailConfig.fromEmail = EmailAddress;
	mailConfig.fromName = "SlotApp";

	auto* sender = new EmailSender(mailConfig, this);
	QPointer<QSslSocket> safeClient(client);

	connect(sender, &EmailSender::finished, this,
		[this, sender, safeClient, hash, expiresAt, email](bool ok, const QString& message) {
			sender->deleteLater();

			if (!safeClient)
				return;

			QJsonObject answer;
			answer["command"] = "get_email_code_reset_password";

			if (!ok) {
				qWarning() << "[ResetPassword] Failed to send email. Email:" << email
					<< "| Reason:" << message;

				answer["ok"] = false;
				answer["code"] = "email_send_failed";
				answer["error"] = message.isEmpty()
					? "Не удалось отправить код на почту."
					: message;

				sendJson(safeClient.data(), answer);
				return;
			}

			cleanupExpiredResetCodes();

			m_valid_hashes.push_back(std::make_tuple(expiresAt, hash));

			qDebug() << "[ResetPassword] Email sent successfully. Email:" << email
				<< "| Active codes:" << m_valid_hashes.size();

			answer["ok"] = true;
			answer["expires_in"] = 10 * 60;
			answer["message"] = "Код отправлен на почту.";

			sendJson(safeClient.data(), answer);
		});

	const QString mailText =
		QStringLiteral(
			"Здравствуйте!\r\n\r\n"
			"Ваш код восстановления пароля: %1\r\n\r\n"
			"Код действует 10 минут.\r\n"
			"Если вы не запрашивали восстановление пароля, просто проигнорируйте это письмо.\r\n\r\n"
			"С уважением,\r\n"
			"SlotApp"
		).arg(code);

	sender->send(
		email,
		"Код восстановления пароля SlotApp",
		mailText
	);
}

void Server::handleIsValidCode(const QJsonObject& params, QSslSocket* client)
{
	const QString email = params.value("email").toString().trimmed().toLower();
	const QString code = params.value("code").toString().trimmed();

	qDebug() << "[IsValidCode] Checking reset code. Email:" << email;

	QJsonObject resp;
	resp["command"] = "IsValidCode";

	if (email.isEmpty() || code.isEmpty()) {
		qWarning() << "[IsValidCode] Email or code was not provided. Email:" << email;

		resp["ok"] = false;
		resp["valid"] = false;
		resp["code"] = "bad_request";
		resp["error"] = "email and code are required";

		sendJson(client, resp);
		return;
	}

	const bool valid = isResetCodeValid(email, code, false);

	qDebug() << "[IsValidCode] Result. Email:" << email << "| Valid:" << valid;

	resp["ok"] = true;
	resp["valid"] = valid;

	if (!valid)
		resp["error"] = "invalid or expired code";

	sendJson(client, resp);
}

void Server::handleChangePassword(const QJsonObject& params, int userId, QSslSocket* client)
{
	const QString oldPassword = params.value("old_password").toString();
	const QString newPassword = params.value("new_password").toString();

	qDebug() << "[ChangePassword] Password change requested. userId:" << userId;

	QJsonObject resp;
	resp["command"] = "change_password";

	if (oldPassword.isEmpty() || newPassword.isEmpty()) {
		qWarning() << "[ChangePassword] Old or new password was not provided. userId:" << userId;

		resp["ok"] = false;
		resp["code"] = "bad_request";
		resp["error"] = "old_password and new_password are required";

		sendJson(client, resp);
		return;
	}

	if (newPassword.length() < 6) {
		qWarning() << "[ChangePassword] New password is too short. userId:" << userId
			<< "| Length:" << newPassword.length();

		resp["ok"] = false;
		resp["code"] = "bad_request";
		resp["error"] = "Новый пароль должен быть не короче 6 символов.";

		sendJson(client, resp);
		return;
	}

	if (!Db::get()->changePasswordByUserId(userId, oldPassword, newPassword)) {
		qWarning() << "[ChangePassword] Old password is invalid. userId:" << userId;

		resp["ok"] = false;
		resp["code"] = "password_change_failed";
		resp["error"] = "Старый пароль указан неверно.";

		sendJson(client, resp);
		return;
	}

	qDebug() << "[ChangePassword] Password changed successfully. userId:" << userId;

	resp["ok"] = true;
	resp["message"] = "Пароль успешно изменён.";

	sendJson(client, resp);
}

void Server::handleResetPasswordByCode(const QJsonObject& params, QSslSocket* client)
{
	cleanupExpiredResetCodes();

	const QString email = params.value("email").toString().trimmed().toLower();
	const QString code = params.value("code").toString().trimmed();
	const QString newPassword = params.value("new_password").toString();

	qDebug() << "[ResetPasswordByCode] Password reset requested. Email:" << email;

	QJsonObject resp;
	resp["command"] = "reset_password_by_code";

	if (email.isEmpty() || code.isEmpty() || newPassword.isEmpty()) {
		qWarning() << "[ResetPasswordByCode] Required parameters are missing. Email:" << email;

		resp["ok"] = false;
		resp["code"] = "bad_request";
		resp["error"] = "email, code and new_password are required";

		sendJson(client, resp);
		return;
	}

	if (newPassword.length() < 6) {
		qWarning() << "[ResetPasswordByCode] New password is too short. Email:" << email
			<< "| Length:" << newPassword.length();

		resp["ok"] = false;
		resp["code"] = "bad_request";
		resp["error"] = "Новый пароль должен быть не короче 6 символов.";

		sendJson(client, resp);
		return;
	}

	const QString hash = resetCodeHash(email, code);
	const QDateTime now = QDateTime::currentDateTimeUtc();

	for (int i = 0; i < m_valid_hashes.size(); ++i) {
		const QDateTime expiresAt = std::get<0>(m_valid_hashes[i]);
		const QString storedHash = std::get<1>(m_valid_hashes[i]);

		if (storedHash == hash && expiresAt > now) {
			if (!Db::get()->resetPasswordByEmail(email, newPassword)) {
				qWarning() << "[ResetPasswordByCode] Failed to update password in database. Email:" << email;

				resp["ok"] = false;
				resp["code"] = "password_reset_failed";
				resp["error"] = "Не удалось изменить пароль. Проверьте email аккаунта.";

				sendJson(client, resp);
				return;
			}

			m_valid_hashes.removeAt(i);

			qDebug() << "[ResetPasswordByCode] Password reset successfully. Email:" << email;

			resp["ok"] = true;
			resp["message"] = "Пароль успешно изменён.";

			sendJson(client, resp);
			return;
		}
	}

	qWarning() << "[ResetPasswordByCode] Invalid or expired code. Email:" << email;

	resp["ok"] = false;
	resp["code"] = "invalid_code";
	resp["error"] = "Неверный или просроченный код.";

	sendJson(client, resp);
}