#pragma once

#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlQuery>
#include <QtSql/QSqlError>
#include <QtSql/QSqlField>
#include <QtSql/QSqlRecord>

#include <QDebug>
#include <QMetaType>
#include <QString>
#include <QStringList>
#include <QVariant>
#include <QVariantMap>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>

#include "AppLogger.h"
#include <algorithm>
#include <type_traits>

enum FieldDataType {
	Int,
	String,
	Float,
	Date,
	Unknown
};

inline QString toQString(FieldDataType type)
{
	switch (type) {
	case Int:     return "Int";
	case String:  return "String";
	case Float:   return "Float";
	case Date:    return "Date";
	case Unknown: return "Unknown";
	default:      return "InvalidType";
	}
}

inline std::string toString(FieldDataType type)
{
	switch (type) {
	case Int:     return "Int";
	case String:  return "String";
	case Float:   return "Float";
	case Date:    return "Date";
	case Unknown: return "Unknown";
	default:      return "InvalidType";
	}
}

// 1 name param, 2 type data, 3 value
using element = std::tuple<QString, FieldDataType, QString>;

// 1 name param, 2 type data
using param = std::tuple<QString, FieldDataType>;

using table_noexception = std::vector<element>;
using table_params = std::vector<param>;
using table_row = std::vector<element>;
using table_data = std::vector<table_row>;

QJsonObject toJson(const table_data& data);

template<class T>
T get_value_in_type(const element& e)
{
	const QString& value = std::get<2>(e);

	if constexpr (std::is_same_v<T, int>) {
		return value.toInt();
	}
	else if constexpr (std::is_same_v<T, float>) {
		return value.toFloat();
	}
	else if constexpr (std::is_same_v<T, QString>) {
		return value;
	}
	else {
		return {};
	}
}

template<class T>
T get_constexpr(QString name_param, const std::vector<element>& el)
{
	auto it = std::find_if(
		el.begin(),
		el.end(),
		[&name_param](const element& e) {
			return std::get<0>(e) == name_param;
		}
	);

	if (it == el.end())
		return {};

	const QString value = std::get<2>(*it);

	if constexpr (std::is_same_v<T, int>) {
		return value.toInt();
	}
	else if constexpr (std::is_same_v<T, float>) {
		return value.toFloat();
	}
	else if constexpr (std::is_same_v<T, QString>) {
		return value;
	}
	else {
		return {};
	}
}

class Db
{
private:
	bool connectToDatabase();
	bool ensureOpen();

	QSqlDatabase m_sql_context;
	AppLogger m_log;
	void init();

public:
	Db();

	static Db* get();

	QSqlDatabase& getDatabaseContext();

	bool createTable(const QString& name, const table_params& params);

	void addTableData(
		const QString& tableName,
		const std::vector<param>& tableStructure,
		const std::vector<element>& dataToAdd
	);

	QJsonObject addTableData(const QString& tableName, const QJsonObject& data);
	QJsonObject updateTableData(const QString& tableName, int id, const QJsonObject& data);
	QJsonObject deleteTableData(const QString& tableName, int id);

	table_row get_id_data(QString nameTb, int id);

	bool set_table_colums(
		QString nameTb,
		int id,
		table_row newData
	);

	void removeRecordById(const QString& tableName, int id);
	void dropTable(QString name);
	void clearTableData(QString nameTb);

	bool isValidTable(QString nameTb);
	bool isValidIdOnTable(QString nameTb, int id);

	bool checkUserCredentials(const QString& login, const QString& password, int* userId = nullptr);

	table_params fetchTableSchema(const QString& tableName);
	FieldDataType resolveFieldType(QMetaType metaType);
	table_data getTableValues(const QString& tableName);

	QJsonObject getMyProfile(int userId);
	QJsonArray getUserSessions(int userId, const QString& currentToken);

	bool createUserSession(
		int userId,
		const QString& token,
		const QString& deviceName,
		const QString& platform,
		const QString& ipAddress,
		int expiresInSeconds
	);

	bool revokeUserSessionByToken(const QString& token);

	int getUserRole(int userId);
	QString getUserFullName(int userId);
	QJsonObject getTeacherShortInfo(int teacherId);

	bool canUserAccessRow(const QString& tableName, int rowId, int userId);

	QString getUserSessionTokenById(int userId, int sessionId);
	QStringList getOtherUserSessionTokens(int userId, const QString& currentToken);

	bool revokeUserSessionById(int userId, int sessionId);
	bool revokeOtherUserSessions(int userId, const QString& currentToken);

	
	QJsonObject getAppointments(int userId);
	QJsonObject cancelAppointment(int userId, int appointmentId);
	QJsonObject rateAppointment(int userId, int appointmentId, int rating);
	QJsonObject getTeachers();

	QJsonObject getTableForClient(const QString& tableName);
	QJsonObject getTableForClient(const QString& tableName, int userId);

	QJsonObject createUserWithRoleData(const QJsonObject& userData,
		const QJsonObject& studentData,
		const QJsonObject& teacherData);


	bool resetPasswordByEmail(const QString& email, const QString& newPassword);


	
	bool changePasswordByUserId(int userId, const QString& oldPassword, const QString& newPassword);


};