#include "AppLogger.h"

#include <iostream>
#include <QDateTime>

void AppLogger::debug(const QString& tag, const QString& message)
{
    write(Level::Debug, tag, message);
}

void AppLogger::info(const QString& tag, const QString& message)
{
    write(Level::Info, tag, message);
}

void AppLogger::warning(const QString& tag, const QString& message)
{
    write(Level::Warning, tag, message);
}

void AppLogger::error(const QString& tag, const QString& message)
{
    write(Level::Error, tag, message);
}

void AppLogger::setColorsEnabled(bool enabled)
{
    s_colorsEnabled = enabled;
}

void AppLogger::write(Level level, const QString& tag, const QString& message)
{
    const QString color = s_colorsEnabled ? levelColor(level) : "";
    const QString reset = s_colorsEnabled ? resetColor() : "";
    const QString dim = s_colorsEnabled ? "\033[2m" : "";
    const QString tagColor = s_colorsEnabled ? "\033[95m" : ""; // фиолетовый
    const QString time = QDateTime::currentDateTime().toString("hh:mm:ss.zzz");

    std::ostream& stream = (level == Level::Warning || level == Level::Error)
        ? std::cerr
        : std::cout;

    stream
        << color.toStdString()
        << "[" << levelName(level).toStdString() << "] "
        << reset.toStdString()

        << dim.toStdString()
        << "[Time:" << time.toStdString() << "]"
        << reset.toStdString()

        << tagColor.toStdString()
        << "[" << tag.toStdString() << "] "
        << reset.toStdString()

        << message.toStdString()
        << std::endl;
}
QString AppLogger::levelName(Level level)
{
    switch (level)
    {
    case Level::Debug:
        return "DEBUG";
    case Level::Info:
        return "INFO";
    case Level::Warning:
        return "WARNING";
    case Level::Error:
        return "ERROR";
    default:
        return "LOG";
    }
}

QString AppLogger::levelColor(Level level)
{
    switch (level)
    {
    case Level::Debug:
        return "\033[94m";      // ярко-синий
    case Level::Info:
        return "\033[92m";      // ярко-зелёный
    case Level::Warning:
        return "\033[93m";      // ярко-жёлтый
    case Level::Error:
        return "\033[1;91m";    // жирный ярко-красный
    default:
        return "\033[0m";
    }
}

QString AppLogger::resetColor()
{
    return "\033[0m";
}