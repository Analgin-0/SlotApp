#include "Db.h"

#include <QCryptographicHash>
#include <QDate>
#include <QTime>
#include <QDateTime>
#include <QRegularExpression>
#include <QHash>
#include <QtGlobal>
#include <iostream>

static QString connectionName()
{
	return "tu_server_db_connection";
}

static bool isSafeSqlIdentifier(const QString& value)
{
	static const QRegularExpression re("^[A-Za-z_][A-Za-z0-9_]*$");
	return re.match(value).hasMatch();
}

static QString safeTableName(const QString& tableName)
{
	return "[dbo].[" + tableName + "]";
}

static QString safeColumnName(const QString& columnName)
{
	return "[" + columnName + "]";
}

static QVariant jsonValueToVariant(const QJsonValue& value)
{
	if (value.isNull() || value.isUndefined())
		return QVariant();

	if (value.isBool())
		return value.toBool();

	if (value.isDouble()) {
		const double d = value.toDouble();
		const int i = value.toInt();

		if (qFuzzyCompare(d, double(i)))
			return i;

		return d;
	}

	if (value.isString())
		return value.toString();

	return value.toVariant();
}

static QJsonValue variantToJsonValue(const QVariant& value)
{
	if (!value.isValid() || value.isNull())
		return QJsonValue();

	switch (value.metaType().id()) {
	case QMetaType::Bool:
		return value.toBool();

	case QMetaType::Int:
	case QMetaType::UInt:
	case QMetaType::LongLong:
	case QMetaType::ULongLong:
	case QMetaType::Short:
	case QMetaType::UShort:
		return value.toInt();

	case QMetaType::Float:
	case QMetaType::Double:
		return value.toDouble();

	case QMetaType::QDate:
		return value.toDate().toString(Qt::ISODate);

	case QMetaType::QTime:
		return value.toTime().toString("HH:mm");

	case QMetaType::QDateTime:
		return value.toDateTime().toString(Qt::ISODate);

	default:
		return value.toString();
	}
}

static QString dateVariantToString(const QVariant& value)
{
	if (!value.isValid() || value.isNull())
		return "";

	if (value.canConvert<QDate>())
		return value.toDate().toString(Qt::ISODate);

	if (value.canConvert<QDateTime>())
		return value.toDateTime().date().toString(Qt::ISODate);

	return value.toString();
}

static QString timeVariantToString(const QVariant& value)
{
	if (!value.isValid() || value.isNull())
		return "";

	if (value.canConvert<QTime>())
		return value.toTime().toString("HH:mm");

	if (value.canConvert<QDateTime>())
		return value.toDateTime().time().toString("HH:mm");

	QString text = value.toString();

	if (text.size() >= 5)
		return text.left(5);

	return text;
}

static int recordIndexOfAny(const QSqlRecord& record, const QStringList& names)
{
	for (const QString& name : names) {
		const int index = record.indexOf(name);

		if (index >= 0)
			return index;
	}

	return -1;
}

static QVariant queryValueAny(const QSqlQuery& query, const QSqlRecord& record, const QStringList& names)
{
	const int index = recordIndexOfAny(record, names);

	if (index < 0)
		return QVariant();

	return query.value(index);
}

static QString queryStringAny(const QSqlQuery& query, const QSqlRecord& record, const QStringList& names)
{
	return queryValueAny(query, record, names).toString();
}

static int queryIntAny(const QSqlQuery& query, const QSqlRecord& record, const QStringList& names, int fallback = 0)
{
	const QVariant value = queryValueAny(query, record, names);

	if (!value.isValid() || value.isNull())
		return fallback;

	bool ok = false;
	const int n = value.toInt(&ok);

	return ok ? n : fallback;
}

static bool queryBoolAny(const QSqlQuery& query, const QSqlRecord& record, const QStringList& names, bool fallback = false)
{
	const QVariant value = queryValueAny(query, record, names);

	if (!value.isValid() || value.isNull())
		return fallback;

	if (value.metaType().id() == QMetaType::Bool)
		return value.toBool();

	const QString text = value.toString().trimmed().toLower();

	if (text == "1" || text == "true" || text == "yes" || text == "да")
		return true;

	if (text == "0" || text == "false" || text == "no" || text == "нет")
		return false;

	return value.toInt() != 0;
}

static QString roleToCancelText(int role)
{
	if (role == 1)
		return "студент";

	if (role == 2)
		return "преподаватель";

	if (role == 3)
		return "админ";

	return "не указано";
}

static QHash<QString, QString> getTableColumnMap(QSqlDatabase& db, const QString& tableName)
{
	QHash<QString, QString> result;

	if (!isSafeSqlIdentifier(tableName))
		return result;

	QSqlQuery query(db);
	const QString sql = "SELECT TOP 0 * FROM " + safeTableName(tableName);

	if (!query.exec(sql)) {
		qWarning() << "getTableColumnMap failed:" << query.lastError().text();
		return result;
	}

	const QSqlRecord record = query.record();

	for (int i = 0; i < record.count(); ++i) {
		const QString fieldName = record.fieldName(i);
		result.insert(fieldName.toLower(), fieldName);
	}

	return result;
}

static QString findColumn(
	const QHash<QString, QString>& columns,
	const QStringList& candidates
)
{
	for (const QString& candidate : candidates) {
		const QString key = candidate.toLower();

		if (columns.contains(key))
			return columns.value(key);
	}

	return "";
}

static bool addUpdatePartIfColumnExists(
	QStringList& setParts,
	QVariantMap& values,
	const QHash<QString, QString>& columns,
	const QStringList& candidates,
	const QString& placeholder,
	const QVariant& value
)
{
	const QString column = findColumn(columns, candidates);

	if (column.isEmpty())
		return false;

	setParts << safeColumnName(column) + " = " + placeholder;
	values.insert(placeholder, value);

	return true;
}

Db::Db()
{
	init();
}

Db* Db::get()
{
	static auto db = new Db();
	return db;
}

QSqlDatabase& Db::getDatabaseContext()
{
	return m_sql_context;
}

bool Db::connectToDatabase()
{
	if (QSqlDatabase::contains(connectionName())) {
		m_sql_context = QSqlDatabase::database(connectionName());
	}
	else {
		m_sql_context = QSqlDatabase::addDatabase("QODBC", connectionName());
	}

	if (m_sql_context.isOpen())
		return true;

	const QString connectionString =
		"DRIVER={ODBC Driver 17 for SQL Server};"
		"SERVER=DESKTOP-QDB1UGD\\SQLEXPRESS;"
		"DATABASE=Tu;"
		"Trusted_Connection=yes;";

	m_sql_context.setDatabaseName(connectionString);

	if (!m_sql_context.open()) {
		qDebug() << "[Database] Connection error:" << m_sql_context.lastError().text();
		return false;
	}

	qDebug() << "[Database] Connected";
	return true;
}

bool Db::ensureOpen()
{
	if (m_sql_context.isOpen())
		return true;

	return connectToDatabase();
}

void Db::init()
{
	static bool is_init = false;

	if (is_init)
		return;

	if (!connectToDatabase()) {
		std::cout << "Failed connectToDatabase\n";
		throw std::runtime_error("Failed connectToDatabase");
	}

	is_init = true;
}

