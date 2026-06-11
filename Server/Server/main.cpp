#include <EmailSender.h>
#include <QtCore/QCoreApplication>
#include <QDebug>          
#include <QJsonDocument>
#include <memory>
#include "Db.h"
#include "Server.h"

int main(int argc, char* argv[])
{
	QCoreApplication app(argc, argv);

	Db::get();
	auto s = std::make_shared<Server>();
	
	return app.exec();
}






