import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Item {
    id: page

    signal logoutRequested()

    property int viewerRole: 0
    property int contentTopInset: 0
    property int contentBottomInset: 0
    readonly property int desktopBreakpoint: 900
    readonly property bool desktopMode: page.width >= page.desktopBreakpoint
    readonly property int contentMaxWidth: 1040
    property bool active: visible

    property bool scheduleLoading: false
    property string errorText: ""

    property int selectedWeekType: currentWeekType()

    readonly property string weekOneTitle: "Неделя 1"
    readonly property string weekTwoTitle: "Неделя 2"

    property var allScheduleItems: []
    property int visibleLessonsCount: 0


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
    readonly property color warning: "#FFFFFF"
    readonly property color warningSoft: "#222222"

    ListModel {
        id: displayScheduleModel
    }

    ListModel {
        id: daysModel

        ListElement { dayNum: 1; shortName: "Пн"; fullName: "Понедельник" }
        ListElement { dayNum: 2; shortName: "Вт"; fullName: "Вторник" }
        ListElement { dayNum: 3; shortName: "Ср"; fullName: "Среда" }
        ListElement { dayNum: 4; shortName: "Чт"; fullName: "Четверг" }
        ListElement { dayNum: 5; shortName: "Пт"; fullName: "Пятница" }
        ListElement { dayNum: 6; shortName: "Сб"; fullName: "Суббота" }
        ListElement { dayNum: 7; shortName: "Вс"; fullName: "Воскресенье" }
    }

    Component.onCompleted: {
        if (page.active)
            Qt.callLater(page.loadScheduleData)
    }

    onActiveChanged: {
        if (page.active)
            Qt.callLater(page.loadScheduleData)
    }

    function currentDbDay() {
        var jsDay = new Date().getDay()
        return jsDay === 0 ? 7 : jsDay
    }

    function currentWeekType() {
        var now = new Date()
        var semesterStart = new Date(2026, 1, 2)
        var diffDays = Math.floor((now - semesterStart) / 86400000)

        if (diffDays < 0)
            return 1

        var weekIndex = Math.floor(diffDays / 7)
        return weekIndex % 2 === 0 ? 1 : 2
    }

    function currentWeekTitle() {
        return page.selectedWeekType === 1 ? page.weekOneTitle : page.weekTwoTitle
    }

    function normalizeCommandName(value) {
        var text = safeString(value)

        if (text.length === 0)
            return ""

        return text.replace(/([a-z0-9])([A-Z])/g, "$1_$2")
                   .replace(/[\s-]+/g, "_")
                   .toLowerCase()
    }

    function responseCmd(obj) {
        if (!obj)
            return ""

        if (obj.command !== undefined && obj.command !== null)
            return normalizeCommandName(obj.command)

        if (obj.cmd !== undefined && obj.cmd !== null)
            return normalizeCommandName(obj.cmd)

        return ""
    }

    function normalizeTableName(value) {
        var text = safeString(value)
        var key = text.replace(/[\s_-]+/g, "").toLowerCase()

        if (key === "scheduleview")
            return "ScheduleView"

        if (key === "schedule" || key === "schedules")
            return "Schedule"

        return text
    }

    function safeString(value) {
        if (value === undefined || value === null)
            return ""

        var text = String(value).trim()

        if (text.toLowerCase() === "null" || text.toLowerCase() === "undefined")
            return ""

        return text
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

        return text === "true" || text === "yes" || text === "да"
    }

    function isArrayLike(value) {
        return value !== undefined
            && value !== null
            && typeof value !== "string"
            && value.length !== undefined
    }

    function extractScheduleArray(obj) {
        if (!obj)
            return []

        if (isArrayLike(obj.schedule))
            return obj.schedule

        if (isArrayLike(obj.Schedule))
            return obj.Schedule

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

        return []
    }

    function firstDefined(obj, keys, fallback) {
        if (!obj)
            return fallback

        for (var i = 0; i < keys.length; i++) {
            var key = keys[i]

            if (obj[key] !== undefined && obj[key] !== null)
                return obj[key]
        }

        return fallback
    }

    function dayName(day) {
        day = Number(day)

        for (var i = 0; i < daysModel.count; i++) {
            var item = daysModel.get(i)

            if (Number(item.dayNum) === day)
                return safeString(item.fullName)
        }

        return "День " + day
    }

    function formatLessonsCount(count) {
        count = Number(count)

        var mod10 = count % 10
        var mod100 = count % 100

        if (mod10 === 1 && mod100 !== 11)
            return count + " занятие"

        if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20))
            return count + " занятия"

        return count + " занятий"
    }

    function lessonTimeFromItem(item) {
        var start = safeString(firstDefined(item, [
            "time_start",
            "timeStart",
            "TimeStart",
            "start_time",
            "StartTime"
        ], ""))

        var end = safeString(firstDefined(item, [
            "time_end",
            "timeEnd",
            "TimeEnd",
            "end_time",
            "EndTime"
        ], ""))

        if (start.length >= 5 && end.length >= 5)
            return start.substring(0, 5) + "–" + end.substring(0, 5)

        var lessonNumber = Number(firstDefined(item, [
            "lesson_number",
            "lessonNumber",
            "LessonNumber",
            "number",
            "Number"
        ], 0))

        switch (lessonNumber) {
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

    function subjectTitleFromItem(item) {
        var fullTitle = safeString(firstDefined(item, [
            "subject_title",
            "SubjectTitle",
            "subjectTitle",
            "subject_name",
            "SubjectName",
            "full_subject_title",
            "FullSubjectTitle",
            "fullSubjectTitle",
            "realTitle",
            "real_title",
            "title",
            "Title",
            "name",
            "Name",
            "subject",
            "Subject"
        ], ""))

        if (fullTitle.length > 0)
            return fullTitle

        var shortTitle = safeString(firstDefined(item, [
            "subject_short_title",
            "subjectShortTitle",
            "SubjectShortTitle",
            "short_title",
            "shortTitle",
            "ShortTitle"
        ], ""))

        return shortTitle.length > 0 ? shortTitle : "Дисциплина"
    }

    function teacherNameFromItem(item) {
        return safeString(firstDefined(item, [
            "teacher_name",
            "TeacherName",
            "teacherName",
            "teacherFullName",
            "full_name",
            "fullName"
        ], ""))
    }

    function groupNameFromItem(item) {
        return safeString(firstDefined(item, [
            "group_name",
            "GroupName",
            "groupName"
        ], ""))
    }

    function cabinetFromItem(item) {
        return safeString(firstDefined(item, [
            "cabinet",
            "Cabinet",
            "room",
            "Room"
        ], ""))
    }

    function noteFromItem(item) {
        return safeString(firstDefined(item, [
            "note",
            "Note",
            "description",
            "Description",
            "comment",
            "Comment"
        ], ""))
    }

    function subgroupFromItem(item) {
        return safeString(firstDefined(item, [
            "subgroup",
            "Subgroup"
        ], ""))
    }

    function isActiveScheduleItem(item) {
        var value = firstDefined(item, [
            "is_active",
            "isActive",
            "IsActive",
            "active",
            "Active"
        ], true)

        return safeBool(value)
    }

    function weekTypeFromItem(item) {
        return Number(firstDefined(item, [
            "week_type",
            "weekType",
            "WeekType"
        ], 0))
    }

    function isVisibleForSelectedWeek(item) {
        var weekType = page.weekTypeFromItem(item)

        return weekType === 0 || weekType === page.selectedWeekType
    }

    function lessonNumberFromItem(item) {
        return Number(firstDefined(item, [
            "lesson_number",
            "lessonNumber",
            "LessonNumber",
            "number",
            "Number"
        ], 0))
    }

    function dayFromItem(item) {
        return Number(firstDefined(item, [
            "day_of_week",
            "dayOfWeek",
            "DayOfWeek",
            "day",
            "Day"
        ], 0))
    }

    function weekBadgeText(item) {
        var weekType = page.weekTypeFromItem(item)

        if (weekType === 0)
            return "Каждую неделю"

        if (weekType === 1)
            return page.weekOneTitle

        if (weekType === 2)
            return page.weekTwoTitle

        return ""
    }

    function appendDisplayRow(rowType, dayNum, dayTitle, dayShort, lessonCount, timeText, lessonNumText, title, teacherName, groupName, placeText, noteText, subgroupText, weekText) {
        displayScheduleModel.append({
            rowType: rowType,

            dayNum: dayNum,
            dayTitle: dayTitle,
            dayShort: dayShort,
            daySubtitle: lessonCount > 0 ? page.formatLessonsCount(lessonCount) + " · " + page.currentWeekTitle() : "занятий нет",
            lessonCount: lessonCount,
            isToday: Number(dayNum) === Number(page.currentDbDay()),

            timeText: timeText,
            lessonNumText: lessonNumText,
            titleText: title,
            teacherName: teacherName,
            groupName: groupName,
            placeText: placeText,
            noteText: noteText,
            subgroupText: subgroupText,
            weekText: weekText
        })
    }

    function buildScheduleByDays() {
        var items = page.allScheduleItems || []
        var byDay = ({})
        var total = 0

        for (var d = 1; d <= 7; d++)
            byDay[d] = []

        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            var day = page.dayFromItem(item)

            if (day < 1 || day > 7)
                continue

            if (!page.isActiveScheduleItem(item))
                continue

            if (!page.isVisibleForSelectedWeek(item))
                continue

            byDay[day].push(item)
            total++
        }

        page.visibleLessonsCount = total
        displayScheduleModel.clear()

        for (var modelIndex = 0; modelIndex < daysModel.count; modelIndex++) {
            var dayInfo = daysModel.get(modelIndex)
            var dayNum = Number(dayInfo.dayNum)
            var list = byDay[dayNum]

            list.sort(function(a, b) {
                var lessonDiff = page.lessonNumberFromItem(a) - page.lessonNumberFromItem(b)

                if (lessonDiff !== 0)
                    return lessonDiff

                return page.weekTypeFromItem(a) - page.weekTypeFromItem(b)
            })

            page.appendDisplayRow(
                        "day",
                        dayNum,
                        safeString(dayInfo.fullName),
                        safeString(dayInfo.shortName),
                        list.length,
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        "",
                        ""
                        )

            if (list.length === 0) {
                page.appendDisplayRow(
                            "empty",
                            dayNum,
                            safeString(dayInfo.fullName),
                            safeString(dayInfo.shortName),
                            0,
                            "",
                            "",
                            "В этот день занятий нет",
                            "",
                            "",
                            "",
                            "",
                            "",
                            ""
                            )
                continue
            }

            for (var j = 0; j < list.length; j++) {
                var lesson = list[j]
                var lessonNumber = page.lessonNumberFromItem(lesson)

                page.appendDisplayRow(
                            "lesson",
                            dayNum,
                            safeString(dayInfo.fullName),
                            safeString(dayInfo.shortName),
                            list.length,
                            page.lessonTimeFromItem(lesson),
                            lessonNumber > 0 ? lessonNumber + " пара" : "",
                            page.subjectTitleFromItem(lesson),
                            page.teacherNameFromItem(lesson),
                            page.groupNameFromItem(lesson),
                            page.cabinetFromItem(lesson),
                            page.noteFromItem(lesson),
                            page.subgroupFromItem(lesson),
                            page.weekBadgeText(lesson)
                            )
            }
        }
    }

    function loadScheduleData() {
        if (!page.active)
            return

        page.errorText = ""
        page.scheduleLoading = true

        if (Db.isConnect()) {
            Db.getTable("ScheduleView")
            return
        }

        Db.connectToServer()
    }

    function fillSchedule(items) {
        page.allScheduleItems = items || []
        page.buildScheduleByDays()
    }

    Connections {
        target: Db
        ignoreUnknownSignals: true

        function onConnectedToServer() {
            if (page.active && page.scheduleLoading)
                Db.getTable("ScheduleView")
        }

        function onDisconnectedFromServer() {
            if (page.scheduleLoading) {
                page.scheduleLoading = false
                page.errorText = "Соединение с сервером потеряно."
            }
        }

        function onConnectionError(error) {
            if (page.scheduleLoading) {
                page.scheduleLoading = false
                page.errorText = error || "Ошибка подключения к серверу."
            }
        }

        function onResponseReceived(response) {
            if (!response || !page.active)
                return

            if (response.code === "unauthorized") {
                page.scheduleLoading = false
                page.errorText = "Сессия устарела. Войдите заново."
                return
            }

            var cmd = page.responseCmd(response)
            var tableName = page.normalizeTableName(page.safeString(
                        response.table_name ||
                        response.tableName ||
                        response.table ||
                        response.Table ||
                        ""
                        ))

            if (cmd === "get_schedule" ||
                    (cmd === "get_table" && (tableName === "ScheduleView" || tableName === "Schedule"))) {
                page.scheduleLoading = false

                if (response.ok === false) {
                    page.errorText = response.error || "Не удалось загрузить расписание."
                    return
                }

                page.fillSchedule(page.extractScheduleArray(response))
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

        topPadding: page.contentTopInset + (page.desktopMode ? 26 : 20)
        bottomPadding: page.contentBottomInset + (page.desktopMode ? 32 : 0)

        background: Rectangle {
            color: page.bg
        }

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: contentColumn

            width: Math.min(scrollView.availableWidth, page.desktopMode ? page.contentMaxWidth : scrollView.availableWidth)
            x: Math.round((scrollView.availableWidth - width) / 2)
            spacing: page.desktopMode ? 16 : 14

            HeaderCard {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            SegmentedCard {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20

                SegmentButton {
                    text: page.weekOneTitle
                    selected: page.selectedWeekType === 1

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    onClicked: {
                        if (page.selectedWeekType !== 1) {
                            page.selectedWeekType = 1
                            page.buildScheduleByDays()
                        }
                    }
                }

                SegmentButton {
                    text: page.weekTwoTitle
                    selected: page.selectedWeekType === 2

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    onClicked: {
                        if (page.selectedWeekType !== 2) {
                            page.selectedWeekType = 2
                            page.buildScheduleByDays()
                        }
                    }
                }
            }

            MessageCard {
                visible: page.scheduleLoading && displayScheduleModel.count === 0
                iconName: "clock"
                text: "Загружаю расписание..."
                iconColor: page.accent
                bgColor: page.surface2

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            ErrorBox {
                visible: page.errorText.length > 0
                text: page.errorText

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            MessageCard {
                visible: !page.scheduleLoading
                         && page.errorText.length === 0
                         && page.visibleLessonsCount === 0
                         && displayScheduleModel.count > 0
                iconName: "empty"
                text: "На выбранную неделю занятий нет."
                iconColor: page.textMuted
                bgColor: page.surface2

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            Repeater {
                model: displayScheduleModel

                ScheduleDisplayItem {
                    rowType: model.rowType

                    dayNum: model.dayNum
                    dayTitle: model.dayTitle
                    dayShort: model.dayShort
                    daySubtitle: model.daySubtitle
                    lessonCount: model.lessonCount
                    isToday: model.isToday

                    timeText: model.timeText
                    lessonNumText: model.lessonNumText
                    titleText: model.titleText
                    teacherName: model.teacherName
                    groupName: model.groupName
                    placeText: model.placeText
                    noteText: model.noteText
                    subgroupText: model.subgroupText
                    weekText: model.weekText

                    Layout.fillWidth: true
                    Layout.leftMargin: 20
                    Layout.rightMargin: 20
                    Layout.topMargin: model.rowType === "day" ? 6 : 0
                }
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
        property bool pressed: hoverArea.pressed


        color: card.pressed ? page.surface3 : card.hovered ? "#333333" : page.surface2
        border.width: 1
        border.color: card.hovered ? "#777777" : page.border
        scale: card.pressed ? 0.992 : card.hovered ? 1.006 : 1.0

        Layout.preferredHeight: headerColumn.implicitHeight + 34

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton
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
                    color: page.surface3
                    border.width: 1
                    border.color: "#555555"

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        name: "calendar"
                        iconColor: page.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "Расписание"
                        color: page.textMain
                        font.pixelSize: 24
                        font.bold: true
                        maximumLineCount: 1
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }

                    Text {
                        text: "По дням недели · " + page.currentWeekTitle()
                        color: page.textMuted
                        font.pixelSize: 14
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap

                        Layout.fillWidth: true
                    }
                }

                BusyIndicator {
                    running: page.scheduleLoading
                    visible: true
                    opacity: running ? 1.0 : 0.0

                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Badge {
                    text: page.currentWeekTitle()
                    colorBg: page.surface3
                    colorText: page.accent
                }

                Badge {
                    text: page.formatLessonsCount(page.visibleLessonsCount)
                    colorBg: page.surface3
                    colorText: page.textSub
                }

                Badge {
                    text: page.dayName(page.currentDbDay())
                    colorBg: page.surface3
                    colorText: page.success
                }

                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }

    component SegmentedCard: Rectangle {
        id: card

        default property alias content: row.data

        property bool hovered: hoverArea.containsMouse

        height: 54
        color: card.hovered ? "#333333" : page.surface2
        border.width: 1
        border.color: card.hovered ? "#777777" : page.border

        Layout.preferredHeight: 54

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
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
        property bool pressed: mouseArea.pressed

        opacity: enabled ? 1.0 : 0.45
        scale: control.pressed ? 0.982 : control.hovered ? 1.012 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 115
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            color: {
                if (control.selected)
                    return page.accent
                if (control.pressed)
                    return page.surface3
                if (control.hovered)
                    return page.surface3
                return "transparent"
            }
            border.width: control.selected || control.hovered ? 1 : 0
            border.color: control.selected ? page.accent : page.border

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
        }

        Text {
            anchors.centerIn: parent
            text: control.text
            color: control.selected ? "#000000" : control.hovered ? page.textMain : page.textSub
            font.pixelSize: page.desktopMode ? 15 : 14
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on color {
                ColorAnimation {
                    duration: 130
                    easing.type: Easing.OutQuad
                }
            }
        }

        MouseArea {
            id: mouseArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                control.clicked()
            }
        }
    }

    component ScheduleDisplayItem: Item {
        id: wrapper

        property string rowType: ""

        property int dayNum: 0
        property string dayTitle: ""
        property string dayShort: ""
        property string daySubtitle: ""
        property int lessonCount: 0
        property bool isToday: false

        property string timeText: ""
        property string lessonNumText: ""
        property string titleText: ""
        property string teacherName: ""
        property string groupName: ""
        property string placeText: ""
        property string noteText: ""
        property string subgroupText: ""
        property string weekText: ""

        Layout.preferredHeight: {
            if (wrapper.rowType === "day")
                return dayHeader.implicitHeight

            if (wrapper.rowType === "lesson")
                return lessonCard.implicitHeight

            return emptyDayCard.implicitHeight
        }

        DayHeaderCard {
            id: dayHeader

            visible: wrapper.rowType === "day"
            width: parent.width

            dayNum: wrapper.dayNum
            dayTitle: wrapper.dayTitle
            dayShort: wrapper.dayShort
            daySubtitle: wrapper.daySubtitle
            lessonCount: wrapper.lessonCount
            isToday: wrapper.isToday
        }

        LessonCard {
            id: lessonCard

            visible: wrapper.rowType === "lesson"
            width: parent.width

            timeText: wrapper.timeText
            lessonNumText: wrapper.lessonNumText
            titleText: wrapper.titleText
            teacherName: wrapper.teacherName
            groupName: wrapper.groupName
            placeText: wrapper.placeText
            noteText: wrapper.noteText
            subgroupText: wrapper.subgroupText
            weekText: wrapper.weekText
        }

        DayEmptyCard {
            id: emptyDayCard

            visible: wrapper.rowType === "empty"
            width: parent.width

            dayTitle: wrapper.dayTitle
            text: wrapper.titleText.length > 0 ? wrapper.titleText : "В этот день занятий нет"
        }
    }

    component DayHeaderCard: Rectangle {
        id: card

        property int dayNum: 0
        property string dayTitle: ""
        property string dayShort: ""
        property string daySubtitle: ""
        property int lessonCount: 0
        property bool isToday: false
        property bool hovered: hoverArea.containsMouse
        property bool pressed: hoverArea.pressed

        implicitHeight: dayRow.implicitHeight + 24


        color: {
            if (card.pressed)
                return page.surface3
            if (card.isToday)
                return card.hovered ? "#444444" : page.surface3
            return card.hovered ? page.surface3 : page.surface2
        }
        border.width: 1
        border.color: card.isToday ? page.accent : card.hovered ? "#777777" : page.border
        scale: card.pressed ? 0.992 : card.hovered ? 1.004 : 1.0

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton
        }

        RowLayout {
            id: dayRow

            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                color: card.isToday ? page.accent : page.surface3
                border.width: 1
                border.color: card.isToday ? page.accent : page.border

                Text {
                    anchors.centerIn: parent
                    text: card.dayShort
                    color: card.isToday ? "#000000" : page.textSub
                    font.pixelSize: 17
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: card.dayTitle
                        color: page.textMain
                        font.pixelSize: 20
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: card.isToday
                        color: page.surface3
                        border.width: 1
                        border.color: page.border

                        Layout.preferredHeight: 26
                        Layout.preferredWidth: todayText.implicitWidth + 18

                        Text {
                            id: todayText

                            anchors.centerIn: parent
                            text: "Сегодня"
                            color: page.textMain
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }
                }

                Text {
                    text: card.daySubtitle
                    color: card.lessonCount > 0 ? page.textSub : page.textMuted
                    font.pixelSize: 13
                    font.bold: card.lessonCount > 0
                    maximumLineCount: 1
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.preferredWidth: countLabel.implicitWidth + 20
                Layout.preferredHeight: 32
                color: card.lessonCount > 0 ? page.surface : page.surface3
                border.width: 1
                border.color: page.border

                Text {
                    id: countLabel

                    anchors.centerIn: parent
                    text: String(card.lessonCount)
                    color: card.lessonCount > 0 ? page.accent : page.textMuted
                    font.pixelSize: 13
                    font.bold: true
                }
            }
        }
    }

    component LessonCard: Rectangle {
        id: card

        property string timeText: ""
        property string lessonNumText: ""
        property string titleText: ""
        property string teacherName: ""
        property string groupName: ""
        property string placeText: ""
        property string noteText: ""
        property string subgroupText: ""
        property string weekText: ""
        property bool hovered: hoverArea.containsMouse
        property bool pressed: hoverArea.pressed

        implicitHeight: cardColumn.implicitHeight + 32


        color: card.pressed ? page.surface3 : card.hovered ? "#222222" : page.surface
        border.width: 1
        border.color: card.hovered ? "#777777" : page.border
        scale: card.pressed ? 0.992 : card.hovered ? 1.006 : 1.0
        transformOrigin: Item.Center

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: card.hovered ? 7 : 5
            color: page.accent
            opacity: card.hovered ? 1.0 : 0.9

            Behavior on width {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutQuad
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutQuad
                }
            }
        }

        ColumnLayout {
            id: cardColumn

            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 86
                    Layout.preferredHeight: 62
                    color: page.surface3
                    border.width: 1
                    border.color: page.border

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            text: card.timeText.length > 0 ? card.timeText : "--:--"
                            color: page.accent
                            font.pixelSize: 13
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter

                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: card.lessonNumText
                            color: page.textSub
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter

                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            visible: card.weekText.length > 0
                            color: page.surface2
                            border.width: 1
                            border.color: page.border

                            Layout.preferredHeight: 30
                            Layout.preferredWidth: weekLabel.implicitWidth + 18

                            Text {
                                id: weekLabel

                                anchors.centerIn: parent
                                text: card.weekText
                                color: card.weekText === "Каждую неделю" ? page.textMain : page.accent
                                font.pixelSize: 11
                                font.bold: true
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        InfoPill {
                            visible: card.placeText.length > 0
                            iconName: "room"
                            text: "каб. " + card.placeText
                        }

                        InfoPill {
                            visible: card.groupName.length > 0
                            iconName: "group"
                            text: card.groupName
                        }

                        InfoPill {
                            visible: card.subgroupText.length > 0
                            iconName: "subgroup"
                            text: card.subgroupText
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: titleColumn.implicitHeight + 22

                color: page.surface2
                border.width: 1
                border.color: page.border

                ColumnLayout {
                    id: titleColumn

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 5

                    Text {
                        text: "Дисциплина"
                        color: page.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        maximumLineCount: 1
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }

                    Text {
                        text: card.titleText
                        color: page.textMain
                        font.pixelSize: 16
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 8
                        elide: Text.ElideRight
                        lineHeight: 1.12

                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                visible: card.teacherName.length > 0

                Layout.fillWidth: true
                Layout.preferredHeight: teacherRow.implicitHeight + 18

                color: page.surface2
                border.width: 1
                border.color: page.border

                RowLayout {
                    id: teacherRow

                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 9

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        color: page.surface3

                        DrawIcon {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            name: "user"
                            iconColor: page.accent
                        }
                    }

                    Text {
                        text: card.teacherName
                        color: page.textSub
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap

                        Layout.fillWidth: true
                    }
                }
            }

            Text {
                visible: card.noteText.length > 0
                text: card.noteText
                color: page.textMuted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }
    }

    component DayEmptyCard: Rectangle {
        id: card

        property string dayTitle: ""
        property string text: "В этот день занятий нет"
        property bool hovered: hoverArea.containsMouse
        property bool pressed: hoverArea.pressed

        implicitHeight: emptyRow.implicitHeight + 20

        color: card.pressed ? page.surface3 : card.hovered ? page.surface2 : page.surface
        border.width: 1
        border.color: card.hovered ? "#777777" : page.border
        opacity: card.hovered ? 0.92 : 0.78
        scale: card.pressed ? 0.994 : card.hovered ? 1.003 : 1.0

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton
        }

        RowLayout {
            id: emptyRow

            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                color: page.surface2
                border.width: 1
                border.color: page.border

                DrawIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    name: "empty"
                    iconColor: page.textMuted
                }
            }

            Text {
                text: card.text
                color: page.textMuted
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.WordWrap

                Layout.fillWidth: true
            }
        }
    }

    component Badge: Rectangle {
        id: badge

        property string text: ""
        property color colorBg: page.surface2
        property color colorText: page.textSub
        property bool hovered: hoverArea.containsMouse

        color: badge.hovered ? "#444444" : badge.colorBg
        border.width: badge.hovered ? 1 : 0
        border.color: page.border
        scale: badge.hovered ? 1.035 : 1.0

        Behavior on color {
            ColorAnimation {
                duration: 140
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Layout.preferredHeight: 30
        Layout.preferredWidth: badgeText.implicitWidth + 22

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

    component InfoPill: Rectangle {
        id: pill

        property string text: ""
        property string iconName: ""
        property bool hovered: hoverArea.containsMouse

        Layout.preferredWidth: Math.min(label.implicitWidth + 42, page.desktopMode ? 220 : 170)
        Layout.preferredHeight: 30

        color: pill.hovered ? page.surface3 : page.surface2
        border.width: 1
        border.color: pill.hovered ? "#777777" : page.border
        scale: pill.hovered ? 1.018 : 1.0

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
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            id: hoverArea
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
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                name: pill.iconName
                iconColor: page.textMuted
            }

            Text {
                id: label

                text: pill.text
                color: page.textMuted
                font.pixelSize: 11
                font.bold: true
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }
    }

    component MessageCard: Rectangle {
        id: card

        property string iconName: ""
        property string text: ""
        property color iconColor: page.accent
        property color bgColor: page.surface2
        property bool hovered: hoverArea.containsMouse

        color: card.hovered ? Qt.rgba(card.iconColor.r, card.iconColor.g, card.iconColor.b, 0.16) : card.bgColor
        border.width: 1
        border.color: card.hovered ? Qt.rgba(card.iconColor.r, card.iconColor.g, card.iconColor.b, 0.45) : page.border
        scale: card.hovered ? 1.003 : 1.0

        Layout.preferredHeight: msgRow.implicitHeight + 24

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            id: hoverArea
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
        property bool hovered: hoverArea.containsMouse

        color: box.hovered ? "#44272A" : page.dangerSoft
        border.width: 1
        border.color: box.hovered ? page.danger : "#5A2D31"
        scale: box.hovered ? 1.003 : 1.0

        Layout.preferredHeight: errRow.implicitHeight + 24

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutQuad
            }
        }

        MouseArea {
            id: hoverArea
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
                color: "#FFD7DA"
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

            if (icon.name === "calendar") {
                ctx.strokeRect(px(0.14), py(0.22), s * 0.72, s * 0.62)

                ctx.beginPath()
                ctx.moveTo(px(0.14), py(0.4))
                ctx.lineTo(px(0.86), py(0.4))
                ctx.moveTo(px(0.32), py(0.14))
                ctx.lineTo(px(0.32), py(0.28))
                ctx.moveTo(px(0.68), py(0.14))
                ctx.lineTo(px(0.68), py(0.28))
                ctx.stroke()

                var cds = s * 0.06
                ctx.fillRect(px(0.34) - cds / 2, py(0.58) - cds / 2, cds, cds)
                ctx.fillRect(px(0.5) - cds / 2, py(0.58) - cds / 2, cds, cds)
                ctx.fillRect(px(0.66) - cds / 2, py(0.58) - cds / 2, cds, cds)
                ctx.fillRect(px(0.34) - cds / 2, py(0.72) - cds / 2, cds, cds)
                ctx.fillRect(px(0.5) - cds / 2, py(0.72) - cds / 2, cds, cds)
            } else if (icon.name === "clock") {
                ctx.strokeRect(px(0.16), py(0.16), s * 0.68, s * 0.68)

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.3))
                ctx.lineTo(px(0.5), py(0.52))
                ctx.lineTo(px(0.66), py(0.62))
                ctx.stroke()
            } else if (icon.name === "room") {
                ctx.strokeRect(px(0.2), py(0.16), s * 0.6, s * 0.7)

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.16))
                ctx.lineTo(px(0.5), py(0.86))
                ctx.stroke()

                var ks = s * 0.05
                ctx.fillRect(px(0.42) - ks / 2, py(0.52) - ks / 2, ks, ks)
            } else if (icon.name === "group") {
                ctx.strokeRect(px(0.25), py(0.2), s * 0.2, s * 0.2)
                ctx.strokeRect(px(0.55), py(0.2), s * 0.2, s * 0.2)
                ctx.strokeRect(px(0.15), py(0.5), s * 0.4, s * 0.3)
                ctx.strokeRect(px(0.45), py(0.5), s * 0.4, s * 0.3)
            } else if (icon.name === "subgroup") {
                ctx.strokeRect(px(0.18), py(0.22), s * 0.64, s * 0.56)

                ctx.beginPath()
                ctx.moveTo(px(0.32), py(0.4))
                ctx.lineTo(px(0.68), py(0.4))
                ctx.moveTo(px(0.32), py(0.56))
                ctx.lineTo(px(0.58), py(0.56))
                ctx.stroke()
            } else if (icon.name === "user") {
                ctx.strokeRect(px(0.34), py(0.17), s * 0.32, s * 0.32)
                ctx.strokeRect(px(0.24), py(0.58), s * 0.52, s * 0.24)
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

                var ws = s * 0.06
                ctx.fillRect(px(0.5) - ws / 2, py(0.69) - ws / 2, ws, ws)
            } else if (icon.name === "empty") {
                ctx.strokeRect(px(0.2), py(0.22), s * 0.6, s * 0.52)

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.5))
                ctx.lineTo(px(0.66), py(0.5))
                ctx.stroke()
            } else if (icon.name === "tasks") {
                ctx.strokeRect(px(0.2), py(0.14), s * 0.6, s * 0.72)

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.34))
                ctx.lineTo(px(0.7), py(0.34))
                ctx.moveTo(px(0.34), py(0.5))
                ctx.lineTo(px(0.7), py(0.5))
                ctx.moveTo(px(0.34), py(0.66))
                ctx.lineTo(px(0.58), py(0.66))
                ctx.stroke()

                var ds = s * 0.05
                ctx.fillRect(px(0.27) - ds / 2, py(0.34) - ds / 2, ds, ds)
                ctx.fillRect(px(0.27) - ds / 2, py(0.5) - ds / 2, ds, ds)
                ctx.fillRect(px(0.27) - ds / 2, py(0.66) - ds / 2, ds, ds)
            } else {
                var defs = s * 0.16
                ctx.fillRect(px(0.5) - defs / 2, py(0.5) - defs / 2, defs, defs)
            }
        }
    }
}