bool Db::createTable(const QString& name, const table_params& params)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection not open!";
		return false;
	}

	if (!isSafeSqlIdentifier(name)) {
		qWarning() << "Unsafe table name:" << name;
		return false;
	}

	if (m_sql_context.tables().contains(name)) {
		qWarning() << "Table" << name << "already exists!";
		return false;
	}

	m_sql_context.transaction();

	try {
		QStringList columns;
		columns << "[id] INT IDENTITY(1,1) PRIMARY KEY";

		for (const auto& [fieldName, type] : params) {
			if (!isSafeSqlIdentifier(fieldName))
				continue;

			if (fieldName.compare("id", Qt::CaseInsensitive) == 0)
				continue;

			QString typeStr;

			switch (type) {
			case Int:
				typeStr = "INT";
				break;

			case Float:
				typeStr = "FLOAT";
				break;

			case String:
				typeStr = "NVARCHAR(MAX)";
				break;

			case Date:
				typeStr = "DATETIME";
				break;

			default:
				typeStr = "NVARCHAR(MAX)";
				break;
			}

			columns << QString("[%1] %2").arg(fieldName, typeStr);
		}

		QSqlQuery createQuery(m_sql_context);

		const QString createSql =
			QString("CREATE TABLE %1 (%2)")
			.arg(safeTableName(name), columns.join(", "));

		if (!createQuery.exec(createSql)) {
			throw std::runtime_error(
				QString("Failed to create table: %1")
				.arg(createQuery.lastError().text())
				.toStdString()
			);
		}

		m_sql_context.commit();

		qDebug() << "Table" << name << "created successfully";
		return true;
	}
	catch (const std::exception& e) {
		m_sql_context.rollback();
		qCritical() << "Operation failed:" << e.what();
		return false;
	}
}

table_row Db::get_id_data(QString nameTb, int id)
{
	table_row result;

	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return result;
	}

	if (!isSafeSqlIdentifier(nameTb)) {
		qWarning() << "Unsafe table name:" << nameTb;
		return result;
	}

	if (!isValidTable(nameTb)) {
		qWarning() << "Table" << nameTb << "does not exist!";
		return result;
	}

	QSqlQuery query(m_sql_context);
	query.prepare("SELECT * FROM " + safeTableName(nameTb) + " WHERE [id] = :id");
	query.bindValue(":id", id);

	if (!query.exec()) {
		qWarning() << "Failed to execute query:" << query.lastError().text();
		return result;
	}

	if (!query.next()) {
		qDebug() << "No record found with ID" << id << "in table" << nameTb;
		return result;
	}

	const QSqlRecord record = query.record();

	for (int i = 0; i < record.count(); ++i) {
		const QString fieldName = record.fieldName(i);
		const QVariant value = query.value(i);
		const QMetaType fieldType = record.field(i).metaType();
		const FieldDataType type = resolveFieldType(fieldType);

		QString strValue;

		if (value.isNull()) {
			strValue = "NULL";
		}
		else {
			switch (type) {
			case Int:
				strValue = QString::number(value.toInt());
				break;

			case Float:
				strValue = QString::number(value.toDouble());
				break;

			case Date:
				strValue = value.toDateTime().toString(Qt::ISODate);
				break;

			case String:
			default:
				strValue = value.toString();
				break;
			}
		}

		result.emplace_back(fieldName, type, strValue);
	}

	return result;
}

bool Db::set_table_colums(QString nameTb, int id, table_row newData)
{
	if (!ensureOpen()) {
		qDebug() << "Database is not connected!";
		return false;
	}

	if (!isSafeSqlIdentifier(nameTb)) {
		qWarning() << "Unsafe table name:" << nameTb;
		return false;
	}

	const table_params tableStructure = fetchTableSchema(nameTb);

	if (tableStructure.empty()) {
		qDebug() << "Failed to get table structure for table:" << nameTb;
		return false;
	}

	QStringList setClauses;
	QVariantList values;

	for (const element& newElement : newData) {
		const QString fieldName = std::get<0>(newElement);
		const FieldDataType fieldType = std::get<1>(newElement);
		const QString fieldValue = std::get<2>(newElement);

		if (!isSafeSqlIdentifier(fieldName))
			continue;

		if (fieldName.compare("id", Qt::CaseInsensitive) == 0)
			continue;

		auto it = std::find_if(
			tableStructure.begin(),
			tableStructure.end(),
			[&fieldName](const param& p) {
				return std::get<0>(p).compare(fieldName, Qt::CaseInsensitive) == 0;
			}
		);

		if (it == tableStructure.end()) {
			qDebug() << "Field" << fieldName << "not found in table" << nameTb;
			continue;
		}

		const FieldDataType expectedType = std::get<1>(*it);

		if (fieldType != expectedType) {
			qDebug() << "Type mismatch for field" << fieldName
				<< "Expected:" << expectedType
				<< "Got:" << fieldType;
			continue;
		}

		setClauses << safeColumnName(fieldName) + " = ?";
		values << fieldValue;
	}

	if (setClauses.isEmpty()) {
		qDebug() << "No valid fields to update";
		return false;
	}

	const QString updateQuery =
		"UPDATE " + safeTableName(nameTb) +
		" SET " + setClauses.join(", ") +
		" WHERE [id] = ?";

	QSqlQuery query(m_sql_context);
	query.prepare(updateQuery);

	for (const QVariant& value : values)
		query.addBindValue(value);

	query.addBindValue(id);

	if (!query.exec()) {
		qDebug() << "Failed to update record:" << query.lastError().text();
		return false;
	}

	if (query.numRowsAffected() <= 0) {
		qDebug() << "No rows affected, record with id" << id << "might not exist";
		return false;
	}

	return true;
}

void Db::removeRecordById(const QString& tableName, int id)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return;
	}

	if (!isSafeSqlIdentifier(tableName)) {
		qWarning() << "Unsafe table name:" << tableName;
		return;
	}

	if (!isValidTable(tableName)) {
		qWarning() << "Table" << tableName << "does not exist!";
		return;
	}

	QSqlQuery query(m_sql_context);
	query.prepare("DELETE FROM " + safeTableName(tableName) + " WHERE [id] = :id");
	query.bindValue(":id", id);

	if (!query.exec()) {
		qWarning() << "Failed to delete record:" << query.lastError().text();
		return;
	}

	qDebug() << "Deleted rows:" << query.numRowsAffected();
}

void Db::dropTable(QString name)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return;
	}

	if (!isSafeSqlIdentifier(name)) {
		qWarning() << "Unsafe table name:" << name;
		return;
	}

	if (!isValidTable(name)) {
		qWarning() << "Table" << name << "does not exist!";
		return;
	}

	QSqlQuery query(m_sql_context);
	query.prepare("DROP TABLE " + safeTableName(name));

	if (!query.exec()) {
		qWarning() << "Failed to delete table" << name << ":" << query.lastError().text();
	}
	else {
		qDebug() << "Table" << name << "deleted successfully";
	}
}

void Db::clearTableData(QString nameTb)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return;
	}

	if (!isSafeSqlIdentifier(nameTb)) {
		qWarning() << "Unsafe table name:" << nameTb;
		return;
	}

	if (!isValidTable(nameTb)) {
		qWarning() << "Table" << nameTb << "does not exist!";
		return;
	}

	QSqlQuery query(m_sql_context);

	if (!query.exec("DELETE FROM " + safeTableName(nameTb))) {
		qWarning() << "Failed to clear table" << nameTb << ":" << query.lastError().text();
	}
	else {
		qDebug() << "Table" << nameTb << "data cleared."
			<< query.numRowsAffected() << "rows affected.";
	}
}

bool Db::isValidTable(QString nameTb)
{
	if (!ensureOpen()) {
		qDebug() << "Error: there is no connection to the database!";
		return false;
	}

	if (!isSafeSqlIdentifier(nameTb))
		return false;

	QSqlQuery query(m_sql_context);
	query.prepare(
		"SELECT COUNT(*) "
		"FROM INFORMATION_SCHEMA.TABLES "
		"WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = ?"
	);
	query.addBindValue(nameTb);

	if (!query.exec()) {
		qDebug() << "Error checking the table:" << query.lastError().text();
		return false;
	}

	if (!query.next())
		return false;

	return query.value(0).toInt() > 0;
}

bool Db::isValidIdOnTable(QString nameTb, int id)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return false;
	}

	if (!isSafeSqlIdentifier(nameTb) || id <= 0)
		return false;

	QSqlQuery query(m_sql_context);
	query.prepare(
		"SELECT COUNT(*) "
		"FROM " + safeTableName(nameTb) + " "
		"WHERE [id] = :id"
	);
	query.bindValue(":id", id);

	if (!query.exec()) {
		qWarning() << "isValidIdOnTable failed:" << query.lastError().text();
		return false;
	}

	if (!query.next())
		return false;

	return query.value(0).toInt() > 0;
}

