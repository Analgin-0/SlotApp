import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Item {
    id: page

    signal backRequested()

    property int contentTopInset: 0
    property int contentBottomInset: 0

    property bool firstShow: true
    property bool waitingList: false
    property bool waitingRevoke: false
    property bool waitingRevokeOthers: false
    property bool waitingDelete: false

    property int deleteSessionId: 0
    property int revokeSessionId: 0

    property string errorText: ""
    property string sessionsMessage: "Сессии не загружены."

    readonly property int desktopBreakpoint: 900
    readonly property bool desktopMode: page.width >= page.desktopBreakpoint
    readonly property int contentMaxWidth: 980
    readonly property int pageSideMargin: page.desktopMode ? 24 : 14
    readonly property int headerBackSize: page.width < 420 ? 42 : 48
    readonly property int headerIconSize: page.width < 420 ? 46 : 58
    readonly property int headerTitleSize: page.width < 420 ? 24 : 29

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

    ListModel {
        id: sessionsModel
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

    function clearRevokedSessions() {
        if (page.busy())
            return

        var deletedCount = 0

             for (var i = sessionsModel.count - 1; i >= 0; i--) {
            var item = sessionsModel.get(i)

            if (item.isRevoked && !item.isCurrent) {
                  Db.deleteTableData("UserSession", item.sessionId)
                  sessionsModel.remove(i)
                deletedCount++
            }
        }

        if (sessionsModel.count === 0)
            sessionsMessage = "Сессии не найдены."
    }

    function refreshData() {
        startLoad()
    }

    function busy() {
        return waitingList || waitingRevoke || waitingRevokeOthers || waitingDelete
    }

    function startLoad() {
        if (page.busy())
            return

        errorText = ""

         sessionsMessage = sessionsModel.count === 0 ? "Загружаем сессии..." : ""

        waitingList = true
        Db.getMySessions()
    }

    function valueOrEmpty(value) {
        if (value === undefined || value === null)
            return ""

        var s = String(value).trim()

        if (s.toLowerCase() === "null" || s.toLowerCase() === "undefined")
            return ""

        return s
    }

    function safeBool(value) {
        if (value === true)
            return true

        if (value === false)
            return false

        if (value === 1 || value === "1")
            return true

        if (value === 0 || value === "0")
            return false

        var s = String(value).trim().toLowerCase()

        return s === "true"
                || s === "yes"
                || s === "да"
    }

    function formatDateTime(value) {
        var s = valueOrEmpty(value)

        if (s.length === 0)
            return ""

        var tIndex = s.indexOf("T")
        if (tIndex > 0)
            s = s.substring(0, tIndex) + " " + s.substring(tIndex + 1)

        if (s.length >= 19)
            s = s.substring(0, 19)

        return s
    }

    function formatSessionTitle(session) {
        var title = valueOrEmpty(session.device_name)

        if (title.length === 0)
            title = valueOrEmpty(session.platform)

        if (title.length === 0)
            title = "Устройство"

        if (safeBool(session.is_current))
            title += " · текущая сессия"
        else if (safeBool(session.is_revoked))
            title += " · завершена"

        return title
    }

    function formatSessionText(session) {
        var lines = []

        var platform = valueOrEmpty(session.platform)
        var ip = valueOrEmpty(session.ip_address)
        var created = formatDateTime(session.created_at)
        var lastActivity = formatDateTime(session.last_activity_at)
        var expires = formatDateTime(session.expires_at)

        if (platform.length > 0)
            lines.push("Платформа: " + platform)

        if (ip.length > 0)
            lines.push("IP: " + ip)

        if (created.length > 0)
            lines.push("Вход: " + created)

        if (lastActivity.length > 0)
            lines.push("Последняя активность: " + lastActivity)

        if (expires.length > 0)
            lines.push("Истекает: " + expires)

        if (safeBool(session.is_revoked))
            lines.push("Статус: завершена")

        if (lines.length === 0)
            return "Нет данных по сессии."

        return lines.join("\n")
    }

    function fillSessions(sessions) {
        sessionsModel.clear()

        if (!sessions || sessions.length === 0) {
            sessionsMessage = "Сессии не найдены."
            return
        }

        sessionsMessage = ""

        for (var i = 0; i < sessions.length; ++i) {
            var session = sessions[i]
            var current = safeBool(session.is_current)
            var revoked = safeBool(session.is_revoked)

            sessionsModel.append({
                                     sessionId: Number(session.id || 0),
                                     title: formatSessionTitle(session),
                                     text: formatSessionText(session),
                                     isCurrent: current,
                                     isRevoked: revoked
                                 })
        }
    }

    function removeSessionFromModel(sessionId) {
        for (var i = 0; i < sessionsModel.count; i++) {
            var item = sessionsModel.get(i)

            if (Number(item.sessionId) === Number(sessionId)) {
                sessionsModel.remove(i)
                break
            }
        }

        if (sessionsModel.count === 0)
            sessionsMessage = "Сессии не найдены."
        else
            sessionsMessage = ""
    }

    function markSessionRevoked(sessionId) {
        for (var i = 0; i < sessionsModel.count; i++) {
            var item = sessionsModel.get(i)

            if (Number(item.sessionId) === Number(sessionId)) {
                sessionsModel.setProperty(i, "isRevoked", true)

                if (String(item.title).indexOf("завершена") < 0)
                    sessionsModel.setProperty(i, "title", item.title + " · завершена")

                if (String(item.text).indexOf("Статус: завершена") < 0)
                    sessionsModel.setProperty(i, "text", item.text + "\nСтатус: завершена")

                break
            }
        }
    }

    function markOtherSessionsRevoked() {
        for (var i = 0; i < sessionsModel.count; i++) {
            var item = sessionsModel.get(i)

            if (!item.isCurrent && !item.isRevoked) {
                sessionsModel.setProperty(i, "isRevoked", true)

                if (String(item.title).indexOf("завершена") < 0)
                    sessionsModel.setProperty(i, "title", item.title + " · завершена")

                if (String(item.text).indexOf("Статус: завершена") < 0)
                    sessionsModel.setProperty(i, "text", item.text + "\nСтатус: завершена")
            }
        }
    }

    function revokeSession(sessionId) {
        if (page.busy())
            return

        if (sessionId <= 0)
            return

        page.errorText = ""
        page.revokeSessionId = sessionId
        page.waitingRevoke = true
        Db.logoutSession(sessionId)
    }

    function deleteFinishedSession(sessionId) {
        if (page.busy())
            return

        if (sessionId <= 0)
            return

        page.errorText = ""
        page.deleteSessionId = sessionId
        page.waitingDelete = true

        Db.deleteTableData("UserSession", sessionId)
    }

    function revokeOtherSessions() {
        if (page.busy())
            return

        page.errorText = ""
        page.waitingRevokeOthers = true
        Db.logoutOtherSessions()
    }

    Component.onCompleted: {
        if (visible && firstShow) {
            firstShow = false
            refreshTimer.start()
        }
    }

    onVisibleChanged: {
        if (visible && firstShow) {
            firstShow = false
            refreshTimer.start()
        }
    }

    Timer {
        id: refreshTimer
        interval: 0
        repeat: false

        onTriggered: {
            page.refreshData()
        }
    }

    Connections {
        target: Db

        function onDisconnectedFromServer() {
            if (page.busy()) {
                page.waitingList = false
                page.waitingRevoke = false
                page.waitingRevokeOthers = false
                page.waitingDelete = false
                page.deleteSessionId = 0
                page.revokeSessionId = 0
                page.errorText = "Соединение с сервером потеряно."
            }
        }

        function onConnectionError(error) {
            if (page.busy()) {
                page.waitingList = false
                page.waitingRevoke = false
                page.waitingRevokeOthers = false
                page.waitingDelete = false
                page.deleteSessionId = 0
                page.revokeSessionId = 0
                page.errorText = error && error.length > 0
                        ? error
                        : "Ошибка подключения к серверу."
            }
        }

        function onResponseReceived(response) {
            if (!response)
                return

            if (response.code === "unauthorized") {
                page.waitingList = false
                page.waitingRevoke = false
                page.waitingRevokeOthers = false
                page.waitingDelete = false
                page.deleteSessionId = 0
                page.revokeSessionId = 0
                page.errorText = "Сессия устарела. Войдите заново."
                return
            }

            var cmd = page.responseCmd(response)

            if (page.waitingDelete) {
                if (cmd.length > 0
                        && cmd !== "delete_table_data"
                        && cmd !== "delete_session"
                        && cmd !== "deleteUserSession")
                    return

                var removedId = page.deleteSessionId

                page.waitingDelete = false
                page.deleteSessionId = 0

                if (!response.ok) {
                    page.errorText = response.error && response.error.length > 0
                            ? response.error
                            : "Не удалось удалить завершённую сессию."
                    return
                }

                page.errorText = ""
                page.removeSessionFromModel(removedId)
                return
            }

            if (page.waitingRevoke) {
                if (cmd.length > 0
                        && cmd !== "logout_session"
                        && cmd !== "logoutSession")
                    return

                var revokedId = page.revokeSessionId

                page.waitingRevoke = false
                page.revokeSessionId = 0

                if (!response.ok) {
                    page.errorText = response.error && response.error.length > 0
                            ? response.error
                            : "Не удалось завершить сессию."
                    return
                }

                page.errorText = ""
                page.markSessionRevoked(revokedId)
                return
            }

            if (page.waitingRevokeOthers) {
                if (cmd.length > 0
                        && cmd !== "logout_other_sessions"
                        && cmd !== "logoutOtherSessions")
                    return

                page.waitingRevokeOthers = false

                if (!response.ok) {
                    page.errorText = response.error && response.error.length > 0
                            ? response.error
                            : "Не удалось завершить другие сессии."
                    return
                }

                page.errorText = ""
                page.markOtherSessionsRevoked()
                return
            }

            if (page.waitingList) {
                if (cmd.length > 0
                        && cmd !== "get_my_sessions"
                        && cmd !== "getMySessions")
                    return

                page.waitingList = false

                if (response.ok && response.sessions) {
                    page.fillSessions(response.sessions)
                    page.errorText = ""
                } else {
                    sessionsModel.clear()
                    page.sessionsMessage = response.error && response.error.length > 0
                            ? response.error
                            : "Не удалось загрузить список сессий."
                }
            }
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
        contentWidth: availableWidth
        contentHeight: contentColumn.implicitHeight

        topPadding: page.contentTopInset + (page.desktopMode ? 24 : 14)
        bottomPadding: page.contentBottomInset + 28

        background: Rectangle {
            color: page.bg
        }

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: contentColumn

            width: scrollView.availableWidth
            spacing: page.desktopMode ? 18 : 14

            HeaderCard {
                Layout.fillWidth: true
                Layout.maximumWidth: page.contentMaxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: page.pageSideMargin
                Layout.rightMargin: page.pageSideMargin
            }

            ErrorBox {
                visible: page.errorText.length > 0
                text: page.errorText

                Layout.fillWidth: true
                Layout.maximumWidth: page.contentMaxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: page.pageSideMargin
                Layout.rightMargin: page.pageSideMargin
            }

            ActionCard {
                Layout.fillWidth: true
                Layout.maximumWidth: page.contentMaxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: page.pageSideMargin
                Layout.rightMargin: page.pageSideMargin
            }

            SectionHeader {
                title: "Устройства"
                countText: String(sessionsModel.count)

                Layout.fillWidth: true
                Layout.maximumWidth: page.contentMaxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: page.pageSideMargin + 2
                Layout.rightMargin: page.pageSideMargin + 2
            }

            MessageCard {
                visible: page.sessionsMessage.length > 0 && sessionsModel.count === 0
                iconName: page.waitingList ? "clock" : "empty"
                text: page.sessionsMessage
                iconColor: page.waitingList ? page.accent : page.textMuted
                bgColor: page.waitingList ? page.accentSoft : page.surface

                Layout.fillWidth: true
                Layout.maximumWidth: page.contentMaxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: page.pageSideMargin
                Layout.rightMargin: page.pageSideMargin
            }

            Repeater {
                model: sessionsModel

                delegate: SessionCard {
                    Layout.fillWidth: true
                    Layout.maximumWidth: page.contentMaxWidth
                    Layout.alignment: Qt.AlignHCenter
                    Layout.leftMargin: page.pageSideMargin
                    Layout.rightMargin: page.pageSideMargin

                    sessionIdValue: model.sessionId
                    titleText: model.title
                    bodyText: model.text
                    currentSession: model.isCurrent
                    revoked: model.isRevoked

                    onRevokeClicked: function(idValue) {
                        page.revokeSession(idValue)
                    }

                    onDeleteClicked: function(idValue) {
                        page.deleteFinishedSession(idValue)
                    }
                }
            }

            Text {
                visible: sessionsModel.count > 0
                text: "Текущую сессию можно завершить обычным выходом из аккаунта."
                color: page.textMuted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.2

                Layout.fillWidth: true
                Layout.maximumWidth: page.contentMaxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: page.pageSideMargin + 8
                Layout.rightMargin: page.pageSideMargin + 8
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
            }
        }
    }

    component HeaderCard: Rectangle {
        id: card

        property bool hovered: hoverArea.containsMouse

        color: card.hovered && page.desktopMode ? page.surface2 : page.surface
        radius: 26
        border.width: 1
        border.color: card.hovered && page.desktopMode ? "#284568" : page.border

        Layout.preferredHeight: headerColumn.implicitHeight + (page.width < 420 ? 28 : 34)

        scale: card.hovered && page.desktopMode ? 1.004 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            id: headerColumn

            anchors.fill: parent
            anchors.margins: page.width < 420 ? 14 : 17
            spacing: page.width < 420 ? 12 : 14

            RowLayout {
                Layout.fillWidth: true
                spacing: page.width < 420 ? 8 : 12

                IconActionButton {
                    id: backButton

                    iconName: "back"
                    enabled: !page.busy()

                    Layout.preferredWidth: page.headerBackSize
                    Layout.preferredHeight: page.headerBackSize

                    onClicked: {
                        page.backRequested()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: page.headerIconSize
                    Layout.preferredHeight: page.headerIconSize
                    radius: page.width < 420 ? 17 : 20
                    color: page.accentSoft
                    border.width: 1
                    border.color: "#284568"

                    DrawIcon {
                        anchors.centerIn: parent
                        width: page.width < 420 ? 24 : 30
                        height: page.width < 420 ? 24 : 30
                        name: "devices"
                        iconColor: page.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: page.width < 420 ? "Входы\nи устройства" : "Входы и устройства"
                        color: page.textMain
                        font.pixelSize: page.headerTitleSize
                        font.bold: true
                        maximumLineCount: page.width < 420 ? 2 : 1
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }

                    Text {
                        text: page.width < 420 ? "Сессии аккаунта" : "Активные входы и устройства аккаунта"
                        color: page.textMuted
                        font.pixelSize: page.width < 420 ? 13 : 14
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }
                }

                BusyIndicator {
                    running: page.busy()

                    visible: true
                    opacity: running ? 1.0 : 0.0

                    Layout.preferredWidth: page.width < 420 ? 24 : 30
                    Layout.preferredHeight: page.width < 420 ? 24 : 30
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Badge {
                    text: sessionsModel.count === 0 ? "Нет данных" : String(sessionsModel.count) + " сесс."
                    colorBg: page.surface2
                    colorText: page.textSub
                }

                Badge {
                    visible: page.waitingList
                    text: "Обновление"
                    colorBg: page.accentSoft
                    colorText: page.accent
                }

                Badge {
                    visible: page.waitingRevoke || page.waitingRevokeOthers || page.waitingDelete
                    text: "Изменение"
                    colorBg: page.warningSoft
                    colorText: page.warning
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }

    component ActionCard: Rectangle {
        id: card

        property bool hovered: hoverArea.containsMouse
        property bool pressed: pressHandler.pressed

        color: card.hovered && page.desktopMode ? page.surface2 : page.surface
        radius: 26
        border.width: 1
        border.color: card.hovered && page.desktopMode ? "#284568" : page.border

        Layout.preferredHeight: actionsColumn.implicitHeight + 32

        scale: card.pressed ? 0.992 : card.hovered && page.desktopMode ? 1.004 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

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
            id: actionsColumn

            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    radius: 14
                    color: page.surface2
                    border.width: 1
                    border.color: page.border

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        name: "shield"
                        iconColor: page.textSub
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Безопасность"
                        color: page.textMain
                        font.pixelSize: 18
                        font.bold: true

                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Проверьте активные входы и завершите лишние."
                        color: page.textMuted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap

                        Layout.fillWidth: true
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columnSpacing: 10
                rowSpacing: 10


                columns: page.width < 550 ? 2 : 3

                AppButton {
                    text: page.waitingList ? "Загрузка..." : "Обновить"
                    variant: "tonal"
                    enabled: !page.busy()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 38

                    onClicked: {
                        page.startLoad()
                    }
                }

                AppButton {
                    text: "Удалить старые"
                    variant: "neutral"
                    enabled: !page.busy()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 38

                    onClicked: {
                        page.clearRevokedSessions()
                    }
                }

                AppButton {
                    text: page.waitingRevokeOthers ? "Завершаем..." : "Выйти везде"
                    variant: "danger"
                    enabled: !page.busy()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 38

                      Layout.columnSpan: page.width < 550 ? 2 : 1

                    onClicked: {
                        page.revokeOtherSessions()
                    }
                }
            }
        }
    }

    component SectionHeader: RowLayout {
        id: section

        property string title: ""
        property string countText: ""

        spacing: 10

        Text {
            text: section.title
            color: page.textMain
            font.pixelSize: 19
            font.bold: true
            maximumLineCount: 1
            elide: Text.ElideRight

            Layout.fillWidth: true
        }

        Rectangle {
            Layout.preferredWidth: counterText.implicitWidth + 18
            Layout.preferredHeight: 28
            radius: 14
            color: page.surface2
            border.width: 1
            border.color: page.border

            Text {
                id: counterText

                anchors.centerIn: parent
                text: section.countText
                color: page.textSub
                font.pixelSize: 12
                font.bold: true
            }
        }
    }

    component SessionCard: Rectangle {
        id: card

        signal revokeClicked(int idValue)
        signal deleteClicked(int idValue)

        property int sessionIdValue: 0
        property string titleText: ""
        property string bodyText: ""
        property bool currentSession: false
        property bool revoked: false
        property bool hovered: hoverArea.containsMouse
        property bool pressed: pressHandler.pressed

        color: card.hovered && page.desktopMode ? page.surface2 : page.surface
        radius: 26
        border.width: 1
        border.color: card.revoked ? "#5A2D31" : card.hovered && page.desktopMode ? "#284568" : page.border

        Layout.preferredHeight: sessionColumn.implicitHeight + 32

        scale: card.pressed ? 0.992 : card.hovered && page.desktopMode ? 1.004 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

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
            id: sessionColumn

            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 50
                    Layout.preferredHeight: 50
                    radius: 18
                    color: card.revoked
                           ? page.dangerSoft
                           : card.currentSession
                             ? page.successSoft
                             : page.accentSoft
                    border.width: 1
                    border.color: card.revoked
                                  ? "#5A2D31"
                                  : card.currentSession
                                    ? "#24513C"
                                    : "#284568"

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        name: card.revoked ? "logout" : card.currentSession ? "check" : "device"
                        iconColor: card.revoked
                                   ? page.danger
                                   : card.currentSession
                                     ? page.success
                                     : page.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: card.titleText
                        color: page.textMain
                        font.pixelSize: 17
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Badge {
                            text: card.currentSession ? "Текущая" : card.revoked ? "Завершена" : "Активная"
                            colorBg: card.currentSession
                                     ? page.successSoft
                                     : card.revoked
                                       ? page.dangerSoft
                                       : page.accentSoft
                            colorText: card.currentSession
                                       ? page.success
                                       : card.revoked
                                         ? page.danger
                                         : page.accent
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: detailsText.implicitHeight + 24

                radius: 20
                color: page.surface2
                border.width: 1
                border.color: page.border

                Text {
                    id: detailsText

                    anchors.fill: parent
                    anchors.margins: 12
                    text: card.bodyText
                    color: page.textSub
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    lineHeight: 1.2
                }
            }

            AppButton {
                visible: !card.currentSession && !card.revoked
                text: page.waitingRevoke && page.revokeSessionId === card.sessionIdValue
                      ? "Завершаем..."
                      : "Завершить сессию"
                variant: "sessionDanger"
                enabled: !page.busy()

                onClicked: {
                    card.revokeClicked(card.sessionIdValue)
                }
            }

            AppButton {
                visible: !card.currentSession && card.revoked
                text: page.waitingDelete && page.deleteSessionId === card.sessionIdValue
                      ? "Удаляем..."
                      : "Удалить из списка"
                variant: "delete"
                enabled: !page.busy()

                onClicked: {
                    card.deleteClicked(card.sessionIdValue)
                }
            }
        }
    }

    component Badge: Rectangle {
        id: badge

        property string text: ""
        property color colorBg: page.surface2
        property color colorText: page.textSub
        property bool hovered: hoverArea.containsMouse

        radius: 999
        color: badge.hovered && page.desktopMode ? page.surface3 : badge.colorBg
        border.width: badge.hovered && page.desktopMode ? 1 : 0
        border.color: page.border

        Layout.preferredHeight: 30
        Layout.preferredWidth: badgeText.implicitWidth + 22

        Behavior on color { ColorAnimation { duration: 130 } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Text {
            id: badgeText

            anchors.centerIn: parent
            text: badge.text
            color: badge.colorText
            font.pixelSize: 12
            font.bold: true
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }

    component MessageCard: Rectangle {
        id: card

        property string iconName: ""
        property string text: ""
        property color iconColor: page.accent
        property color bgColor: page.surface
        property bool hovered: hoverArea.containsMouse
        property bool pressed: pressHandler.pressed

        color: card.hovered && page.desktopMode ? page.surface2 : card.bgColor
        radius: 24
        border.width: 1
        border.color: card.hovered && page.desktopMode ? "#284568" : page.border

        Layout.preferredHeight: msgRow.implicitHeight + 28

        scale: card.pressed ? 0.992 : 1.0

        Behavior on color { ColorAnimation { duration: 150 } }
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
            id: msgRow

            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 16
                color: Qt.rgba(card.iconColor.r, card.iconColor.g, card.iconColor.b, 0.14)

                DrawIcon {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    name: card.iconName
                    iconColor: card.iconColor
                }
            }

            Text {
                text: card.text
                color: page.textSub
                font.pixelSize: 14
                font.bold: true
                wrapMode: Text.WordWrap
                lineHeight: 1.15

                Layout.fillWidth: true
            }
        }
    }

    component ErrorBox: Rectangle {
        id: box

        property string text: ""
        property bool hovered: hoverArea.containsMouse

        color: page.dangerSoft
        radius: 22
        border.width: 1
        border.color: box.hovered && page.desktopMode ? page.danger : "#5A2D31"

        Layout.preferredHeight: errorRow.implicitHeight + 24

        Behavior on border.color { ColorAnimation { duration: 150 } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            id: errorRow

            anchors.fill: parent
            anchors.margins: 14
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
    }

    component IconActionButton: Item {
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
            radius: page.width < 420 ? 15 : 17
            color: {
                if (!button.enabled)
                    return page.surface2
                if (mouseArea.pressed)
                    return page.surface3
                if (button.hovered && page.desktopMode)
                    return page.accentSoft
                return page.surface2
            }
            border.width: 1
            border.color: button.hovered && page.desktopMode ? "#284568" : page.border

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        DrawIcon {
            anchors.centerIn: parent
            width: page.width < 420 ? 21 : 23
            height: page.width < 420 ? 21 : 23
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

    component AppButton: Item {
        id: button

        signal clicked()

        property string text: ""
        property string variant: "tonal"
        property bool hovered: mouseArea.containsMouse
        property bool dangerLike: variant === "danger" || variant === "sessionDanger"

        Layout.preferredHeight: variant === "sessionDanger" || variant === "delete" ? 44 : 50

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
            radius: button.variant === "sessionDanger" || button.variant === "delete" ? 17 : 18

            color: {
                if (!button.enabled)
                    return page.surface3

                if (button.variant === "danger") {
                    if (mouseArea.pressed)
                        return "#C94A4A"
                    if (button.hovered && page.desktopMode)
                        return "#E85D5D"
                    return page.danger
                }

                if (button.variant === "sessionDanger") {
                    if (mouseArea.pressed)
                        return "#44272A"
                    if (button.hovered && page.desktopMode)
                        return "#4A2529"
                    return page.dangerSoft
                }

                if (button.variant === "delete") {
                    if (mouseArea.pressed)
                        return page.surface3
                    if (button.hovered && page.desktopMode)
                        return page.surface3
                    return page.surface2
                }

                if (mouseArea.pressed)
                    return "#255FA9"
                if (button.hovered && page.desktopMode)
                    return "#2B6CBE"
                return page.accent
            }

            border.width: button.variant === "sessionDanger" || button.variant === "delete" || (button.hovered && page.desktopMode) ? 1 : 0

            border.color: {
                if (button.variant === "sessionDanger")
                    return page.danger

                if (button.variant === "delete")
                    return button.hovered && page.desktopMode ? page.textMuted : page.border

                if (button.hovered && page.desktopMode)
                    return button.dangerLike ? page.danger : "#7FB5FF"

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

                if (button.variant === "danger")
                    return "#FFFFFF"

                if (button.variant === "sessionDanger")
                    return page.danger

                if (button.variant === "delete")
                    return button.hovered && page.desktopMode ? page.textMain : page.textSub

                return "#FFFFFF"
            }

            font.pixelSize: button.variant === "sessionDanger" || button.variant === "delete" ? 13 : 14
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
            ctx.lineWidth = Math.max(1.8, s * 0.085)
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
            } else if (icon.name === "devices") {
                roundedRectPath(px(0.14), py(0.2), s * 0.5, s * 0.42, s * 0.07)
                ctx.stroke()

                roundedRectPath(px(0.5), py(0.38), s * 0.36, s * 0.46, s * 0.07)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.28), py(0.72))
                ctx.lineTo(px(0.5), py(0.72))
                ctx.moveTo(px(0.39), py(0.62))
                ctx.lineTo(px(0.39), py(0.72))
                ctx.stroke()
            } else if (icon.name === "device") {
                roundedRectPath(px(0.24), py(0.12), s * 0.52, s * 0.76, s * 0.1)
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.5), py(0.78), s * 0.025, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.name === "shield") {
                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.12))
                ctx.lineTo(px(0.8), py(0.24))
                ctx.lineTo(px(0.75), py(0.58))
                ctx.quadraticCurveTo(px(0.68), py(0.78), px(0.5), py(0.88))
                ctx.quadraticCurveTo(px(0.32), py(0.78), px(0.25), py(0.58))
                ctx.lineTo(px(0.2), py(0.24))
                ctx.closePath()
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.36), py(0.5))
                ctx.lineTo(px(0.46), py(0.61))
                ctx.lineTo(px(0.66), py(0.39))
                ctx.stroke()
            } else if (icon.name === "logout") {
                roundedRectPath(px(0.16), py(0.2), s * 0.42, s * 0.6, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.48), py(0.5))
                ctx.lineTo(px(0.84), py(0.5))
                ctx.moveTo(px(0.7), py(0.36))
                ctx.lineTo(px(0.84), py(0.5))
                ctx.lineTo(px(0.7), py(0.64))
                ctx.stroke()
            } else if (icon.name === "check") {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.34, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.51))
                ctx.lineTo(px(0.46), py(0.63))
                ctx.lineTo(px(0.68), py(0.39))
                ctx.stroke()
            } else if (icon.name === "clock") {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.34, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.3))
                ctx.lineTo(px(0.5), py(0.52))
                ctx.lineTo(px(0.66), py(0.62))
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
            } else if (icon.name === "empty") {
                roundedRectPath(px(0.2), py(0.22), s * 0.6, s * 0.52, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.5))
                ctx.lineTo(px(0.66), py(0.5))
                ctx.stroke()
            } else {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.08, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }
}