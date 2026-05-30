import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Page {
    id: page

    focus: true

    signal backRequested()
    signal passwordChanged()
    signal forgotPasswordRequested()

    property int mode: 1
    property int emailStep: 1
    property bool waiting: false

    readonly property int desktopBreakpoint: 900
    readonly property bool desktopMode: page.width >= page.desktopBreakpoint
    readonly property int contentMaxWidth: 720
    readonly property int pageSideMargin: page.desktopMode ? 24 : 20
    readonly property int compactWidth: 420
    readonly property bool compactMode: page.width < page.compactWidth

    property int contentTopInset: 0
    property int contentBottomInset: 0
    property var lastFocusedField: null
    property var activeTextInput: null

    readonly property int keyboardSafePadding: Qt.inputMethod.visible ? 18 : 0

    property string savedEmail: ""
    property string errorText: ""
    property string infoText: ""

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

    function hideKeyboardAndTakeFocus() {
        page.forceActiveFocus()
        Qt.inputMethod.hide()
    }

    function ensureVisible(item) {
        if (!item || !scrollView || !scrollView.contentItem)
            return

        var flick = scrollView.contentItem

        if (!flick || flick.contentY === undefined)
            return

        var p = item.mapToItem(rootColumn, 0, 0)
        var itemTop = p.y
        var itemBottom = itemTop + item.height

        // adjustResize уже уменьшает высоту окна. Тут считаем только реальную
        // видимую область ScrollView, без прибавления высоты клавиатуры.
        var viewportHeight = Math.max(140, scrollView.height - scrollView.topPadding - scrollView.bottomPadding)
        var currentY = flick.contentY
        var maxY = Math.max(0, rootColumn.implicitHeight - viewportHeight)
        var targetY = currentY
        var bottomGap = Qt.inputMethod.visible ? 26 : 18
        var topGap = 18

        if (itemBottom + bottomGap > currentY + viewportHeight)
            targetY = itemBottom + bottomGap - viewportHeight
        else if (itemTop - topGap < currentY)
            targetY = itemTop - topGap

        targetY = Math.max(0, Math.min(maxY, targetY))

        if (Math.abs(targetY - currentY) < 2)
            return

        scrollYAnimation.stop()
        scrollYAnimation.from = currentY
        scrollYAnimation.to = targetY
        scrollYAnimation.start()
    }

    function clearMessages() {
        page.errorText = ""
        page.infoText = ""
    }

    function isValidEmail(email) {
        var re = /^[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}$/i
        return re.test(email)
    }

    function passwordsMatch(password, repeatPassword) {
        if (password.length < 6) {
            page.errorText = "Пароль должен быть не короче 6 символов."
            return false
        }

        if (password !== repeatPassword) {
            page.errorText = "Пароли не совпадают."
            return false
        }

        return true
    }

    function changeByOldPassword() {
        clearMessages()

        var oldPassword = oldPasswordField.text
        var newPassword = newPasswordField.text
        var repeatPassword = repeatPasswordField.text

        if (oldPassword.length === 0) {
            page.errorText = "Введите текущий пароль."
            return
        }

        if (!passwordsMatch(newPassword, repeatPassword))
            return

        if (!Db.isConnect()) {
            page.errorText = "Нет подключения к серверу."
            Db.connectToServer()
            return
        }

        page.hideKeyboardAndTakeFocus()
        page.waiting = true
        page.infoText = "Меняем пароль..."

        Db.changePassword(oldPassword, newPassword)
    }

    function requestEmailCode() {
        clearMessages()

        var email = emailField.text.trim().toLowerCase()

        if (email.length === 0) {
            page.errorText = "Введите email."
            return
        }

        if (!isValidEmail(email)) {
            page.errorText = "Введите корректный email."
            return
        }

        if (!Db.isConnect()) {
            page.errorText = "Нет подключения к серверу."
            Db.connectToServer()
            return
        }

        page.savedEmail = email
        page.hideKeyboardAndTakeFocus()
        page.waiting = true
        page.infoText = "Отправляем код..."

        Db.getEmailCodeResetPassword(email)
    }

    function checkCode() {
        clearMessages()

        var code = codeField.text.trim()

        if (code.length === 0) {
            page.errorText = "Введите код из письма."
            return
        }

        if (!Db.isConnect()) {
            page.errorText = "Нет подключения к серверу."
            Db.connectToServer()
            return
        }

        page.hideKeyboardAndTakeFocus()
        page.waiting = true
        page.infoText = "Проверяем код..."

        Db.isValidResetCode(page.savedEmail, code)
    }

    function resetByEmailCode() {
        clearMessages()

        var code = codeField.text.trim()
        var newPassword = emailNewPasswordField.text
        var repeatPassword = emailRepeatPasswordField.text

        if (code.length === 0) {
            page.errorText = "Введите код из письма."
            page.emailStep = 2
            return
        }

        if (!passwordsMatch(newPassword, repeatPassword))
            return

        if (!Db.isConnect()) {
            page.errorText = "Нет подключения к серверу."
            Db.connectToServer()
            return
        }

        page.hideKeyboardAndTakeFocus()
        page.waiting = true
        page.infoText = "Сохраняем новый пароль..."

        Db.resetPasswordByCode(page.savedEmail, code, newPassword)
    }

    Component.onCompleted: {
        Qt.callLater(function() {
            page.hideKeyboardAndTakeFocus()
        })
    }

    onVisibleChanged: {
        page.hideKeyboardAndTakeFocus()

        Qt.callLater(function() {
            page.hideKeyboardAndTakeFocus()
        })

        if (!page.visible) {
            page.waiting = false
            page.infoText = ""
        }
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
            event.accepted = true
            page.hideKeyboardAndTakeFocus()
            page.backRequested()
        }
    }

    Connections {
        target: Db
        ignoreUnknownSignals: true

        function onResponseReceived(response) {
            if (!page.visible)
                return

            if (!response)
                return

            var cmd = page.responseCmd(response)

            if (cmd === "change_password") {
                page.waiting = false

                if (response.ok === true) {
                    page.errorText = ""
                    page.infoText = response.message || "Пароль успешно изменён."
                    page.hideKeyboardAndTakeFocus()
                    doneDialog.open()
                    return
                }

                page.infoText = ""
                page.errorText = response.error || "Не удалось изменить пароль."
                return
            }

            if (cmd === "get_email_code_reset_password") {
                page.waiting = false

                if (response.ok === true) {
                    page.emailStep = 2
                    page.errorText = ""
                    page.infoText = response.message || "Код отправлен на почту."

                    if (page.visible) {
                        Qt.callLater(function() {
                            if (page.visible)
                                codeField.forceActiveFocus()
                        })
                    }

                    return
                }

                page.infoText = ""
                page.errorText = response.error || "Не удалось отправить код."
                return
            }

            if (cmd === "IsValidCode") {
                page.waiting = false

                if (response.ok === true && response.valid === true) {
                    page.emailStep = 3
                    page.errorText = ""
                    page.infoText = "Код подтверждён. Введите новый пароль."

                    if (page.visible) {
                        Qt.callLater(function() {
                            if (page.visible)
                                emailNewPasswordField.forceActiveFocus()
                        })
                    }

                    return
                }

                page.infoText = ""
                page.errorText = response.error || "Неверный или просроченный код."
                return
            }

            if (cmd === "reset_password_by_code" || cmd === "reset_password") {
                page.waiting = false

                if (response.ok === true) {
                    page.errorText = ""
                    page.infoText = response.message || "Пароль успешно изменён."
                    page.hideKeyboardAndTakeFocus()
                    doneDialog.open()
                    return
                }

                page.infoText = ""
                page.errorText = response.error || "Не удалось изменить пароль."
                return
            }
        }

        function onDisconnectedFromServer() {
            if (!page.visible)
                return

            if (page.waiting) {
                page.waiting = false
                page.infoText = ""
                page.errorText = "Соединение с сервером потеряно."
            }
        }

        function onConnectionError(error) {
            if (!page.visible)
                return

            if (page.waiting) {
                page.waiting = false
                page.infoText = ""
                page.errorText = error || "Ошибка подключения к серверу."
            }
        }
    }

    Timer {
        id: keyboardEnsureTimer
        // Ждём, пока Android закончит adjustResize-анимацию окна.
        // Если скроллить раньше — переход получается кривой.
        interval: 420
        repeat: false

        onTriggered: {
            if (page.lastFocusedField)
                page.ensureVisible(page.lastFocusedField)
        }
    }

    Connections {
        target: Qt.inputMethod
        ignoreUnknownSignals: true

        function onVisibleChanged() {
            if (Qt.inputMethod.visible && page.lastFocusedField)
                keyboardEnsureTimer.restart()
        }
    }

    onHeightChanged: {
        if (Qt.inputMethod.visible && page.lastFocusedField)
            keyboardEnsureTimer.restart()
    }

    NumberAnimation {
        id: scrollYAnimation
        target: scrollView.contentItem
        property: "contentY"
        duration: 170
        easing.type: Easing.OutCubic
    }

    ScrollView {
        id: scrollView

        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        contentHeight: rootColumn.implicitHeight

        topPadding: page.contentTopInset
        bottomPadding: page.contentBottomInset + 24 + page.keyboardSafePadding

        background: Rectangle {
            color: page.bg
        }

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            id: rootColumn

            width: Math.min(scrollView.availableWidth, page.contentMaxWidth)
            x: Math.max(0, Math.round((scrollView.availableWidth - width) / 2))
            spacing: page.desktopMode ? 18 : 16

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: page.pageSideMargin
                Layout.rightMargin: page.pageSideMargin
                spacing: 12

                IconButton {
                    iconName: "back"
                    enabled: !page.waiting

                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46

                    onClicked: {
                        page.hideKeyboardAndTakeFocus()
                        page.backRequested()
                    }
                }

                Text {
                    text: "Смена пароля"
                    color: page.textMain
                    font.pixelSize: page.compactMode ? 24 : 26
                    font.bold: true
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter

                    Layout.fillWidth: true
                }
            }

            HeaderCard {
                Layout.fillWidth: true
                Layout.leftMargin: page.pageSideMargin
                Layout.rightMargin: page.pageSideMargin
            }

            MessageBox {
                visible: page.errorText.length > 0
                text: page.errorText
                danger: true

                Layout.fillWidth: true
                Layout.leftMargin: page.pageSideMargin
                Layout.rightMargin: page.pageSideMargin
            }

            MessageBox {
                visible: page.infoText.length > 0
                text: page.infoText
                danger: false

                Layout.fillWidth: true
                Layout.leftMargin: page.pageSideMargin
                Layout.rightMargin: page.pageSideMargin
            }

            SegmentCard {
                Layout.fillWidth: true
                Layout.leftMargin: page.pageSideMargin
                Layout.rightMargin: page.pageSideMargin

                SegmentButton {
                    text: "Знаю пароль"
                    selected: page.mode === 1
                    enabled: !page.waiting

                    Layout.fillWidth: true

                    onClicked: {
                        page.hideKeyboardAndTakeFocus()
                        page.mode = 1
                        page.clearMessages()
                    }
                }

                SegmentButton {
                    text: "Через почту"
                    selected: page.mode === 2
                    enabled: !page.waiting

                    Layout.fillWidth: true

                    onClicked: {
                        page.hideKeyboardAndTakeFocus()
                        page.mode = 2
                        page.clearMessages()
                    }
                }
            }

            FormCard {
                visible: page.mode === 1
                title: "Смена по текущему паролю"

                FieldLabel {
                    text: "Текущий пароль"
                }

                AppTextField {
                    id: oldPasswordField

                    placeholderText: "Введите текущий пароль"
                    echoMode: TextInput.Password
                    enabled: !page.waiting

                    Layout.fillWidth: true

                    onTextChanged: page.clearMessages()

                    onAccepted: {
                        newPasswordField.forceActiveFocus()
                    }
                }

                FieldLabel {
                    text: "Новый пароль"
                }

                AppTextField {
                    id: newPasswordField

                    placeholderText: "Минимум 6 символов"
                    echoMode: TextInput.Password
                    enabled: !page.waiting

                    Layout.fillWidth: true

                    onTextChanged: page.clearMessages()

                    onAccepted: {
                        repeatPasswordField.forceActiveFocus()
                    }
                }

                FieldLabel {
                    text: "Повторите новый пароль"
                }

                AppTextField {
                    id: repeatPasswordField

                    placeholderText: "Повторите пароль"
                    echoMode: TextInput.Password
                    enabled: !page.waiting

                    Layout.fillWidth: true

                    onTextChanged: page.clearMessages()

                    onAccepted: {
                        page.changeByOldPassword()
                    }
                }

                AppButton {
                    text: page.waiting ? "Сохраняем..." : "Изменить пароль"
                    enabled: !page.waiting
                    variant: "primary"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54

                    onClicked: {
                        page.changeByOldPassword()
                    }
                }
            }

            FormCard {
                visible: page.mode === 2 && page.emailStep === 1
                title: "Получение кода"

                FieldLabel {
                    text: "Email аккаунта"
                }

                AppTextField {
                    id: emailField

                    placeholderText: "Введите email"
                    enabled: !page.waiting
                    inputMethodHints: Qt.ImhEmailCharactersOnly

                    Layout.fillWidth: true

                    onTextChanged: page.clearMessages()

                    onAccepted: {
                        page.requestEmailCode()
                    }
                }

                Text {
                    text: "На почту придёт одноразовый код. Он действует 10 минут."
                    color: page.textMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap

                    Layout.fillWidth: true
                }

                AppButton {
                    text: page.waiting ? "Отправляем..." : "Получить код"
                    enabled: !page.waiting
                    variant: "primary"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54

                    onClicked: {
                        page.requestEmailCode()
                    }
                }
            }

            FormCard {
                visible: page.mode === 2 && page.emailStep === 2
                title: "Подтверждение кода"

                InfoPill {
                    text: "Код отправлен на " + page.savedEmail
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

                    onTextChanged: page.clearMessages()

                    onAccepted: {
                        page.checkCode()
                    }
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
                            page.hideKeyboardAndTakeFocus()
                            page.emailStep = 1
                            codeField.text = ""
                            page.clearMessages()
                        }
                    }

                    AppButton {
                        text: "Отправить ещё"
                        variant: "tonal"
                        enabled: !page.waiting

                        Layout.fillWidth: true
                        Layout.preferredHeight: 50

                        onClicked: {
                            page.hideKeyboardAndTakeFocus()
                            emailField.text = page.savedEmail
                            page.requestEmailCode()
                        }
                    }
                }

                AppButton {
                    text: page.waiting ? "Проверяем..." : "Подтвердить код"
                    enabled: !page.waiting
                    variant: "primary"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54

                    onClicked: {
                        page.checkCode()
                    }
                }
            }

            FormCard {
                visible: page.mode === 2 && page.emailStep === 3
                title: "Новый пароль"

                InfoPill {
                    text: "Почта подтверждена: " + page.savedEmail
                }

                FieldLabel {
                    text: "Новый пароль"
                }

                AppTextField {
                    id: emailNewPasswordField

                    placeholderText: "Минимум 6 символов"
                    echoMode: TextInput.Password
                    enabled: !page.waiting

                    Layout.fillWidth: true

                    onTextChanged: page.clearMessages()

                    onAccepted: {
                        emailRepeatPasswordField.forceActiveFocus()
                    }
                }

                FieldLabel {
                    text: "Повторите новый пароль"
                }

                AppTextField {
                    id: emailRepeatPasswordField

                    placeholderText: "Повторите пароль"
                    echoMode: TextInput.Password
                    enabled: !page.waiting

                    Layout.fillWidth: true

                    onTextChanged: page.clearMessages()

                    onAccepted: {
                        page.resetByEmailCode()
                    }
                }

                AppButton {
                    text: page.waiting ? "Сохраняем..." : "Сохранить новый пароль"
                    enabled: !page.waiting
                    variant: "primary"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54

                    onClicked: {
                        page.resetByEmailCode()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
            }
        }
    }

    Dialog {
        id: doneDialog

        modal: true
        dim: true
        closePolicy: Popup.NoAutoClose
        title: ""

        width: Math.min(page.width - 40, 390)
        anchors.centerIn: parent

        background: Rectangle {
            color: page.surface
            radius: 24
            border.width: 1
            border.color: page.border
        }

        contentItem: ColumnLayout {
            spacing: 14

            IconCircle {
                iconText: "✓"
                bgColor: page.successSoft
                textColor: page.success

                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
            }

            Text {
                text: "Пароль изменён"
                color: page.textMain
                font.pixelSize: 22
                font.bold: true

                Layout.fillWidth: true
            }

            Text {
                text: "Теперь используйте новый пароль для входа в аккаунт."
                color: page.textMuted
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                lineHeight: 1.2

                Layout.fillWidth: true
            }

            AppButton {
                text: "Готово"
                variant: "primary"

                Layout.fillWidth: true
                Layout.preferredHeight: 50

                onClicked: {
                    doneDialog.close()
                    page.hideKeyboardAndTakeFocus()
                    page.passwordChanged()
                }
            }
        }
    }

    component HeaderCard: Rectangle {
        id: card

        property bool hovered: hoverArea.containsMouse
        property bool pressed: pressHandler.pressed

        color: card.hovered && page.desktopMode ? page.surface2 : page.surface
        radius: 26
        border.width: 1
        border.color: card.hovered && page.desktopMode ? "#284568" : page.border

        Layout.preferredHeight: headerRow.implicitHeight + (page.compactMode ? 28 : 32)

        scale: card.pressed && !page.desktopMode ? 0.992 : card.hovered && page.desktopMode ? 1.004 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        TapHandler {
            id: pressHandler
            enabled: !page.desktopMode
            gesturePolicy: TapHandler.DragThreshold
        }

        RowLayout {
            id: headerRow

            anchors.fill: parent
            anchors.margins: page.compactMode ? 14 : 16
            spacing: page.compactMode ? 11 : 14

            Rectangle {
                Layout.preferredWidth: page.compactMode ? 50 : 58
                Layout.preferredHeight: page.compactMode ? 50 : 58
                radius: page.compactMode ? 17 : 20
                color: page.accentSoft
                border.width: 1
                border.color: "#284568"

                DrawIcon {
                    anchors.centerIn: parent
                    width: page.compactMode ? 26 : 30
                    height: page.compactMode ? 26 : 30
                    name: page.mode === 1 ? "quickPassword" : "mail"
                    iconColor: page.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: page.mode === 1 ? "Быстрая смена" : "Восстановление через почту"
                    color: page.textMain
                    font.pixelSize: page.compactMode ? 20 : 22
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: page.mode === 1
                          ? "Введите текущий пароль и задайте новый"
                          : "Получите код, подтвердите почту и задайте новый пароль"
                    color: page.textMuted
                    font.pixelSize: page.compactMode ? 13 : 14
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }
        }
    }

    component SegmentCard: Rectangle {
        id: card

        default property alias content: row.data
        property bool hovered: hoverArea.containsMouse
        property bool pressed: pressHandler.pressed

        height: 52
        radius: 26
        color: card.hovered && page.desktopMode ? page.surface2 : page.surface
        border.width: 1
        border.color: card.hovered && page.desktopMode ? "#284568" : page.border

        Layout.preferredHeight: 52

        scale: card.pressed && !page.desktopMode ? 0.992 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        TapHandler {
            id: pressHandler
            enabled: !page.desktopMode
            gesturePolicy: TapHandler.DragThreshold
        }

        RowLayout {
            id: row

            anchors.fill: parent
            anchors.margins: 5
            spacing: 5
        }
    }

    component SegmentButton: Item {
        id: control

        signal clicked()

        property string text: ""
        property bool selected: false
        property bool hovered: mouseArea.containsMouse

        Layout.preferredHeight: 42
        Layout.fillHeight: true

        opacity: enabled ? 1.0 : 0.45
        scale: mouseArea.pressed ? 0.97 : control.hovered && page.desktopMode ? 1.015 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 21
            color: {
                if (control.selected)
                    return mouseArea.pressed ? "#255FA9" : control.hovered && page.desktopMode ? "#2B6CBE" : page.accent

                if (mouseArea.pressed)
                    return page.surface3

                if (control.hovered && page.desktopMode)
                    return page.surface2

                return "transparent"
            }
            border.width: control.hovered && page.desktopMode && !control.selected ? 1 : 0
            border.color: page.border

            Behavior on color { ColorAnimation { duration: 130 } }
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            text: control.text
            color: control.selected ? "#FFFFFF" : control.hovered && page.desktopMode ? page.textMain : page.textSub
            font.pixelSize: page.compactMode ? 13 : 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: control.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                control.clicked()
            }
        }
    }

    component FormCard: Rectangle {
        id: card

        default property alias content: cardColumn.data
        property string title: ""
        property bool hovered: hoverArea.containsMouse
        property bool pressed: pressHandler.pressed

        color: card.hovered && page.desktopMode ? page.surface2 : page.surface
        radius: 26
        border.width: 1
        border.color: card.hovered && page.desktopMode ? "#284568" : page.border

        Layout.fillWidth: true
        Layout.leftMargin: page.pageSideMargin
        Layout.rightMargin: page.pageSideMargin
        Layout.preferredHeight: cardColumn.implicitHeight + 34

        scale: card.pressed && !page.desktopMode ? 0.992 : card.hovered && page.desktopMode ? 1.003 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        TapHandler {
            id: pressHandler
            enabled: !page.desktopMode
            gesturePolicy: TapHandler.DragThreshold
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

    component InfoPill: Rectangle {
        id: pill

        property string text: ""
        property bool hovered: hoverArea.containsMouse

        radius: 18
        color: pill.hovered && page.desktopMode ? "#203553" : page.accentSoft
        border.width: 1
        border.color: pill.hovered && page.desktopMode ? "#3D6697" : "#284568"

        Layout.fillWidth: true
        Layout.preferredHeight: pillText.implicitHeight + 24

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Text {
            id: pillText

            anchors.fill: parent
            anchors.margins: 12
            text: pill.text
            color: page.accent
            font.pixelSize: 13
            font.bold: true
            wrapMode: Text.WrapAnywhere
            verticalAlignment: Text.AlignVCenter
        }
    }

    component MessageBox: Rectangle {
        id: box

        property string text: ""
        property bool danger: false
        property bool hovered: hoverArea.containsMouse
        property bool pressed: pressHandler.pressed

        color: box.danger ? page.dangerSoft : page.successSoft
        radius: 20
        border.width: 1
        border.color: {
            if (box.danger)
                return box.hovered && page.desktopMode ? page.danger : "#5A2D31"

            return box.hovered && page.desktopMode ? page.success : "#24513C"
        }

        Layout.preferredHeight: boxRow.implicitHeight + 24

        scale: box.pressed && !page.desktopMode ? 0.992 : 1.0

        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        TapHandler {
            id: pressHandler
            enabled: !page.desktopMode
            gesturePolicy: TapHandler.DragThreshold
        }

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
            font.pixelSize: icon.iconText.length > 1 ? 16 : 20
            font.bold: true
        }
    }

    component IconButton: Item {
        id: button

        signal clicked()

        property string iconName: ""
        property bool hovered: mouseArea.containsMouse

        opacity: enabled ? 1.0 : 0.45
        scale: mouseArea.pressed ? 0.94 : button.hovered && page.desktopMode ? 1.06 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: {
                if (!button.enabled)
                    return page.surface2

                if (mouseArea.pressed)
                    return page.surface3

                if (button.hovered && page.desktopMode)
                    return page.accentSoft

                return page.surface
            }
            border.width: 1
            border.color: button.hovered && page.desktopMode ? "#284568" : page.border

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        DrawIcon {
            anchors.centerIn: parent
            width: 23
            height: 23
            name: button.iconName
            iconColor: button.enabled ? (button.hovered && page.desktopMode ? page.accent : page.textMain) : page.textMuted
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                button.clicked()
            }
        }
    }

    component DrawIcon: Canvas {
        id: icon

        property string name: ""
        property color iconColor: page.textMain

        onNameChanged: requestPaint()
        onIconColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var s = Math.min(width, height)
            var x = (width - s) / 2
            var y = (height - s) / 2

            ctx.strokeStyle = icon.iconColor
            ctx.fillStyle = icon.iconColor
            ctx.lineWidth = Math.max(1.8, s * 0.08)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            function px(v) {
                return x + s * v
            }

            function py(v) {
                return y + s * v
            }

            function roundedRectPath(left, top, w, h, r) {
                ctx.beginPath()
                ctx.moveTo(left + r, top)
                ctx.lineTo(left + w - r, top)
                ctx.quadraticCurveTo(left + w, top, left + w, top + r)
                ctx.lineTo(left + w, top + h - r)
                ctx.quadraticCurveTo(left + w, top + h, left + w - r, top + h)
                ctx.lineTo(left + r, top + h)
                ctx.quadraticCurveTo(left, top + h, left, top + h - r)
                ctx.lineTo(left, top + r)
                ctx.quadraticCurveTo(left, top, left + r, top)
                ctx.closePath()
            }

            if (icon.name === "back") {
                ctx.beginPath()
                ctx.moveTo(px(0.62), py(0.24))
                ctx.lineTo(px(0.36), py(0.5))
                ctx.lineTo(px(0.62), py(0.76))
                ctx.stroke()
            } else if (icon.name === "quickPassword") {
                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.12))
                ctx.lineTo(px(0.78), py(0.24))
                ctx.lineTo(px(0.78), py(0.48))
                ctx.quadraticCurveTo(px(0.78), py(0.72), px(0.5), py(0.88))
                ctx.quadraticCurveTo(px(0.22), py(0.72), px(0.22), py(0.48))
                ctx.lineTo(px(0.22), py(0.24))
                ctx.closePath()
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.56), py(0.27))
                ctx.lineTo(px(0.42), py(0.52))
                ctx.lineTo(px(0.54), py(0.52))
                ctx.lineTo(px(0.43), py(0.75))
                ctx.stroke()
            } else if (icon.name === "mail") {
                roundedRectPath(px(0.14), py(0.24), s * 0.72, s * 0.52, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.16), py(0.3))
                ctx.lineTo(px(0.5), py(0.55))
                ctx.lineTo(px(0.84), py(0.3))
                ctx.stroke()
            } else {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.08, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    component AppTextField: Rectangle {
        id: field

        property alias text: input.text
        property alias placeholderText: placeholder.text
        property alias echoMode: input.echoMode
        property alias inputMethodHints: input.inputMethodHints
        property bool hovered: hoverArea.containsMouse

        signal accepted()

        function forceActiveFocus() {
            if (page.activeTextInput && page.activeTextInput !== input)
                page.activeTextInput.cursorVisible = false

            page.activeTextInput = input
            input.forceActiveFocus()
            input.cursorVisible = true
            page.lastFocusedField = field

            Qt.callLater(function() {
                keyboardEnsureTimer.restart()
            })
        }

        height: 56
        implicitHeight: 56

        Layout.preferredHeight: 56

        radius: 18
        color: {
            if (input.activeFocus)
                return page.surface3

            if (field.hovered && page.desktopMode && field.enabled)
                return page.surface3

            return page.surface2
        }
        border.width: input.activeFocus || (field.hovered && page.desktopMode && field.enabled) ? 2 : 1
        border.color: {
            if (input.activeFocus)
                return page.accent

            if (field.hovered && page.desktopMode && field.enabled)
                return "#284568"

            return page.border
        }
        opacity: enabled ? 1.0 : 0.55
        scale: input.activeFocus ? 1.0 : 1.0

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

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
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

            cursorVisible: false

            echoMode: TextInput.Normal

            cursorDelegate: Rectangle {
                width: 2
                visible: input.activeFocus && page.activeTextInput === input
                color: page.accent
            }

            onActiveFocusChanged: {
                if (input.activeFocus) {
                    if (page.activeTextInput && page.activeTextInput !== input)
                        page.activeTextInput.cursorVisible = false

                    page.activeTextInput = input
                    input.cursorVisible = true
                    page.lastFocusedField = field

                    Qt.callLater(function() {
                        keyboardEnsureTimer.restart()
                    })
                } else {
                    input.cursorVisible = false
                }
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

            color: field.hovered && page.desktopMode && field.enabled ? page.textSub : page.textMuted
            font.pixelSize: 16
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            enabled: false
        }
    }

    component AppButton: Item {
        id: button

        signal clicked()

        property string text: ""
        property string variant: "primary"
        property bool hovered: mouseArea.containsMouse

        Layout.preferredHeight: 50

        opacity: enabled ? 1.0 : 0.45
        scale: mouseArea.pressed ? 0.975 : button.hovered && page.desktopMode ? 1.015 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 17

            color: {
                if (!button.enabled)
                    return page.surface3

                if (button.variant === "primary") {
                    if (mouseArea.pressed)
                        return "#255FA9"
                    if (button.hovered && page.desktopMode)
                        return "#2B6CBE"
                    return page.accent
                }

                if (button.variant === "outlined") {
                    if (mouseArea.pressed)
                        return page.surface3
                    if (button.hovered && page.desktopMode)
                        return page.accentSoft
                    return "transparent"
                }

                if (mouseArea.pressed)
                    return page.surface3

                if (button.hovered && page.desktopMode)
                    return page.surface3

                return page.surface2
            }

            border.width: button.variant === "outlined" || (button.hovered && page.desktopMode) ? 1 : 0
            border.color: {
                if (button.variant === "outlined")
                    return button.hovered && page.desktopMode ? "#284568" : page.border

                if (button.hovered && page.desktopMode)
                    return "#7FB5FF"

                return "transparent"
            }

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            text: button.text

            color: {
                if (!button.enabled)
                    return page.textMuted

                if (button.variant === "primary")
                    return "#FFFFFF"

                if (button.variant === "outlined")
                    return button.hovered && page.desktopMode ? page.accent : page.accent

                return button.hovered && page.desktopMode ? page.textMain : page.textSub
            }

            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                button.clicked()
            }
        }
    }

}