void Db::addTableData(
	const QString& tableName,
	const std::vector<param>& tableStructure,
	const std::vector<element>& dataToAdd
)
{
	if (!ensureOpen()) {
		qWarning() << "Database is not connected!";
		return;
	}

	if (!isSafeSqlIdentifier(tableName)) {
		qWarning() << "Unsafe table name:" << tableName;
		return;
	}

	QStringList fields;
	QStringList placeholders;
	QVector<QVariant> values;

	for (size_t i = 0; i < tableStructure.size(); ++i) {
		const auto& [fieldName, fieldType] = tableStructure[i];

		Q_UNUSED(fieldType);

		if (!isSafeSqlIdentifier(fieldName))
			continue;

		if (fieldName.compare("id", Qt::CaseInsensitive) == 0)
			continue;

		if (i >= dataToAdd.size()) {
			qWarning() << "Data index out of range";
			return;
		}

		fields << safeColumnName(fieldName);
		placeholders << "?";

		const auto& [name, type, value] = dataToAdd[i];
		Q_UNUSED(name);

		switch (type) {
		case Int:
			values << value.toInt();
			break;

		case Float:
			values << value.toDouble();
			break;

		case Date:
			values << QDateTime::fromString(value, Qt::ISODate);
			break;

		case String:
		default:
			values << value;
			break;
		}
	}

	const QString queryStr =
		"INSERT INTO " + safeTableName(tableName) +
		" (" + fields.join(", ") + ") "
		"VALUES (" + placeholders.join(", ") + ")";

	QSqlQuery query(m_sql_context);

	if (!query.prepare(queryStr)) {
		qWarning() << "Prepare failed:" << query.lastError().text();
		return;
	}

	for (const auto& val : values)
		query.addBindValue(val);

	if (!query.exec()) {
		qWarning() << "Failed to insert data:" << query.lastError().text();
	}
	else {
		qDebug() << "Successfully added data to" << tableName;
	}
}

bool Db::checkUserCredentials(const QString& login, const QString& password, int* userId)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return false;
	}

	QSqlQuery query(m_sql_context);
	query.prepare("SELECT [id], [Password] FROM [dbo].[User] WHERE [Login] = :login");
	query.bindValue(":login", login);

	if (!query.exec()) {
		qWarning() << "Auth query failed:" << query.lastError().text();
		return false;
	}

	if (!query.next()) {
		qWarning() << "User not found:" << login;
		return false;
	}

	const int dbUserId = query.value("id").toInt();
	const QString dbPassword = query.value("Password").toString();

	if (dbPassword != password) {
		qWarning() << "Wrong password for user:" << login;
		return false;
	}

	if (userId)
		*userId = dbUserId;

	return true;
}

table_params Db::fetchTableSchema(const QString& tableName)
{
	table_params structure;

	if (!ensureOpen()) {
		qDebug() << "Database is not open!";
		return structure;
	}

	if (!isSafeSqlIdentifier(tableName))
		return structure;

	QSqlQuery query(m_sql_context);
	const QString sql = "SELECT TOP 0 * FROM " + safeTableName(tableName);

	if (!query.exec(sql)) {
		qDebug() << "Failed to execute query:" << query.lastError().text();
		return structure;
	}

	const QSqlRecord record = query.record();

	for (int i = 0; i < record.count(); ++i) {
		const QString fieldName = record.fieldName(i);
		const QMetaType fieldMetaType = record.field(i).metaType();
		const FieldDataType customType = resolveFieldType(fieldMetaType);

		structure.emplace_back(fieldName, customType);
	}

	return structure;
}

FieldDataType Db::resolveFieldType(QMetaType metaType)
{
	switch (metaType.id()) {
	case QMetaType::Int:
	case QMetaType::UInt:
	case QMetaType::LongLong:
	case QMetaType::ULongLong:
	case QMetaType::Short:
	case QMetaType::UShort:
		return Int;

	case QMetaType::QString:
	case QMetaType::QChar:
	case QMetaType::QByteArray:
		return String;

	case QMetaType::Float:
	case QMetaType::Double:
		return Float;

	case QMetaType::QDate:
	case QMetaType::QDateTime:
		return Date;

	default:
		return Unknown;
	}
}

table_data Db::getTableValues(const QString& tableName)
{
	table_data result;

	if (!ensureOpen()) {
		qWarning() << "Database not connected!";
		return result;
	}

	if (!isSafeSqlIdentifier(tableName)) {
		qWarning() << "Unsafe table name:" << tableName;
		return result;
	}

	QSqlQuery query(m_sql_context);

	if (!query.exec("SELECT * FROM " + safeTableName(tableName))) {
		qWarning() << "Query failed:" << query.lastError();
		return result;
	}

	const QSqlRecord record = query.record();

	std::vector<QString> fieldNames;
	std::vector<FieldDataType> fieldTypes;

	for (int i = 0; i < record.count(); ++i) {
		fieldNames.push_back(record.fieldName(i));
		fieldTypes.push_back(resolveFieldType(record.field(i).metaType()));
	}

	while (query.next()) {
		table_row row;

		for (int i = 0; i < record.count(); ++i) {
			const QVariant value = query.value(i);
			const QString strValue = value.isNull() ? "NULL" : value.toString();

			row.emplace_back(fieldNames[i], fieldTypes[i], strValue);
		}

		result.push_back(row);
	}

	return result;
}

QJsonObject toJson(const table_data& data)
{
	QJsonObject root;
	QJsonArray tableArray;

	for (const auto& row : data) {
		QJsonObject rowObject;

		for (const auto& val : row) {
			const auto [name, type, value] = val;
			Q_UNUSED(type);

			rowObject[name] = value;
		}

		tableArray.append(rowObject);
	}

	root["MyTable"] = tableArray;

	return root;
}

QJsonObject Db::getMyProfile(int userId)
{
	QJsonObject result;

	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return result;
	}

	QSqlQuery userQuery(m_sql_context);
	userQuery.prepare(
		"SELECT [id], [Login], [Name], [LastName], [MiddleName], [Age], "
		"[Role], [Post], [BirthDate], [Gender], [Phone] "
		"FROM [dbo].[User] WHERE [id] = :id"
	);
	userQuery.bindValue(":id", userId);

	if (!userQuery.exec()) {
		qWarning() << "getMyProfile user query failed:" << userQuery.lastError().text();
		return result;
	}

	if (!userQuery.next()) {
		qWarning() << "User not found, id =" << userId;
		return result;
	}

	QJsonObject userObj;
	userObj["id"] = userQuery.value("id").toInt();
	userObj["login"] = userQuery.value("Login").toString();
	userObj["name"] = userQuery.value("Name").toString();
	userObj["last_name"] = userQuery.value("LastName").toString();
	userObj["middle_name"] = userQuery.value("MiddleName").toString();
	userObj["age"] = userQuery.value("Age").isNull()
		? QJsonValue()
		: QJsonValue(userQuery.value("Age").toInt());
	userObj["role"] = userQuery.value("Role").isNull()
		? QJsonValue()
		: QJsonValue(userQuery.value("Role").toInt());
	userObj["post"] = userQuery.value("Post").toString();
	userObj["birth_date"] = userQuery.value("BirthDate").toDate().toString(Qt::ISODate);
	userObj["gender"] = userQuery.value("Gender").toString();
	userObj["phone"] = userQuery.value("Phone").toString();

	result["user"] = userObj;

	const int role = userQuery.value("Role").toInt();

	if (role == 1) {
		QSqlQuery studentQuery(m_sql_context);
		studentQuery.prepare(
			"SELECT [id], [UserId], [GroupName], [Course], [Faculty], [Speciality], "
			"[StudentCardNumber], [EducationForm] "
			"FROM [dbo].[Student] WHERE [UserId] = :user_id"
		);
		studentQuery.bindValue(":user_id", userId);

		if (studentQuery.exec() && studentQuery.next()) {
			QJsonObject studentObj;
			studentObj["id"] = studentQuery.value("id").toInt();
			studentObj["user_id"] = studentQuery.value("UserId").toInt();
			studentObj["group_name"] = studentQuery.value("GroupName").toString();
			studentObj["course"] = studentQuery.value("Course").isNull()
				? QJsonValue()
				: QJsonValue(studentQuery.value("Course").toInt());
			studentObj["faculty"] = studentQuery.value("Faculty").toString();
			studentObj["speciality"] = studentQuery.value("Speciality").toString();
			studentObj["student_card_number"] = studentQuery.value("StudentCardNumber").toString();
			studentObj["education_form"] = studentQuery.value("EducationForm").toString();

			result["student"] = studentObj;
		}
	}
	else if (role == 2) {
		QSqlQuery teacherQuery(m_sql_context);
		teacherQuery.prepare(
			"SELECT [id], [UserId], [Department], [Post], [Cabinet], [AcademicDegree], [AcademicTitle] "
			"FROM [dbo].[Teacher] WHERE [UserId] = :user_id"
		);
		teacherQuery.bindValue(":user_id", userId);

		if (teacherQuery.exec() && teacherQuery.next()) {
			QJsonObject teacherObj;
			teacherObj["id"] = teacherQuery.value("id").toInt();
			teacherObj["user_id"] = teacherQuery.value("UserId").toInt();
			teacherObj["department"] = teacherQuery.value("Department").toString();
			teacherObj["post"] = teacherQuery.value("Post").toString();
			teacherObj["cabinet"] = teacherQuery.value("Cabinet").toString();
			teacherObj["academic_degree"] = teacherQuery.value("AcademicDegree").toString();
			teacherObj["academic_title"] = teacherQuery.value("AcademicTitle").toString();

			result["teacher"] = teacherObj;
		}
	}

	return result;
}

