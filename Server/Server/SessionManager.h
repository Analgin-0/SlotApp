#pragma once

#include <QObject>
#include <QHash>
#include <QDateTime>
#include <QCryptographicHash>
#include <QRandomGenerator>

struct SessionData
{
	int userId = -1;
	QDateTime expiresAtUtc;
};

class SessionManager : public QObject
{
	Q_OBJECT
public:

	// delete
	SessionManager(SessionManager&) = delete;
	SessionManager(SessionManager&&) = delete;

	SessionManager& operator=(SessionManager&) = delete;
	SessionManager& operator=(SessionManager&&) = delete;


	explicit SessionManager(QObject* parent = nullptr);

	QString createSession(int userId, int ttlSeconds = 24 * 60 * 60);
	bool validateToken(const QString& token, int* userId = nullptr);
	void removeSession(const QString& token);
	void cleanupExpired();

private:
	QString generateToken() const;
	QByteArray tokenHash(const QString& token) const;

private:
	QHash<QByteArray, SessionData> m_sessions;
};
