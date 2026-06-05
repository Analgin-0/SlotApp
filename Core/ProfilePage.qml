import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Item {
    id: page

    signal logoutRequested()
    signal sessionsRequested()
    signal changePasswordRequested()

    property int contentTopInset: 0
    property int contentBottomInset: 0

    readonly property int desktopBreakpoint: 900
    readonly property bool desktopMode: page.width >= page.desktopBreakpoint
    readonly property int contentMaxWidth: page.desktopMode ? 940 : page.width

    property bool firstShow: true
    property bool profileLoaded: false
    property bool waitingProfile: false
    property bool loggingOut: false
    property bool extraVisible: false

    property string profileName: "Загрузка профиля..."
    property string profileRole: "Подождите, получаем данные аккаунта."

    property string emailValue: "—"
    property string phoneValue: "—"
    property string birthDateValue: "—"
    property string genderValue: "—"

    property string extraTitle: "Дополнительная информация"
    property string extraLabel1: "—"
    property string extraLabel2: "—"
    property string extraLabel3: "—"
    property string extraLabel4: "—"
    property string extraValue1: "—"
    property string extraValue2: "—"
    property string extraValue3: "—"
    property string extraValue4: "—"

    property string errorText: ""

    property string stubTitle: ""
    property string stubText: ""

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

    function responseCmd(response) {
        if (!response)
            return ""

        if (response.command !== undefined && response.command !== null)
            return String(response.command)

        if (response.cmd !== undefined && response.cmd !== null)
            return String(response.cmd)

        return ""
    }

    function refreshData() {
        requestProfileData()
    }

    function showStub(title, text) {
        page.stubTitle = title
        page.stubText = text
        stubDialog.open()
    }

    function requestProfileData() {
        if (page.waitingProfile || page.loggingOut)
            return

        page.errorText = ""
        page.waitingProfile = true

        if (!page.profileLoaded) {
            page.extraVisible = true
            page.extraTitle = "Дополнительная информация"
            page.extraLabel1 = "Статус"
            page.extraValue1 = "Загружаем..."
            page.extraLabel2 = "Данные"
            page.extraValue2 = "—"
            page.extraLabel3 = "Профиль"
            page.extraValue3 = "—"
            page.extraLabel4 = "Аккаунт"
            page.extraValue4 = "—"
        }

        if (Db.isConnect()) {
            Db.getMyProfile()
            return
        }

        Db.connectToServer()
    }

    function roleToString(role) {
        role = Number(role)

        switch (role) {
        case 1:
            return "Студент"
        case 2:
            return "Преподаватель"
        case 3:
            return "Администратор"
        default:
            return "Пользователь"
        }
    }

    function valueOrDash(value) {
        if (value === undefined || value === null)
            return "—"

        var s = String(value).trim()

        if (s.length === 0)
            return "—"

        if (s.toLowerCase() === "null")
            return "—"

        if (s.toLowerCase() === "undefined")
            return "—"

        return s
    }

    function firstValue(obj, names, fallback) {
        if (!obj)
            return fallback

        for (var i = 0; i < names.length; i++) {
            var name = names[i]

            if (obj[name] !== undefined && obj[name] !== null)
                return obj[name]
        }

        return fallback
    }

    function formatGender(value) {
        var raw = valueOrDash(value)

        if (raw === "—")
            return "—"

        var s = raw.toLowerCase()

        if (s === "m" || s === "male" || s === "м" || s === "муж")
            return "Мужской"

        if (s === "f" || s === "female" || s === "ж" || s === "жен")
            return "Женский"

        return raw
    }

    function formatDate(value) {
        var s = valueOrDash(value)

        if (s === "—")
            return "—"

        var tIndex = s.indexOf("T")
        if (tIndex > 0)
            s = s.substring(0, tIndex)

        var spaceIndex = s.indexOf(" ")
        if (spaceIndex > 0)
            s = s.substring(0, spaceIndex)

        var parts = s.split("-")

        if (parts.length === 3)
            return parts[2] + "." + parts[1] + "." + parts[0]

        return s
    }

    function joinFullName(user) {
        if (!user)
            return "Без имени"

        var parts = []

        var lastName = valueOrDash(user.last_name)
        var name = valueOrDash(user.name)
        var middleName = valueOrDash(user.middle_name)

        if (lastName !== "—")
            parts.push(lastName)

        if (name !== "—")
            parts.push(name)

        if (middleName !== "—")
            parts.push(middleName)

        return parts.length > 0 ? parts.join(" ") : "Без имени"
    }

    function fillEmptyExtraInfo(role) {
        page.extraVisible = true
        page.extraTitle = "Дополнительно"

        page.extraLabel1 = "Роль"
        page.extraValue1 = page.roleToString(role)

        page.extraLabel2 = "Статус"
        page.extraValue2 = "Дополнительных данных нет"

        page.extraLabel3 = "Профиль"
        page.extraValue3 = "—"

        page.extraLabel4 = "Аккаунт"
        page.extraValue4 = "—"
    }

    function fillProfile(response) {
        if (!response)
            return

        var user = response.user || {}
        var student = response.student || {}
        var teacher = response.teacher || {}

        var role = Number(user.role || 0)

        page.profileName = page.joinFullName(user)
        page.profileRole = page.roleToString(role)

        page.emailValue = page.valueOrDash(page.firstValue(user, [
            "email",
            "Email",
            "mail",
            "Mail",
            "login",
            "Login"
        ], ""))

        page.phoneValue = page.valueOrDash(user.phone)
        page.birthDateValue = page.formatDate(user.birth_date)
        page.genderValue = page.formatGender(user.gender)

        if (role === 1) {
            page.extraVisible = true
            page.extraTitle = "Учёба"

            page.extraLabel1 = "Группа"
            page.extraValue1 = page.valueOrDash(student.group_name)

            page.extraLabel2 = "Курс"
            page.extraValue2 = student.course === undefined || student.course === null
                    ? "—"
                    : String(student.course)

            page.extraLabel3 = "Факультет"
            page.extraValue3 = page.valueOrDash(student.faculty)

            page.extraLabel4 = "Специальность"
            page.extraValue4 = page.valueOrDash(student.speciality)
        } else if (role === 2) {
            page.extraVisible = true
            page.extraTitle = "Работа"

            page.extraLabel1 = "Кафедра"
            page.extraValue1 = page.valueOrDash(teacher.department)

            page.extraLabel2 = "Должность"
            page.extraValue2 = page.valueOrDash(teacher.post)

            page.extraLabel3 = "Кабинет"
            page.extraValue3 = page.valueOrDash(teacher.cabinet)

            page.extraLabel4 = "Степень / звание"

            var degree = page.valueOrDash(teacher.academic_degree)
            var title = page.valueOrDash(teacher.academic_title)

            if (degree === "—" && title === "—")
                page.extraValue4 = "—"
            else if (degree === "—")
                page.extraValue4 = title
            else if (title === "—")
                page.extraValue4 = degree
            else
                page.extraValue4 = degree + ", " + title
        } else {
            page.fillEmptyExtraInfo(role)
        }

        page.profileLoaded = true
    }

    Component.onCompleted: {
        if (visible && firstShow) {
            firstShow = false
            firstShowTimer.start()
        }
    }

    onVisibleChanged: {
        if (visible && firstShow) {
            firstShow = false
            firstShowTimer.start()
        }
    }

    Timer {
        id: firstShowTimer
        interval: 0
        repeat: false

        onTriggered: {
            page.refreshData()
        }
    }

    Connections {
        target: Db

        function onConnectedToServer() {
            if (page.waitingProfile && !page.loggingOut)
                Db.getMyProfile()
        }

        function onDisconnectedFromServer() {
            if (page.waitingProfile) {
                page.waitingProfile = false
                page.errorText = "Соединение с сервером потеряно."
            }
        }

        function onConnectionError(error) {
            if (page.waitingProfile) {
                page.waitingProfile = false
                page.errorText = error && error.length > 0
                        ? error
                        : "Ошибка подключения к серверу."
            }
        }

        function onResponseReceived(response) {
            if (!response)
                return

            if (response.code === "unauthorized") {
                page.waitingProfile = false
                page.loggingOut = false
                page.logoutRequested()
                return
            }

            if (page.loggingOut)
                return

            if (!page.waitingProfile)
                return

            var cmd = page.responseCmd(response)

            if (cmd.length > 0 && cmd !== "get_my_profile")
                return

            page.waitingProfile = false

            if (response.ok && response.user) {
                page.fillProfile(response)
                page.errorText = ""
                return
            }

            page.errorText = response.error && response.error.length > 0
                    ? response.error
                    : "Не удалось загрузить профиль."
        }
    }

    Rectangle {
        anchors.fill: parent
        color: page.bg
    }

    ScrollView {
        id: scrollView

        anchors.fill: parent
        clip: true

        topPadding: page.contentTopInset + 18

        leftPadding: 0
        rightPadding: 0

        contentWidth: availableWidth
        contentHeight: contentColumn.implicitHeight

        background: Rectangle {
            color: page.bg
        }

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: contentColumn

            width: Math.min(scrollView.availableWidth, page.contentMaxWidth)
            x: Math.round((scrollView.availableWidth - width) / 2)
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "Профиль"
                        color: page.textMain
                        font.pixelSize: 30
                        font.bold: true

                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Данные аккаунта и настройки"
                        color: page.textMuted
                        font.pixelSize: 14

                        Layout.fillWidth: true
                    }
                }

                BusyIndicator {
                    running: page.waitingProfile
                    visible: page.waitingProfile

                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                }

                IconButton {
                    iconName: "refresh"
                    enabled: !page.waitingProfile && !page.loggingOut

                    onClicked: {
                        page.refreshData()
                    }
                }
            }

            ProfileCard {
                fullName: page.profileName
                role: page.profileRole
                email: page.emailValue
                loading: page.waitingProfile

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            ErrorBox {
                visible: page.errorText.length > 0
                text: page.errorText
                loading: page.waitingProfile

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                onRetryClicked: {
                    page.refreshData()
                }
            }

            SectionTitle {
                title: "Основная информация"
            }

            InfoCard {
                InfoRow {
                    label: "Телефон"
                    value: page.phoneValue
                    iconName: "phone"
                }

                DividerLine {}

                InfoRow {
                    label: "Дата рождения"
                    value: page.birthDateValue
                    iconName: "calendar"
                }

                DividerLine {}

                InfoRow {
                    label: "Пол"
                    value: page.genderValue
                    iconName: "user"
                }

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            SectionTitle {
                visible: page.extraVisible
                title: page.extraTitle
            }

            InfoCard {
                visible: page.extraVisible

                InfoRow {
                    label: page.extraLabel1
                    value: page.extraValue1
                    iconName: "dot"
                }

                DividerLine {}

                InfoRow {
                    label: page.extraLabel2
                    value: page.extraValue2
                    iconName: "dot"
                }

                DividerLine {}

                InfoRow {
                    label: page.extraLabel3
                    value: page.extraValue3
                    iconName: "dot"
                }

                DividerLine {}

                InfoRow {
                    label: page.extraLabel4
                    value: page.extraValue4
                    iconName: "dot"
                }

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            SectionTitle {
                title: "Аккаунт"
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
                spacing: 10

               ActionRow  {
                    visible: false
                    title: "Сменить email"
                    subtitle: "Раздел пока в разработке"
                    iconName: "mail"
                    enabled: !page.waitingProfile && !page.loggingOut

                    onClicked: {
                        page.showStub(
                            "Смена email",
                            "Этот раздел пока в разработке. Позже здесь можно будет изменить адрес электронной почты."
                        )
                    }
                }

               ActionRow {
                   title: "Сменить пароль"
                   subtitle: "По текущему паролю или через почту"
                   iconName: "lock"
                   enabled: !page.waitingProfile && !page.loggingOut

                   onClicked: {
                       page.changePasswordRequested()
                   }
               }

                ActionRow {
                    title: "Управление сессиями"
                    subtitle: "Активные входы и устройства"
                    iconName: "devices"
                    enabled: !page.waitingProfile && !page.loggingOut

                    onClicked: {
                        page.sessionsRequested()
                    }
                }

                ActionRow {
                    title: page.loggingOut ? "Выход..." : "Выйти из аккаунта"
                    subtitle: "Завершить текущую сессию"
                    iconName: "logout"
                    danger: true
                    enabled: !page.loggingOut

                    onClicked: {
                        if (page.loggingOut)
                            return

                        logoutDialog.open()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
            }
        }
    }

    Dialog {
        id: stubDialog

        modal: true
        dim: true
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

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 18
                color: page.accentSoft

                DrawIcon {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    name: "info"
                    iconColor: page.accent
                }
            }

            Text {
                text: page.stubTitle
                color: page.textMain
                font.pixelSize: 22
                font.bold: true
                wrapMode: Text.WordWrap

                Layout.fillWidth: true
            }

            Text {
                text: page.stubText
                color: page.textMuted
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                lineHeight: 1.2

                Layout.fillWidth: true
            }
        }
        footer: Item {

                    implicitHeight: 54

                    RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.bottomMargin: 16
                    spacing: 0

                    AppButton {
                        id: stubOkButton

                        text: "Понятно"
                        variant: "primary"

                        Layout.fillWidth: true
                        Layout.preferredHeight: 38

                    onClicked: {
                        stubDialog.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: logoutDialog

        modal: true
        dim: true
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

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 18
                color: page.dangerSoft

                DrawIcon {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    name: "logout"
                    iconColor: page.danger
                }
            }

            Text {
                text: "Выйти из аккаунта?"
                color: page.textMain
                font.pixelSize: 22
                font.bold: true
                wrapMode: Text.WordWrap

                Layout.fillWidth: true
            }

            Text {
                text: "Текущая сессия будет завершена. После выхода потребуется снова войти в аккаунт."
                color: page.textMuted
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                lineHeight: 1.2

                Layout.fillWidth: true
            }
        }

        footer: Item {

        implicitHeight: 54

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        anchors.bottomMargin: 16
                        spacing: 12

                        AppButton {
                            id: cancelLogoutButton

                            text: "Отмена"
                            variant: "neutral"
                            enabled: !page.loggingOut

                            Layout.fillWidth: true
                            Layout.preferredHeight: 38

                            onClicked: {
                                logoutDialog.close()
                            }
                        }

                        AppButton {
                            id: confirmLogoutButton

                            text: "Выйти"
                            variant: "danger"
                            enabled: !page.loggingOut

                            Layout.fillWidth: true
                            Layout.preferredHeight: 38

                            onClicked: {
                                logoutDialog.close()

                                if (page.loggingOut)
                                    return

                                page.loggingOut = true
                                page.waitingProfile = false
                                page.logoutRequested()
                            }
                        }
                    }
                }
    }

    component ProfileCard: Rectangle {
        id: card

        property string fullName: ""
        property string role: ""
        property string email: ""
        property bool loading: false
        property bool hovered: hoverArea.containsMouse
        property bool pressed: hoverArea.pressed

        color: card.pressed ? page.surface3 : card.hovered ? "#1D2230" : page.surface
        radius: 26
        border.width: 1
        border.color: card.hovered ? "#284568" : page.border
        scale: card.pressed ? 0.992 : card.hovered ? 1.006 : 1.0

        Layout.preferredHeight: profileLayout.implicitHeight + 32

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        ColumnLayout {
            id: profileLayout

            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 76
                    Layout.preferredHeight: 76
                    radius: 24
                    color: page.accentSoft
                    border.width: 1
                    border.color: card.hovered ? page.accent : "#284568"

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: card.fullName.length > 0 ? card.fullName.charAt(0).toUpperCase() : "?"
                        color: page.accent
                        font.pixelSize: 34
                        font.bold: true
                    }

                    Rectangle {
                        visible: card.loading
                        width: 18
                        height: 18
                        radius: 9
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        color: page.accent
                        border.width: 3
                        border.color: page.surface

                        SequentialAnimation on opacity {
                            running: card.loading
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 0.35
                                duration: 500
                            }

                            NumberAnimation {
                                to: 1.0
                                duration: 500
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: card.fullName
                        color: page.textMain
                        font.pixelSize: page.desktopMode ? 26 : 24
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        lineHeight: 1.02

                        Layout.fillWidth: true
                    }

                    Text {
                        text: card.role
                        color: page.textMuted
                        font.pixelSize: 14
                        maximumLineCount: 1
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: emailText.implicitHeight + 24
                radius: 18
                color: card.hovered ? "#222837" : page.surface2
                border.width: 1
                border.color: card.hovered ? "#284568" : page.border

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    DrawIcon {
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        name: "mail"
                        iconColor: card.hovered ? page.accent : page.textMuted
                    }

                    Text {
                        id: emailText

                        text: card.email
                        color: page.textMain
                        font.pixelSize: 15
                        font.bold: true
                        wrapMode: Text.WrapAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: false
            onClicked: {}
        }
    }

    component SectionTitle: Text {
        id: section

        property string title: ""

        text: title
        color: page.textMain
        font.pixelSize: 19
        font.bold: true

        Layout.fillWidth: true
        Layout.leftMargin: 22
        Layout.rightMargin: 22
        Layout.topMargin: 2
    }

    component InfoCard: Rectangle {
        id: card

        default property alias content: cardColumn.data
        property bool hovered: hoverHandler.hovered
        property bool pressed: false

        color: card.hovered ? "#1D2230" : page.surface
        radius: 22
        border.width: 1
        border.color: card.hovered ? "#284568" : page.border
        scale: card.pressed ? 0.995 : card.hovered ? 1.004 : 1.0

        Layout.preferredHeight: cardColumn.implicitHeight

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        ColumnLayout {
            id: cardColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: 0
        }

        HoverHandler {
            id: hoverHandler
        }
    }

    component InfoRow: Item {
        id: row

        property string label: ""
        property string value: ""
        property string iconName: ""
        property bool hovered: hoverArea.containsMouse
        property bool pressed: hoverArea.pressed

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(72, rowLayout.implicitHeight + 22)

        scale: row.pressed ? 0.992 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            radius: 18
            color: row.hovered ? page.surface2 : "transparent"
            opacity: row.hovered ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutQuad
                }
            }
        }

        RowLayout {
            id: rowLayout

            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 11
            anchors.bottomMargin: 11
            spacing: 13

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 15
                color: row.hovered ? page.accentSoft : page.surface2
                border.width: 1
                border.color: row.hovered ? "#284568" : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                DrawIcon {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    name: row.iconName
                    iconColor: row.hovered ? page.accent : page.textSub
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: row.label
                    color: page.textMuted
                    font.pixelSize: 12
                    maximumLineCount: 1
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: row.value
                    color: page.textMain
                    font.pixelSize: 16
                    font.bold: true
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    lineHeight: 1.12

                    Layout.fillWidth: true
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: false
            onClicked: {}
        }
    }

    component ActionRow: Item {
        id: action

        signal clicked()

        property string title: ""
        property string subtitle: ""
        property string iconName: ""
        property bool danger: false
        property bool hovered: actionMouse.containsMouse
        property bool pressed: actionMouse.pressed

        Layout.fillWidth: true
        Layout.preferredHeight: 74

        opacity: enabled ? 1.0 : 0.45
        scale: action.pressed ? 0.985 : action.hovered ? 1.006 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: {
                if (action.danger)
                    return action.pressed ? "#44272A" : action.hovered ? "#3A2023" : page.dangerSoft

                return action.pressed ? page.surface3 : action.hovered ? "#1D2230" : page.surface
            }
            border.width: 1
            border.color: {
                if (action.danger)
                    return action.hovered ? page.danger : "#5A2D31"

                return action.hovered ? "#284568" : page.border
            }

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 13

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 16
                color: action.danger ? "#4A2529" : action.hovered ? page.accentSoft : page.surface2
                border.width: action.hovered && !action.danger ? 1 : 0
                border.color: "#284568"

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                DrawIcon {
                    anchors.centerIn: parent
                    width: 23
                    height: 23
                    name: action.iconName
                    iconColor: action.danger ? page.danger : page.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: action.title
                    color: action.danger ? page.danger : page.textMain
                    font.pixelSize: 16
                    font.bold: true
                    maximumLineCount: 1
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: action.subtitle
                    color: action.danger ? "#E79499" : page.textMuted
                    font.pixelSize: 12
                    maximumLineCount: 1
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }

            DrawIcon {
                visible: !action.danger
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                name: "chevron"
                iconColor: action.hovered ? page.accent : page.textMuted
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            enabled: action.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: false

            onClicked: {
                action.clicked()
            }
        }
    }

    component IconButton: Item {
        id: button

        signal clicked()

        property string iconName: ""
        property bool hovered: mouseArea.containsMouse
        property bool pressed: mouseArea.pressed

        Layout.preferredWidth: 44
        Layout.preferredHeight: 44

        opacity: enabled ? 1.0 : 0.45
        scale: button.pressed ? 0.94 : button.hovered ? 1.06 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: button.pressed ? page.surface3 : button.hovered ? page.accentSoft : page.surface
            border.width: 1
            border.color: button.hovered ? "#284568" : page.border

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        DrawIcon {
            anchors.centerIn: parent
            width: 23
            height: 23
            name: button.iconName
            iconColor: button.enabled ? (button.hovered ? page.accent : page.textMain) : page.textMuted
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

    component DividerLine: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 69
        Layout.rightMargin: 14
        Layout.preferredHeight: 1
        color: page.border
    }

    component ErrorBox: Rectangle {
        id: box

        signal retryClicked()

        property string text: ""
        property bool loading: false

        color: page.dangerSoft
        radius: 22
        border.width: 1
        border.color: "#5A2D31"

        Layout.preferredHeight: errorColumn.implicitHeight + 24

        ColumnLayout {
            id: errorColumn

            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 15
                    color: "#4A2529"

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        name: "warning"
                        iconColor: page.danger
                    }
                }

                Text {
                    text: box.text
                    color: "#FFD7DA"
                    font.pixelSize: 13
                    font.bold: true
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2

                    Layout.fillWidth: true
                }
            }

            AppButton {
                id: retryButton

                text: "Повторить"
                variant: "dangerOutline"
                visible: !box.loading

                Layout.alignment: Qt.AlignRight
                Layout.preferredHeight: 40
                Layout.preferredWidth: 126

                onClicked: {
                    box.retryClicked()
                }
            }
        }
    }

    component AppButton: Item {
        id: button

        signal clicked()

        property string text: ""
        property string variant: "primary"
        property bool hovered: buttonMouse.containsMouse
        property bool pressed: buttonMouse.pressed

        opacity: enabled ? 1.0 : 0.45
        scale: button.pressed ? 0.975 : button.hovered ? 1.012 : 1.0

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
                    return page.surface3

                if (button.variant === "danger")
                    return button.pressed ? "#C94D4D" : button.hovered ? "#E85D5D" : page.danger

                if (button.variant === "dangerOutline")
                    return button.pressed ? "#5A2D31" : button.hovered ? "#3A2023" : "transparent"

                if (button.variant === "neutral")
                    return button.pressed ? page.surface3 : button.hovered ? "#242A34" : page.surface2

                return button.pressed ? "#255FA9" : button.hovered ? "#2B6CBE" : page.accent
            }

            border.width: button.variant === "neutral" || button.variant === "dangerOutline" ? 1 : 0
            border.color: {
                if (button.variant === "dangerOutline")
                    return page.danger

                if (button.variant === "neutral")
                    return button.hovered ? "#284568" : page.border

                return "transparent"
            }

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: button.text

            color: {
                if (!button.enabled)
                    return page.textMuted

                if (button.variant === "dangerOutline")
                    return page.danger

                if (button.variant === "neutral")
                    return page.textMain

                return "#FFFFFF"
            }

            font.pixelSize: 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: buttonMouse
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

            if (icon.name === "refresh") {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.28, 0.25 * Math.PI, 1.7 * Math.PI)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.72), py(0.18))
                ctx.lineTo(px(0.82), py(0.17))
                ctx.lineTo(px(0.78), py(0.31))
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.28, 1.25 * Math.PI, 0.7 * Math.PI)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.28), py(0.82))
                ctx.lineTo(px(0.18), py(0.83))
                ctx.lineTo(px(0.22), py(0.69))
                ctx.stroke()
            } else if (icon.name === "mail") {
                ctx.beginPath()
                ctx.roundedRect(px(0.14), py(0.24), s * 0.72, s * 0.52, s * 0.08, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.16), py(0.3))
                ctx.lineTo(px(0.5), py(0.55))
                ctx.lineTo(px(0.84), py(0.3))
                ctx.stroke()
            } else if (icon.name === "lock") {
                ctx.beginPath()
                ctx.roundedRect(px(0.2), py(0.42), s * 0.6, s * 0.38, s * 0.08, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.5), py(0.42), s * 0.19, Math.PI, 0, false)
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.5), py(0.6), s * 0.035, 0, Math.PI * 2)
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.63))
                ctx.lineTo(px(0.5), py(0.7))
                ctx.stroke()
            } else if (icon.name === "devices") {
                ctx.beginPath()
                ctx.roundedRect(px(0.12), py(0.22), s * 0.5, s * 0.38, s * 0.06, s * 0.06)
                ctx.stroke()

                ctx.beginPath()
                ctx.roundedRect(px(0.56), py(0.42), s * 0.28, s * 0.38, s * 0.06, s * 0.06)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.68))
                ctx.lineTo(px(0.48), py(0.68))
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.7), py(0.72), s * 0.015, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.name === "logout") {
                ctx.beginPath()
                ctx.moveTo(px(0.18), py(0.2))
                ctx.lineTo(px(0.18), py(0.8))
                ctx.lineTo(px(0.52), py(0.8))
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.46), py(0.5))
                ctx.lineTo(px(0.84), py(0.5))
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.68), py(0.34))
                ctx.lineTo(px(0.84), py(0.5))
                ctx.lineTo(px(0.68), py(0.66))
                ctx.stroke()
            } else if (icon.name === "phone") {
                ctx.beginPath()
                ctx.moveTo(px(0.3), py(0.18))
                ctx.quadraticCurveTo(px(0.2), py(0.22), px(0.24), py(0.36))
                ctx.quadraticCurveTo(px(0.35), py(0.7), px(0.64), py(0.78))
                ctx.quadraticCurveTo(px(0.78), py(0.82), px(0.83), py(0.7))
                ctx.lineTo(px(0.72), py(0.6))
                ctx.quadraticCurveTo(px(0.67), py(0.55), px(0.6), py(0.6))
                ctx.lineTo(px(0.53), py(0.65))
                ctx.quadraticCurveTo(px(0.38), py(0.56), px(0.34), py(0.42))
                ctx.lineTo(px(0.42), py(0.35))
                ctx.quadraticCurveTo(px(0.47), py(0.3), px(0.42), py(0.24))
                ctx.lineTo(px(0.3), py(0.18))
                ctx.stroke()
            } else if (icon.name === "calendar") {
                ctx.beginPath()
                ctx.roundedRect(px(0.16), py(0.22), s * 0.68, s * 0.6, s * 0.08, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.16), py(0.4))
                ctx.lineTo(px(0.84), py(0.4))
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.32), py(0.16))
                ctx.lineTo(px(0.32), py(0.28))
                ctx.moveTo(px(0.68), py(0.16))
                ctx.lineTo(px(0.68), py(0.28))
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.36), py(0.56), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.5), py(0.56), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.64), py(0.56), s * 0.025, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.name === "user") {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.34), s * 0.16, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.roundedRect(px(0.24), py(0.58), s * 0.52, s * 0.24, s * 0.12, s * 0.12)
                ctx.stroke()
            } else if (icon.name === "chevron") {
                ctx.beginPath()
                ctx.moveTo(px(0.38), py(0.24))
                ctx.lineTo(px(0.62), py(0.5))
                ctx.lineTo(px(0.38), py(0.76))
                ctx.stroke()
            } else if (icon.name === "warning") {
                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.14))
                ctx.lineTo(px(0.86), py(0.78))
                ctx.lineTo(px(0.14), py(0.78))
                ctx.closePath()
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.36))
                ctx.lineTo(px(0.5), py(0.58))
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.5), py(0.69), s * 0.025, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.name === "info") {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.34, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.5), py(0.32), s * 0.025, 0, Math.PI * 2)
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.46))
                ctx.lineTo(px(0.5), py(0.68))
                ctx.stroke()
            } else {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.08, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }
}