QJsonArray Db::getUserSessions(int userId, const QString& currentToken)
{
	QJsonArray sessions;

	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return sessions;
	}

	QSqlQuery query(m_sql_context);
	query.prepare(
		"SELECT [id], [UserId], [Token], [DeviceName], [Platform], [IpAddress], "
		"[CreatedAt], [LastActivityAt], [ExpiresAt], [IsRevoked] "
		"FROM [dbo].[UserSession] "
		"WHERE [UserId] = :user_id "
		"ORDER BY [CreatedAt] DESC"
	);
	query.bindValue(":user_id", userId);

	if (!query.exec()) {
		qWarning() << "getUserSessions query failed:" << query.lastError().text();
		return sessions;
	}

	while (query.next()) {
		QJsonObject s;

		const QString token = query.value("Token").toString();

		s["id"] = query.value("id").toInt();
		s["user_id"] = query.value("UserId").toInt();
		s["device_name"] = query.value("DeviceName").toString();
		s["platform"] = query.value("Platform").toString();
		s["ip_address"] = query.value("IpAddress").toString();
		s["created_at"] = query.value("CreatedAt").toDateTime().toString(Qt::ISODate);
		s["last_activity_at"] = query.value("LastActivityAt").toDateTime().toString(Qt::ISODate);
		s["expires_at"] = query.value("ExpiresAt").toDateTime().toString(Qt::ISODate);
		s["is_revoked"] = query.value("IsRevoked").toBool();
		s["is_current"] = token == currentToken;

		sessions.append(s);
	}

	return sessions;
}

bool Db::createUserSession(
	int userId,
	const QString& token,
	const QString& deviceName,
	const QString& platform,
	const QString& ipAddress,
	int expiresInSeconds
)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return false;
	}

	QSqlQuery query(m_sql_context);
	query.prepare(
		"INSERT INTO [dbo].[UserSession] "
		"([UserId], [Token], [DeviceName], [Platform], [IpAddress], [CreatedAt], [LastActivityAt], [ExpiresAt], [IsRevoked]) "
		"VALUES (:user_id, :token, :device_name, :platform, :ip_address, GETDATE(), GETDATE(), DATEADD(SECOND, :expires_in, GETDATE()), 0)"
	);

	query.bindValue(":user_id", userId);
	query.bindValue(":token", token);
	query.bindValue(":device_name", deviceName);
	query.bindValue(":platform", platform);
	query.bindValue(":ip_address", ipAddress);
	query.bindValue(":expires_in", expiresInSeconds);

	if (!query.exec()) {
		qWarning() << "createUserSession failed:" << query.lastError().text();
		return false;
	}

	return true;
}

bool Db::revokeUserSessionByToken(const QString& token)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return false;
	}

	QSqlQuery query(m_sql_context);
	query.prepare(
		"UPDATE [dbo].[UserSession] "
		"SET [IsRevoked] = 1, [LastActivityAt] = GETDATE() "
		"WHERE [Token] = :token"
	);
	query.bindValue(":token", token);

	if (!query.exec()) {
		qWarning() << "revokeUserSessionByToken failed:" << query.lastError().text();
		return false;
	}

	return true;
}

QJsonObject Db::addTableData(const QString& tableName, const QJsonObject& data)
{
	QJsonObject resp;

	if (!ensureOpen()) {
		resp["ok"] = false;
		resp["error"] = "database is not open";
		return resp;
	}

	if (!isSafeSqlIdentifier(tableName) || data.isEmpty()) {
		resp["ok"] = false;
		resp["error"] = "tableName/data is invalid";
		return resp;
	}

	QStringList columns;
	QStringList placeholders;
	QVariantMap bindValues;

	int index = 0;

	for (auto it = data.begin(); it != data.end(); ++it) {
		const QString column = it.key();

		if (!isSafeSqlIdentifier(column))
			continue;

		const QString placeholder = ":v" + QString::number(index++);

		columns << safeColumnName(column);
		placeholders << placeholder;
		bindValues[placeholder] = jsonValueToVariant(it.value());
	}

	if (columns.isEmpty()) {
		resp["ok"] = false;
		resp["error"] = "no valid columns";
		return resp;
	}

	const QString sql =
		"INSERT INTO " + safeTableName(tableName) +
		" (" + columns.join(", ") + ") "
		"OUTPUT INSERTED.[id] "
		"VALUES (" + placeholders.join(", ") + ")";

	QSqlQuery query(m_sql_context);
	query.prepare(sql);

	for (auto it = bindValues.begin(); it != bindValues.end(); ++it)
		query.bindValue(it.key(), it.value());

	if (!query.exec()) {
		resp["ok"] = false;
		resp["error"] = query.lastError().text();

		qWarning() << "addTableData error:" << query.lastError().text();
		qWarning() << "SQL:" << sql;

		return resp;
	}

	int insertedId = 0;

	if (query.next())
		insertedId = query.value(0).toInt();

	resp["ok"] = true;
	resp["id"] = insertedId;

	return resp;
}

QJsonObject Db::updateTableData(const QString& tableName, int id, const QJsonObject& data)
{
	QJsonObject resp;

	if (!ensureOpen()) {
		resp["ok"] = false;
		resp["error"] = "database is not open";
		return resp;
	}

	if (!isSafeSqlIdentifier(tableName) || id <= 0 || data.isEmpty()) {
		resp["ok"] = false;
		resp["error"] = "tableName/id/data is invalid";
		return resp;
	}

	QStringList setParts;
	QVariantMap bindValues;

	int index = 0;

	for (auto it = data.begin(); it != data.end(); ++it) {
		const QString column = it.key();

		if (!isSafeSqlIdentifier(column))
			continue;

		const QString placeholder = ":v" + QString::number(index++);

		setParts << safeColumnName(column) + " = " + placeholder;
		bindValues[placeholder] = jsonValueToVariant(it.value());
	}

	if (setParts.isEmpty()) {
		resp["ok"] = false;
		resp["error"] = "no valid columns";
		return resp;
	}

	const QString sql =
		"UPDATE " + safeTableName(tableName) + " "
		"SET " + setParts.join(", ") + " "
		"WHERE [id] = :id";

	QSqlQuery query(m_sql_context);
	query.prepare(sql);

	query.bindValue(":id", id);

	for (auto it = bindValues.begin(); it != bindValues.end(); ++it)
		query.bindValue(it.key(), it.value());

	if (!query.exec()) {
		resp["ok"] = false;
		resp["error"] = query.lastError().text();

		qWarning() << "updateTableData error:" << query.lastError().text();
		qWarning() << "SQL:" << sql;

		return resp;
	}

	resp["ok"] = true;
	resp["rows_affected"] = query.numRowsAffected();

	return resp;
}

