import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Item {
    id: page

    signal backRequested()
    signal createRequested()
    signal editRequested(var scheduleItem)

    property int contentTopInset: 0
    property int contentBottomInset: 0

    property bool loadingSchedule: false
    property bool deleting: false

    property string errorText: ""
    property string successText: ""

    property int selectedGroupIndex: 0
    property int selectedWeekFilterIndex: 0

    property int pendingDeleteId: -1
    property string pendingDeleteTitle: ""

    readonly property bool loading: loadingSchedule || deleting

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
        id: scheduleModel
    }

    ListModel {
        id: filteredScheduleModel
    }

    ListModel {
        id: displayScheduleModel
    }

    ListModel {
        id: groupModel
    }

    ListModel {
        id: weekFilterModel

        ListElement {
            idValue: -1
            title: "Все недели"
        }

        ListElement {
            idValue: 0
            title: "Каждая неделя"
        }

        ListElement {
            idValue: 1
            title: "Числитель"
        }

        ListElement {
            idValue: 2
            title: "Знаменатель"
        }
    }

    Component.onCompleted: {
        Qt.callLater(page.loadSchedule)
    }

    Timer {
        id: loadTimeoutTimer

        interval: 9000
        repeat: false

        onTriggered: {
            if (!page.loadingSchedule)
                return

            page.loadingSchedule = false
            page.deleting = false

            if (page.errorText.length === 0)
                page.errorText = "Расписание не загрузилось. Проверьте ScheduleView на сервере."
        }
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

    function safeString(value) {
        if (value === undefined || value === null)
            return ""

        var text = String(value).trim()

        if (text.toLowerCase() === "null" || text.toLowerCase() === "undefined")
            return ""

        return text
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

        return text === "true" || text === "yes" || text === "да"
    }

    function extractArray(obj) {
        if (!obj)
            return []

        if (obj.MyTable && obj.MyTable.length !== undefined)
            return obj.MyTable

        if (obj.items && obj.items.length !== undefined)
            return obj.items

        if (obj.data && obj.data.length !== undefined)
            return obj.data

        if (obj.result && obj.result.length !== undefined)
            return obj.result

        return []
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

    function activeValue(obj, fallback) {
        var value = firstDefined(
                    obj,
                    ["is_active", "isActive", "IsActive", "active", "Active"],
                    undefined
                    )

        if (value === undefined || value === null)
            return fallback

        return safeBool(value)
    }

    function clearMessages() {
        page.errorText = ""
        page.successText = ""
    }

    function formatTime(value) {
        var text = safeString(value)

        if (text.length >= 5)
            return text.substring(0, 5)

        return text
    }

    function dayName(day) {
        day = Number(day)

        if (day === 1)
            return "Понедельник"

        if (day === 2)
            return "Вторник"

        if (day === 3)
            return "Среда"

        if (day === 4)
            return "Четверг"

        if (day === 5)
            return "Пятница"

        if (day === 6)
            return "Суббота"

        if (day === 7)
            return "Воскресенье"

        return "День " + day
    }

    function weekName(weekType) {
        weekType = Number(weekType)

        if (weekType === 0)
            return "Каждая неделя"

        if (weekType === 1)
            return "Числитель"

        if (weekType === 2)
            return "Знаменатель"

        return "Неделя " + weekType
    }

    function openCreatePage() {
        page.clearMessages()
        page.createRequested()
    }

    function refresh() {
        page.loadSchedule()
    }

    function loadSchedule() {
        page.clearMessages()

        if (!Db.isConnect()) {
            page.loadingSchedule = false
            page.deleting = false
            page.errorText = "Нет соединения с сервером."
            Db.connectToServer()
            return
        }

        page.loadingSchedule = true
        loadTimeoutTimer.restart()

        Db.getTable("ScheduleView")
    }

    function normalizeScheduleItem(src) {
        var subject = safeString(firstDefined(src, [
            "subject_title",
            "subjectTitle",
            "SubjectTitle",
            "title",
            "Title",
            "subject",
            "Subject"
        ], ""))

        var shortSubject = safeString(firstDefined(src, [
            "subject_short_title",
            "subjectShortTitle",
            "SubjectShortTitle",
            "short_title",
            "shortTitle",
            "ShortTitle"
        ], ""))

        if (shortSubject.length > 0)
            subject = shortSubject

        var timeStart = formatTime(firstDefined(src, [
            "time_start",
            "timeStart",
            "TimeStart",
            "start_time",
            "StartTime"
        ], ""))

        var timeEnd = formatTime(firstDefined(src, [
            "time_end",
            "timeEnd",
            "TimeEnd",
            "end_time",
            "EndTime"
        ], ""))

        var timeText = ""

        if (timeStart.length > 0 && timeEnd.length > 0)
            timeText = timeStart + "–" + timeEnd

        var day = safeInt(firstDefined(src, [
            "day_of_week",
            "dayOfWeek",
            "DayOfWeek",
            "day",
            "Day"
        ], 0), 0)

        var weekType = safeInt(firstDefined(src, [
            "week_type",
            "weekType",
            "WeekType"
        ], 0), 0)

        return {
            idValue: safeInt(firstDefined(src, ["id", "Id", "ID", "idValue"], 0), 0),
            groupName: safeString(firstDefined(src, ["group_name", "GroupName", "groupName"], "")),
            subjectId: safeInt(firstDefined(src, ["subject_id", "subjectId", "SubjectId", "SubjectID"], 0), 0),
            subjectTitle: subject.length > 0 ? subject : "Предмет",
            teacherId: safeInt(firstDefined(src, ["teacher_id", "teacherId", "TeacherId", "TeacherID"], 0), 0),
            teacherUserId: safeInt(firstDefined(src, ["teacher_user_id", "teacherUserId", "TeacherUserId", "TeacherUserID"], 0), 0),
            teacherName: safeString(firstDefined(src, ["teacher_name", "teacherName", "TeacherName", "full_name", "fullName"], "")),
            dayOfWeek: day,
            dayText: dayName(day),
            weekType: weekType,
            weekText: weekName(weekType),
            lessonNumber: safeInt(firstDefined(src, ["lesson_number", "lessonNumber", "LessonNumber", "number", "Number"], 0), 0),
            timeText: timeText,
            cabinet: safeString(firstDefined(src, ["cabinet", "Cabinet", "room", "Room"], "")),
            subgroup: safeString(firstDefined(src, ["subgroup", "Subgroup"], "")),
            note: safeString(firstDefined(src, ["note", "Note", "comment", "Comment"], "")),
            isActive: activeValue(src, true)
        }
    }

    function fillSchedule(items) {
        scheduleModel.clear()

        for (var i = 0; i < items.length; i++)
            scheduleModel.append(normalizeScheduleItem(items[i]))

        page.rebuildGroupModel()
        page.rebuildScheduleFilter()

        page.loadingSchedule = false
        loadTimeoutTimer.stop()
    }

    function rebuildGroupModel() {
        var previousGroup = ""

        if (page.selectedGroupIndex >= 0 && page.selectedGroupIndex < groupModel.count)
            previousGroup = safeString(groupModel.get(page.selectedGroupIndex).groupName)

        var groups = []

        for (var i = 0; i < scheduleModel.count; i++) {
            var groupName = safeString(scheduleModel.get(i).groupName)

            if (groupName.length > 0 && groups.indexOf(groupName) < 0)
                groups.push(groupName)
        }

        groups.sort()

        groupModel.clear()

        groupModel.append({
            idValue: 0,
            title: "Все группы",
            groupName: ""
        })

        for (var j = 0; j < groups.length; j++) {
            groupModel.append({
                idValue: j + 1,
                title: groups[j],
                groupName: groups[j]
            })
        }

        page.selectedGroupIndex = 0

        if (previousGroup.length > 0) {
            for (var k = 0; k < groupModel.count; k++) {
                if (safeString(groupModel.get(k).groupName) === previousGroup) {
                    page.selectedGroupIndex = k
                    return
                }
            }
        }
    }

    function rebuildScheduleFilter() {
        filteredScheduleModel.clear()
        displayScheduleModel.clear()

        var groupName = ""
        var weekFilter = -1

        if (page.selectedGroupIndex >= 0 && page.selectedGroupIndex < groupModel.count)
            groupName = safeString(groupModel.get(page.selectedGroupIndex).groupName)

        if (page.selectedWeekFilterIndex >= 0 && page.selectedWeekFilterIndex < weekFilterModel.count)
            weekFilter = safeInt(weekFilterModel.get(page.selectedWeekFilterIndex).idValue, -1)

        var list = []

        for (var i = 0; i < scheduleModel.count; i++) {
            var item = scheduleModel.get(i)

            if (groupName.length > 0 && safeString(item.groupName) !== groupName)
                continue

            if (weekFilter >= 0 && Number(item.weekType) !== weekFilter)
                continue

            list.push({
                idValue: safeInt(item.idValue, 0),
                groupName: safeString(item.groupName),
                subjectId: safeInt(item.subjectId, 0),
                subjectTitle: safeString(item.subjectTitle),
                teacherId: safeInt(item.teacherId, 0),
                teacherUserId: safeInt(item.teacherUserId, 0),
                teacherName: safeString(item.teacherName),
                dayOfWeek: safeInt(item.dayOfWeek, 0),
                dayText: safeString(item.dayText),
                weekType: safeInt(item.weekType, 0),
                weekText: safeString(item.weekText),
                lessonNumber: safeInt(item.lessonNumber, 0),
                timeText: safeString(item.timeText),
                cabinet: safeString(item.cabinet),
                subgroup: safeString(item.subgroup),
                note: safeString(item.note),
                isActive: safeBool(item.isActive)
            })
        }

        list.sort(function(a, b) {
            if (a.groupName < b.groupName)
                return -1

            if (a.groupName > b.groupName)
                return 1

            if (a.dayOfWeek !== b.dayOfWeek)
                return a.dayOfWeek - b.dayOfWeek

            if (a.lessonNumber !== b.lessonNumber)
                return a.lessonNumber - b.lessonNumber

            return a.weekType - b.weekType
        })

        for (var n = 0; n < list.length; n++)
            filteredScheduleModel.append(list[n])

        var lastGroup = "__none__"
        var lastDay = -999

        for (var d = 0; d < list.length; d++) {
            var row = list[d]
            var currentGroup = row.groupName.length > 0 ? row.groupName : "Без группы"

            if (currentGroup !== lastGroup) {
                displayScheduleModel.append({
                    rowType: "group",
                    sourceIndex: -1,
                    title: currentGroup,
                    subtitle: groupRowsCount(list, row.groupName) + " строк",
                    idValue: -1,
                    groupName: row.groupName,
                    subjectId: 0,
                    subjectTitle: "",
                    teacherId: 0,
                    teacherUserId: 0,
                    teacherName: "",
                    dayOfWeek: 0,
                    dayText: "",
                    weekType: 0,
                    weekText: "",
                    lessonNumber: 0,
                    timeText: "",
                    cabinet: "",
                    subgroup: "",
                    note: "",
                    isActive: true
                })

                lastGroup = currentGroup
                lastDay = -999
            }

            if (row.dayOfWeek !== lastDay) {
                displayScheduleModel.append({
                    rowType: "day",
                    sourceIndex: -1,
                    title: row.dayText,
                    subtitle: dayRowsCount(list, row.groupName, row.dayOfWeek) + " пар",
                    idValue: -1,
                    groupName: row.groupName,
                    subjectId: 0,
                    subjectTitle: "",
                    teacherId: 0,
                    teacherUserId: 0,
                    teacherName: "",
                    dayOfWeek: row.dayOfWeek,
                    dayText: row.dayText,
                    weekType: 0,
                    weekText: "",
                    lessonNumber: 0,
                    timeText: "",
                    cabinet: "",
                    subgroup: "",
                    note: "",
                    isActive: true
                })

                lastDay = row.dayOfWeek
            }

            displayScheduleModel.append({
                rowType: "lesson",
                sourceIndex: d,
                title: "",
                subtitle: "",
                idValue: row.idValue,
                groupName: row.groupName,
                subjectId: row.subjectId,
                subjectTitle: row.subjectTitle,
                teacherId: row.teacherId,
                teacherUserId: row.teacherUserId,
                teacherName: row.teacherName,
                dayOfWeek: row.dayOfWeek,
                dayText: row.dayText,
                weekType: row.weekType,
                weekText: row.weekText,
                lessonNumber: row.lessonNumber,
                timeText: row.timeText,
                cabinet: row.cabinet,
                subgroup: row.subgroup,
                note: row.note,
                isActive: row.isActive
            })
        }
    }

    function groupRowsCount(list, groupName) {
        var count = 0

        for (var i = 0; i < list.length; i++) {
            if (safeString(list[i].groupName) === safeString(groupName))
                count++
        }

        return count
    }

    function dayRowsCount(list, groupName, dayOfWeek) {
        var count = 0

        for (var i = 0; i < list.length; i++) {
            if (safeString(list[i].groupName) === safeString(groupName)
                    && Number(list[i].dayOfWeek) === Number(dayOfWeek)) {
                count++
            }
        }

        return count
    }

    function schedulePayloadFromFilteredIndex(index) {
        if (index < 0 || index >= filteredScheduleModel.count)
            return ({})

        var item = filteredScheduleModel.get(index)

        return {
            id: safeInt(item.idValue, 0),
            idValue: safeInt(item.idValue, 0),
            groupName: safeString(item.groupName),
            group_name: safeString(item.groupName),
            subjectId: safeInt(item.subjectId, 0),
            subject_id: safeInt(item.subjectId, 0),
            subjectTitle: safeString(item.subjectTitle),
            teacherId: safeInt(item.teacherId, 0),
            teacher_id: safeInt(item.teacherId, 0),
            teacherUserId: safeInt(item.teacherUserId, 0),
            teacherName: safeString(item.teacherName),
            teacher_name: safeString(item.teacherName),
            dayOfWeek: safeInt(item.dayOfWeek, 0),
            day_of_week: safeInt(item.dayOfWeek, 0),
            weekType: safeInt(item.weekType, 0),
            week_type: safeInt(item.weekType, 0),
            lessonNumber: safeInt(item.lessonNumber, 0),
            lesson_number: safeInt(item.lessonNumber, 0),
            cabinet: safeString(item.cabinet),
            subgroup: safeString(item.subgroup),
            note: safeString(item.note),
            isActive: safeBool(item.isActive),
            is_active: safeBool(item.isActive) ? 1 : 0
        }
    }

    function requestEditFromFilteredIndex(index) {
        if (index < 0 || index >= filteredScheduleModel.count)
            return

        page.clearMessages()
        page.editRequested(page.schedulePayloadFromFilteredIndex(index))
    }

    function requestDeleteFromFilteredIndex(index) {
        if (index < 0 || index >= filteredScheduleModel.count)
            return

        var item = filteredScheduleModel.get(index)

        page.pendingDeleteId = safeInt(item.idValue, -1)
        page.pendingDeleteTitle =
                safeString(item.groupName) + " · " +
                safeString(item.subjectTitle) + " · " +
                safeString(item.dayText) + " · " +
                safeString(item.weekText)

        deleteDialog.open()
    }

    function confirmDelete() {
        if (page.pendingDeleteId <= 0)
            return

        if (!Db.isConnect()) {
            page.errorText = "Нет соединения с сервером."
            Db.connectToServer()
            return
        }

        page.clearMessages()
        page.deleting = true
        Db.deleteTableData("Schedule", page.pendingDeleteId)
    }

    Connections {
        target: Db
        ignoreUnknownSignals: true

        function onConnectedToServer() {
            if (scheduleModel.count === 0)
                page.loadSchedule()
        }

        function onDisconnectedFromServer() {
            loadTimeoutTimer.stop()
            page.loadingSchedule = false
            page.deleting = false
            page.errorText = "Соединение с сервером потеряно."
        }

        function onConnectionError(error) {
            loadTimeoutTimer.stop()
            page.loadingSchedule = false
            page.deleting = false
            page.errorText = error || "Ошибка подключения к серверу."
        }

        function onResponseReceived(obj) {
            if (!obj)
                return

            var cmd = page.responseCmd(obj)
            var tableName = page.normalizeTableName(
                        page.firstDefined(obj, ["table_name", "tableName", "table", "Table"], "")
                        )

            if (cmd === "get_table" && tableName === "ScheduleView") {
                if (obj.ok === false) {
                    page.loadingSchedule = false
                    loadTimeoutTimer.stop()
                    page.errorText = obj.error || "Не удалось загрузить расписание."
                    return
                }

                page.fillSchedule(page.extractArray(obj))
                return
            }

            if (cmd === "delete_table_data" && (tableName === "Schedule" || tableName.length === 0)) {
                page.deleting = false
                page.pendingDeleteId = -1
                page.pendingDeleteTitle = ""

                if (obj.ok === false) {
                    page.errorText = obj.error || "Не удалось удалить строку расписания."
                    return
                }

                page.successText = "Строка расписания удалена."
                page.loadSchedule()
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
        contentHeight: rootColumn.implicitHeight

        topPadding: page.contentTopInset + 18
        bottomPadding: page.contentBottomInset + 0

        background: Rectangle {
            color: page.bg
        }

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            id: rootColumn

            width: scrollView.availableWidth
            spacing: 16

            HeaderCard {
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
                visible: page.successText.length > 0
                text: page.successText
                danger: false

                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            FilterCard {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            ScheduleListCard {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }
        }
    }

    Item {
        id: fabWrapper

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        anchors.bottomMargin: 18 + page.contentBottomInset

        width: 64
        height: 64
        z: 200

        visible: !deleteDialog.visible

        Rectangle {
            id: fabBg

            anchors.fill: parent
            radius: 24

            color: page.loading
                   ? page.surface3
                   : fabArea.pressed
                     ? page.accentSoft
                     : page.surface

            border.width: 1
            border.color: page.loading ? page.border : page.accent

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: 19
                color: page.loading ? "transparent" : page.accent
                opacity: fabArea.pressed ? 0.72 : 1.0
            }

            DrawIcon {
                anchors.centerIn: parent
                width: 28
                height: 28
                name: "plus"
                iconColor: "#FFFFFF"
            }
        }

        MouseArea {
            id: fabArea

            anchors.fill: parent
            enabled: !page.loading
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                page.clearMessages()
                page.createRequested()
            }
        }
    }

    Dialog {
        id: deleteDialog

        modal: true
        dim: true
        title: ""
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

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

            Text {
                text: "Удалить строку расписания?"
                color: page.textMain
                font.pixelSize: 21
                font.bold: true

                Layout.fillWidth: true
            }

            Text {
                text: page.pendingDeleteTitle.length > 0
                      ? page.pendingDeleteTitle
                      : "Выбранная строка будет удалена."
                color: page.textMuted
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                lineHeight: 1.2

                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallButton {
                    text: "Отмена"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    onClicked: {
                        deleteDialog.close()
                    }
                }

                Button {
                    id: confirmDeleteButton

                    text: page.deleting ? "Удаление..." : "Удалить"
                    enabled: !page.deleting

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    background: Rectangle {
                        radius: 17
                        color: !confirmDeleteButton.enabled
                               ? page.surface3
                               : confirmDeleteButton.down
                                 ? "#E35A5A"
                                 : page.danger
                    }

                    contentItem: Text {
                        text: confirmDeleteButton.text
                        color: "#FFFFFF"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        deleteDialog.close()
                        page.confirmDelete()
                    }
                }
            }
        }
    }

    component HeaderCard: Rectangle {
        color: page.surface
        radius: 26
        border.width: 1
        border.color: page.border

        Layout.preferredHeight: headerRow.implicitHeight + 34

        RowLayout {
            id: headerRow

            anchors.fill: parent
            anchors.margins: 17
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
                    font.pixelSize: 29
                    font.bold: true
                    maximumLineCount: 1
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: page.loading
                          ? "Загрузка данных..."
                          : "По группам и дням недели"
                    color: page.textMuted
                    font.pixelSize: 14
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap

                    Layout.fillWidth: true
                }
            }

            BusyIndicator {
                running: page.loading
                visible: true
                opacity: running ? 1.0 : 0.0

                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
            }
        }
    }

    component FilterCard: Rectangle {
        color: page.surface2
        radius: 26
        border.width: 1
        border.color: "#284568"

        Layout.preferredHeight: filterColumn.implicitHeight + 34

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 5
            radius: 3
            color: page.accent
            opacity: 0.9
        }

        ColumnLayout {
            id: filterColumn

            anchors.fill: parent
            anchors.margins: 17
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 15
                    color: page.accentSoft
                    border.width: 1
                    border.color: "#284568"

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        name: "filter"
                        iconColor: page.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Фильтры просмотра"
                        color: page.textMain
                        font.pixelSize: 20
                        font.bold: true

                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Показано: " + filteredScheduleModel.count + " · Всего: " + scheduleModel.count
                        color: page.textMuted
                        font.pixelSize: 13

                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#284568"
                opacity: 0.8
            }

            FieldLabel {
                text: "Группа"
            }

            AppCombo {
                model: groupModel
                textRole: "title"
                emptyText: "Группы не найдены"
                enabled: groupModel.count > 0 && !page.loading
                currentIndex: page.selectedGroupIndex
                filterStyle: true

                onActivated: function(index) {
                    page.selectedGroupIndex = index
                    page.rebuildScheduleFilter()
                }
            }

            FieldLabel {
                text: "Тип недели"
            }

            AppCombo {
                model: weekFilterModel
                textRole: "title"
                emptyText: "Выберите неделю"
                enabled: !page.loading
                currentIndex: page.selectedWeekFilterIndex
                filterStyle: true

                onActivated: function(index) {
                    page.selectedWeekFilterIndex = index
                    page.rebuildScheduleFilter()
                }
            }
        }
    }

    component ScheduleListCard: Rectangle {
        color: page.surface
        radius: 26
        border.width: 1
        border.color: page.border

        Layout.preferredHeight: listColumn.implicitHeight + 34

        ColumnLayout {
            id: listColumn

            anchors.fill: parent
            anchors.margins: 17
            spacing: 13

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Данные расписания"
                        color: page.textMain
                        font.pixelSize: 20
                        font.bold: true

                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Группы → дни недели → пары"
                        color: page.textMuted
                        font.pixelSize: 13

                        Layout.fillWidth: true
                    }
                }
            }

            MessageRow {
                visible: page.loadingSchedule && displayScheduleModel.count === 0
                iconName: "clock"
                text: "Загружаю расписание..."
                iconColor: page.accent
                bgColor: page.accentSoft

                Layout.fillWidth: true
            }

            MessageRow {
                visible: !page.loadingSchedule && displayScheduleModel.count === 0
                iconName: "empty"
                text: "По выбранным фильтрам расписание не найдено."
                iconColor: page.textMuted
                bgColor: page.surface2

                Layout.fillWidth: true
            }

            Repeater {
                model: displayScheduleModel

                ScheduleDisplayDelegate {
                    rowType: model.rowType
                    sourceRowIndex: model.sourceIndex

                    title: model.title
                    subtitle: model.subtitle

                    idValue: model.idValue
                    dayText: model.dayText
                    weekText: model.weekText
                    timeText: model.timeText
                    subjectTitle: model.subjectTitle
                    groupName: model.groupName
                    teacherName: model.teacherName
                    cabinet: model.cabinet
                    subgroup: model.subgroup
                    note: model.note
                    isActive: model.isActive

                    Layout.fillWidth: true

                    onEditRequested: {
                        page.requestEditFromFilteredIndex(sourceRowIndex)
                    }

                    onDeleteRequested: {
                        page.requestDeleteFromFilteredIndex(sourceRowIndex)
                    }
                }
            }
        }
    }

    component ScheduleDisplayDelegate: Item {
        id: delegateRoot

        signal editRequested()
        signal deleteRequested()

        property string rowType: "lesson"
        property int sourceRowIndex: -1

        property string title: ""
        property string subtitle: ""

        property int idValue: -1
        property string dayText: ""
        property string weekText: ""
        property string timeText: ""
        property string subjectTitle: ""
        property string groupName: ""
        property string teacherName: ""
        property string cabinet: ""
        property string subgroup: ""
        property string note: ""
        property bool isActive: true

        Layout.preferredHeight: {
            if (delegateRoot.rowType === "group")
                return groupHeader.implicitHeight

            if (delegateRoot.rowType === "day")
                return dayHeader.implicitHeight

            return lessonRow.implicitHeight
        }

        Layout.fillWidth: true

        GroupHeaderRow {
            id: groupHeader

            visible: delegateRoot.rowType === "group"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            title: delegateRoot.title
            subtitle: delegateRoot.subtitle
        }

        DayHeaderRow {
            id: dayHeader

            visible: delegateRoot.rowType === "day"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            title: delegateRoot.title
            subtitle: delegateRoot.subtitle
        }

        ScheduleRow {
            id: lessonRow

            visible: delegateRoot.rowType === "lesson"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            idValue: delegateRoot.idValue
            dayText: delegateRoot.dayText
            weekText: delegateRoot.weekText
            timeText: delegateRoot.timeText
            subjectTitle: delegateRoot.subjectTitle
            groupName: delegateRoot.groupName
            teacherName: delegateRoot.teacherName
            cabinet: delegateRoot.cabinet
            subgroup: delegateRoot.subgroup
            note: delegateRoot.note
            isActive: delegateRoot.isActive

            onEditRequested: {
                delegateRoot.editRequested()
            }

            onDeleteRequested: {
                delegateRoot.deleteRequested()
            }
        }
    }

    component GroupHeaderRow: Rectangle {
        id: groupHeader

        property string title: ""
        property string subtitle: ""

        implicitHeight: groupHeaderContent.implicitHeight + 24
        height: implicitHeight

        radius: 22
        color: page.accentSoft
        border.width: 1
        border.color: "#284568"

        RowLayout {
            id: groupHeaderContent

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 15
                color: page.accent
                opacity: 0.95

                Text {
                    anchors.centerIn: parent
                    text: "Г"
                    color: "#FFFFFF"
                    font.pixelSize: 18
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: groupHeader.title.length > 0 ? groupHeader.title : "Без группы"
                    color: page.textMain
                    font.pixelSize: 20
                    font.bold: true
                    maximumLineCount: 1
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: groupHeader.subtitle
                    color: page.textSub
                    font.pixelSize: 12
                    font.bold: true

                    Layout.fillWidth: true
                }
            }
        }
    }

    component DayHeaderRow: Rectangle {
        id: dayHeader

        property string title: ""
        property string subtitle: ""

        implicitHeight: dayHeaderContent.implicitHeight + 18
        height: implicitHeight

        radius: 18
        color: "#172233"
        border.width: 1
        border.color: "#284568"

        RowLayout {
            id: dayHeaderContent

            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 9
            anchors.bottomMargin: 9
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 10
                Layout.preferredHeight: 10
                radius: 5
                color: page.accent
            }

            Text {
                text: dayHeader.title
                color: page.textMain
                font.pixelSize: 16
                font.bold: true
                maximumLineCount: 1
                elide: Text.ElideRight

                Layout.fillWidth: true
            }

            Text {
                text: dayHeader.subtitle
                color: page.textMuted
                font.pixelSize: 12
                font.bold: true
            }
        }
    }

    component ScheduleRow: Rectangle {
        id: row

        signal editRequested()
        signal deleteRequested()

        property int idValue: -1
        property string dayText: ""
        property string weekText: ""
        property string timeText: ""
        property string subjectTitle: ""
        property string groupName: ""
        property string teacherName: ""
        property string cabinet: ""
        property string subgroup: ""
        property string note: ""
        property bool isActive: true

        implicitHeight: rowContent.implicitHeight + 24
        height: implicitHeight

        radius: 22
        color: page.surface2
        border.width: 1
        border.color: page.border

        RowLayout {
            id: rowContent

            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 78
                Layout.preferredHeight: 62
                radius: 18
                color: row.isActive ? page.accentSoft : page.surface3
                border.width: 1
                border.color: row.isActive ? "#284568" : page.border

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        text: row.timeText.length > 0 ? row.timeText : "--:--"
                        color: row.isActive ? page.accent : page.textMuted
                        font.pixelSize: 11
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter

                        Layout.preferredWidth: 68
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: row.weekText
                        color: row.isActive ? page.success : page.textMuted
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        elide: Text.ElideRight

                        Layout.preferredWidth: 68
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: row.subjectTitle
                        color: page.textMain
                        font.pixelSize: 16
                        font.bold: true
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight

                        Layout.fillWidth: true
                    }

                    Rectangle {
                        radius: 10
                        color: page.accentSoft
                        border.width: 1
                        border.color: "#284568"

                        Layout.preferredHeight: 26
                        Layout.preferredWidth: groupText.implicitWidth + 18

                        Text {
                            id: groupText

                            anchors.centerIn: parent
                            text: row.groupName
                            color: page.accent
                            font.pixelSize: 12
                            font.bold: true
                            maximumLineCount: 1
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    text: row.isActive ? "активно" : "выключено"
                    color: page.textSub
                    font.pixelSize: 12
                    font.bold: true
                    maximumLineCount: 1
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: (row.teacherName.length > 0 ? row.teacherName : "Преподаватель не указан")
                          + (row.cabinet.length > 0 ? " · каб. " + row.cabinet : "")
                          + (row.subgroup.length > 0 ? " · " + row.subgroup : "")
                    color: page.textMuted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    visible: row.note.length > 0
                    text: row.note
                    color: page.textMuted
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SmallButton {
                        text: "Изменить"
                        enabled: !page.loading

                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        onClicked: {
                            row.editRequested()
                        }
                    }

                    SmallButton {
                        text: "Удалить"
                        enabled: !page.loading

                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        onClicked: {
                            row.deleteRequested()
                        }
                    }
                }
            }
        }
    }

    component MessageBox: Rectangle {
        id: box

        property string text: ""
        property bool danger: true

        color: box.danger ? page.dangerSoft : page.successSoft
        radius: 20
        border.width: 1
        border.color: box.danger ? "#5A2D31" : "#24513C"

        Layout.preferredHeight: messageRow.implicitHeight + 24

        RowLayout {
            id: messageRow

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 14
                color: box.danger ? "#4A2529" : "#123021"

                DrawIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    name: box.danger ? "warning" : "check"
                    iconColor: box.danger ? page.danger : page.success
                }
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

    component MessageRow: Rectangle {
        id: msg

        property string iconName: ""
        property string text: ""
        property color iconColor: page.accent
        property color bgColor: page.surface2

        radius: 20
        color: msg.bgColor
        border.width: 1
        border.color: page.border

        Layout.preferredHeight: msgLayout.implicitHeight + 24

        RowLayout {
            id: msgLayout

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 14
                color: Qt.rgba(msg.iconColor.r, msg.iconColor.g, msg.iconColor.b, 0.14)

                DrawIcon {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    name: msg.iconName
                    iconColor: msg.iconColor
                }
            }

            Text {
                text: msg.text
                color: page.textSub
                font.pixelSize: 14
                font.bold: true
                wrapMode: Text.WordWrap
                lineHeight: 1.15

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

    component AppCombo: ComboBox {
        id: combo

        property string emptyText: "Нет данных"
        property bool filterStyle: false

        function itemText(row) {
            if (row < 0 || row >= combo.count)
                return combo.emptyText

            if (combo.model && combo.model.get) {
                var item = combo.model.get(row)

                if (item && combo.textRole.length > 0) {
                    var byRole = page.safeString(item[combo.textRole])

                    if (byRole.length > 0)
                        return byRole
                }

                if (item && item.title !== undefined) {
                    var byTitle = page.safeString(item.title)

                    if (byTitle.length > 0)
                        return byTitle
                }
            }

            var byTextAt = page.safeString(combo.textAt(row))

            if (byTextAt.length > 0)
                return byTextAt

            return combo.emptyText
        }

        Layout.fillWidth: true
        Layout.preferredHeight: 52

        font.pixelSize: 15

        background: Rectangle {
            radius: 17

            color: combo.filterStyle
                   ? combo.activeFocus ? page.surface : "#172233"
                   : combo.activeFocus ? page.surface3 : page.surface2

            border.width: combo.activeFocus ? 2 : 1

            border.color: combo.filterStyle
                          ? combo.activeFocus ? page.accent : "#284568"
                          : combo.activeFocus ? page.accent : page.border

            opacity: combo.enabled ? 1.0 : 0.65
        }

        contentItem: Text {
            text: combo.itemText(combo.currentIndex)
            color: combo.enabled ? page.textMain : page.textMuted
            font.pixelSize: 15
            font.bold: true
            verticalAlignment: Text.AlignVCenter
            leftPadding: 16
            rightPadding: 44
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        indicator: DrawIcon {
            x: combo.width - width - 16
            y: combo.topPadding + (combo.availableHeight - height) / 2
            width: 20
            height: 20
            name: "chevronDown"
            iconColor: combo.enabled ? page.textMuted : page.surface3
        }

        popup: Popup {
            y: combo.height + 6
            width: combo.width
            implicitHeight: Math.min(contentItem.implicitHeight + 12, 280)
            padding: 6

            background: Rectangle {
                color: page.surface2
                radius: 18
                border.width: 1
                border.color: page.border
            }

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
                boundsBehavior: Flickable.StopAtBounds
            }
        }

        delegate: ItemDelegate {
            id: delegateItem

            width: combo.width - 12
            height: Math.max(44, delegateText.implicitHeight + 18)

            background: Rectangle {
                radius: 14
                color: delegateItem.highlighted ? page.surface3 : "transparent"
            }

            contentItem: Text {
                id: delegateText

                text: combo.itemText(index)
                color: page.textMain
                font.pixelSize: 15
                font.bold: combo.currentIndex === index
                verticalAlignment: Text.AlignVCenter
                leftPadding: 10
                rightPadding: 10
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
            }
        }
    }

    component SmallButton: Button {
        id: control

        background: Rectangle {
            radius: 16
            color: !control.enabled ? page.surface3 : control.down ? page.surface3 : page.surface2
            border.width: 1
            border.color: page.border
        }

        contentItem: Text {
            text: control.text
            color: control.enabled ? page.textMain : page.textMuted
            font.pixelSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
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
            var ox = (width - s) / 2
            var oy = (height - s) / 2

            ctx.strokeStyle = icon.iconColor
            ctx.fillStyle = icon.iconColor
            ctx.lineWidth = Math.max(1.8, s * 0.085)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            function px(v) {
                return ox + s * v
            }

            function py(v) {
                return oy + s * v
            }

            function roundedRectPath(l, t, w, h, r) {
                ctx.beginPath()
                ctx.moveTo(l + r, t)
                ctx.lineTo(l + w - r, t)
                ctx.quadraticCurveTo(l + w, t, l + w, t + r)
                ctx.lineTo(l + w, t + h - r)
                ctx.quadraticCurveTo(l + w, t + h, l + w - r, t + h)
                ctx.lineTo(l + r, t + h)
                ctx.quadraticCurveTo(l, t + h, l, t + h - r)
                ctx.lineTo(l, t + r)
                ctx.quadraticCurveTo(l, t, l + r, t)
                ctx.closePath()
            }

            if (icon.name === "calendar") {
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

                ctx.beginPath()
                ctx.arc(px(0.34), py(0.56), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.5), py(0.56), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.66), py(0.56), s * 0.025, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.name === "filter") {
                ctx.beginPath()
                ctx.moveTo(px(0.18), py(0.26))
                ctx.lineTo(px(0.82), py(0.26))
                ctx.lineTo(px(0.58), py(0.53))
                ctx.lineTo(px(0.58), py(0.78))
                ctx.lineTo(px(0.42), py(0.86))
                ctx.lineTo(px(0.42), py(0.53))
                ctx.closePath()
                ctx.stroke()
            } else if (icon.name === "plus") {
                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.24))
                ctx.lineTo(px(0.5), py(0.76))
                ctx.moveTo(px(0.24), py(0.5))
                ctx.lineTo(px(0.76), py(0.5))
                ctx.stroke()
            } else if (icon.name === "empty") {
                roundedRectPath(px(0.2), py(0.22), s * 0.6, s * 0.52, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.5))
                ctx.lineTo(px(0.66), py(0.5))
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
            } else if (icon.name === "check") {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.34, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.51))
                ctx.lineTo(px(0.46), py(0.63))
                ctx.lineTo(px(0.68), py(0.39))
                ctx.stroke()
            } else if (icon.name === "chevronDown") {
                ctx.beginPath()
                ctx.moveTo(px(0.28), py(0.38))
                ctx.lineTo(px(0.5), py(0.62))
                ctx.lineTo(px(0.72), py(0.38))
                ctx.stroke()
            } else {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.08, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }
}