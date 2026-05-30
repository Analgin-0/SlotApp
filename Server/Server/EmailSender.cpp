#include "EmailSender.h"

#include <QDateTime>
#include <QRandomGenerator>
#include <QDebug>

EmailSender::EmailSender(const Config& config, QObject* parent)
	: QObject(parent)
	, m_config(config)
	, m_socket(new QSslSocket(this))
	, m_timeoutTimer(new QTimer(this))
{
	m_timeoutTimer->setSingleShot(true);
	m_timeoutTimer->setInterval(m_config.timeoutMs);

	connect(m_timeoutTimer, &QTimer::timeout,
		this, &EmailSender::onTimeout);

	connect(m_socket, &QSslSocket::encrypted,
		this, &EmailSender::onEncrypted);

	connect(m_socket, &QSslSocket::readyRead,
		this, &EmailSender::onReadyRead);

	connect(m_socket, &QSslSocket::errorOccurred,
		this, &EmailSender::onSocketError);

	connect(m_socket, &QSslSocket::sslErrors,
		this, &EmailSender::onSslErrors);
}

bool EmailSender::isBusy() const
{
	return m_busy;
}

void EmailSender::send(
	const QString& toEmail,
	const QString& subject,
	const QString& text
)
{
	if (m_busy) {
		emit finished(false, "EmailSender уже отправляет письмо.");
		return;
	}

	if (m_config.host.trimmed().isEmpty()) {
		emit finished(false, "SMTP host не указан.");
		return;
	}

	if (m_config.username.trimmed().isEmpty()) {
		emit finished(false, "SMTP username не указан.");
		return;
	}

	if (m_config.password.isEmpty()) {
		emit finished(false, "SMTP password не указан.");
		return;
	}

	if (m_config.fromEmail.trimmed().isEmpty()) {
		emit finished(false, "Email отправителя не указан.");
		return;
	}

	const QString cleanTo = extractEmailAddress(toEmail);

	if (cleanTo.isEmpty() || !cleanTo.contains("@")) {
		emit finished(false, "Некорректный email получателя.");
		return;
	}

	resetState();

	m_busy = true;
	m_step = Step::WaitGreeting;

	m_toEmail = cleanTo;
	m_subject = subject;
	m_text = text;

	qDebug() << "EmailSender: connecting to SMTP"
		<< m_config.host
		<< m_config.port;

	startTimeout();
	m_socket->connectToHostEncrypted(m_config.host, m_config.port);
}

void EmailSender::resetState()
{
	stopTimeout();

	m_buffer.clear();
	m_responseLines.clear();

	m_toEmail.clear();
	m_subject.clear();
	m_text.clear();

	m_step = Step::Idle;

	if (m_socket->state() != QAbstractSocket::UnconnectedState)
		m_socket->abort();
}

void EmailSender::startTimeout()
{
	m_timeoutTimer->start(m_config.timeoutMs);
}

void EmailSender::stopTimeout()
{
	m_timeoutTimer->stop();
}

void EmailSender::onEncrypted()
{
	qDebug() << "EmailSender: SSL encrypted connection established";
	startTimeout();
}

void EmailSender::onReadyRead()
{
	if (!m_busy)
		return;

	m_buffer += m_socket->readAll();

	while (true) {
		const int lfIndex = m_buffer.indexOf('\n');

		if (lfIndex < 0)
			break;

		QByteArray rawLine = m_buffer.left(lfIndex);
		m_buffer.remove(0, lfIndex + 1);

		if (rawLine.endsWith('\r'))
			rawLine.chop(1);

		const QString line = QString::fromUtf8(rawLine);

		if (line.length() < 3)
			continue;

		bool codeOk = false;
		const int code = line.left(3).toInt(&codeOk);

		if (!codeOk)
			continue;

		m_responseLines.append(line);

		const bool responseCompleted =
			line.length() < 4 || line.at(3) == QLatin1Char(' ');

		if (!responseCompleted)
			continue;

		const QString response = m_responseLines.join("\n");
		m_responseLines.clear();

		handleSmtpResponse(code, response);

		if (!m_busy)
			return;
	}
}

void EmailSender::handleSmtpResponse(int code, const QString& response)
{
	startTimeout();

	switch (m_step) {
	case Step::WaitGreeting:
		if (code != 220) {
			finishFail("SMTP greeting error: " + response);
			return;
		}

		m_step = Step::WaitEhlo;
		writeLine("EHLO localhost");
		return;

	case Step::WaitEhlo:
		if (code != 250) {
			finishFail("SMTP EHLO error: " + response);
			return;
		}

		m_step = Step::WaitAuthLogin;
		writeLine("AUTH LOGIN");
		return;

	case Step::WaitAuthLogin:
		if (code != 334) {
			finishFail("SMTP AUTH LOGIN error: " + response);
			return;
		}

		m_step = Step::WaitUsername;
		writeLine(QString::fromLatin1(m_config.username.toUtf8().toBase64()));
		return;

	case Step::WaitUsername:
		if (code != 334) {
			finishFail("SMTP username error: " + response);
			return;
		}

		m_step = Step::WaitPassword;
		writeLine(QString::fromLatin1(m_config.password.toUtf8().toBase64()));
		return;

	case Step::WaitPassword:
		if (code != 235) {
			finishFail("SMTP password/auth error: " + response);
			return;
		}

		m_step = Step::WaitMailFrom;
		writeLine("MAIL FROM:<" + extractEmailAddress(m_config.fromEmail) + ">");
		return;

	case Step::WaitMailFrom:
		if (code != 250) {
			finishFail("SMTP MAIL FROM error: " + response);
			return;
		}

		m_step = Step::WaitRcptTo;
		writeLine("RCPT TO:<" + m_toEmail + ">");
		return;

	case Step::WaitRcptTo:
		if (code != 250 && code != 251) {
			finishFail("SMTP RCPT TO error: " + response);
			return;
		}

		m_step = Step::WaitData;
		writeLine("DATA");
		return;

	case Step::WaitData:
		if (code != 354) {
			finishFail("SMTP DATA error: " + response);
			return;
		}

		m_step = Step::WaitBodyAccepted;

		{
			QByteArray message = buildMessageData();
			message += "\r\n.\r\n";
			writeRaw(message);
		}

		return;

	case Step::WaitBodyAccepted:
		if (code != 250) {
			finishFail("SMTP body accept error: " + response);
			return;
		}

		m_step = Step::WaitQuit;
		writeLine("QUIT");
		return;

	case Step::WaitQuit:
		finishOk("Письмо успешно отправлено.");
		return;

	case Step::Idle:
	default:
		return;
	}
}