QJsonObject Db::deleteTableData(const QString& tableName, int id)
{
	QJsonObject resp;

	if (!ensureOpen()) {
		resp["ok"] = false;
		resp["error"] = "database is not open";
		return resp;
	}

	if (!isSafeSqlIdentifier(tableName) || id <= 0) {
		resp["ok"] = false;
		resp["error"] = "tableName/id is invalid";
		return resp;
	}

	const QString sql =
		"DELETE FROM " + safeTableName(tableName) + " "
		"WHERE [id] = :id";

	QSqlQuery query(m_sql_context);
	query.prepare(sql);
	query.bindValue(":id", id);

	if (!query.exec()) {
		resp["ok"] = false;
		resp["error"] = query.lastError().text();

		qWarning() << "deleteTableData error:" << query.lastError().text();
		qWarning() << "SQL:" << sql;

		return resp;
	}

	const int rows = query.numRowsAffected();

	if (rows <= 0) {
		resp["ok"] = false;
		resp["error"] = "record was not deleted";
		resp["rows_affected"] = rows;
		return resp;
	}

	resp["ok"] = true;
	resp["rows_affected"] = rows;

	return resp;
}

int Db::getUserRole(int userId)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return 0;
	}

	QSqlQuery query(m_sql_context);
	query.prepare(
		"SELECT [Role] "
		"FROM [dbo].[User] "
		"WHERE [id] = :id"
	);
	query.bindValue(":id", userId);

	if (!query.exec()) {
		qWarning() << "getUserRole failed:" << query.lastError().text();
		return 0;
	}

	if (!query.next())
		return 0;

	return query.value(0).toInt();
}

QString Db::getUserFullName(int userId)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return {};
	}

	QSqlQuery query(m_sql_context);
	query.prepare(
		"SELECT "
		"LTRIM(RTRIM(CONCAT("
		"ISNULL([LastName], ''), ' ', "
		"ISNULL([Name], ''), ' ', "
		"ISNULL([MiddleName], '')"
		"))) AS [full_name] "
		"FROM [dbo].[User] "
		"WHERE [id] = :id"
	);
	query.bindValue(":id", userId);

	if (!query.exec()) {
		qWarning() << "getUserFullName failed:" << query.lastError().text();
		return {};
	}

	if (!query.next())
		return {};

	return query.value("full_name").toString();
}

QJsonObject Db::getTeacherShortInfo(int teacherId)
{
	QJsonObject obj;

	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return obj;
	}

	QSqlQuery query(m_sql_context);
	query.prepare(
		"SELECT "
		"t.[id], "
		"LTRIM(RTRIM(CONCAT("
		"ISNULL(u.[LastName], ''), ' ', "
		"ISNULL(u.[Name], ''), ' ', "
		"ISNULL(u.[MiddleName], '')"
		"))) AS [full_name], "
		"ISNULL(t.[Department], '') AS [department], "
		"ISNULL(t.[Cabinet], '') AS [cabinet] "
		"FROM [dbo].[Teacher] t "
		"JOIN [dbo].[User] u ON u.[id] = t.[UserId] "
		"WHERE t.[id] = :id"
	);
	query.bindValue(":id", teacherId);

	if (!query.exec()) {
		qWarning() << "getTeacherShortInfo failed:" << query.lastError().text();
		return obj;
	}

	if (!query.next())
		return obj;

	obj["idValue"] = query.value("id").toInt();
	obj["fullName"] = query.value("full_name").toString();
	obj["department"] = query.value("department").toString();
	obj["cabinet"] = query.value("cabinet").toString();

	return obj;
}

bool Db::canUserAccessRow(const QString& tableName, int rowId, int userId)
{
	if (!ensureOpen()) {
		qWarning() << "Database connection is not open!";
		return false;
	}

	if (rowId <= 0 || userId <= 0)
		return false;

	if (tableName == "Appointments") {
		const int role = getUserRole(userId);

		if (role == 3)
			return true;

		QSqlQuery query(m_sql_context);

		if (role == 1) {
			query.prepare(
				"SELECT COUNT(*) "
				"FROM [dbo].[Appointments] "
				"WHERE [id] = :id AND [user_id] = :user_id"
			);

			query.bindValue(":id", rowId);
			query.bindValue(":user_id", userId);
		}
		else if (role == 2) {
			query.prepare(
				"SELECT COUNT(*) "
				"FROM [dbo].[Appointments] a "
				"JOIN [dbo].[Teacher] t ON t.[id] = a.[teacher_id] "
				"WHERE a.[id] = :id AND t.[UserId] = :user_id"
			);

			query.bindValue(":id", rowId);
			query.bindValue(":user_id", userId);
		}
		else {
			return false;
		}

		if (!query.exec()) {
			qWarning() << "canUserAccessRow Appointments failed:" << query.lastError().text();
			return false;
		}

		if (!query.next())
			return false;

		return query.value(0).toInt() > 0;
	}

	if (tableName == "UserSession") {
		QSqlQuery query(m_sql_context);

		query.prepare(
			"SELECT COUNT(*) "
			"FROM [dbo].[UserSession] "
			"WHERE [id] = :id "
			"AND [UserId] = :user_id "
			"AND [IsRevoked] = 1"
		);

		query.bindValue(":id", rowId);
		query.bindValue(":user_id", userId);

		if (!query.exec()) {
			qWarning() << "canUserAccessRow UserSession failed:" << query.lastError().text();
			return false;
		}

		if (!query.next())
			return false;

		return query.value(0).toInt() > 0;
	}

	return false;
}
QString Db::getUserSessionTokenById(int userId, int sessionId)
{
	if (!ensureOpen())
		return {};

	QSqlQuery query(m_sql_context);
	query.prepare(
		"SELECT [Token] "
		"FROM [dbo].[UserSession] "
		"WHERE [id] = :session_id AND [UserId] = :user_id"
	);
	query.bindValue(":session_id", sessionId);
	query.bindValue(":user_id", userId);

	if (!query.exec()) {
		qWarning() << "getUserSessionTokenById failed:" << query.lastError().text();
		return {};
	}

	if (!query.next())
		return {};

	return query.value("Token").toString();
}

QStringList Db::getOtherUserSessionTokens(int userId, const QString& currentToken)
{
	QStringList tokens;

	if (!ensureOpen())
		return tokens;

	QSqlQuery query(m_sql_context);
	query.prepare(
		"SELECT [Token] "
		"FROM [dbo].[UserSession] "
		"WHERE [UserId] = :user_id "
		"AND [Token] <> :current_token "
		"AND [IsRevoked] = 0"
	);
	query.bindValue(":user_id", userId);
	query.bindValue(":current_token", currentToken);

	if (!query.exec()) {
		qWarning() << "getOtherUserSessionTokens failed:" << query.lastError().text();
		return tokens;
	}

	while (query.next())
		tokens << query.value("Token").toString();

	return tokens;
}

bool Db::revokeUserSessionById(int userId, int sessionId)
{
	if (!ensureOpen())
		return false;

	QSqlQuery query(m_sql_context);
	query.prepare(
		"UPDATE [dbo].[UserSession] "
		"SET [IsRevoked] = 1, [LastActivityAt] = GETDATE() "
		"WHERE [id] = :session_id AND [UserId] = :user_id"
	);
	query.bindValue(":session_id", sessionId);
	query.bindValue(":user_id", userId);

	if (!query.exec()) {
		qWarning() << "revokeUserSessionById failed:" << query.lastError().text();
		return false;
	}

	return query.numRowsAffected() > 0;
}

