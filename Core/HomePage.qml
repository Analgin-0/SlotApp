import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Item {
    id: page

    signal logoutRequested()
    signal appointmentsRequested()
    signal scheduleRequested()
    signal profileRequested()
    signal addUserRequested()

    property int viewerRole: 0
    property int contentTopInset: 0
    property int contentBottomInset: 0

    property bool firstShow: true
    property bool profileLoading: false
    property bool appointmentsLoading: false
    property bool scheduleLoading: false

    property string errorText: ""

    property string fullName: "Пользователь"
    property string firstName: "Пользователь"
    property string roleText: "Пользователь"

    property string studentGroup: ""
    property int studentCourse: 0
    property string studentFaculty: ""

    property int teacherId: 0
    property int teacherUserId: 0

    property bool hasNearestAppointment: false
    property string nearestTitle: ""
    property string nearestPerson: ""
    property string nearestDate: ""
    property string nearestTime: ""
    property string nearestCabinet: ""
    property string nearestDescription: ""


    readonly property color bg: "#000000"
    readonly property color surface: "#111111"
    readonly property color surface2: "#222222"
    readonly property color surface3: "#333333"
    readonly property color border: "#555555"
    readonly property color textMain: "#FFFFFF"
    readonly property color textSub: "#DDDDDD"
    readonly property color textMuted: "#AAAAAA"
    readonly property color accent: "#FFFFFF"
    readonly property color accentSoft: "#333333"
    readonly property color danger: "#FFFFFF"
    readonly property color dangerSoft: "#222222"
    readonly property color success: "#FFFFFF"
    readonly property color successSoft: "#222222"

    readonly property int desktopBreakpoint: 900
    readonly property bool desktopMode: page.width >= page.desktopBreakpoint
    readonly property bool pointerMode: Qt.platform.os !== "android" && Qt.platform.os !== "ios"
    readonly property bool touchMode: !page.pointerMode
    readonly property int contentMaxWidth: page.desktopMode ? 1180 : 640
    readonly property int contentSideMargin: page.desktopMode ? 28 : 20
    readonly property int contentTopPadding: page.desktopMode ? 28 : 20
    readonly property int contentBottomPadding: page.desktopMode ? 34 : 24
    readonly property int sectionSpacing: page.desktopMode ? 20 : 16

    ListModel {
        id: scheduleModel
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

    function valueOrDash(v) {
        if (v === undefined || v === null)
            return "—"

        var s = String(v).trim()

        if (s.length === 0)
            return "—"

        if (s.toLowerCase() === "null")
            return "—"

        if (s.toLowerCase() === "undefined")
            return "—"

        return s
    }

    function safeString(v) {
        if (v === undefined || v === null)
            return ""

        var s = String(v).trim()

        if (s.length === 0)
            return ""

        if (s.toLowerCase() === "null")
            return ""

        if (s.toLowerCase() === "undefined")
            return ""

        return s
    }

    function safeBool(v) {
        if (v === true)
            return true

        if (v === false)
            return false

        if (v === 1 || v === "1")
            return true

        if (v === 0 || v === "0")
            return false

        var t = String(v).trim().toLowerCase()

        return t === "true" ||
               t === "yes" ||
               t === "да" ||
               t === "canceled" ||
               t === "cancelled" ||
               t.indexOf("отмен") >= 0
    }

    function safeNumber(v, fallback) {
        if (v === undefined || v === null)
            return fallback

        var s = String(v).trim()

        if (s.length === 0)
            return fallback

        if (s.toLowerCase() === "null")
            return fallback

        if (s.toLowerCase() === "undefined")
            return fallback

        var n = Number(s)

        if (isNaN(n))
            return fallback

        return n
    }

    function roleToString(r) {
        r = Number(r)

        if (r === 1)
            return "Студент"

        if (r === 2)
            return "Преподаватель"

        if (r === 3)
            return "Администратор"

        return "Пользователь"
    }

    function joinFullName(user) {
        if (!user)
            return "Пользователь"

        var parts = []

        var ln = valueOrDash(user.last_name || user.LastName)
        if (ln !== "—")
            parts.push(ln)

        var n = valueOrDash(user.name || user.Name)
        if (n !== "—")
            parts.push(n)

        var mn = valueOrDash(user.middle_name || user.MiddleName)
        if (mn !== "—")
            parts.push(mn)

        return parts.length > 0 ? parts.join(" ") : "Пользователь"
    }

    function extractFirstName(user) {
        if (!user)
            return "Пользователь"

        var n = valueOrDash(user.name || user.Name)

        if (n !== "—")
            return n

        var full = joinFullName(user)
        var p = full.split(" ")

        return p.length >= 2 ? p[1] : full
    }

    function greetingPrefix() {
        var h = new Date().getHours()

        if (h >= 5 && h < 12)
            return "Доброе утро"

        if (h >= 12 && h < 18)
            return "Добрый день"

        if (h >= 18 && h < 23)
            return "Добрый вечер"

        return "Здравствуйте"
    }

    function greetingText() {
        return greetingPrefix() + ", " + page.firstName
    }

    function todayDateText() {
        var d = new Date()

        var m = [
            "января",
            "февраля",
            "марта",
            "апреля",
            "мая",
            "июня",
            "июля",
            "августа",
            "сентября",
            "октября",
            "ноября",
            "декабря"
        ]

        return d.getDate() + " " + m[d.getMonth()] + " " + d.getFullYear()
    }

    function dayNameText() {
        var d = new Date()

        var days = [
            "Воскресенье",
            "Понедельник",
            "Вторник",
            "Среда",
            "Четверг",
            "Пятница",
            "Суббота"
        ]

        return days[d.getDay()]
    }

    function firstValue(obj, names, fallback) {
        if (!obj)
            return fallback

        for (var i = 0; i < names.length; i++) {
            if (obj[names[i]] !== undefined && obj[names[i]] !== null)
                return obj[names[i]]
        }

        return fallback
    }

    function isArrayLike(v) {
        return v !== undefined &&
               v !== null &&
               typeof v !== "string" &&
               v.length !== undefined
    }

    function extractArray(obj) {
        if (!obj)
            return []

        if (isArrayLike(obj.MyTable))
            return obj.MyTable

        if (isArrayLike(obj.appointments))
            return obj.appointments

        if (isArrayLike(obj.schedule))
            return obj.schedule

        if (isArrayLike(obj.Schedule))
            return obj.Schedule

        if (isArrayLike(obj.items))
            return obj.items

        if (isArrayLike(obj.table))
            return obj.table

        if (isArrayLike(obj.result))
            return obj.result

        if (isArrayLike(obj.data))
            return obj.data

        return []
    }

    function formatDateValue(v) {
        if (v === undefined || v === null)
            return ""

        var t = String(v).trim()

        if (t.length === 0)
            return ""

        var ti = t.indexOf("T")
        if (ti > 0)
            return t.substring(0, ti)

        var si = t.indexOf(" ")
        if (si > 0)
            return t.substring(0, si)

        return t
    }

    function formatDateForUi(v) {
        var s = formatDateValue(v)

        if (s.length === 0)
            return ""

        var p = s.split("-")

        return p.length === 3 ? p[2] + "." + p[1] + "." + p[0] : s
    }

    function formatTimeValue(v) {
        if (v === undefined || v === null)
            return ""

        var t = String(v).trim()

        if (t.length === 0)
            return ""

        var si = t.indexOf(" ")
        if (si >= 0 && t.length >= si + 6)
            return t.substring(si + 1, si + 6)

        var ti = t.indexOf("T")
        if (ti >= 0 && t.length >= ti + 6)
            return t.substring(ti + 1, ti + 6)

        if (t.length >= 5 && t.charAt(2) === ":")
            return t.substring(0, 5)

        return t
    }

    function parseDateTime(dateText, timeText) {
        var d = formatDateValue(dateText)
        var t = formatTimeValue(timeText)

        if (d.length === 0)
            return null

        var p = d.split("-")

        if (p.length !== 3)
            return null

        var y = Number(p[0])
        var m = Number(p[1])
        var day = Number(p[2])

        if (isNaN(y) || isNaN(m) || isNaN(day))
            return null

        var h = 0
        var mi = 0

        if (t.length >= 5 && t.charAt(2) === ":") {
            h = Number(t.substring(0, 2))
            mi = Number(t.substring(3, 5))

            if (isNaN(h) || isNaN(mi)) {
                h = 0
                mi = 0
            }
        }

        return new Date(y, m - 1, day, h, mi, 0, 0)
    }

    function normalizeAppointment(src) {
        var statusText = safeString(firstValue(src, ["status", "Status"], ""))
        var statusLower = statusText.toLowerCase()

        var rawDate = firstValue(src, ["appointment_date", "date", "Date"], "")
        var rawTime = firstValue(src, ["appointment_time", "time", "Time"], "")

        if (!rawTime || String(rawTime).trim().length === 0)
            rawTime = rawDate

        var isCanceledRaw = firstValue(src, [
            "isCanceled",
            "is_canceled",
            "canceled",
            "cancelled"
        ], false)

        var isCanceled = safeBool(isCanceledRaw) ||
                         statusLower.indexOf("отмен") >= 0 ||
                         statusLower.indexOf("cancel") >= 0 ||
                         Number(src.status) === 3

        var dateText = formatDateValue(rawDate)
        var timeText = formatTimeValue(rawTime)

        return {
            title: safeString(firstValue(src, ["title", "Title", "topic", "subject"], "")),
            description: safeString(firstValue(src, ["description", "Description", "comment"], "")),
            date: dateText,
            time: timeText,
            dateTime: parseDateTime(dateText, timeText),
            isCanceled: isCanceled,
            cabinet: safeString(firstValue(src, ["cabinet", "Cabinet", "room"], "")),
            teacherName: safeString(firstValue(src, ["teacher_name", "teacherName", "teacher"], "")),
            studentName: safeString(firstValue(src, ["student_name", "studentName", "student"], ""))
        }
    }

    function displayPersonName(item) {
        var r = Number(page.viewerRole)

        if (r === 1)
            return item.teacherName.length > 0 ? item.teacherName : "Преподаватель не указан"

        if (r === 2)
            return item.studentName.length > 0 ? item.studentName : "Студент не указан"

        if (item.studentName.length > 0 && item.teacherName.length > 0)
            return item.studentName + " / " + item.teacherName

        if (item.studentName.length > 0)
            return item.studentName

        if (item.teacherName.length > 0)
            return item.teacherName

        return "Участник не указан"
    }

    function findNearestAppointment(items) {
        page.hasNearestAppointment = false

        page.nearestTitle = ""
        page.nearestPerson = ""
        page.nearestDate = ""
        page.nearestTime = ""
        page.nearestCabinet = ""
        page.nearestDescription = ""

        if (!items || !items.length)
            return

        var now = new Date()
        var nearest = null

        for (var i = 0; i < items.length; i++) {
            var item = normalizeAppointment(items[i])

            if (item.isCanceled || item.dateTime === null)
                continue

            if (item.dateTime.getTime() < now.getTime())
                continue

            if (nearest === null || item.dateTime.getTime() < nearest.dateTime.getTime())
                nearest = item
        }

        if (nearest === null)
            return

        page.hasNearestAppointment = true

        page.nearestTitle = nearest.title.length > 0 ? nearest.title : "Консультация"
        page.nearestPerson = displayPersonName(nearest)
        page.nearestDate = formatDateForUi(nearest.date)
        page.nearestTime = nearest.time.length > 0 ? nearest.time : "--:--"
        page.nearestCabinet = nearest.cabinet
        page.nearestDescription = nearest.description
    }

    function emptyAppointmentText() {
        var r = Number(page.viewerRole)

        if (r === 1)
            return "Ближайших консультаций пока нет."

        if (r === 2)
            return "На ближайшее время консультаций нет."

        if (r === 3)
            return "Ближайших записей пока нет."

        return "Ближайших записей пока нет."
    }

    function emptyScheduleText() {
        var r = Number(page.viewerRole)

        if (r === 1)
            return "На сегодня пар нет."

        if (r === 2)
            return "На сегодня занятий нет."

        if (r === 3)
            return "На сегодня расписание пустое."

        return "На сегодня ничего не запланировано."
    }

    function lessonTimeFromItem(item) {
        var ts = safeString(item.time_start || item.TimeStart || item.start_time || "")
        var te = safeString(item.time_end || item.TimeEnd || item.end_time || "")

        if (ts.length >= 5 && te.length >= 5)
            return ts.substring(0, 5) + "–" + te.substring(0, 5)

        var n = safeNumber(item.lesson_number || item.lessonNumber || 0, 0)

        switch (n) {
            case 1:
                return "08:30–10:00"

            case 2:
                return "10:15–11:45"

            case 3:
                return "12:00–13:30"

            case 4:
                return "13:45–15:15"

            case 5:
                return "15:30–17:00"

            case 6:
                return "17:15–18:45"

            case 7:
                return "19:00–20:30"

            default:
                return "--:--"
        }
    }

    function currentWeekType() {
        var now = new Date()

        var semesterStart = new Date(2026, 1, 2)
        var diffDays = Math.floor((now - semesterStart) / 86400000)

        if (diffDays < 0)
            return 1

        var weekIndex = Math.floor(diffDays / 7)

        return (weekIndex % 2 === 0) ? 1 : 2
    }

    function fillSchedule(items) {
        scheduleModel.clear()

        if (!items || items.length === 0) {
            console.log("HomePage schedule: empty source")
            return
        }

        var jsDay = new Date().getDay()
        var dbDay = (jsDay === 0) ? 7 : jsDay
        var wt = currentWeekType()
        var role = Number(page.viewerRole)

        console.log("HomePage schedule: day=" + dbDay +
                    " weekType=" + wt +
                    " role=" + role +
                    " group=" + page.studentGroup +
                    " teacherId=" + page.teacherId +
                    " teacherUserId=" + page.teacherUserId +
                    " total=" + items.length)

        function collectLessons(strictFilter) {
            var result = []

            for (var i = 0; i < items.length; i++) {
                var itm = items[i]

                var itemDay = safeNumber(
                    itm.day_of_week ||
                    itm.dayOfWeek ||
                    itm.DayOfWeek ||
                    0,
                    0
                )

                var itemWeek = safeNumber(
                    itm.week_type ||
                    itm.weekType ||
                    itm.WeekType ||
                    0,
                    0
                )

                var itemGroup = safeString(
                    itm.group_name ||
                    itm.GroupName ||
                    itm.group ||
                    ""
                )

                var itemTeacherId = safeNumber(
                    itm.teacher_id ||
                    itm.teacherId ||
                    0,
                    0
                )

                var itemTeacherUserId = safeNumber(
                    itm.teacher_user_id ||
                    itm.teacherUserId ||
                    0,
                    0
                )

                var isActive = true

                if (itm.is_active !== undefined && itm.is_active !== null)
                    isActive = safeBool(itm.is_active)

                if (!isActive)
                    continue

                if (itemDay !== dbDay)
                    continue

                if (itemWeek !== 0 && itemWeek !== wt)
                    continue

                if (strictFilter) {
                    if (role === 1 && page.studentGroup.length > 0) {
                        if (itemGroup.toLowerCase() !== page.studentGroup.toLowerCase())
                            continue
                    }

                    if (role === 2) {
                        var teacherOk = false

                        if (page.teacherId > 0 && itemTeacherId === page.teacherId)
                            teacherOk = true

                        if (page.teacherUserId > 0 && itemTeacherUserId === page.teacherUserId)
                            teacherOk = true

                        if (!teacherOk)
                            continue
                    }
                }

                result.push(itm)
            }

            return result
        }

        var todayLessons = collectLessons(true)

        if (todayLessons.length === 0) {
            console.log("HomePage schedule: strict filter empty, fallback without group/teacher filter")
            todayLessons = collectLessons(false)
        }

        todayLessons.sort(function(a, b) {
            return safeNumber(a.lesson_number || a.lessonNumber || 0, 0) -
                   safeNumber(b.lesson_number || b.lessonNumber || 0, 0)
        })

        console.log("HomePage schedule: filtered=" + todayLessons.length)

        for (var j = 0; j < todayLessons.length; j++) {
            var lesson = todayLessons[j]

            var subjectTitle = safeString(
                lesson.subject_title ||
                lesson.SubjectTitle ||
                lesson.subject_short_title ||
                lesson.SubjectShortTitle ||
                lesson.subject_name ||
                lesson.SubjectName ||
                lesson.title ||
                lesson.Title ||
                ""
            )

            if (subjectTitle.length === 0) {
                var subjectId = safeString(lesson.subject_id || lesson.SubjectId || "")
                subjectTitle = subjectId.length > 0 ? "Предмет #" + subjectId : "Дисциплина"
            }

            var cab = safeString(lesson.cabinet || lesson.Cabinet || "")
            var teacherName = safeString(lesson.teacher_name || lesson.teacherName || "")
            var groupName = safeString(lesson.group_name || lesson.GroupName || "")

            var subtitleParts = []

            if (cab.length > 0)
                subtitleParts.push("ауд. " + cab)
            else
                subtitleParts.push("аудитория не указана")

            if (groupName.length > 0)
                subtitleParts.push("группа " + groupName)

            if (teacherName.length > 0)
                subtitleParts.push(teacherName)

            scheduleModel.append({
                time: lessonTimeFromItem(lesson),
                title: subjectTitle,
                place: subtitleParts.join(" · ")
            })
        }
    }

    function loadData() {
        if (!page || !page.visible)
            return

        page.errorText = ""

        page.profileLoading = true
        page.appointmentsLoading = true
        page.scheduleLoading = true

        if (Db.isConnect()) {
            Db.getMyProfile()
            Db.getAppointments()
            Db.getTable("Schedule")
            return
        }

        Db.connectToServer()
    }

    function fillProfile(response) {
        var user = response.user || {}

        page.fullName = joinFullName(user)
        page.firstName = extractFirstName(user)

        if (user.role !== undefined && user.role !== null)
            page.viewerRole = Number(user.role)
        else if (user.Role !== undefined && user.Role !== null)
            page.viewerRole = Number(user.Role)

        page.roleText = roleToString(page.viewerRole)

        var student = response.student || user.student || {}

        page.studentGroup = safeString(
            student.GroupName ||
            student.group_name ||
            student.group ||
            ""
        )

        page.studentCourse = safeNumber(student.Course || student.course || 0, 0)
        page.studentFaculty = safeString(student.Faculty || student.faculty || "")

        var teacher = response.teacher || user.teacher || {}

        page.teacherId = safeNumber(
            teacher.id ||
            teacher.teacher_id ||
            teacher.TeacherId ||
            0,
            0
        )

        page.teacherUserId = safeNumber(
            teacher.UserId ||
            teacher.user_id ||
            user.id ||
            user.Id ||
            0,
            0
        )

        console.log("HomePage profile: role=" + page.viewerRole +
                    " group=" + page.studentGroup +
                    " teacherId=" + page.teacherId +
                    " teacherUserId=" + page.teacherUserId)
    }

    Component.onCompleted: {
        if (visible && firstShow) {
            firstShow = false
            Qt.callLater(loadData)
        }
    }

    onVisibleChanged: {
        if (visible && firstShow) {
            firstShow = false
            Qt.callLater(loadData)
        }
    }

    Connections {
        target: Db

        function onConnectedToServer() {
            if (!page || !page.visible)
                return

            if (page.profileLoading)
                Db.getMyProfile()

            if (page.appointmentsLoading)
                Db.getAppointments()

            if (page.scheduleLoading)
                Db.getTable("Schedule")
        }

        function onDisconnectedFromServer() {
            if (!page)
                return

            page.profileLoading = false
            page.appointmentsLoading = false
            page.scheduleLoading = false

            page.errorText = "Соединение с сервером потеряно."
        }

        function onConnectionError(error) {
            if (!page)
                return

            page.profileLoading = false
            page.appointmentsLoading = false
            page.scheduleLoading = false

            page.errorText = error || "Ошибка подключения к серверу."
        }

        function onResponseReceived(response) {
            if (!page || !page.visible || !response)
                return

            if (response.code === "unauthorized") {
                page.profileLoading = false
                page.appointmentsLoading = false
                page.scheduleLoading = false
                page.errorText = "Сессия устарела. Войдите заново."
                return
            }

            var cmd = page.responseCmd(response)
            var tableName = safeString(response.table_name || response.tableName || "")

            if (cmd === "get_my_profile") {
                page.profileLoading = false

                if (response.ok && response.user) {
                    page.fillProfile(response)
                    page.errorText = ""
                } else {
                    page.errorText = response.error || "Не удалось загрузить профиль."
                }

                return
            }

            if (cmd === "get_table" && tableName === "Appointments") {
                page.appointmentsLoading = false

                if (response.ok === false) {
                    page.errorText = response.error || "Не удалось загрузить записи."
                    return
                }

                page.findNearestAppointment(extractArray(response))
                return
            }

            if (cmd === "get_table" && (tableName === "Schedule" || tableName === "ScheduleView")) {
                page.scheduleLoading = false

                if (response.ok === false) {
                    page.errorText = response.error || "Не удалось загрузить расписание."
                    return
                }

                page.fillSchedule(extractArray(response))
                return
            }

            if (cmd === "get_schedule") {
                page.scheduleLoading = false

                if (response.ok === false) {
                    page.errorText = response.error || "Не удалось загрузить расписание."
                    return
                }

                page.fillSchedule(extractArray(response))
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

        topPadding: page.contentTopInset + page.contentTopPadding
        bottomPadding: page.contentBottomInset + page.contentBottomPadding

        background: Rectangle {
            color: page.bg
        }

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: contentColumn

            width: Math.min(scrollView.availableWidth, page.contentMaxWidth)
            x: Math.max(0, (scrollView.availableWidth - width) / 2)
            spacing: page.sectionSpacing

            Rectangle {
                id: greetingCard

                color: (greetingMouse.containsMouse || greetingMouse.pressed) ? "#222222" : page.surface
                border.width: 1
                border.color: (greetingMouse.containsMouse || greetingMouse.pressed) ? page.accent : page.border

                Layout.fillWidth: true
                Layout.leftMargin: page.contentSideMargin
                Layout.rightMargin: page.contentSideMargin
                Layout.preferredHeight: greetingColumn.implicitHeight + (page.desktopMode ? 40 : 34)

                scale: greetingMouse.pressed ? 0.985 : (greetingMouse.containsMouse || greetingMouse.pressed) ? 1.010 : 1.0
                transformOrigin: Item.Center

                Behavior on scale {
                    NumberAnimation {
                        duration: 130
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: 170
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: 170
                    }
                }

                MouseArea {
                    id: greetingMouse
                    anchors.fill: parent
                    hoverEnabled: page.pointerMode
                    enabled: true
                    acceptedButtons: Qt.LeftButton
                    preventStealing: false
                    cursorShape: page.pointerMode ? Qt.PointingHandCursor : Qt.ArrowCursor

                    onClicked: {
                        page.profileRequested()
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    height: 1
                    color: page.accent
                    opacity: (greetingMouse.containsMouse || greetingMouse.pressed) ? 0.55 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 170
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                ColumnLayout {
                    id: greetingColumn

                    anchors.fill: parent
                    anchors.margins: page.desktopMode ? 20 : 17
                    spacing: page.desktopMode ? 14 : 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: page.desktopMode ? 15 : 12

                        Rectangle {
                            Layout.preferredWidth: page.desktopMode ? 64 : 58
                            Layout.preferredHeight: page.desktopMode ? 64 : 58
                            color: page.accentSoft
                            border.width: 1
                            border.color: (greetingMouse.containsMouse || greetingMouse.pressed) ? page.accent : "#555555"

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 170
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: page.firstName.length > 0 ? page.firstName.charAt(0).toUpperCase() : "?"
                                color: page.accent
                                font.pixelSize: page.desktopMode ? 31 : 28
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: page.greetingText()
                                color: page.textMain
                                font.pixelSize: page.desktopMode ? 30 : 25
                                font.bold: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: page.desktopMode ? 2 : 3
                                elide: Text.ElideRight
                                lineHeight: 1.04

                                Layout.fillWidth: true
                            }

                            Text {
                                text: page.todayDateText() + " · " + page.dayNameText()
                                color: page.textMuted
                                font.pixelSize: page.desktopMode ? 15 : 14
                                maximumLineCount: 1
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }
                        }

                        BusyIndicator {
                            running: page.profileLoading ||
                                     page.appointmentsLoading ||
                                     page.scheduleLoading

                            visible: true
                            opacity: running ? 1.0 : 0.0

                            Layout.preferredWidth: page.desktopMode ? 34 : 30
                            Layout.preferredHeight: page.desktopMode ? 34 : 30

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Badge {
                            text: page.roleText
                            colorBg: page.accentSoft
                            colorText: page.accent
                        }

                        Badge {
                            visible: Number(page.viewerRole) === 1 && page.studentGroup.length > 0
                            text: page.studentGroup
                            colorBg: page.surface2
                            colorText: page.textSub
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            ErrorBox {
                visible: page.errorText.length > 0
                text: page.errorText

                Layout.fillWidth: true
                Layout.leftMargin: page.contentSideMargin
                Layout.rightMargin: page.contentSideMargin
            }

            ColumnLayout {
                id: mobileContent

                visible: !page.desktopMode
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? implicitHeight : 0
                spacing: page.sectionSpacing

                SectionTitle {
                    title: "Ближайшая запись"
                }

                AppointmentCard {
                    hasAppointment: page.hasNearestAppointment
                    titleText: page.hasNearestAppointment ? page.nearestTitle : "Записей нет"
                    personText: page.nearestPerson
                    dateText: page.nearestDate
                    timeText: page.nearestTime
                    cabinetText: page.nearestCabinet
                    descriptionText: page.nearestDescription
                    emptyText: page.emptyAppointmentText()
                    loading: page.appointmentsLoading

                    Layout.fillWidth: true
                    Layout.leftMargin: page.contentSideMargin
                    Layout.rightMargin: page.contentSideMargin
                }

                SectionTitle {
                    title: "Расписание на сегодня"
                }

                ScheduleCard {
                    Layout.fillWidth: true
                    Layout.leftMargin: page.contentSideMargin
                    Layout.rightMargin: page.contentSideMargin
                }
            }

            GridLayout {
                id: desktopContent

                visible: page.desktopMode
                Layout.fillWidth: true
                Layout.leftMargin: page.contentSideMargin
                Layout.rightMargin: page.contentSideMargin
                Layout.preferredHeight: visible ? implicitHeight : 0

                columns: 2
                columnSpacing: 20
                rowSpacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 400
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    SectionTitle {
                        title: "Ближайшая запись"
                        Layout.leftMargin: 2
                        Layout.rightMargin: 0
                    }

                    AppointmentCard {
                        hasAppointment: page.hasNearestAppointment
                        titleText: page.hasNearestAppointment ? page.nearestTitle : "Записей нет"
                        personText: page.nearestPerson
                        dateText: page.nearestDate
                        timeText: page.nearestTime
                        cabinetText: page.nearestCabinet
                        descriptionText: page.nearestDescription
                        emptyText: page.emptyAppointmentText()
                        loading: page.appointmentsLoading

                        Layout.fillWidth: true
                        Layout.leftMargin: 0
                        Layout.rightMargin: 0
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 620
                    Layout.alignment: Qt.AlignTop
                    spacing: 12

                    SectionTitle {
                        title: "Расписание на сегодня"
                        Layout.leftMargin: 2
                        Layout.rightMargin: 0
                    }

                    ScheduleCard {
                        Layout.fillWidth: true
                        Layout.leftMargin: 0
                        Layout.rightMargin: 0
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: page.desktopMode ? 14 : 8
            }
        }
    }

    component SectionTitle: Text {
        id: section

        property string title: ""

        text: section.title
        color: page.textMain
        font.pixelSize: page.desktopMode ? 21 : 19
        font.bold: true

        Layout.fillWidth: true
        Layout.leftMargin: page.contentSideMargin + 2
        Layout.rightMargin: page.contentSideMargin + 2
        Layout.topMargin: 4
    }

    component Badge: Rectangle {
        id: badge

        property string text: ""
        property color colorBg: page.surface2
        property color colorText: page.textSub

        color: badgeMouse.containsMouse ? "#333333" : badge.colorBg

        Layout.preferredHeight: page.desktopMode ? 32 : 30
        Layout.preferredWidth: badgeText.implicitWidth + (page.desktopMode ? 26 : 22)

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        MouseArea {
            id: badgeMouse
            anchors.fill: parent
            hoverEnabled: page.pointerMode
            enabled: page.pointerMode
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.ArrowCursor
        }

        Text {
            id: badgeText

            anchors.centerIn: parent
            text: badge.text
            color: badge.colorText
            font.pixelSize: page.desktopMode ? 13 : 12
            font.bold: true
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }

    component AppointmentCard: Rectangle {
        id: card

        property bool hasAppointment: false
        property string titleText: ""
        property string personText: ""
        property string dateText: ""
        property string timeText: ""
        property string cabinetText: ""
        property string descriptionText: ""
        property string emptyText: ""
        property bool loading: false

        color: (appointmentMouse.containsMouse || appointmentMouse.pressed) ? "#222222" : page.surface
        border.width: 1
        border.color: (appointmentMouse.containsMouse || appointmentMouse.pressed) ? page.accent : page.border

        Layout.preferredHeight: content.implicitHeight + (page.desktopMode ? 36 : 32)

        scale: appointmentMouse.pressed ? 0.985 : (appointmentMouse.containsMouse || appointmentMouse.pressed) ? 1.012 : 1.0
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutQuad
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 170
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 170
            }
        }

        MouseArea {
            id: appointmentMouse
            anchors.fill: parent
            hoverEnabled: page.pointerMode
            enabled: true
            acceptedButtons: Qt.LeftButton
            preventStealing: false
            cursorShape: page.pointerMode ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: {
                page.appointmentsRequested()
            }
        }

        ColumnLayout {
            id: content

            anchors.fill: parent
            anchors.margins: page.desktopMode ? 18 : 16
            spacing: page.desktopMode ? 16 : 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    color: (appointmentMouse.containsMouse || appointmentMouse.pressed) && card.hasAppointment ? "#444444" : card.hasAppointment ? page.accentSoft : page.surface2

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 25
                        height: 25
                        name: card.hasAppointment ? "tasks" : "empty"
                        iconColor: card.hasAppointment ? page.accent : page.textMuted
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: card.loading && !card.hasAppointment ? "Загружаем запись..." : card.titleText
                        color: page.textMain
                        font.pixelSize: page.desktopMode ? 19 : 18
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }

                    Text {
                        visible: card.hasAppointment
                        text: card.personText
                        color: page.textMuted
                        font.pixelSize: 14
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                visible: card.hasAppointment
                Layout.fillWidth: true
                spacing: 10

                DetailPill {
                    iconName: "calendar"
                    text: card.dateText.length > 0 ? card.dateText : "Дата"
                    Layout.fillWidth: true
                }

                DetailPill {
                    iconName: "clock"
                    text: card.timeText.length > 0 ? card.timeText : "--:--"
                    Layout.fillWidth: true
                }
            }

            DetailPill {
                visible: card.hasAppointment && card.cabinetText.length > 0
                iconName: "room"
                text: "Кабинет " + card.cabinetText
                Layout.fillWidth: true
            }

            Text {
                visible: card.hasAppointment && card.descriptionText.length > 0
                text: card.descriptionText
                color: page.textMuted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                lineHeight: 1.2

                Layout.fillWidth: true
            }

            Text {
                visible: !card.hasAppointment && !card.loading
                text: card.emptyText
                color: page.textMuted
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                lineHeight: 1.2

                Layout.fillWidth: true
            }
        }
    }

    component ScheduleCard: Rectangle {
        id: scheduleCard

        color: (scheduleMouse.containsMouse || scheduleMouse.pressed) ? "#222222" : page.surface
        border.width: 1
        border.color: (scheduleMouse.containsMouse || scheduleMouse.pressed) ? page.accent : page.border

        Layout.preferredHeight: scheduleColumn.implicitHeight + (page.desktopMode ? 36 : 32)

        scale: scheduleMouse.pressed ? 0.988 : (scheduleMouse.containsMouse || scheduleMouse.pressed) ? 1.006 : 1.0
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation {
                duration: 130
                easing.type: Easing.OutQuad
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 170
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 170
            }
        }

        MouseArea {
            id: scheduleMouse
            anchors.fill: parent
            hoverEnabled: page.pointerMode
            enabled: true
            acceptedButtons: Qt.LeftButton
            preventStealing: false
            cursorShape: page.pointerMode ? Qt.PointingHandCursor : Qt.ArrowCursor

            onClicked: {
                page.scheduleRequested()
            }
        }

        ColumnLayout {
            id: scheduleColumn

            anchors.fill: parent
            anchors.margins: page.desktopMode ? 18 : 16
            spacing: page.desktopMode ? 13 : 12

            MessageRow {
                visible: page.scheduleLoading && scheduleModel.count === 0
                iconName: "clock"
                text: "Загружаем расписание..."
                iconColor: page.accent
                bgColor: page.accentSoft

                Layout.fillWidth: true
            }

            MessageRow {
                visible: new Date().getDay() === 0 && !page.scheduleLoading
                iconName: "check"
                text: "Сегодня воскресенье — выходной!"
                iconColor: page.success
                bgColor: page.successSoft

                Layout.fillWidth: true
            }

            MessageRow {
                visible: scheduleModel.count === 0 &&
                         !page.scheduleLoading &&
                         new Date().getDay() !== 0

                iconName: "empty"
                text: page.emptyScheduleText()
                iconColor: page.textMuted
                bgColor: page.surface2

                Layout.fillWidth: true
            }

            Repeater {
                model: scheduleModel

                delegate: Rectangle {
                    id: lessonCard

                    color: (lessonMouse.containsMouse || lessonMouse.pressed) ? "#333333" : page.surface2
                    border.width: 1
                    border.color: (lessonMouse.containsMouse || lessonMouse.pressed) ? page.accent : page.border

                    Layout.fillWidth: true
                    Layout.preferredHeight: lessonRow.implicitHeight + (page.desktopMode ? 26 : 24)

                    scale: lessonMouse.pressed ? 0.982 : (lessonMouse.containsMouse || lessonMouse.pressed) ? 1.008 : 1.0
                    transformOrigin: Item.Center

                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutQuad
                        }
                    }

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

                    MouseArea {
                        id: lessonMouse
                        anchors.fill: parent
                        hoverEnabled: page.pointerMode
                        enabled: true
                        acceptedButtons: Qt.LeftButton
                        preventStealing: false
                        cursorShape: page.pointerMode ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }

                    RowLayout {
                        id: lessonRow

                        anchors.fill: parent
                        anchors.margins: page.desktopMode ? 13 : 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: page.desktopMode ? 92 : 86
                            Layout.preferredHeight: 46
                            color: (lessonMouse.containsMouse || lessonMouse.pressed) ? "#555555" : page.accentSoft

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: model.time
                                color: page.accent
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: model.title
                                color: page.textMain
                                font.pixelSize: page.desktopMode ? 16 : 15
                                font.bold: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: page.desktopMode ? 2 : 3
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.place
                                color: page.textMuted
                                font.pixelSize: page.desktopMode ? 13 : 12
                                wrapMode: Text.WordWrap
                                maximumLineCount: page.desktopMode ? 2 : 3
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }

    component DetailPill: Rectangle {
        id: pill

        property string iconName: ""
        property string text: ""

        color: (detailMouse.containsMouse || detailMouse.pressed) ? "#333333" : page.surface2
        border.width: 1
        border.color: (detailMouse.containsMouse || detailMouse.pressed) ? page.accent : page.border

        Layout.preferredHeight: 44

        scale: detailMouse.pressed ? 0.992 : 1.0
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

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

        MouseArea {
            id: detailMouse
            anchors.fill: parent
            hoverEnabled: page.pointerMode
            enabled: true
            acceptedButtons: Qt.LeftButton
            preventStealing: false
            cursorShape: page.pointerMode ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            DrawIcon {
                Layout.preferredWidth: 19
                Layout.preferredHeight: 19
                name: pill.iconName
                iconColor: page.accent
            }

            Text {
                text: pill.text
                color: page.textSub
                font.pixelSize: 13
                font.bold: true
                maximumLineCount: 1
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }
    }

    component MessageRow: Rectangle {
        id: row

        property string iconName: ""
        property string text: ""
        property color iconColor: page.accent
        property color bgColor: page.surface2
        property bool touched: messageTouch.pressed

        color: messageMouse.containsMouse || row.touched ? "#333333" : row.bgColor
        border.width: 1
        border.color: messageMouse.containsMouse || row.touched ? page.accent : page.border

        Layout.preferredHeight: msgLayout.implicitHeight + 24
        scale: row.touched ? 0.992 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

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

        MouseArea {
            id: messageMouse
            anchors.fill: parent
            hoverEnabled: page.pointerMode
            enabled: page.pointerMode
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.ArrowCursor
        }

        TapHandler {
            id: messageTouch
            enabled: page.touchMode
            gesturePolicy: TapHandler.DragThreshold
        }

        RowLayout {
            id: msgLayout

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                color: Qt.rgba(row.iconColor.r, row.iconColor.g, row.iconColor.b, 0.14)

                DrawIcon {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    name: row.iconName
                    iconColor: row.iconColor
                }
            }

            Text {
                text: row.text
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
        property bool touched: errorTouch.pressed

        color: errorMouse.containsMouse || box.touched ? "#333333" : page.dangerSoft
        border.width: 1
        border.color: errorMouse.containsMouse || box.touched ? page.danger : "#555555"

        Layout.preferredHeight: errRow.implicitHeight + 24
        scale: box.touched ? 0.992 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

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

        MouseArea {
            id: errorMouse
            anchors.fill: parent
            hoverEnabled: page.pointerMode
            enabled: page.pointerMode
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.ArrowCursor
        }

        TapHandler {
            id: errorTouch
            enabled: page.touchMode
            gesturePolicy: TapHandler.DragThreshold
        }

        RowLayout {
            id: errRow

            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                color: "#333333"

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
                color: "#FFFFFF"
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.WordWrap
                lineHeight: 1.2

                Layout.fillWidth: true
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

            ctx.lineCap = "square"
            ctx.lineJoin = "miter"

            function px(v) {
                return x + s * v
            }

            function py(v) {
                return y + s * v
            }

            function rectPath(left, top, w, h) {
                ctx.beginPath()
                ctx.rect(left, top, w, h)
            }

            if (icon.name === "tasks") {
                rectPath(px(0.2), py(0.14), s * 0.6, s * 0.72)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.34))
                ctx.lineTo(px(0.7), py(0.34))
                ctx.moveTo(px(0.34), py(0.5))
                ctx.lineTo(px(0.7), py(0.5))
                ctx.moveTo(px(0.34), py(0.66))
                ctx.lineTo(px(0.58), py(0.66))
                ctx.stroke()


                var dSize = s * 0.03
                ctx.fillRect(px(0.27) - dSize / 2, py(0.34) - dSize / 2, dSize, dSize)
                ctx.fillRect(px(0.27) - dSize / 2, py(0.5) - dSize / 2, dSize, dSize)
                ctx.fillRect(px(0.27) - dSize / 2, py(0.66) - dSize / 2, dSize, dSize)
            } else if (icon.name === "calendar") {
                rectPath(px(0.14), py(0.22), s * 0.72, s * 0.62)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.14), py(0.4))
                ctx.lineTo(px(0.86), py(0.4))
                ctx.moveTo(px(0.32), py(0.14))
                ctx.lineTo(px(0.32), py(0.28))
                ctx.moveTo(px(0.68), py(0.14))
                ctx.lineTo(px(0.68), py(0.28))
                ctx.stroke()


                var cdSize = s * 0.05
                ctx.fillRect(px(0.34) - cdSize / 2, py(0.56) - cdSize / 2, cdSize, cdSize)
                ctx.fillRect(px(0.5) - cdSize / 2, py(0.56) - cdSize / 2, cdSize, cdSize)
                ctx.fillRect(px(0.66) - cdSize / 2, py(0.56) - cdSize / 2, cdSize, cdSize)
                ctx.fillRect(px(0.34) - cdSize / 2, py(0.7) - cdSize / 2, cdSize, cdSize)
                ctx.fillRect(px(0.5) - cdSize / 2, py(0.7) - cdSize / 2, cdSize, cdSize)
            } else if (icon.name === "clock") {

                ctx.beginPath()
                ctx.rect(px(0.16), py(0.16), s * 0.68, s * 0.68)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.3))
                ctx.lineTo(px(0.5), py(0.52))
                ctx.lineTo(px(0.66), py(0.62))
                ctx.stroke()
            } else if (icon.name === "room") {
                rectPath(px(0.2), py(0.16), s * 0.6, s * 0.7)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.16))
                ctx.lineTo(px(0.5), py(0.86))
                ctx.stroke()


                var kSize = s * 0.05
                ctx.fillRect(px(0.42) - kSize / 2, py(0.52) - kSize / 2, kSize, kSize)
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


                var wSize = s * 0.05
                ctx.fillRect(px(0.5) - wSize / 2, py(0.69) - wSize / 2, wSize, wSize)
            } else if (icon.name === "check") {

                ctx.beginPath()
                ctx.rect(px(0.16), py(0.16), s * 0.68, s * 0.68)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.51))
                ctx.lineTo(px(0.46), py(0.63))
                ctx.lineTo(px(0.68), py(0.39))
                ctx.stroke()
            } else if (icon.name === "empty") {
                rectPath(px(0.2), py(0.22), s * 0.6, s * 0.52)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.5))
                ctx.lineTo(px(0.66), py(0.5))
                ctx.stroke()
            } else {

                var defaultSize = s * 0.16
                ctx.fillRect(px(0.5) - defaultSize / 2, py(0.5) - defaultSize / 2, defaultSize, defaultSize)
            }
        }
    }
}