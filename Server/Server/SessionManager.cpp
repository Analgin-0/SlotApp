#include "SessionManager.h"
#include <Db.h>


SessionManager::SessionManager(QObject* parent)
	: QObject(parent)
{

	if (Db::get()== nullptr)
	{
		qDebug() << "Error: SessionManager requires Db instance to be initialized first.";
		return;
	}
	
	auto sessions = Db::get()->getTableValues("UserSession");

	for (auto values : sessions)
	{
		
		if (not get_constexpr<bool>("IsRevoked", values))
		{
			 auto token = get_constexpr<QString>("Token", values);
			 auto userId = get_constexpr<int>("UserId", values);

			 //qDebug() << "Restoring session for token:" << token;
			 //qDebug() << "Restoring session for userId:" << userId;
			 SessionData s;
			 s.expiresAtUtc = QDateTime::currentDateTimeUtc().addMonths(12);
			 s.userId = userId;
			 m_sessions.insert(tokenHash(token), s);
		}
		
	}

}

QString SessionManager::generateToken() const
{
	QByteArray raw;
	raw.reserve(32);

	auto* rng = QRandomGenerator::system();
	for (int i = 0; i < 4; ++i) {
		const quint64 value = rng->generate64();
		raw.append(reinterpret_cast<const char*>(&value), sizeof(value));
	}

	return QString::fromLatin1(
		raw.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals)
	);
}

QByteArray SessionManager::tokenHash(const QString& token) const
{
	return QCryptographicHash::hash(token.toUtf8(), QCryptographicHash::Sha256);
}

QString SessionManager::createSession(int userId, int ttlSeconds)
{
	const QString token = generateToken();

	SessionData s;
	s.userId = userId;
	s.expiresAtUtc = QDateTime::currentDateTimeUtc().addSecs(ttlSeconds);

	m_sessions.insert(tokenHash(token), s);
	return token;
}

bool SessionManager::validateToken(const QString& token, int* userId)
{
	cleanupExpired();

	if (token.isEmpty())
		return false;

	const QByteArray key = tokenHash(token);
	auto it = m_sessions.find(key);
	if (it == m_sessions.end())
		return false;

	if (it->expiresAtUtc < QDateTime::currentDateTimeUtc()) {
		m_sessions.erase(it);
		return false;
	}

	if (userId)
		*userId = it->userId;

	return true;
}

void SessionManager::removeSession(const QString& token)
{
	if (!token.isEmpty())
		m_sessions.remove(tokenHash(token));
}

void SessionManager::cleanupExpired()
{
	const QDateTime now = QDateTime::currentDateTimeUtc();

	for (auto it = m_sessions.begin(); it != m_sessions.end(); ) {
		if (it->expiresAtUtc < now)
			it = m_sessions.erase(it);
		else
			++it;
	}
}