void EmailSender::writeLine(const QString& line)
{
	if (!m_busy || !m_socket)
		return;

	QByteArray data = line.toUtf8();
	data += "\r\n";

	m_socket->write(data);
	m_socket->flush();

	startTimeout();
}

void EmailSender::writeRaw(const QByteArray& data)
{
	if (!m_busy || !m_socket)
		return;

	m_socket->write(data);
	m_socket->flush();

	startTimeout();
}

QByteArray EmailSender::buildMessageData() const
{
	const QString fromAddress = extractEmailAddress(m_config.fromEmail);
	const QString toAddress = extractEmailAddress(m_toEmail);

	QString fromHeader;

	if (m_config.fromName.trimmed().isEmpty()) {
		fromHeader = "<" + fromAddress + ">";
	}
	else {
		fromHeader = encodeHeaderUtf8(m_config.fromName) + " <" + fromAddress + ">";
	}

	const QString messageId =
		QString("<%1.%2@%3>")
		.arg(QDateTime::currentMSecsSinceEpoch())
		.arg(QRandomGenerator::global()->generate())
		.arg(m_config.host);

	QStringList headers;
	headers << "Date: " + QDateTime::currentDateTimeUtc().toString(Qt::RFC2822Date);
	headers << "From: " + fromHeader;
	headers << "To: <" + toAddress + ">";
	headers << "Subject: " + encodeHeaderUtf8(m_subject);
	headers << "Message-ID: " + messageId;
	headers << "MIME-Version: 1.0";
	headers << "Content-Type: text/plain; charset=UTF-8";
	headers << "Content-Transfer-Encoding: 8bit";
	headers << "";

	QByteArray result = headers.join("\r\n").toUtf8();
	result += buildBodyData(m_text);

	return result;
}

QByteArray EmailSender::buildBodyData(const QString& text) const
{
	QString normalized = text;
	normalized.replace("\r\n", "\n");
	normalized.replace("\r", "\n");

	QStringList lines = normalized.split('\n');

	for (int i = 0; i < lines.size(); ++i) {
		if (lines[i].startsWith('.'))
			lines[i].prepend('.');
	}

	return lines.join("\r\n").toUtf8();
}

QString EmailSender::encodeHeaderUtf8(const QString& text)
{
	const QString clean = cleanHeaderText(text);

	if (clean.isEmpty())
		return "";

	return "=?UTF-8?B?" + QString::fromLatin1(clean.toUtf8().toBase64()) + "?=";
}

QString EmailSender::cleanHeaderText(const QString& text)
{
	QString result = text;
	result.remove('\r');
	result.remove('\n');
	return result.trimmed();
}

QString EmailSender::extractEmailAddress(const QString& value)
{
	QString s = value.trimmed();
	s.remove('\r');
	s.remove('\n');

	const int left = s.indexOf('<');
	const int right = s.indexOf('>');

	if (left >= 0 && right > left)
		return s.mid(left + 1, right - left - 1).trimmed();

	return s;
}

void EmailSender::onSocketError(QAbstractSocket::SocketError error)
{
	Q_UNUSED(error);

	if (!m_busy)
		return;

	finishFail("Ошибка SMTP-сокета: " + m_socket->errorString());
}

void EmailSender::onSslErrors(const QList<QSslError>& errors)
{
	if (!m_busy)
		return;

	QStringList texts;

	for (const QSslError& e : errors)
		texts << e.errorString();

	finishFail("SSL ошибка SMTP: " + texts.join("; "));
}

void EmailSender::onTimeout()
{
	if (!m_busy)
		return;

	finishFail("Превышено время ожидания SMTP-сервера.");
}

void EmailSender::finishOk(const QString& message)
{
	if (!m_busy)
		return;

	m_busy = false;
	stopTimeout();

	if (m_socket)
		m_socket->disconnectFromHost();

	m_step = Step::Idle;

	emit finished(true, message);
}

void EmailSender::finishFail(const QString& message)
{
	if (!m_busy)
		return;

	qWarning() << "EmailSender error:" << message;

	m_busy = false;
	stopTimeout();

	if (m_socket)
		m_socket->abort();

	m_step = Step::Idle;

	emit finished(false, message);
}

#include <random>

int EmailSender::createCode()
{
	std::random_device rd;
	std::mt19937 gen(rd());

	std::uniform_int_distribution<> dt(1000, 9999);
	return dt(gen);
}
