import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Page {
    id: page

    signal backRequested()

    property string savedEmail: ""
    property string savedCode: ""
    property int step: 1
    property bool waiting: false
    property string errorText: ""
    property string infoText: ""
    property Item focusedField: null

    readonly property color bg: "#111318"
    readonly property color surface: "#181B21"
    readonly property color surface2: "#20242C"
    readonly property color surface3: "#2A2F39"
    readonly property color border: "#313640"
    readonly property color textMain: "#F4F6F8"
    readonly property color textSub: "#C8CDD4"
    readonly property color textMuted: "#8D96A3"
    readonly property color accent: "#6EA8FE"
    readonly property color accentSoft: "#1C2B44"
    readonly property color danger: "#FF6B6B"
    readonly property color dangerSoft: "#3A2023"
    readonly property color success: "#6EE7A8"
    readonly property color successSoft: "#173427"
    readonly property color warning: "#FFD166"
    readonly property color warningSoft: "#392F18"

    readonly property int contentMaxWidth: 660

    background: Rectangle {
        color: page.bg
    }

    function responseCmd(obj) {
        if (!obj)
            return ""
        if (obj.command !== undefined && obj.command !== null)
            return String(obj.command)
        if (obj.cmd !== undefined && obj.cmd !== null)
            return String(obj.cmd)
        return ""
    }

    function clearMessages() {
        page.errorText = ""
        page.infoText = ""
    }

    function isValidEmail(email) {
        var re = /^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$/i
        return re.test(email)
    }

    function cleanEmail() {
        return emailField.text.trim().toLowerCase()
    }

    function cleanCode() {
        return codeField.text.trim()
    }

    function scrollToY(y, immediate) {
        var flick = scrollView.contentItem
        if (!flick)
            return

        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var targetY = Math.max(0, Math.min(y, maxY))

        scrollAnimation.stop()

        if (immediate) {
            flick.contentY = targetY
            return
        }

        if (Math.abs(flick.contentY - targetY) < 1)
            return

        scrollAnimation.target = flick
        scrollAnimation.from = flick.contentY
        scrollAnimation.to = targetY
        scrollAnimation.start()
    }

    function ensureVisible(item) {
        var flick = scrollView.contentItem
        if (!item || !flick)
            return

        var pos = item.mapToItem(rootColumn, 0, 0)
        var itemTop = pos.y
        var itemBottom = itemTop + item.height

        var topMargin = 12
        var bottomMargin = 24

        var visibleTop = flick.contentY + topMargin
        var visibleBottom = flick.contentY + flick.height - bottomMargin

        var newY = flick.contentY

        if (itemBottom > visibleBottom)
            newY += itemBottom - visibleBottom
        else if (itemTop < visibleTop)
            newY -= visibleTop - itemTop

        page.scrollToY(newY, false)
    }

    function goBackSmart() {
        if (page.waiting)
            return

        if (page.step === 4) {
            page.backRequested()
            return
        }

        if (page.step > 1) {
            page.step--
            page.clearMessages()

            if (page.step === 1) {
                Qt.callLater(function() {
                    emailField.forceActiveFocus()
                })
            } else if (page.step === 2) {
                Qt.callLater(function() {
                    codeField.forceActiveFocus()
                })
            }

            return
        }

        page.backRequested()
    }

    function resetLocalState() {
        page.step = 1
        page.savedEmail = ""
        page.savedCode = ""
        page.waiting = false
        page.errorText = ""
        page.infoText = ""

        emailField.text = ""
        codeField.text = ""
        passwordField.text = ""
        repeatPasswordField.text = ""
    }

    function requestCode() {
        page.clearMessages()

        var email = page.cleanEmail()

        if (email.length === 0) {
            page.errorText = "Введите почту."
            return
        }

        if (!page.isValidEmail(email)) {
            page.errorText = "Введите корректную почту."
            return
        }

        if (!Db.isConnect()) {
            page.errorText = "Нет подключения к серверу."
            Db.connectToServer()
            return
        }

        page.savedEmail = email
        page.savedCode = ""
        page.waiting = true
        page.infoText = "Отправляем код на почту..."

        Db.sendCommand("get_email_code_reset_password", {
            "email": email
        })
    }

    function resendCode() {
        if (page.savedEmail.length > 0)
            emailField.text = page.savedEmail

        page.requestCode()
    }

    function checkCode() {
        page.clearMessages()

        var code = page.cleanCode()

        if (page.savedEmail.length === 0) {
            page.step = 1
            page.errorText = "Сначала запросите код на почту."
            return
        }

        if (code.length === 0) {
            page.errorText = "Введите код из письма."
            return
        }

        if (code.length < 4) {
            page.errorText = "Код слишком короткий."
            return
        }

        if (!Db.isConnect()) {
            page.errorText = "Нет подключения к серверу."
            Db.connectToServer()
            return
        }

        page.savedCode = code
        page.waiting = true
        page.infoText = "Проверяем код..."

        Db.sendCommand("IsValidCode", {
            "email": page.savedEmail,
            "code": code
        })
    }

    function resetPassword() {
        page.clearMessages()

        var password = passwordField.text
        var repeatPassword = repeatPasswordField.text

        if (page.savedEmail.length === 0 || page.savedCode.length === 0) {
            page.step = 1
            page.errorText = "Сначала подтвердите почту и код."
            return
        }

        if (password.length === 0 || repeatPassword.length === 0) {
            page.errorText = "Введите новый пароль два раза."
            return
        }

        if (password.length < 6) {
            page.errorText = "Пароль должен быть не короче 6 символов."
            return
        }

        if (password !== repeatPassword) {
            page.errorText = "Пароли не совпадают."
            return
        }

        if (!Db.isConnect()) {
            page.errorText = "Нет подключения к серверу."
            Db.connectToServer()
            return
        }

        page.waiting = true
        page.infoText = "Меняем пароль..."

        Db.sendCommand("reset_password_by_code", {
            "email": page.savedEmail,
            "code": page.savedCode,
            "new_password": password
        })
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
            event.accepted = true
            page.goBackSmart()
        }
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            emailField.forceActiveFocus()
        })
    }

    Timer {
        id: ensureVisibleTimer
        interval: 160
        repeat: false
        onTriggered: {
            page.ensureVisible(page.focusedField)
        }
    }

    NumberAnimation {
        id: scrollAnimation
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
    }

    Connections {
        target: Qt.inputMethod

        function onVisibleChanged() {
            if (Qt.inputMethod.visible && page.focusedField)
                ensureVisibleTimer.restart()
        }
    }

    Connections {
        target: Db

        function onResponseReceived(response) {
            if (!response)
                return

            var cmd = page.responseCmd(response)

            if (cmd === "get_email_code_reset_password") {
                page.waiting = false

                if (response.ok === true) {
                    page.step = 2
                    page.errorText = ""
                    page.infoText = response.message || "Код отправлен на почту."

                    Qt.callLater(function() {
                        codeField.forceActiveFocus()
                    })
                    return
                }

                page.infoText = ""
                page.errorText = response.error || "Не удалось отправить код."
                return
            }

            if (cmd === "IsValidCode") {
                page.waiting = false

                if (response.ok === true && response.valid === true) {
                    page.step = 3
                    page.errorText = ""
                    page.infoText = "Код подтверждён. Придумайте новый пароль."

                    Qt.callLater(function() {
                        passwordField.forceActiveFocus()
                    })
                    return
                }

                page.infoText = ""
                page.errorText = response.error || "Неверный или просроченный код."
                return
            }

            if (cmd === "reset_password_by_code") {
                page.waiting = false

                if (response.ok === true) {
                    page.step = 4
                    page.errorText = ""
                    page.infoText = response.message || "Пароль успешно изменён."
                    passwordField.text = ""
                    repeatPasswordField.text = ""
                    return
                }

                page.infoText = ""
                page.errorText = response.error || "Не удалось изменить пароль."
                return
            }
        }

        function onDisconnectedFromServer() {
            if (page.waiting) {
                page.waiting = false
                page.infoText = ""
                page.errorText = "Соединение с сервером потеряно."
            }
        }

        function onConnectionError(error) {
            if (page.waiting) {
                page.waiting = false
                page.infoText = ""
                page.errorText = error || "Ошибка подключения к серверу."
            }
        }
    }

    ScrollView {
        id: scrollView

        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        onHeightChanged: {
            if (Qt.inputMethod.visible && page.focusedField)
                ensureVisibleTimer.restart()
        }

        background: Rectangle {
            color: page.bg
        }

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            id: rootColumn

            width: Math.min(scrollView.availableWidth, page.contentMaxWidth)
            x: Math.max(0, (scrollView.availableWidth - width) / 2)
            spacing: 16

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 12

                AppButton {
                    text: page.step === 4 ? "Войти" : "Назад"
                    variant: "outlined"
                    enabled: !page.waiting

                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 46

                    onClicked: {
                        if (page.step === 4)
                            page.backRequested()
                        else
                            page.goBackSmart()
                    }
                }

                Text {
                    text: "Сброс пароля"
                    color: page.textMain
                    font.pixelSize: 26
                    font.bold: true
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }

            HeaderCard {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            StepLine {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            MessageBox {
                visible: page.errorText.length > 0
                text: page.errorText
                danger: true

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            MessageBox {
                visible: page.infoText.length > 0
                text: page.infoText
                danger: false

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            FormCard {
                title: "1. Почта аккаунта"
                visible: page.step === 1

                Text {
                    text: "Введите email, который привязан к вашему аккаунту. Мы отправим туда одноразовый код."
                    color: page.textMuted
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15

                    Layout.fillWidth: true
                }

                FieldLabel {
                    text: "Email"
                }

                AppTextField {
                    id: emailField

                    placeholderText: "example@mail.com"
                    enabled: !page.waiting
                    inputMethodHints: Qt.ImhEmailCharactersOnly

                    Layout.fillWidth: true

                    onTextChanged: {
                        page.clearMessages()
                    }

                    onAccepted: {
                        page.requestCode()
                    }

                    onFocusActivated: {
                        page.focusedField = emailField
                        ensureVisibleTimer.restart()
                    }
                }

                AppButton {
                    text: page.waiting ? "Отправляем..." : "Получить код"
                    variant: "primary"
                    enabled: !page.waiting

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54

                    onClicked: {
                        page.requestCode()
                    }
                }
            }

            FormCard {
                title: "2. Код подтверждения"
                visible: page.step === 2

                SelectedEmailBox {
                    Layout.fillWidth: true
                }

                FieldLabel {
                    text: "Код из письма"
                }

                AppTextField {
                    id: codeField

                    placeholderText: "Введите код"
                    enabled: !page.waiting
                    inputMethodHints: Qt.ImhDigitsOnly

                    Layout.fillWidth: true

                    onTextChanged: {
                        page.clearMessages()
                    }

                    onAccepted: {
                        page.checkCode()
                    }

                    onFocusActivated: {
                        page.focusedField = codeField
                        ensureVisibleTimer.restart()
                    }
                }

                Text {
                    text: "Код действует 10 минут. Если письмо не пришло, проверьте папку «Спам» или отправьте код ещё раз."
                    color: page.textMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15

                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    AppButton {
                        text: "Сменить email"
                        variant: "outlined"
                        enabled: !page.waiting

                        Layout.fillWidth: true
                        Layout.preferredHeight: 50

                        onClicked: {
                            page.step = 1
                            page.clearMessages()
                            codeField.text = ""

                            Qt.callLater(function() {
                                emailField.forceActiveFocus()
                            })
                        }
                    }

                    AppButton {
                        text: page.waiting ? "Ждите..." : "Ещё раз"
                        variant: "tonal"
                        enabled: !page.waiting

                        Layout.fillWidth: true
                        Layout.preferredHeight: 50

                        onClicked: {
                            page.resendCode()
                        }
                    }
                }

                AppButton {
                    text: page.waiting ? "Проверяем..." : "Подтвердить код"
                    variant: "primary"
                    enabled: !page.waiting

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54

                    onClicked: {
                        page.checkCode()
                    }
                }
            }

            FormCard {
                title: "3. Новый пароль"
                visible: page.step === 3

                SelectedEmailBox {
                    Layout.fillWidth: true
                }

                Text {
                    text: "Код подтверждён. Теперь задайте новый пароль для входа в аккаунт."
                    color: page.textMuted
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    lineHeight: 1.15

                    Layout.fillWidth: true
                }

                FieldLabel {
                    text: "Новый пароль"
                }

                AppTextField {
                    id: passwordField

                    placeholderText: "Минимум 6 символов"
                    enabled: !page.waiting
                    echoMode: TextInput.Password

                    Layout.fillWidth: true

                    onTextChanged: {
                        page.clearMessages()
                    }

                    onAccepted: {
                        repeatPasswordField.forceActiveFocus()
                    }

                    onFocusActivated: {
                        page.focusedField = passwordField
                        ensureVisibleTimer.restart()
                    }
                }

                FieldLabel {
                    text: "Повторите пароль"
                }

                AppTextField {
                    id: repeatPasswordField

                    placeholderText: "Введите пароль ещё раз"
                    enabled: !page.waiting
                    echoMode: TextInput.Password

                    Layout.fillWidth: true

                    onTextChanged: {
                        page.clearMessages()
                    }

                    onAccepted: {
                        page.resetPassword()
                    }

                    onFocusActivated: {
                        page.focusedField = repeatPasswordField
                        ensureVisibleTimer.restart()
                    }
                }

                AppButton {
                    text: page.waiting ? "Сохраняем..." : "Изменить пароль"
                    variant: "primary"
                    enabled: !page.waiting

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54

                    onClicked: {
                        page.resetPassword()
                    }
                }
            }

            FormCard {
                title: "Готово"
                visible: page.step === 4

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    IconCircle {
                        iconText: "✓"
                        bgColor: page.successSoft
                        textColor: page.success

                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 70
                    }

                    Text {
                        text: "Пароль изменён"
                        color: page.textMain
                        font.pixelSize: 23
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter

                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Теперь можно войти в аккаунт с новым паролем."
                        color: page.textMuted
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.15

                        Layout.fillWidth: true
                    }

                    AppButton {
                        text: "Вернуться ко входу"
                        variant: "primary"

                        Layout.fillWidth: true
                        Layout.preferredHeight: 54

                        onClicked: {
                            page.backRequested()
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
            }
        }
    }

    component HeaderCard: Rectangle {
        id: headerCard

        color: headerHover.hovered ? "#1B1F27" : page.surface
        radius: 26
        border.width: 1
        border.color: headerHover.hovered ? "#3D5E88" : page.border
        scale: headerHover.hovered ? 1.004 : 1.0

        Layout.preferredHeight: headerRow.implicitHeight + 32

        Behavior on color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutQuad
            }
        }

        HoverHandler {
            id: headerHover
        }

        RowLayout {
            id: headerRow

            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            IconCircle {
                iconText: {
                    if (page.step === 1)
                        return "@"
                    if (page.step === 2)
                        return "#"
                    if (page.step === 3)
                        return "●"
                    return "✓"
                }

                bgColor: page.step === 4 ? page.successSoft : page.accentSoft
                textColor: page.step === 4 ? page.success : page.accent

                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: {
                        if (page.step === 1)
                            return "Восстановление доступа"
                        if (page.step === 2)
                            return "Проверьте почту"
                        if (page.step === 3)
                            return "Создайте новый пароль"
                        return "Доступ восстановлен"
                    }

                    color: page.textMain
                    font.pixelSize: 22
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: {
                        if (page.step === 1)
                            return "Сначала укажите email аккаунта"
                        if (page.step === 2)
                            return "Введите код из письма"
                        if (page.step === 3)
                            return "Пароль будет изменён после сохранения"
                        return "Можно возвращаться ко входу"
                    }

                    color: page.textMuted
                    font.pixelSize: 14
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }
        }
    }

    component StepLine: Rectangle {
        id: stepLine

        height: 62
        radius: 22
        color: stepHover.hovered ? "#1B1F27" : page.surface
        border.width: 1
        border.color: stepHover.hovered ? "#3A4352" : page.border

        Behavior on color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        HoverHandler {
            id: stepHover
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            StepPill {
                number: 1
                label: "Email"
                active: page.step === 1
                done: page.step > 1
            }

            StepPill {
                number: 2
                label: "Код"
                active: page.step === 2
                done: page.step > 2
            }

            StepPill {
                number: 3
                label: "Пароль"
                active: page.step === 3
                done: page.step > 3
            }
        }
    }

    component StepPill: Rectangle {
        id: pill

        property int number: 1
        property string label: ""
        property bool active: false
        property bool done: false

        Layout.fillWidth: true
        Layout.fillHeight: true

        radius: 17
        color: pill.active ? page.accentSoft : pill.done ? page.successSoft : page.surface2
        border.width: 1
        border.color: pill.active ? "#284568" : pill.done ? "#24513C" : page.border

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 12
                color: pill.done ? page.success : pill.active ? page.accent : page.surface3

                Text {
                    anchors.centerIn: parent
                    text: pill.done ? "✓" : String(pill.number)
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Text {
                text: pill.label
                color: pill.done ? page.success : pill.active ? page.accent : page.textMuted
                font.pixelSize: 12
                font.bold: true
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }
    }

    component SelectedEmailBox: Rectangle {
        radius: 18
        color: page.accentSoft
        border.width: 1
        border.color: "#284568"

        Layout.preferredHeight: selectedEmailRow.implicitHeight + 22

        RowLayout {
            id: selectedEmailRow

            anchors.fill: parent
            anchors.margins: 11
            spacing: 10

            IconCircle {
                iconText: "@"
                bgColor: page.surface
                textColor: page.accent

                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Аккаунт"
                    color: page.accent
                    font.pixelSize: 12
                    font.bold: true

                    Layout.fillWidth: true
                }

                Text {
                    text: page.savedEmail.length > 0 ? page.savedEmail : "email не выбран"
                    color: page.textMain
                    font.pixelSize: 14
                    font.bold: true
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }
        }
    }

    component FormCard: Rectangle {
        id: card

        default property alias content: cardColumn.data
        property string title: ""

        color: cardHover.hovered ? "#1B1F27" : page.surface
        radius: 26
        border.width: 1
        border.color: cardHover.hovered ? "#3D5E88" : page.border
        scale: cardHover.hovered ? 1.004 : 1.0

        Layout.fillWidth: true
        Layout.leftMargin: 20
        Layout.rightMargin: 20
        Layout.preferredHeight: cardColumn.implicitHeight + 34

        Behavior on color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutQuad
            }
        }

        HoverHandler {
            id: cardHover
        }

        ColumnLayout {
            id: cardColumn

            anchors.fill: parent
            anchors.margins: 17
            spacing: 12

            Text {
                text: card.title
                color: page.textMain
                font.pixelSize: 19
                font.bold: true

                Layout.fillWidth: true
            }
        }
    }

    component FieldLabel: Text {
        color: page.textSub
        font.pixelSize: 13
        font.bold: true

        Layout.fillWidth: true
    }

    component MessageBox: Rectangle {
        id: box

        property string text: ""
        property bool danger: false

        color: box.danger ? page.dangerSoft : page.successSoft
        radius: 20
        border.width: 1
        border.color: box.danger ? "#5A2D31" : "#24513C"

        Layout.preferredHeight: boxRow.implicitHeight + 24

        RowLayout {
            id: boxRow

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            IconCircle {
                iconText: box.danger ? "!" : "✓"
                bgColor: box.danger ? "#4A2529" : "#123021"
                textColor: box.danger ? page.danger : page.success

                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
            }

            Text {
                text: box.text
                color: box.danger ? "#FFD7DA" : "#D8FFE8"
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.WordWrap
                lineHeight: 1.15

                Layout.fillWidth: true
            }
        }
    }

    component IconCircle: Rectangle {
        id: icon

        property string iconText: ""
        property color bgColor: page.surface2
        property color textColor: page.textMain

        radius: width / 2
        color: icon.bgColor
        border.width: 1
        border.color: page.border

        Layout.preferredWidth: 38
        Layout.preferredHeight: 38

        Text {
            anchors.centerIn: parent
            text: icon.iconText
            color: icon.textColor
            font.pixelSize: 20
            font.bold: true
        }
    }

    component AppTextField: Rectangle {
        id: field

        property alias text: input.text
        property alias placeholderText: placeholder.text
        property alias echoMode: input.echoMode
        property alias inputMethodHints: input.inputMethodHints

        signal accepted()
        signal focusActivated()

        function forceActiveFocus() {
            input.forceActiveFocus()
        }

        height: 56
        implicitHeight: 56

        Layout.preferredHeight: 56

        radius: 18
        color: {
            if (!field.enabled)
                return page.surface2
            if (input.activeFocus)
                return page.surface3
            if (fieldHover.hovered)
                return "#242A34"
            return page.surface2
        }
        border.width: input.activeFocus ? 2 : 1
        border.color: {
            if (!field.enabled)
                return page.border
            if (input.activeFocus)
                return page.accent
            if (fieldHover.hovered)
                return "#3D4656"
            return page.border
        }
        opacity: enabled ? 1.0 : 0.55

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        HoverHandler {
            id: fieldHover
            cursorShape: Qt.IBeamCursor
        }

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            enabled: field.enabled

            color: page.textMain
            selectionColor: page.accent
            selectedTextColor: "#FFFFFF"
            font.pixelSize: 16

            verticalAlignment: TextInput.AlignVCenter
            clip: true

            echoMode: TextInput.Normal

            cursorDelegate: Rectangle {
                width: 2
                color: page.accent
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    field.focusActivated()
            }

            onAccepted: {
                field.accepted()
            }
        }

        Text {
            id: placeholder

            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            opacity: (input.text.length === 0 && input.preeditText.length === 0) ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.InOutQuad
                }
            }

            color: page.textMuted
            font.pixelSize: 16
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            enabled: false
        }
    }

    component AppButton: Rectangle {
        id: button

        property string text: ""
        property string variant: "primary"
        property bool hovered: mouseArea.containsMouse
        property bool down: mouseArea.pressed && mouseArea.containsMouse

        signal clicked()

        implicitHeight: 50
        Layout.preferredHeight: 50

        radius: 17
        clip: true
        enabled: true
        activeFocusOnTab: enabled
        opacity: enabled ? 1.0 : 0.55

        scale: {
            if (!button.enabled)
                return 1.0
            if (button.down)
                return 0.985
            if (button.hovered)
                return 1.006
            return 1.0
        }

        color: {
            if (!button.enabled)
                return page.surface3

            if (button.variant === "primary") {
                if (button.down)
                    return "#1E4F90"
                if (button.hovered)
                    return "#2B6CBE"
                return "#255FA9"
            }

            if (button.variant === "outlined") {
                if (button.down)
                    return "#202A38"
                if (button.hovered)
                    return "#182233"
                return "transparent"
            }

            if (button.variant === "danger") {
                if (button.down)
                    return "#8E2F35"
                if (button.hovered)
                    return "#A63A42"
                return "#94343B"
            }

            if (button.down)
                return "#202A38"
            if (button.hovered)
                return "#1E2C42"
            return page.surface2
        }

        border.width: button.variant === "outlined" || button.hovered || button.activeFocus ? 1 : 0
        border.color: {
            if (!button.enabled)
                return page.border
            if (button.variant === "primary")
                return button.hovered || button.activeFocus ? "#3D7FCC" : "#255FA9"
            if (button.variant === "danger")
                return button.hovered || button.activeFocus ? "#BD4A52" : "#94343B"
            if (button.variant === "outlined")
                return button.hovered || button.activeFocus ? "#3D5E88" : page.border
            return button.hovered || button.activeFocus ? "#34455E" : page.border
        }

        Behavior on color {
            ColorAnimation {
                duration: 140
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 140
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            width: parent.width - 28

            text: button.text
            color: {
                if (!button.enabled)
                    return page.textMuted

                if (button.variant === "primary" || button.variant === "danger")
                    return "#FFFFFF"

                if (button.variant === "outlined")
                    return button.hovered || button.activeFocus ? "#91C0FF" : page.accent

                return button.hovered || button.activeFocus ? page.textMain : page.textSub
            }

            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            maximumLineCount: 1

            Behavior on color {
                ColorAnimation {
                    duration: 140
                    easing.type: Easing.OutQuad
                }
            }
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPressed: {
                if (button.enabled)
                    button.forceActiveFocus()
            }

            onClicked: {
                if (button.enabled)
                    button.clicked()
            }
        }

        Keys.onPressed: function(event) {
            if (!button.enabled)
                return

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                event.accepted = true
                button.clicked()
            }
        }
    }
}