cmake_minimum_required(VERSION 3.16)


set(APP_NAME "SlotApp")


project(${APP_NAME} VERSION 0.1 LANGUAGES CXX)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.2 COMPONENTS Quick Quick3D Network Multimedia REQUIRED)


qt_add_executable(${APP_NAME}
    main.cpp
)

qt_add_qml_module(${APP_NAME}
    URI QmlCore
    VERSION 1.0
    QML_FILES main.qml
    QML_FILES LoginPage.qml
    QML_FILES LoadingPage.qml
    SOURCES db.h db.cpp
    QML_FILES HomePage.qml
    QML_FILES ProfilePage.qml
    QML_FILES SessionsPage.qml
    QML_FILES AddTaskPage.qml
    QML_FILES TasksPage.qml
    QML_FILES MainPage.qml
    QML_FILES SchedulePage.qml
    QML_FILES ResetPasswordPage.qml
    QML_FILES ChangePasswordPage.qml
    QML_FILES AdminSchedulePage.qml
    QML_FILES AdminScheduleEditorPage.qml
    SOURCES sha.hpp sha.cpp
)


# OpenSSL для Android, чтобы QSslSocket реально работал на телефоне
if(ANDROID)
    include(FetchContent)

    FetchContent_Declare(
        android_openssl
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        URL https://github.com/KDAB/android_openssl/archive/refs/heads/master.zip
    )

    FetchContent_MakeAvailable(android_openssl)
    include(${android_openssl_SOURCE_DIR}/android_openssl.cmake)

    add_android_openssl_libraries(${APP_NAME})
endif()


set_target_properties(${APP_NAME} PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
    QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
)

target_link_libraries(${APP_NAME}
    PRIVATE
        Qt6::Quick
        Qt6::Quick3D
        Qt6::Network
        Qt6::Multimedia
)

include(GNUInstallDirs)
install(TARGETS ${APP_NAME}
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)