bool Db::revokeOtherUserSessions(int userId, const QString& currentToken)
{
	if (!ensureOpen())
		return false;

	QSqlQuery query(m_sql_context);
	query.prepare(
		"UPDATE [dbo].[UserSession] "
		"SET [IsRevoked] = 1, [LastActivityAt] = GETDATE() "
		"WHERE [UserId] = :user_id "
		"AND [Token] <> :current_token"
	);
	query.bindValue(":user_id", userId);
	query.bindValue(":current_token", currentToken);

	if (!query.exec()) {
		qWarning() << "revokeOtherUserSessions failed:" << query.lastError().text();
		return false;
	}

	return true;
}

QJsonObject Db::getAppointments(int userId)
{
	QJsonObject resp;
	resp["ok"] = false;
	resp["command"] = "get_appointments";
	resp["appointments"] = QJsonArray();
	resp["MyTable"] = QJsonArray();

	if (!m_sql_context.isOpen()) {
		if (!connectToDatabase()) {
			resp["error"] = "database is not open";
			return resp;
		}
	}

	const int role = getUserRole(userId);

	if (role <= 0) {
		resp["error"] = "unknown user role";
		return resp;
	}

	QString sql =
		"SELECT "
		"a.*, "
		"CONVERT(varchar(10), a.[appointment_date], 23) AS [appointment_date_text], "
		"CONVERT(varchar(5), a.[appointment_time], 108) AS [appointment_time_text], "

		"LTRIM(RTRIM(CONCAT("
		"ISNULL(tu.[LastName], ''), ' ', "
		"ISNULL(tu.[Name], ''), ' ', "
		"ISNULL(tu.[MiddleName], '')"
		"))) AS [teacherName], "

		"LTRIM(RTRIM(CONCAT("
		"ISNULL(su.[LastName], ''), ' ', "
		"ISNULL(su.[Name], ''), ' ', "
		"ISNULL(su.[MiddleName], '')"
		"))) AS [studentName], "

		"ISNULL(t.[Cabinet], '') AS [teacherCabinet] "

		"FROM [dbo].[Appointments] a "
		"LEFT JOIN [dbo].[Teacher] t ON t.[id] = a.[teacher_id] "
		"LEFT JOIN [dbo].[User] tu ON tu.[id] = t.[UserId] "
		"LEFT JOIN [dbo].[User] su ON su.[id] = a.[user_id] ";

	if (role == 1) {
		sql += "WHERE a.[user_id] = :user_id ";
	}
	else if (role == 2) {
		sql += "WHERE t.[UserId] = :user_id ";
	}

	sql += "ORDER BY a.[appointment_date] DESC, a.[appointment_time] DESC, a.[id] DESC";

	QSqlQuery query(m_sql_context);
	query.prepare(sql);

	if (role == 1 || role == 2)
		query.bindValue(":user_id", userId);

	if (!query.exec()) {
		resp["error"] = query.lastError().text();

		qWarning() << "getAppointments failed:" << query.lastError().text();
		qWarning() << "SQL:" << sql;

		return resp;
	}

	QJsonArray appointments;

	while (query.next()) {
		QSqlRecord record = query.record();

		auto valueByNames = [&](const QStringList& names) -> QVariant {
			for (const QString& name : names) {
				int idx = record.indexOf(name);

				if (idx >= 0)
					return query.value(idx);
			}

			return QVariant();
			};

		auto stringByNames = [&](const QStringList& names, const QString& fallback = "") -> QString {
			QVariant value = valueByNames(names);

			if (!value.isValid() || value.isNull())
				return fallback;

			return value.toString();
			};

		auto intByNames = [&](const QStringList& names, int fallback = 0) -> int {
			QVariant value = valueByNames(names);

			if (!value.isValid() || value.isNull())
				return fallback;

			bool ok = false;
			int n = value.toInt(&ok);

			return ok ? n : fallback;
			};

		auto boolByNames = [&](const QStringList& names, bool fallback = false) -> bool {
			QVariant value = valueByNames(names);

			if (!value.isValid() || value.isNull())
				return fallback;

			if (value.metaType().id() == QMetaType::Bool)
				return value.toBool();

			QString text = value.toString().trimmed().toLower();

			if (text == "1" || text == "true" || text == "yes" || text == "да")
				return true;

			if (text == "0" || text == "false" || text == "no" || text == "нет")
				return false;

			return value.toInt() != 0;
			};

		const int appointmentId = intByNames({
			"id",
			"ID",
			"appointmentId",
			"appointment_id"
			});

		const QString dateText = stringByNames({
			"appointment_date_text"
			});

		const QString timeText = stringByNames({
			"appointment_time_text"
			});

		const QString statusText = stringByNames({
			"status",
			"Status"
			});

		const QString statusLower = statusText.toLower();

		const bool isCanceled =
			boolByNames({
				"isCanceled",
				"IsCanceled",
				"is_cancelled",
				"is_canceled",
				"canceled",
				"cancelled",
				"Canceled",
				"Cancelled"
				}, false)
			|| statusLower.contains("отмен")
			|| statusLower.contains("cancel");

		const bool consultationPassed =
			boolByNames({
				"consultationPassed",
				"ConsultationPassed",
				"consultation_passed",
				"isPassed",
				"IsPassed",
				"passed",
				"Passed"
				}, false)
			|| statusLower.contains("прош")
			|| statusLower.contains("done")
			|| statusLower.contains("completed");

		QString cabinet = stringByNames({
			"cabinet",
			"Cabinet",
			"room",
			"Room"
			});

		if (cabinet.trimmed().isEmpty())
			cabinet = stringByNames({ "teacherCabinet" });

		QJsonObject item;

		item["appointmentId"] = appointmentId;
		item["taskId"] = appointmentId;

		item["appointment_date"] = dateText;
		item["appointment_time"] = timeText;

		item["date"] = dateText;
		item["time"] = timeText;

		item["user_id"] = intByNames({
			"user_id",
			"UserId",
			"student_user_id"
			});

		item["teacher_id"] = intByNames({
			"teacher_id",
			"TeacherId",
			"teacherId"
			});

		item["title"] = stringByNames({
			"title",
			"Title",
			"topic",
			"Topic",
			"theme",
			"Theme",
			"subject",
			"Subject"
			});

		item["description"] = stringByNames({
			"description",
			"Description",
			"comment",
			"Comment",
			"comments",
			"Comments"
			});

		item["cabinet"] = cabinet;

		item["durationMinutes"] = intByNames({
			"durationMinutes",
			"DurationMinutes",
			"duration_minutes",
			"duration",
			"Duration",
			"minutes",
			"Minutes"
			}, 30);

		item["isCanceled"] = isCanceled;
		item["consultationPassed"] = consultationPassed;

		item["rating"] = intByNames({
			"rating",
			"Rating",
			"mark",
			"Mark",
			"grade",
			"Grade"
			}, 0);

		item["teacherName"] = stringByNames({
			"teacherName"
			});

		item["studentName"] = stringByNames({
			"studentName"
			});

		item["status"] = statusText;

		item["cancelledByRole"] = intByNames({
			"cancelledByRole",
			"CancelledByRole",
			"canceledByRole",
			"CanceledByRole",
			"cancelled_by_role",
			"canceled_by_role"
			}, 0);

		item["cancelledByText"] = stringByNames({
			"cancelledByText",
			"CancelledByText",
			"canceledByText",
			"CanceledByText",
			"cancelled_by_text",
			"canceled_by_text",
			"cancelledBy",
			"canceledBy"
			});

		qDebug() << "Appointment:"
			<< "id =" << appointmentId
			<< "date =" << dateText
			<< "time =" << timeText;

		appointments.append(item);
	}

	resp["ok"] = true;
	resp["appointments"] = appointments;
	resp["MyTable"] = appointments;

	return resp;
}

