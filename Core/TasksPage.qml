import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Item {
    id: page

    focus: true

    signal addTaskRequested()

    property bool active: visible

    property var tasksModel
    property int viewerRole: 3
    property int bottomInset: 0
    property int modelRevision: 0
    property bool loading: false
    property bool actionBusy: false
    property string loadError: ""

    property int pendingRateRow: -1
    property int pendingRateAppointmentId: 0
    property int pendingRateValue: 0

    property int pendingCancelRow: -1

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
    readonly property color success: "#6EE7A8"
    readonly property color successSoft: "#173427"
    readonly property color danger: "#FF6B6B"
    readonly property color dangerSoft: "#3A2023"
    readonly property color warning: "#FFD166"
    readonly property color warningSoft: "#392F18"

    readonly property int desktopBreakpoint: 900
    readonly property bool desktopMode: page.width >= page.desktopBreakpoint
    readonly property int desktopContentMaxWidth: 1180
    readonly property int desktopCardRadius: 28

    function canAddTask() {
        return Number(page.viewerRole) === 1
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

    function resetPendingRating() {
        page.actionBusy = false
        page.pendingRateRow = -1
        page.pendingRateAppointmentId = 0
        page.pendingRateValue = 0
    }

    function safeString(value) {
        if (value === undefined || value === null)
            return ""

        return String(value)
    }

    function safeInt(value, fallback) {
        if (value === undefined || value === null || value === "")
            return fallback

        var n = Number(value)

        if (isNaN(n))
            return fallback

        return Math.round(n)
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

        var text = String(value).trim().toLowerCase()

        return text === "true"
            || text === "yes"
            || text === "да"
            || text === "passed"
            || text === "done"
            || text === "completed"
            || text === "canceled"
            || text === "cancelled"
            || text.indexOf("отмен") >= 0
            || text.indexOf("прош") >= 0
    }

    function formatDateValue(value) {
        if (value === undefined || value === null)
            return ""

        var text = String(value).trim()

        if (text.length === 0)
            return ""

        var tIndex = text.indexOf("T")
        if (tIndex > 0)
            return text.substring(0, tIndex)

        var spaceIndex = text.indexOf(" ")
        if (spaceIndex > 0)
            return text.substring(0, spaceIndex)

        return text
    }

    function formatTimeValue(value) {
        if (value === undefined || value === null)
            return ""

        var text = String(value).trim()

        if (text.length === 0)
            return ""

        var spaceIndex = text.indexOf(" ")
        if (spaceIndex >= 0 && text.length >= spaceIndex + 6)
            return text.substring(spaceIndex + 1, spaceIndex + 6)

        var tIndex = text.indexOf("T")
        if (tIndex >= 0 && text.length >= tIndex + 6)
            return text.substring(tIndex + 1, tIndex + 6)

        if (text.length >= 5 && text.charAt(2) === ":")
            return text.substring(0, 5)

        return text
    }

    function parseDateParts(dateText) {
        var d = formatDateValue(dateText)

        if (d.length === 0)
            return null

        var year = 0
        var month = 0
        var day = 0

        if (d.indexOf("-") > 0) {
            var p = d.split("-")

            if (p.length !== 3)
                return null

            year = Number(p[0])
            month = Number(p[1])
            day = Number(p[2])
        } else if (d.indexOf(".") > 0) {
            var p2 = d.split(".")

            if (p2.length !== 3)
                return null

            day = Number(p2[0])
            month = Number(p2[1])
            year = Number(p2[2])
        } else {
            return null
        }

        if (isNaN(year) || isNaN(month) || isNaN(day))
            return null

        if (year <= 0 || month <= 0 || day <= 0)
            return null

        return {
            year: year,
            month: month,
            day: day
        }
    }

    function parseTimeParts(timeText) {
        var t = formatTimeValue(timeText)

        if (t.length < 5)
            return null

        if (t.charAt(2) !== ":")
            return null

        var hour = Number(t.substring(0, 2))
        var minute = Number(t.substring(3, 5))

        if (isNaN(hour) || isNaN(minute))
            return null

        if (hour < 0 || hour > 23 || minute < 0 || minute > 59)
            return null

        return {
            hour: hour,
            minute: minute
        }
    }

    function isAppointmentPassedByDate(dateText, timeText) {
        var dateParts = parseDateParts(dateText)

        if (dateParts === null)
            return false

        var timeParts = parseTimeParts(timeText)
        var now = new Date()

        if (timeParts === null) {
            var appointmentDay = new Date(
                dateParts.year,
                dateParts.month - 1,
                dateParts.day,
                0,
                0,
                0,
                0
            )

            var today = new Date(
                now.getFullYear(),
                now.getMonth(),
                now.getDate(),
                0,
                0,
                0,
                0
            )

            return appointmentDay.getTime() < today.getTime()
        }

        var appointmentDateTime = new Date(
            dateParts.year,
            dateParts.month - 1,
            dateParts.day,
            timeParts.hour,
            timeParts.minute,
            0,
            0
        )

        return appointmentDateTime.getTime() < now.getTime()
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

    function isArrayLike(value) {
        return value !== undefined
            && value !== null
            && typeof value !== "string"
            && value.length !== undefined
    }

    function extractAppointmentsArray(obj) {
        if (!obj)
            return []

        if (isArrayLike(obj.appointments))
            return obj.appointments

        if (isArrayLike(obj.Appointments))
            return obj.Appointments

        if (isArrayLike(obj.MyTable))
            return obj.MyTable

        if (isArrayLike(obj.items))
            return obj.items

        if (isArrayLike(obj.table))
            return obj.table

        if (isArrayLike(obj.result))
            return obj.result

        if (isArrayLike(obj.data))
            return obj.data

        if (obj.data && isArrayLike(obj.data.appointments))
            return obj.data.appointments

        if (obj.result && isArrayLike(obj.result.appointments))
            return obj.result.appointments

        return []
    }

    function isGetAppointmentsResponse(obj) {
        if (!obj)
            return false

        var cmd = page.responseCmd(obj)

        if (cmd === "get_appointments")
            return true

        if (cmd === "getAppointments")
            return true

        if (cmd === "appointments")
            return true

        if (cmd === "get_table" && obj.table_name === "Appointments")
            return true

        return false
    }

    function isAppointmentsChangedResponse(obj) {
        if (!obj)
            return false

        var cmd = page.responseCmd(obj)

        if (cmd === "cancel_appointment")
            return true

        if (cmd === "cancelAppointment")
            return true

        if (cmd === "update_table_data" && obj.table_name === "Appointments")
            return true

        if (cmd === "add_table_data" && obj.table_name === "Appointments")
            return true

        if (cmd === "delete_table_data" && obj.table_name === "Appointments")
            return true

        return false
    }

    function isRateAppointmentResponse(obj) {
        if (!obj)
            return false

        var cmd = page.responseCmd(obj)

        if (cmd === "rate_appointment")
            return true

        if (cmd === "rateAppointment")
            return true

        if (cmd === "update_table_data" && obj.table_name === "Appointments")
            return true

        return false
    }

    function normalizeAppointment(src) {
        var statusText = safeString(firstValue(src, [
            "status",
            "Status",
            "appointmentStatus",
            "modelStatusText"
        ], ""))

        var statusLower = statusText.toLowerCase()

        var rawDate = firstValue(src, [
            "appointment_date",
            "Appointment_Date",
            "AppointmentDate",
            "appointmentDate",
            "consultation_date",
            "ConsultationDate",
            "consultationDate",
            "date",
            "Date",
            "dateText",
            "DateTime",
            "dateTime",
            "datetime",
            "appointmentDateTime",
            "AppointmentDateTime",
            "startDateTime",
            "StartDateTime",
            "start_at",
            "StartAt",
            "CreatedAt",
            "created_at"
        ], "")

        var rawTime = firstValue(src, [
            "appointment_time",
            "Appointment_Time",
            "AppointmentTime",
            "appointmentTime",
            "consultation_time",
            "ConsultationTime",
            "consultationTime",
            "time",
            "Time",
            "timeText",
            "startTime",
            "StartTime",
            "start_time",
            "Start_Time",
            "beginTime",
            "BeginTime",
            "begin_time"
        ], "")

        if (rawTime === undefined || rawTime === null || String(rawTime).trim().length === 0)
            rawTime = rawDate

        var dateText = formatDateValue(rawDate)
        var timeText = formatTimeValue(rawTime)

        var isCanceledRaw = firstValue(src, [
            "isCanceled",
            "isCancelled",
            "is_canceled",
            "is_cancelled",
            "canceled",
            "cancelled",
            "Canceled",
            "Cancelled"
        ], false)

        var passedRaw = firstValue(src, [
            "consultationPassed",
            "consultation_passed",
            "isPassed",
            "is_passed",
            "passed",
            "Passed"
        ], false)

        var isCanceled = safeBool(isCanceledRaw)
            || statusLower.indexOf("отмен") >= 0
            || statusLower.indexOf("cancel") >= 0
            || String(statusText) === "3"
            || Number(src.status) === 3

        var consultationPassed = safeBool(passedRaw)
            || statusLower.indexOf("прош") >= 0
            || statusLower.indexOf("done") >= 0
            || statusLower.indexOf("completed") >= 0
            || statusLower.indexOf("past") >= 0
            || String(statusText) === "2"
            || Number(src.status) === 2
            || page.isAppointmentPassedByDate(dateText, timeText)

        var appointmentId = safeInt(firstValue(src, [
            "appointmentId",
            "appointment_id",
            "id",
            "Id",
            "ID",
            "taskId",
            "AppointmentID"
        ], 0), 0)

        return {
            appointmentId: appointmentId,

            title: safeString(firstValue(src, [
                "title",
                "Title",
                "topic",
                "Topic",
                "theme",
                "Theme",
                "subject",
                "Subject"
            ], "")),

            description: safeString(firstValue(src, [
                "description",
                "Description",
                "comment",
                "Comment",
                "comments",
                "Comments"
            ], "")),

            date: dateText,
            time: timeText,

            cabinet: safeString(firstValue(src, [
                "cabinet",
                "Cabinet",
                "room",
                "Room",
                "cabinetText"
            ], "")),

            durationMinutes: safeInt(firstValue(src, [
                "durationMinutes",
                "DurationMinutes",
                "duration_minutes",
                "duration",
                "Duration",
                "minutes",
                "Minutes"
            ], 30), 30),

            isCanceled: isCanceled,
            consultationPassed: consultationPassed,

            rating: safeInt(firstValue(src, [
                "rating",
                "Rating",
                "mark",
                "Mark",
                "grade",
                "Grade"
            ], 0), 0),

            teacherName: safeString(firstValue(src, [
                "teacherName",
                "TeacherName",
                "teacher",
                "teacherFullName"
            ], "")),

            studentName: safeString(firstValue(src, [
                "studentName",
                "StudentName",
                "student",
                "studentFullName"
            ], "")),

            status: statusText,

            cancelledByRole: safeInt(firstValue(src, [
                "cancelledByRole",
                "CancelledByRole",
                "canceledByRole",
                "CanceledByRole",
                "cancelled_by_role",
                "canceled_by_role"
            ], 0), 0),

            cancelledByText: safeString(firstValue(src, [
                "cancelledByText",
                "CancelledByText",
                "canceledByText",
                "CanceledByText",
                "cancelled_by_text",
                "canceled_by_text",
                "cancelledBy",
                "canceledBy"
            ], ""))
        }
    }

    function belongsToSection(isCanceled, consultationPassed, section) {
        if (section === "upcoming")
            return !isCanceled && !consultationPassed

        if (section === "past")
            return !isCanceled && consultationPassed

        if (section === "cancelled")
            return isCanceled

        return false
    }

    function sectionCount(section) {
        var revision = page.modelRevision
        revision = revision

        if (!page.tasksModel)
            return 0

        var count = 0

        for (var i = 0; i < page.tasksModel.count; i++) {
            var item = page.tasksModel.get(i)

            if (page.belongsToSection(item.isCanceled, item.consultationPassed, section))
                count++
        }

        return count
    }

    function visibleAppointmentsCount() {
        return page.sectionCount("upcoming")
            + page.sectionCount("past")
            + page.sectionCount("cancelled")
    }

    function loadAppointments() {
        if (page.loading || page.actionBusy)
            return

        page.loadError = ""

        // Если данные уже есть, обновляем тихо.
        // Старый список остаётся на экране, loading-карточка не появляется.
        page.loading = true

        if (Db.isConnect()) {
            console.log("TasksPage: Db.getAppointments()")
            Db.getAppointments()
            return
        }

        console.log("TasksPage: connectToServer() before getAppointments")
        Db.connectToServer()
    }

    function fillTasksModel(items) {
        if (!page.tasksModel) {
            page.loading = false
            return
        }


        var hasItems = items && items.length

        if (!hasItems) {
            page.tasksModel.clear()
            page.modelRevision++
            page.loading = false
            return
        }

        var normalized = []

        for (var i = 0; i < items.length; i++)
            normalized.push(page.normalizeAppointment(items[i]))

        page.tasksModel.clear()

        for (var j = 0; j < normalized.length; j++)
            page.tasksModel.append(normalized[j])

        page.modelRevision++
        page.loading = false

        console.log("TasksPage: loaded appointments =", page.tasksModel.count)
    }

    function applyRatingLocally() {
        if (!page.tasksModel)
            return

        if (page.pendingRateRow >= 0 && page.pendingRateRow < page.tasksModel.count) {
            var item = page.tasksModel.get(page.pendingRateRow)

            if (item && Number(item.appointmentId) === Number(page.pendingRateAppointmentId)) {
                page.tasksModel.setProperty(page.pendingRateRow, "rating", page.pendingRateValue)
                page.modelRevision++
                return
            }
        }

        for (var i = 0; i < page.tasksModel.count; i++) {
            var item2 = page.tasksModel.get(i)

            if (item2 && Number(item2.appointmentId) === Number(page.pendingRateAppointmentId)) {
                page.tasksModel.setProperty(i, "rating", page.pendingRateValue)
                page.modelRevision++
                return
            }
        }
    }

    function cancelAppointment(row) {
        if (page.loading || page.actionBusy)
            return

        if (!page.tasksModel)
            return

        if (row < 0 || row >= page.tasksModel.count)
            return

        page.pendingCancelRow = row
        cancelConfirmDialog.open()
    }

    function executeCancelAppointment() {
        var row = page.pendingCancelRow
        if (row < 0 || row >= page.tasksModel.count)
            return

        var item = page.tasksModel.get(row)

        if (!item || !item.appointmentId || item.appointmentId <= 0) {
            page.loadError = "Не найден ID записи для отмены"
            return
        }

        page.loading = true
        page.loadError = ""

        console.log("TasksPage: cancelAppointment", item.appointmentId)

        Db.cancelAppointment(item.appointmentId)
    }

    function rateAppointment(row, value) {
        if (page.loading || page.actionBusy)
            return

        if (!page.tasksModel)
            return

        if (row < 0 || row >= page.tasksModel.count)
            return

        if (value < 1 || value > 5)
            return

        var item = page.tasksModel.get(row)

        if (!item || !item.appointmentId || item.appointmentId <= 0) {
            page.loadError = "Не найден ID записи для оценки"
            return
        }

        page.actionBusy = true
        page.pendingRateRow = row
        page.pendingRateAppointmentId = item.appointmentId
        page.pendingRateValue = value
        page.loadError = ""

        console.log("TasksPage: rateAppointment", item.appointmentId, value)
        Db.rateAppointment(item.appointmentId, value)
    }

    Component.onCompleted: {
        console.log("TasksPage loaded. role =", page.viewerRole)
        if (page.active)
            page.loadAppointments()
    }

    onActiveChanged: {
        if (page.active)
            page.loadAppointments()
    }

    Connections {
        target: Db

        function onConnectedToServer() {
            if (!page.loading)
                return

            console.log("TasksPage: connectedToServer -> getAppointments()")
            Db.getAppointments()
        }

        function onDisconnectedFromServer() {
            page.loading = false
            page.resetPendingRating()
            page.loadError = "Нет подключения к серверу"
        }

        function onConnectionError(error) {
            page.loading = false
            page.resetPendingRating()
            page.loadError = error || "Ошибка подключения к серверу"
        }

        function onResponseReceived(obj) {
            if (!obj)
                return

            console.log("TasksPage response:", JSON.stringify(obj))

            if (obj.code === "unauthorized") {
                page.loading = false
                page.resetPendingRating()
                page.loadError = "Сессия устарела. Войдите заново."
                return
            }

            if (page.actionBusy) {
                if (!page.isRateAppointmentResponse(obj))
                    return

                page.actionBusy = false

                if (obj.ok === false) {
                    page.loadError = obj.error || "Ошибка сохранения оценки"
                } else {
                    page.loadError = ""
                    page.applyRatingLocally()
                }

                page.pendingRateRow = -1
                page.pendingRateAppointmentId = 0
                page.pendingRateValue = 0
                return
            }

            if (page.isGetAppointmentsResponse(obj)) {
                if (obj.ok === false) {
                    page.loading = false
                    page.loadError = obj.error || "Ошибка загрузки записей"
                    return
                }

                page.fillTasksModel(page.extractAppointmentsArray(obj))
                return
            }

            if (page.isAppointmentsChangedResponse(obj)) {
                if (obj.ok === false) {
                    page.loading = false
                    page.loadError = obj.error || "Ошибка изменения записи"
                    return
                }

                page.loading = false
                page.loadAppointments()
                return
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

        topPadding: page.desktopMode ? 28 : 18
        bottomPadding: (page.desktopMode ? 34 : 0) + page.bottomInset

        background: Rectangle {
            color: page.bg
        }

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: contentColumn

            width: Math.min(scrollView.availableWidth, page.desktopMode ? page.desktopContentMaxWidth : scrollView.availableWidth)
            x: Math.max(0, Math.round((scrollView.availableWidth - width) / 2))
            spacing: page.desktopMode ? 18 : 16

            HeaderCard {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            MessageCard {
                visible: page.loading && page.visibleAppointmentsCount() === 0
                iconName: "clock"
                text: "Загружаю записи с сервера..."
                iconColor: page.accent
                bgColor: page.accentSoft

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            ErrorBox {
                visible: page.loadError.length > 0
                text: page.loadError

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            EmptyState {
                visible: !page.loading
                         && page.loadError.length === 0
                         && page.visibleAppointmentsCount() === 0

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            ExpandableSection {
                title: "Запланированные"
                count: page.sectionCount("upcoming")
                dotColor: page.success
                defaultExpanded: true
                visible: !page.loading && page.loadError.length === 0 && count > 0

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                Repeater {
                    model: page.tasksModel

                    AppointmentCardWrapper {
                        matched: page.belongsToSection(
                            model.isCanceled,
                            model.consultationPassed,
                            "upcoming"
                        )

                        rowIndex: index
                        viewerRole: page.viewerRole
                        busy: page.loading || page.actionBusy

                        titleText: model.title || ""
                        descriptionText: model.description || ""
                        dateText: model.date || ""
                        timeText: model.time || ""
                        cabinetText: model.cabinet || ""
                        durationMinutes: model.durationMinutes || 30
                        isCanceled: model.isCanceled === true
                        consultationPassed: model.consultationPassed === true
                        ratingValue: model.rating || 0
                        teacherName: model.teacherName || ""
                        studentName: model.studentName || ""
                        modelStatusText: String(model.status || "")
                        cancelledByRole: model.cancelledByRole || 0
                        cancelledByText: model.cancelledByText || ""

                        onCancelClicked: function(row) {
                            page.cancelAppointment(row)
                        }

                        onRateClicked: function(row, value) {
                            page.rateAppointment(row, value)
                        }
                    }
                }
            }

            ExpandableSection {
                title: "Прошедшие"
                count: page.sectionCount("past")
                dotColor: page.textMuted
                defaultExpanded: false
                visible: !page.loading && page.loadError.length === 0 && count > 0

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                Repeater {
                    model: page.tasksModel

                    AppointmentCardWrapper {
                        matched: page.belongsToSection(
                            model.isCanceled,
                            model.consultationPassed,
                            "past"
                        )

                        rowIndex: index
                        viewerRole: page.viewerRole
                        busy: page.loading || page.actionBusy

                        titleText: model.title || ""
                        descriptionText: model.description || ""
                        dateText: model.date || ""
                        timeText: model.time || ""
                        cabinetText: model.cabinet || ""
                        durationMinutes: model.durationMinutes || 30
                        isCanceled: model.isCanceled === true
                        consultationPassed: model.consultationPassed === true
                        ratingValue: model.rating || 0
                        teacherName: model.teacherName || ""
                        studentName: model.studentName || ""
                        modelStatusText: String(model.status || "")
                        cancelledByRole: model.cancelledByRole || 0
                        cancelledByText: model.cancelledByText || ""

                        onCancelClicked: function(row) {
                            page.cancelAppointment(row)
                        }

                        onRateClicked: function(row, value) {
                            page.rateAppointment(row, value)
                        }
                    }
                }
            }

            ExpandableSection {
                title: "Отменённые"
                count: page.sectionCount("cancelled")
                dotColor: page.danger
                defaultExpanded: false
                visible: !page.loading && page.loadError.length === 0 && count > 0

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                Repeater {
                    model: page.tasksModel

                    AppointmentCardWrapper {
                        matched: page.belongsToSection(
                            model.isCanceled,
                            model.consultationPassed,
                            "cancelled"
                        )

                        rowIndex: index
                        viewerRole: page.viewerRole
                        busy: page.loading || page.actionBusy

                        titleText: model.title || ""
                        descriptionText: model.description || ""
                        dateText: model.date || ""
                        timeText: model.time || ""
                        cabinetText: model.cabinet || ""
                        durationMinutes: model.durationMinutes || 30
                        isCanceled: model.isCanceled === true
                        consultationPassed: model.consultationPassed === true
                        ratingValue: model.rating || 0
                        teacherName: model.teacherName || ""
                        studentName: model.studentName || ""
                        modelStatusText: String(model.status || "")
                        cancelledByRole: model.cancelledByRole || 0
                        cancelledByText: model.cancelledByText || ""

                        onCancelClicked: function(row) {
                            page.cancelAppointment(row)
                        }

                        onRateClicked: function(row, value) {
                            page.rateAppointment(row, value)
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 84 + page.bottomInset
            }
        }
    }

    AppFabButton {
        id: fab

        visible: page.canAddTask()
        enabled: visible && !page.loading && !page.actionBusy
        z: 100

        width: page.desktopMode ? 68 : 64
        height: page.desktopMode ? 68 : 64

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: page.desktopMode
                             ? Math.max(28, Math.round((page.width - Math.min(page.width, page.desktopContentMaxWidth)) / 2) + 30)
                             : 20
        anchors.bottomMargin: (page.desktopMode ? 28 : 18) + page.bottomInset

        Accessible.name: "Добавить запись"

        onClicked: {
            if (!page.canAddTask())
                return

            if (page.loading || page.actionBusy)
                return

            page.addTaskRequested()
        }
    }

    Dialog {
        id: cancelConfirmDialog

        modal: true
        dim: true
        title: ""

        width: Math.min(page.width - 44, page.desktopMode ? 460 : 380)
        anchors.centerIn: parent

        background: Rectangle {
            color: page.surface
            radius: 26
            border.width: 1
            border.color: page.border
        }

        contentItem: ColumnLayout {
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                radius: 18
                color: page.dangerSoft
                border.width: 1
                border.color: "#5A2D31"

                DrawIcon {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    name: "warning"
                    iconColor: page.danger
                }
            }

            Text {
                text: "Отмена записи"
                color: page.textMain
                font.pixelSize: 22
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: "Вы уверены, что хотите отменить эту запись?"
                color: page.textMuted
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                lineHeight: 1.15
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                AppButton {
                    id: backButton

                    text: "Назад"
                    variant: "secondary"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    onClicked: cancelConfirmDialog.close()
                }

                AppButton {
                    id: confirmCancelButton

                    text: "Отменить"
                    variant: "danger"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    onClicked: {
                        cancelConfirmDialog.close()
                        page.executeCancelAppointment()
                    }
                }
            }
        }
    }

    component AppButton: Item {
        id: control

        signal clicked()

        property string text: ""
        property string variant: "primary"
        property bool hovered: mouseArea.containsMouse
        property bool pressed: mouseArea.pressed

        implicitHeight: 48
        opacity: enabled ? 1.0 : 0.55
        scale: pressed ? 0.975 : hovered ? 1.012 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height >= 48 ? 17 : 15
            color: control.backgroundColor()
            border.width: control.variant === "primary" || control.variant === "danger" ? 0 : 1
            border.color: control.borderColor()

            Behavior on color {
                ColorAnimation { duration: 130 }
            }

            Behavior on border.color {
                ColorAnimation { duration: 130 }
            }
        }

        Text {
            anchors.fill: parent
            text: control.text
            color: control.textColor()
            font.pixelSize: control.height <= 42 ? 12 : 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: control.enabled
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                control.clicked()
            }
        }

        function backgroundColor() {
            if (!control.enabled)
                return page.surface3

            if (control.variant === "danger")
                return control.pressed ? "#D95858" : control.hovered ? "#F26666" : page.danger

            if (control.variant === "dangerSoft")
                return control.pressed ? "#44272A" : control.hovered ? "#4A2529" : page.dangerSoft

            if (control.variant === "secondary")
                return control.pressed ? page.surface3 : control.hovered ? "#252A34" : page.surface2

            return control.pressed ? "#255FA9" : control.hovered ? "#2B6CBE" : page.accent
        }

        function borderColor() {
            if (!control.enabled)
                return page.border

            if (control.variant === "dangerSoft")
                return control.hovered ? page.danger : "#5A2D31"

            if (control.variant === "secondary")
                return control.hovered ? "#3B4658" : page.border

            return page.border
        }

        function textColor() {
            if (!control.enabled)
                return page.textMuted

            if (control.variant === "danger" || control.variant === "primary")
                return "#FFFFFF"

            if (control.variant === "dangerSoft")
                return page.danger

            return page.textMain
        }
    }

    component AppFabButton: Item {
        id: fabButton

        signal clicked()

        property bool hovered: mouseArea.containsMouse
        property bool pressed: mouseArea.pressed

        opacity: enabled ? 1.0 : 0.55
        scale: pressed ? 0.94 : hovered ? 1.06 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: !fabButton.enabled ? page.surface3
                  : fabButton.pressed ? page.accentSoft
                  : fabButton.hovered ? "#1D2634"
                  : page.surface
            border.width: 1
            border.color: !fabButton.enabled ? page.border : fabButton.hovered ? "#8BBCFF" : page.accent

            Behavior on color {
                ColorAnimation { duration: 140 }
            }

            Behavior on border.color {
                ColorAnimation { duration: 140 }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: fabButton.hovered ? 5 : 6
                radius: 19
                color: !fabButton.enabled ? "transparent" : fabButton.pressed ? "#255FA9" : page.accent
                opacity: fabButton.pressed ? 0.78 : 1.0

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }
            }
        }

        DrawIcon {
            anchors.centerIn: parent
            width: 28
            height: 28
            name: "plus"
            iconColor: "#FFFFFF"
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: fabButton.enabled
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                fabButton.clicked()
            }
        }
    }

    component HeaderCard: Rectangle {
        id: headerCard

        property bool hovered: headerHoverArea.containsMouse

        color: headerCard.hovered ? "#1B2029" : page.surface
        radius: page.desktopCardRadius
        border.width: 1
        border.color: headerCard.hovered ? "#284568" : page.border
        scale: headerCard.hovered ? 1.004 : 1.0

        Layout.preferredHeight: headerColumn.implicitHeight + (page.desktopMode ? 38 : 34)

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

        MouseArea {
            id: headerHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            id: headerColumn

            anchors.fill: parent
            anchors.margins: 17
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 58
                    radius: 20
                    color: page.accentSoft
                    border.width: 1
                    border.color: "#284568"

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        name: "tasks"
                        iconColor: page.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Записи"
                        color: page.textMain
                        font.pixelSize: 30
                        font.bold: true
                        maximumLineCount: 1
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }

                    Text {
                        text: page.visibleAppointmentsCount() === 0
                              ? "Консультации и история записей"
                              : "Всего записей: " + page.visibleAppointmentsCount()
                        color: page.textMuted
                        font.pixelSize: 14
                        maximumLineCount: 1
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }
                }

                BusyIndicator {
                    running: page.loading || page.actionBusy

                    visible: true
                    opacity: running ? 1.0 : 0.0

                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                CountBadge {
                    text: "Активные"
                    count: page.sectionCount("upcoming")
                    colorBg: page.successSoft
                    colorText: page.success
                }

                CountBadge {
                    text: "Прошедшие"
                    count: page.sectionCount("past")
                    colorBg: page.surface2
                    colorText: page.textSub
                }

                CountBadge {
                    text: "Отменённые"
                    count: page.sectionCount("cancelled")
                    colorBg: page.dangerSoft
                    colorText: page.danger
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }

    component CountBadge: Rectangle {
        id: badge

        property string text: ""
        property int count: 0
        property color colorBg: page.surface2
        property color colorText: page.textSub
        property bool hovered: badgeHoverArea.containsMouse

        radius: 999
        color: badge.hovered ? page.surface3 : badge.colorBg
        border.width: badge.hovered ? 1 : 0
        border.color: Qt.rgba(badge.colorText.r, badge.colorText.g, badge.colorText.b, 0.38)
        scale: badge.hovered ? 1.035 : 1.0

        Layout.preferredHeight: 30
        Layout.preferredWidth: badgeLabel.implicitWidth + 24

        Behavior on color { ColorAnimation { duration: 130 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

        MouseArea {
            id: badgeHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Text {
            id: badgeLabel

            anchors.centerIn: parent
            text: badge.text + " " + badge.count
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
        property color bgColor: page.surface2
        property bool hovered: cardHoverArea.containsMouse

        radius: 22
        color: card.bgColor
        border.width: 1
        border.color: card.hovered ? Qt.rgba(card.iconColor.r, card.iconColor.g, card.iconColor.b, 0.55) : page.border
        scale: card.hovered ? 1.003 : 1.0

        Layout.preferredHeight: msgRow.implicitHeight + 24

        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        MouseArea {
            id: cardHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            id: msgRow

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 14
                color: Qt.rgba(card.iconColor.r, card.iconColor.g, card.iconColor.b, 0.14)

                DrawIcon {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
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
        property bool hovered: errorHoverArea.containsMouse

        color: box.hovered ? "#44272A" : page.dangerSoft
        radius: 22
        border.width: 1
        border.color: box.hovered ? page.danger : "#5A2D31"
        scale: box.hovered ? 1.003 : 1.0

        Layout.preferredHeight: errRow.implicitHeight + 24

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        MouseArea {
            id: errorHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            id: errRow

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

    component EmptyState: Rectangle {
        id: emptyState

        property bool hovered: emptyHoverArea.containsMouse

        Layout.preferredHeight: page.desktopMode ? 196 : 178
        color: emptyState.hovered ? "#1B2029" : page.surface
        radius: page.desktopCardRadius
        border.width: 1
        border.color: emptyState.hovered ? "#284568" : page.border
        scale: emptyState.hovered ? 1.004 : 1.0

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        MouseArea {
            id: emptyHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 40
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                Layout.alignment: Qt.AlignHCenter
                radius: 19
                color: page.surface2

                DrawIcon {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    name: "empty"
                    iconColor: page.textMuted
                }
            }

            Text {
                text: "У вас пока нет записей"
                color: page.textMain
                font.pixelSize: 20
                font.bold: true
                horizontalAlignment: Text.AlignHCenter

                Layout.fillWidth: true
            }

            Text {
                text: page.canAddTask()
                      ? "Нажмите +, чтобы записаться на консультацию"
                      : "Записей пока нет"
                color: page.textMuted
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter

                Layout.fillWidth: true
            }
        }
    }

    component ExpandableSection: ColumnLayout {
        id: section

        default property alias content: body.data

        property string title: ""
        property int count: 0
        property color dotColor: page.accent
        property bool defaultExpanded: true
        property bool expanded: defaultExpanded
        property bool hovered: sectionHeaderMouseArea.containsMouse

        spacing: section.expanded ? 10 : 0

        Rectangle {
            id: sectionHeader

            Layout.fillWidth: true
            Layout.preferredHeight: 50

            radius: 20
            color: section.hovered ? "#1B2029" : page.surface
            border.width: 1
            border.color: section.hovered ? Qt.rgba(section.dotColor.r, section.dotColor.g, section.dotColor.b, 0.55) : page.border
            scale: sectionHeaderMouseArea.pressed ? 0.992 : section.hovered ? 1.004 : 1.0

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    radius: 5
                    color: section.dotColor
                }

                Text {
                    text: section.title
                    color: page.textMain
                    font.pixelSize: 17
                    font.bold: true
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: countText.implicitWidth + 18
                    Layout.preferredHeight: 28
                    radius: 14
                    color: page.surface2
                    border.width: 1
                    border.color: page.border

                    Text {
                        id: countText

                        anchors.centerIn: parent
                        text: section.count
                        color: page.textSub
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 13
                    color: section.expanded ? page.accentSoft : section.hovered ? page.surface3 : page.surface2
                    border.width: 1
                    border.color: section.expanded ? "#284568" : section.hovered ? "#3B4658" : page.border

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        name: section.expanded ? "chevronUp" : "chevronDown"
                        iconColor: section.expanded || section.hovered ? page.accent : page.textMuted
                    }
                }
            }

            MouseArea {
                id: sectionHeaderMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    section.expanded = !section.expanded
                }
            }
        }

        ColumnLayout {
            id: body

            visible: section.expanded
            spacing: 10
            clip: true

            Layout.fillWidth: true
        }
    }

    component AppointmentCardWrapper: Item {
        id: wrapper

        signal cancelClicked(int row)
        signal rateClicked(int row, int value)

        property bool matched: false
        property bool busy: false

        property int rowIndex: -1
        property int viewerRole: 1

        property string titleText: ""
        property string descriptionText: ""
        property string dateText: ""
        property string timeText: ""
        property string cabinetText: ""
        property int durationMinutes: 30
        property bool isCanceled: false
        property bool consultationPassed: false
        property int ratingValue: 0
        property string teacherName: ""
        property string studentName: ""
        property string modelStatusText: ""
        property int cancelledByRole: 0
        property string cancelledByText: ""

        visible: matched
        clip: true

        Layout.fillWidth: true
        Layout.preferredHeight: matched ? bookingCard.implicitHeight : 0

        BookingCard {
            id: bookingCard

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            rowIndex: wrapper.rowIndex
            viewerRole: wrapper.viewerRole
            busy: wrapper.busy

            titleText: wrapper.titleText
            descriptionText: wrapper.descriptionText
            dateText: wrapper.dateText
            timeText: wrapper.timeText
            cabinetText: wrapper.cabinetText
            durationMinutes: wrapper.durationMinutes
            isCanceled: wrapper.isCanceled
            consultationPassed: wrapper.consultationPassed
            ratingValue: wrapper.ratingValue
            teacherName: wrapper.teacherName
            studentName: wrapper.studentName
            modelStatusText: wrapper.modelStatusText
            cancelledByRole: wrapper.cancelledByRole
            cancelledByText: wrapper.cancelledByText

            onCancelClicked: function(row) {
                wrapper.cancelClicked(row)
            }

            onRateClicked: function(row, value) {
                wrapper.rateClicked(row, value)
            }
        }
    }

    component BookingCard: Rectangle {
        id: card

        signal cancelClicked(int row)
        signal rateClicked(int row, int value)

        property int rowIndex: -1
        property int viewerRole: 1
        property bool busy: false

        property string titleText: ""
        property string descriptionText: ""
        property string dateText: ""
        property string timeText: ""
        property string cabinetText: ""
        property int durationMinutes: 30
        property bool isCanceled: false
        property bool consultationPassed: false
        property int ratingValue: 0
        property string teacherName: ""
        property string studentName: ""
        property string modelStatusText: ""
        property int cancelledByRole: 0
        property string cancelledByText: ""

        property bool hovered: bookingHoverArea.containsMouse

        implicitHeight: contentColumn.implicitHeight + (page.desktopMode ? 36 : 32)
        height: implicitHeight

        radius: page.desktopMode ? 26 : 24
        color: card.hovered ? "#1B2029" : page.surface
        border.width: 1
        border.color: card.isCanceled ? (card.hovered ? page.danger : "#5A2D31")
                     : card.hovered ? "#284568"
                     : page.border
        scale: bookingHoverArea.pressed ? 0.996 : card.hovered ? 1.004 : 1.0
        clip: true

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

        MouseArea {
            id: bookingHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        ColumnLayout {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16

            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 17
                    color: card.iconBackgroundColor()
                    border.width: 1
                    border.color: card.iconBorderColor()

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        name: card.iconName()
                        iconColor: card.statusColor()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        Rectangle {
                            Layout.preferredWidth: roleBadgeText.implicitWidth + 20
                            Layout.preferredHeight: 26
                            radius: 13
                            color: card.badgeBackgroundColor()
                            border.width: 1
                            border.color: card.badgeBorderColor()

                            Text {
                                id: roleBadgeText

                                anchors.centerIn: parent
                                text: card.badgeText()
                                color: card.badgeTextColor()
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        Text {
                            text: card.statusText()
                            color: card.statusColor()
                            font.pixelSize: 12
                            font.bold: true
                            verticalAlignment: Text.AlignVCenter

                            Layout.fillWidth: true
                        }
                    }

                    Text {
                        text: card.displayPersonName()
                        color: page.textMain
                        font.pixelSize: 18
                        font.bold: true
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap

                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 84
                    Layout.minimumWidth: 84
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    spacing: 2

                    Text {
                        text: card.timeText.length > 0 ? card.timeText : "--:--"
                        color: card.statusColor()
                        font.pixelSize: 20
                        font.bold: true
                        horizontalAlignment: Text.AlignRight

                        Layout.fillWidth: true
                    }

                    Text {
                        text: card.dateText
                        color: page.textMuted
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }

                    Text {
                        text: card.durationMinutes + " мин"
                        color: page.textMuted
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignRight

                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                visible: card.cabinetText.length > 0 || card.titleText.length > 0
                Layout.fillWidth: true
                spacing: 8

                InfoPill {
                    visible: card.cabinetText.length > 0
                    iconName: "room"
                    text: "каб. " + card.cabinetText
                }

                InfoPill {
                    visible: card.titleText.length > 0
                    iconName: "topic"
                    text: card.titleText
                    Layout.fillWidth: true
                }
            }

            Text {
                visible: card.isCanceled
                text: "Отменил: " + card.cancelledByLabel()
                color: page.danger
                font.pixelSize: 12
                font.bold: true
                maximumLineCount: 1
                elide: Text.ElideRight

                Layout.fillWidth: true
            }

            Text {
                visible: card.descriptionText.length > 0
                text: card.descriptionText
                color: page.textMuted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                clip: true
                lineHeight: 1.18

                Layout.fillWidth: true
            }

            RatingBlock {
                visible: Number(card.viewerRole) === 1
                         && card.consultationPassed
                         && !card.isCanceled
                enabled: !card.busy
                ratingValue: card.ratingValue

                Layout.fillWidth: true

                onRateSelected: function(value) {
                    card.rateClicked(card.rowIndex, value)
                }
            }

            RowLayout {
                visible: !card.consultationPassed && !card.isCanceled

                Layout.fillWidth: true
                spacing: 8

                Item {
                    Layout.fillWidth: true
                }

                AppButton {
                    id: cancelButton

                    enabled: !card.busy
                    text: "Отменить"
                    variant: "dangerSoft"
                    Accessible.name: "Отменить запись"

                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 40

                    onClicked: card.cancelClicked(card.rowIndex)
                }
            }
        }

        function iconName() {
            if (card.isCanceled)
                return "cancel"

            if (card.consultationPassed)
                return "check"

            return "calendar"
        }

        function iconBackgroundColor() {
            if (card.isCanceled)
                return page.dangerSoft

            if (card.consultationPassed)
                return page.surface2

            return page.successSoft
        }

        function iconBorderColor() {
            if (card.isCanceled)
                return "#5A2D31"

            if (card.consultationPassed)
                return page.border

            return "#24513C"
        }

        function badgeText() {
            var role = Number(card.viewerRole)

            if (role === 1)
                return "ПРЕПОДАВАТЕЛЬ"

            if (role === 2)
                return "СТУДЕНТ"

            return "ЗАПИСЬ"
        }

        function badgeBackgroundColor() {
            var role = Number(card.viewerRole)

            if (role === 1)
                return page.accentSoft

            if (role === 2)
                return page.successSoft

            return page.surface2
        }

        function badgeBorderColor() {
            var role = Number(card.viewerRole)

            if (role === 1)
                return "#284568"

            if (role === 2)
                return "#24513C"

            return page.border
        }

        function badgeTextColor() {
            var role = Number(card.viewerRole)

            if (role === 1)
                return page.accent

            if (role === 2)
                return page.success

            return page.textSub
        }

        function displayPersonName() {
            var role = Number(card.viewerRole)

            if (role === 1)
                return card.teacherName.length > 0 ? card.teacherName : "Преподаватель"

            if (role === 2)
                return card.studentName.length > 0 ? card.studentName : "Студент"

            if (card.teacherName.length > 0 && card.studentName.length > 0)
                return card.studentName + " / " + card.teacherName

            if (card.studentName.length > 0)
                return card.studentName

            if (card.teacherName.length > 0)
                return card.teacherName

            return "Запись"
        }

        function statusText() {
            if (card.isCanceled)
                return "Отменена"

            if (card.consultationPassed)
                return "Прошла"

            return "Активна"
        }

        function statusColor() {
            if (card.isCanceled)
                return page.danger

            if (card.consultationPassed)
                return page.textMuted

            return page.success
        }

        function cancelledByLabel() {
            var text = String(card.cancelledByText).toLowerCase()

            if (text.indexOf("студ") >= 0)
                return "студент"

            if (text.indexOf("преп") >= 0)
                return "преподаватель"

            if (text.indexOf("админ") >= 0)
                return "админ"

            if (card.cancelledByRole === 1)
                return "студент"

            if (card.cancelledByRole === 2)
                return "преподаватель"

            if (card.cancelledByRole === 3)
                return "админ"

            var status = String(card.modelStatusText).toLowerCase()

            if (status.indexOf("студ") >= 0)
                return "студент"

            if (status.indexOf("преп") >= 0)
                return "преподаватель"

            if (status.indexOf("админ") >= 0)
                return "админ"

            return "не указано"
        }
    }

    component InfoPill: Rectangle {
        id: pill

        property string text: ""
        property string iconName: ""
        property bool hovered: pillHoverArea.containsMouse

        Layout.preferredWidth: Math.min(label.implicitWidth + 42, page.desktopMode ? 240 : 180)
        Layout.preferredHeight: 32

        radius: 16
        color: pill.hovered ? page.surface3 : page.surface2
        border.width: 1
        border.color: pill.hovered ? "#3B4658" : page.border
        scale: pill.hovered ? 1.012 : 1.0

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        MouseArea {
            id: pillHoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            spacing: 5

            DrawIcon {
                Layout.preferredWidth: 15
                Layout.preferredHeight: 15
                name: pill.iconName
                iconColor: page.textMuted
            }

            Text {
                id: label

                text: pill.text
                color: page.textMuted
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }
    }

    component RatingBlock: ColumnLayout {
        id: block

        signal rateSelected(int value)

        property int ratingValue: 0

        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: page.border
        }

        Text {
            text: block.ratingValue > 0
                  ? "Ваша оценка: " + block.ratingValue + "/5"
                  : "Оцените консультацию"
            color: page.textMuted
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter

            Layout.fillWidth: true
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            Repeater {
                model: 5

                StarButton {
                    filled: index < block.ratingValue
                    enabled: block.enabled

                    onClicked: {
                        block.rateSelected(index + 1)
                    }
                }
            }
        }
    }

    component StarButton: Item {
        id: star

        signal clicked()
        property bool filled: false
        property bool enabled: true

        property bool hovered: mouseArea.containsMouse
        property bool pressed: mouseArea.pressed

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        opacity: enabled ? 1.0 : 0.45
        scale: pressed ? 0.90 : hovered ? 1.16 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }

        Canvas {
            id: starCanvas  // ✅ Добавили id
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var cx = width / 2
                var cy = height / 2
                var outer = Math.min(width, height) * 0.38
                var inner = outer * 0.48

                ctx.beginPath()

                for (var i = 0; i < 10; i++) {
                    var angle = -Math.PI / 2 + i * Math.PI / 5
                    var r = i % 2 === 0 ? outer : inner
                    var x = cx + Math.cos(angle) * r
                    var y = cy + Math.sin(angle) * r

                    if (i === 0)
                        ctx.moveTo(x, y)
                    else
                        ctx.lineTo(x, y)
                }

                ctx.closePath()

                ctx.lineWidth = 2
                ctx.strokeStyle = star.filled || star.hovered ? page.warning : page.textMuted
                ctx.fillStyle = star.filled ? page.warning : "transparent"

                if (star.filled)
                    ctx.fill()

                ctx.stroke()
            }

            Connections {
                target: star
                function onFilledChanged() {
                    starCanvas.requestPaint()  // ✅ Обращаемся к Canvas по id
                }

                function onEnabledChanged() {
                    starCanvas.requestPaint()  // ✅
                }

                function onHoveredChanged() {
                    starCanvas.requestPaint()
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: star.enabled
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                star.clicked()
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

            if (icon.name === "tasks") {
                roundedRectPath(px(0.2), py(0.14), s * 0.6, s * 0.72, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.34))
                ctx.lineTo(px(0.7), py(0.34))
                ctx.moveTo(px(0.34), py(0.5))
                ctx.lineTo(px(0.7), py(0.5))
                ctx.moveTo(px(0.34), py(0.66))
                ctx.lineTo(px(0.58), py(0.66))
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.27), py(0.34), s * 0.015, 0, Math.PI * 2)
                ctx.arc(px(0.27), py(0.5), s * 0.015, 0, Math.PI * 2)
                ctx.arc(px(0.27), py(0.66), s * 0.015, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.name === "clock") {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.34, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.3))
                ctx.lineTo(px(0.5), py(0.52))
                ctx.lineTo(px(0.66), py(0.62))
                ctx.stroke()
            } else if (icon.name === "calendar") {
                roundedRectPath(px(0.14), py(0.22), s * 0.72, s * 0.62, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.14), py(0.4))
                ctx.lineTo(px(0.86), py(0.4))
                ctx.moveTo(px(0.32), py(0.14))
                ctx.lineTo(px(0.32), py(0.28))
                ctx.moveTo(px(0.68), py(0.14))
                ctx.lineTo(px(0.68), py(0.28))
                ctx.stroke()
            } else if (icon.name === "room") {
                roundedRectPath(px(0.2), py(0.16), s * 0.6, s * 0.7, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.16))
                ctx.lineTo(px(0.5), py(0.86))
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.42), py(0.52), s * 0.025, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.name === "topic") {
                roundedRectPath(px(0.18), py(0.22), s * 0.64, s * 0.56, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.32), py(0.4))
                ctx.lineTo(px(0.68), py(0.4))
                ctx.moveTo(px(0.32), py(0.56))
                ctx.lineTo(px(0.58), py(0.56))
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
            } else if (icon.name === "cancel") {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.34, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.38), py(0.38))
                ctx.lineTo(px(0.62), py(0.62))
                ctx.moveTo(px(0.62), py(0.38))
                ctx.lineTo(px(0.38), py(0.62))
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
            } else if (icon.name === "plus") {
                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.24))
                ctx.lineTo(px(0.5), py(0.76))
                ctx.moveTo(px(0.24), py(0.5))
                ctx.lineTo(px(0.76), py(0.5))
                ctx.stroke()
            } else if (icon.name === "chevronDown") {
                ctx.beginPath()
                ctx.moveTo(px(0.28), py(0.38))
                ctx.lineTo(px(0.5), py(0.62))
                ctx.lineTo(px(0.72), py(0.38))
                ctx.stroke()
            } else if (icon.name === "chevronUp") {
                ctx.beginPath()
                ctx.moveTo(px(0.28), py(0.62))
                ctx.lineTo(px(0.5), py(0.38))
                ctx.lineTo(px(0.72), py(0.62))
                ctx.stroke()
            } else {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.08, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }
}