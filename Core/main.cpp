#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QCoreApplication>
#include <QSslSocket>
#include <QDebug>

#include "db.h"

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    QCoreApplication::setAttribute(Qt::AA_UseOpenGLES);

    QGuiApplication app(argc, argv);

    QCoreApplication::setOrganizationName("SlotApp");
    QCoreApplication::setOrganizationDomain("slotapp.local");
    QCoreApplication::setApplicationName("SlotApp");

    qDebug() << "Settings org:" << QCoreApplication::organizationName();
    qDebug() << "Settings app:" << QCoreApplication::applicationName();

    qDebug() << "SSL supported:" << QSslSocket::supportsSsl();
    qDebug() << "SSL build:" << QSslSocket::sslLibraryBuildVersionString();
    qDebug() << "SSL runtime:" << QSslSocket::sslLibraryVersionString();

    QQmlApplicationEngine engine;

    qmlRegisterSingletonInstance("App.Core", 1, 0, "Db", Db::get());

    const QUrl url(QStringLiteral("qrc:/QmlCore/main.qml"));

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() {
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection
        );

    engine.load(url);

    return app.exec();
}