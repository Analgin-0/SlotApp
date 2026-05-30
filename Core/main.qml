import QtQuick
import QtQuick.Controls
import App.Core 1.0

ApplicationWindow {
    id: window

    width: 390
    height: 780
    minimumWidth: 320
    minimumHeight: 560
    visible: true
    title: "SlotApp"

    property bool animationRunning: false

    function startAnimation() {
        animationRunning = true
    }

    function stopAnimation() {
        animationRunning = false
    }

    function responseCmd(response) {
        if (!response)
            return ""

        if (response.command !== undefined && response.command !== null)
            return String(response.command)

        if (response.cmd !== undefined && response.cmd !== null)
            return String(response.cmd)

        return ""
    }

    function goToLogin() {
        stackView.replace(loginPageComponent, StackView.Immediate)
    }

    function goToHome() {
        stackView.replace(mainPageComponent, StackView.Immediate)
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: loadingPageComponent
    }

    Component {
        id: loadingPageComponent

        LoadingPage {
            id: loadingPage

            property bool serverConnected: false
            property bool minimumDelayPassed: false
            property bool tokenValidationStarted: false

            appName: "SlotApp"
            statusText: "Подключение к серверу..."

            function tryStartTokenCheck() {
                if (!serverConnected)
                    return

                if (!minimumDelayPassed)
                    return

                if (tokenValidationStarted)
                    return

                tokenValidationStarted = true

                if (!Db.hasSavedToken()) {
                    loadingPage.stopAnimation()
                    window.goToLogin()
                    return
                }

                loadingPage.setStatusText("Проверка авторизации...")
                validationTimeoutTimer.start()
                Db.getMyProfile()
            }

            Component.onCompleted: {
                loadingPage.startAnimation()
                minimumDelayTimer.start()

                if (Db.isConnect()) {
                    serverConnected = true
                    loadingPage.setStatusText("Подключено")
                    tryStartTokenCheck()
                } else {
                    loadingPage.setStatusText("Подключение к серверу...")
                    Db.connectToServer()
                }
            }

            Timer {
                id: minimumDelayTimer
                interval: 2000
                repeat: false

                onTriggered: {
                    loadingPage.minimumDelayPassed = true
                    loadingPage.tryStartTokenCheck()
                }
            }

            Timer {
                id: validationTimeoutTimer
                interval: 5000
                repeat: false

                onTriggered: {
                    Db.clearToken()
                    loadingPage.stopAnimation()
                    window.goToLogin()
                }
            }

            Connections {
                target: Db

                function onConnectedToServer() {
                    loadingPage.serverConnected = true
                    loadingPage.setStatusText("Подключено")
                    loadingPage.tryStartTokenCheck()
                }

                function onDisconnectedFromServer() {
                    loadingPage.serverConnected = false
                    loadingPage.tokenValidationStarted = false
                    validationTimeoutTimer.stop()

                    loadingPage.setStatusText("Соединение потеряно. Переподключение...")
                    loadingPage.startAnimation()
                }

                function onConnectionError(error) {
                    loadingPage.serverConnected = false
                    loadingPage.tokenValidationStarted = false
                    validationTimeoutTimer.stop()

                    loadingPage.setStatusText(error || "Ошибка подключения к серверу")
                    loadingPage.startAnimation()
                }

                function onResponseReceived(response) {
                    if (!loadingPage.tokenValidationStarted)
                        return

                    if (!response)
                        return

                    var cmd = window.responseCmd(response)

                    if (cmd.length > 0 && cmd !== "get_my_profile")
                        return

                    validationTimeoutTimer.stop()

                    var code = response.code || ""

                    if (response.ok && response.user) {
                        loadingPage.stopAnimation()
                        window.goToHome()
                        return
                    }

                    if (code === "unauthorized" || code === "auth_failed") {
                        Db.clearToken()
                        loadingPage.stopAnimation()
                        window.goToLogin()
                        return
                    }

                    Db.clearToken()
                    loadingPage.stopAnimation()
                    window.goToLogin()
                }
            }
        }
    }

    Component {
        id: loginPageComponent

        LoginPage {
            id: loginPage

            property bool loginRequestActive: false

            onLoginRequested: function(login, password) {
                if (loginRequestActive)
                    return

                if (!Db.isConnect()) {
                    loginPage.showError("Нет соединения с сервером.")
                    return
                }

                loginRequestActive = true
                loginPage.setLoading(true)
                Db.login(login, password)
            }

            onForgotPasswordRequested: {
                stackView.replace(resetPasswordPageComponent, StackView.Immediate)
            }

            Connections {
                target: Db

                function onResponseReceived(response) {
                    if (!loginPage.loginRequestActive)
                        return

                    if (!response)
                        return

                    var cmd = window.responseCmd(response)

                    if (cmd.length > 0 && cmd !== "login")
                        return

                    loginPage.loginRequestActive = false
                    loginPage.setLoading(false)

                    var code = response.code || ""

                    if (response.ok && response.token) {
                        window.goToHome()
                        return
                    }

                    if (code === "auth_failed" || code === "unauthorized") {
                        loginPage.showError("Неверный логин или пароль.")
                        return
                    }

                    if (!response.ok && response.error) {
                        loginPage.showError(response.error)
                        return
                    }

                    loginPage.showError("Не удалось выполнить вход.")
                }

                function onDisconnectedFromServer() {
                    loginPage.loginRequestActive = false
                    loginPage.setLoading(false)
                    loginPage.showError("Соединение с сервером потеряно.")
                }

                function onConnectionError(error) {
                    loginPage.loginRequestActive = false
                    loginPage.setLoading(false)
                    loginPage.showError(error || "Ошибка подключения к серверу.")
                }
            }
        }
    }


    Component {
        id: resetPasswordPageComponent

        ResetPasswordPage {
            onBackRequested: {
                stackView.replace(loginPageComponent, StackView.Immediate)
            }
        }
    }

    Component {
        id: mainPageComponent

        MainPage {
            id: mainPage

            onLogoutRequested: {
                Db.logout()
                Db.clearToken()
                window.goToLogin()
            }

            Connections {
                target: Db

                function onAuthorizedChanged(authorized) {
                    if (!authorized) {
                        Db.clearToken()
                        window.goToLogin()
                    }
                }

                function onResponseReceived(response) {
                    if (!response)
                        return

                    if (response.code === "unauthorized") {
                        Db.clearToken()
                        window.goToLogin()
                    }
                }
            }
        }
    }
}