#pragma once

#include <QObject>
#include <QSslSocket>
#include <QSslError>
#include <QTimer>
#include <QString>
#include <QStringList>

class EmailSender : public QObject
{
	Q_OBJECT

public:
	struct Config
	{
		QString host;        
		quint16 port = 465;  

		QString username;    // email/логин SMTP
		QString password;    // пароль приложения SMTP

		QString fromEmail;   // от кого
		QString fromName;    // имя отправителя

		int timeoutMs = 15000;
	};

	explicit EmailSender(const Config& config, QObject* parent = nullptr);

	bool isBusy() const;

	void send(
		const QString& toEmail,
		const QString& subject,
		const QString& text
	);


	int createCode();

signals:
	void finished(bool ok, const QString& message);

private slots:
	void onEncrypted();
	void onReadyRead();
	void onSocketError(QAbstractSocket::SocketError error);
	void onSslErrors(const QList<QSslError>& errors);
	void onTimeout();

private:
	enum class Step
	{
		Idle,
		WaitGreeting,
		WaitEhlo,
		WaitAuthLogin,
		WaitUsername,
		WaitPassword,
		WaitMailFrom,
		WaitRcptTo,
		WaitData,
		WaitBodyAccepted,
		WaitQuit
	};

private:
	Config m_config;

	QSslSocket* m_socket = nullptr;
	QTimer* m_timeoutTimer = nullptr;

	Step m_step = Step::Idle;
	bool m_busy = false;

	QByteArray m_buffer;
	QStringList m_responseLines;

	QString m_toEmail;
	QString m_subject;
	QString m_text;

private:
	void resetState();
	void startTimeout();
	void stopTimeout();

	void writeLine(const QString& line);
	void writeRaw(const QByteArray& data);

	void handleSmtpResponse(int code, const QString& response);

	void finishOk(const QString& message);
	void finishFail(const QString& message);

	QByteArray buildMessageData() const;
	QByteArray buildBodyData(const QString& text) const;

	static QString encodeHeaderUtf8(const QString& text);
	static QString cleanHeaderText(const QString& text);
	static QString extractEmailAddress(const QString& value);
};