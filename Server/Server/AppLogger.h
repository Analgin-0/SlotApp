#pragma once

#include <QString>

class AppLogger
{
public:

    enum class Level {
        Debug,
        Info,
        Warning,
        Error
    };

    void debug(const QString& tag, const QString& message);
    void info(const QString& tag, const QString& message);
    void warning(const QString& tag, const QString& message);
    void error(const QString& tag, const QString& message);

    void setColorsEnabled(bool enabled);

private:
    void write(Level level, const QString& tag, const QString& message);

    QString levelName(Level level);
    QString levelColor(Level level);
    QString resetColor();

    bool s_colorsEnabled = true;
};