QJsonObject Db::cancelAppointment(int userId, int appointmentId)
{
	QJsonObject resp;
	resp["command"] = "cancel_appointment";

	if (!ensureOpen()) {
		resp["ok"] = false;
		resp["error"] = "database is not open";
		return resp;
	}

	if (userId <= 0 || appointmentId <= 0) {
		resp["ok"] = false;
		resp["error"] = "invalid userId/appointmentId";
		return resp;
	}

	if (!canUserAccessRow("Appointments", appointmentId, userId)) {
		resp["ok"] = false;
		resp["error"] = "access denied";
		return resp;
	}

	const int role = getUserRole(userId);
	const QString cancelText = roleToCancelText(role);

	const QHash<QString, QString> columns = getTableColumnMap(m_sql_context, "Appointments");

	QStringList setParts;
	QVariantMap values;

	addUpdatePartIfColumnExists(
		setParts,
		values,
		columns,
		{ "IsCanceled", "isCanceled", "isCancelled", "IsCancelled", "Canceled", "canceled", "Cancelled", "cancelled" },
		":is_canceled",
		true
	);

	addUpdatePartIfColumnExists(
		setParts,
		values,
		columns,
		{ "Status", "status" },
		":status",
		"Отменена"
	);

	addUpdatePartIfColumnExists(
		setParts,
		values,
		columns,
		{ "CancelledByRole", "cancelledByRole", "CanceledByRole", "canceledByRole", "cancelled_by_role", "canceled_by_role" },
		":cancelled_by_role",
		role
	);

	addUpdatePartIfColumnExists(
		setParts,
		values,
		columns,
		{ "CancelledByText", "cancelledByText", "CanceledByText", "canceledByText", "cancelled_by_text", "canceled_by_text", "CancelledBy", "CanceledBy" },
		":cancelled_by_text",
		cancelText
	);

	if (setParts.isEmpty()) {
		resp["ok"] = false;
		resp["error"] = "no cancel columns found in Appointments";
		return resp;
	}

	const QString sql =
		"UPDATE [dbo].[Appointments] "
		"SET " + setParts.join(", ") + " "
		"WHERE [id] = :id";

	QSqlQuery query(m_sql_context);
	query.prepare(sql);
	query.bindValue(":id", appointmentId);

	for (auto it = values.begin(); it != values.end(); ++it)
		query.bindValue(it.key(), it.value());

	if (!query.exec()) {
		resp["ok"] = false;
		resp["error"] = query.lastError().text();

		qWarning() << "cancelAppointment failed:" << query.lastError().text();
		qWarning() << "SQL:" << sql;

		return resp;
	}

	resp["ok"] = true;
	resp["rows_affected"] = query.numRowsAffected();

	return resp;
}

QJsonObject Db::rateAppointment(int userId, int appointmentId, int rating)
{
	QJsonObject resp;
	resp["command"] = "rate_appointment";

	if (!ensureOpen()) {
		resp["ok"] = false;
		resp["error"] = "database is not open";
		return resp;
	}

	if (userId <= 0 || appointmentId <= 0) {
		resp["ok"] = false;
		resp["error"] = "invalid userId/appointmentId";
		return resp;
	}

	if (rating < 1 || rating > 5) {
		resp["ok"] = false;
		resp["error"] = "rating must be from 1 to 5";
		return resp;
	}

	if (!canUserAccessRow("Appointments", appointmentId, userId)) {
		resp["ok"] = false;
		resp["error"] = "access denied";
		return resp;
	}

	const QHash<QString, QString> columns = getTableColumnMap(m_sql_context, "Appointments");
	const QString ratingColumn = findColumn(columns, {
		"Rating",
		"rating",
		"Mark",
		"mark",
		"Grade",
		"grade"
		});

	if (ratingColumn.isEmpty()) {
		resp["ok"] = false;
		resp["error"] = "rating column not found in Appointments";
		return resp;
	}

	const QString sql =
		"UPDATE [dbo].[Appointments] "
		"SET " + safeColumnName(ratingColumn) + " = :rating "
		"WHERE [id] = :id";

	QSqlQuery query(m_sql_context);
	query.prepare(sql);
	query.bindValue(":rating", rating);
	query.bindValue(":id", appointmentId);

	if (!query.exec()) {
		resp["ok"] = false;
		resp["error"] = query.lastError().text();

		qWarning() << "rateAppointment failed:" << query.lastError().text();
		qWarning() << "SQL:" << sql;

		return resp;
	}

	resp["ok"] = true;
	resp["rows_affected"] = query.numRowsAffected();

	return resp;
}

QJsonObject Db::getTeachers()
{
	QJsonObject resp;
	resp["command"] = "get_teachers";

	if (!ensureOpen()) {
		resp["ok"] = false;
		resp["error"] = "database is not open";
		resp["teachers"] = QJsonArray();
		return resp;
	}

	QSqlQuery query(m_sql_context);
	query.prepare(
		"SELECT "
		"t.[id], "
		"t.[UserId], "
		"LTRIM(RTRIM(CONCAT(ISNULL(u.[LastName], ''), ' ', ISNULL(u.[Name], ''), ' ', ISNULL(u.[MiddleName], '')))) AS [full_name], "
		"ISNULL(t.[Department], '') AS [department], "
		"ISNULL(t.[Post], '') AS [post], "
		"ISNULL(t.[Cabinet], '') AS [cabinet], "
		"ISNULL(t.[AcademicDegree], '') AS [academic_degree], "
		"ISNULL(t.[AcademicTitle], '') AS [academic_title] "
		"FROM [dbo].[Teacher] t "
		"JOIN [dbo].[User] u ON u.[id] = t.[UserId] "
		"ORDER BY [full_name]"
	);

	if (!query.exec()) {
		resp["ok"] = false;
		resp["error"] = query.lastError().text();
		resp["teachers"] = QJsonArray();

		qWarning() << "getTeachers failed:" << query.lastError().text();

		return resp;
	}

	QJsonArray teachers;

	while (query.next()) {
		QJsonObject t;

		t["id"] = query.value("id").toInt();
		t["idValue"] = query.value("id").toInt();
		t["user_id"] = query.value("UserId").toInt();
		t["fullName"] = query.value("full_name").toString();
		t["full_name"] = query.value("full_name").toString();
		t["department"] = query.value("department").toString();
		t["post"] = query.value("post").toString();
		t["cabinet"] = query.value("cabinet").toString();
		t["academic_degree"] = query.value("academic_degree").toString();
		t["academic_title"] = query.value("academic_title").toString();

		teachers.append(t);
	}

	resp["ok"] = true;
	resp["teachers"] = teachers;
	resp["MyTable"] = teachers;

	return resp;
}



QJsonObject Db::getTableForClient(const QString& tableName)
{
	QJsonObject resp;

	resp["command"] = "get_table";
	resp["table_name"] = tableName;

	if (!ensureOpen()) {
		resp["ok"] = false;
		resp["error"] = "database is not open";
		resp["MyTable"] = QJsonArray();
		return resp;
	}

	if (!isSafeSqlIdentifier(tableName)) {
		resp["ok"] = false;
		resp["error"] = "invalid table name";
		resp["MyTable"] = QJsonArray();
		return resp;
	}

	table_data data = getTableValues(tableName);
	QJsonObject json = toJson(data);

	resp["ok"] = true;
	resp["MyTable"] = json["MyTable"].toArray();

	return resp;
}

QJsonObject Db::getTableForClient(const QString& tableName, int userId)
{
	if (tableName == "Appointments")
		return getAppointments(userId);

	if (tableName == "Teachers" || tableName == "Teacher")
		return getTeachers();

	QJsonObject resp = getTableForClient(tableName);

	resp["command"] = "get_table";
	resp["table_name"] = tableName;

	return resp;
}

static QVariant jsonStringOrNull(const QJsonObject& obj, const QString& key)
{
	if (!obj.contains(key))
		return QVariant();

	const QJsonValue value = obj.value(key);

	if (value.isNull() || value.isUndefined())
		return QVariant();

	const QString text = value.toString().trimmed();

	if (text.isEmpty())
		return QVariant();

	return text;
}

static QVariant jsonIntOrNull(const QJsonObject& obj, const QString& key)
{
	if (!obj.contains(key))
		return QVariant();

	const QJsonValue value = obj.value(key);

	if (value.isNull() || value.isUndefined())
		return QVariant();

	if (value.isDouble())
		return value.toInt();

	const QString text = value.toString().trimmed();

	if (text.isEmpty())
		return QVariant();

	bool ok = false;
	const int result = text.toInt(&ok);

	if (!ok)
		return QVariant();

	return result;
}

QJsonObject Db::createUserWithRoleData(const QJsonObject& userData,
	const QJsonObject& studentData,
	const QJsonObject& teacherData)
{
	QJsonObject resp;
	resp["command"] = "create_user";

	if (!ensureOpen()) {
		resp["ok"] = false;
		resp["error"] = "database is not open";
		return resp;
	}

	const QString login = userData.value("Login").toString().trimmed();
	const QString password = userData.value("Password").toString();
	const QString name = userData.value("Name").toString().trimmed();
	const QString lastName = userData.value("LastName").toString().trimmed();
	const int role = userData.value("Role").toInt();

	if (login.isEmpty() || password.isEmpty() || name.isEmpty() || lastName.isEmpty()) {
		resp["ok"] = false;
		resp["error"] = "login, password, name and lastname are required";
		return resp;
	}

	if (role < 1 || role > 3) {
		resp["ok"] = false;
		resp["error"] = "invalid role";
		return resp;
	}

	if (!m_sql_context.transaction()) {
		resp["ok"] = false;
		resp["error"] = "failed to start transaction";
		return resp;
	}

	int newUserId = 0;

	{
		QSqlQuery query(m_sql_context);

		query.prepare(
			"INSERT INTO [dbo].[User] "
			"([Login], [Password], [Name], [LastName], [MiddleName], [Age], [Role], [Post], [BirthDate], [Gender], [Phone]) "
			"OUTPUT INSERTED.[id] "
			"VALUES "
			"(:login, :password, :name, :last_name, :middle_name, :age, :role, :post, :birth_date, :gender, :phone)"
		);

		query.bindValue(":login", login);
		query.bindValue(":password", password);
		query.bindValue(":name", name);
		query.bindValue(":last_name", lastName);
		query.bindValue(":middle_name", jsonStringOrNull(userData, "MiddleName"));
		query.bindValue(":age", jsonIntOrNull(userData, "Age"));
		query.bindValue(":role", role);
		query.bindValue(":post", jsonStringOrNull(userData, "Post"));
		query.bindValue(":birth_date", jsonStringOrNull(userData, "BirthDate"));
		query.bindValue(":gender", jsonStringOrNull(userData, "Gender"));
		query.bindValue(":phone", jsonStringOrNull(userData, "Phone"));

		if (!query.exec()) {
			m_sql_context.rollback();

			resp["ok"] = false;
			resp["error"] = query.lastError().text();

			qWarning() << "createUserWithRoleData User insert failed:" << query.lastError().text();

			return resp;
		}

		if (!query.next()) {
			m_sql_context.rollback();

			resp["ok"] = false;
			resp["error"] = "failed to get inserted user id";
			return resp;
		}

		newUserId = query.value(0).toInt();
	}

	if (role == 1) {
		QSqlQuery query(m_sql_context);

		query.prepare(
			"INSERT INTO [dbo].[Student] "
			"([UserId], [GroupName], [Course], [Faculty], [Speciality], [StudentCardNumber], [EducationForm]) "
			"VALUES "
			"(:user_id, :group_name, :course, :faculty, :speciality, :card_number, :education_form)"
		);

		query.bindValue(":user_id", newUserId);
		query.bindValue(":group_name", jsonStringOrNull(studentData, "GroupName"));
		query.bindValue(":course", jsonIntOrNull(studentData, "Course"));
		query.bindValue(":faculty", jsonStringOrNull(studentData, "Faculty"));
		query.bindValue(":speciality", jsonStringOrNull(studentData, "Speciality"));
		query.bindValue(":card_number", jsonStringOrNull(studentData, "StudentCardNumber"));
		query.bindValue(":education_form", jsonStringOrNull(studentData, "EducationForm"));

		if (!query.exec()) {
			m_sql_context.rollback();

			resp["ok"] = false;
			resp["error"] = query.lastError().text();

			qWarning() << "createUserWithRoleData Student insert failed:" << query.lastError().text();

			return resp;
		}
	}

	if (role == 2) {
		QSqlQuery query(m_sql_context);

		query.prepare(
			"INSERT INTO [dbo].[Teacher] "
			"([UserId], [Department], [Post], [Cabinet], [AcademicDegree], [AcademicTitle]) "
			"VALUES "
			"(:user_id, :department, :post, :cabinet, :academic_degree, :academic_title)"
		);

		query.bindValue(":user_id", newUserId);
		query.bindValue(":department", jsonStringOrNull(teacherData, "Department"));
		query.bindValue(":post", jsonStringOrNull(teacherData, "Post"));
		query.bindValue(":cabinet", jsonStringOrNull(teacherData, "Cabinet"));
		query.bindValue(":academic_degree", jsonStringOrNull(teacherData, "AcademicDegree"));
		query.bindValue(":academic_title", jsonStringOrNull(teacherData, "AcademicTitle"));

		if (!query.exec()) {
			m_sql_context.rollback();

			resp["ok"] = false;
			resp["error"] = query.lastError().text();

			qWarning() << "createUserWithRoleData Teacher insert failed:" << query.lastError().text();

			return resp;
		}
	}

	if (!m_sql_context.commit()) {
		m_sql_context.rollback();

		resp["ok"] = false;
		resp["error"] = "failed to commit transaction";
		return resp;
	}

	resp["ok"] = true;
	resp["user_id"] = newUserId;
	resp["role"] = role;

	return resp;
}


bool Db::resetPasswordByEmail(const QString& email, const QString& newPassword)
{
	if (!ensureOpen()) {
		qWarning() << "resetPasswordByEmail error: database is not open";
		return false;
	}

	const QString normalizedEmail = email.trimmed().toLower();

	if (normalizedEmail.isEmpty() || newPassword.isEmpty()) {
		qWarning() << "resetPasswordByEmail error: email/password is empty";
		return false;
	}

	QSqlQuery query(m_sql_context);

	query.prepare(
		"UPDATE [dbo].[User] "
		"SET [Password] = :password "
		"WHERE LOWER([Login]) = LOWER(:email)"
	);

	query.bindValue(":password", newPassword);
	query.bindValue(":email", normalizedEmail);

	if (!query.exec()) {
		qWarning() << "resetPasswordByEmail error:" << query.lastError().text();
		return false;
	}

	const int affected = query.numRowsAffected();

	if (affected <= 0) {
		qWarning() << "resetPasswordByEmail: user not found by email/login:" << normalizedEmail;
		return false;
	}

	return true;
}






bool Db::changePasswordByUserId(int userId, const QString& oldPassword, const QString& newPassword)
{
	if (!ensureOpen())
		return false;

	QSqlQuery checkQuery(m_sql_context);

	checkQuery.prepare(
		"SELECT COUNT(*) "
		"FROM [dbo].[User] "
		"WHERE [id] = :id AND [Password] = :old_password"
	);

	checkQuery.bindValue(":id", userId);
	checkQuery.bindValue(":old_password", oldPassword);

	if (!checkQuery.exec()) {
		qWarning() << "changePasswordByUserId check error:" << checkQuery.lastError().text();
		return false;
	}

	if (!checkQuery.next() || checkQuery.value(0).toInt() <= 0)
		return false;

	QSqlQuery updateQuery(m_sql_context);

	updateQuery.prepare(
		"UPDATE [dbo].[User] "
		"SET [Password] = :new_password "
		"WHERE [id] = :id"
	);

	updateQuery.bindValue(":new_password", newPassword);
	updateQuery.bindValue(":id", userId);

	if (!updateQuery.exec()) {
		qWarning() << "changePasswordByUserId update error:" << updateQuery.lastError().text();
		return false;
	}

	return updateQuery.numRowsAffected() > 0;
}