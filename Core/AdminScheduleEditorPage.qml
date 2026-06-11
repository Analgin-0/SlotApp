import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Item {
    id: page

    signal backRequested()
    signal scheduleSaved()

    property int contentTopInset: 0
    property int contentBottomInset: 0

    property var scheduleItem: null

    property bool loadingGroups: false
    property bool loadingSubjects: false
    property bool loadingTeachers: false
    property bool loadingLessonTimes: false
    property bool saving: false
    property bool addingSubject: false

    property bool dataApplied: false
    property bool subjectFallbackSent: false

    property string errorText: ""
    property string successText: ""

    property int editingScheduleId: -1

    property string formGroupName: ""
    property string formCabinet: ""
    property string formSubgroup: ""
    property string formNote: ""
    property bool formIsActive: true

    property int selectedGroupIndex: -1
    property int selectedSubjectIndex: -1
    property int selectedLessonIndex: -1
    property int selectedDayIndex: 0
    property int selectedWeekIndex: 0

    property string teacherSearchText: ""
    property int selectedTeacherId: 0
    property string selectedTeacherTitle: "Без преподавателя"
    property string selectedTeacherCabinet: ""

    property string newGroupName: ""
    property string newSubjectTitle: ""
    property string newSubjectShortTitle: ""

    property string pendingSubjectSelectTitle: ""
    property string pendingSubjectSelectShortTitle: ""

    readonly property bool loading: loadingGroups || loadingSubjects || loadingTeachers || loadingLessonTimes || saving || addingSubject
    readonly property bool isEditMode: editingScheduleId > 0

    readonly property color bg: "#111111"
    readonly property color surface: "#1A1A1A"
    readonly property color surface2: "#222222"
    readonly property color surface3: "#333333"
    readonly property color border: "#555555"
    readonly property color textMain: "#FFFFFF"
    readonly property color textSub: "#DDDDDD"
    readonly property color textMuted: "#AAAAAA"
    readonly property color accent: "#DDDDDD"
    readonly property color accentSoft: "#222222"
    readonly property color danger: "#FFFFFF"
    readonly property color dangerSoft: "#333333"
    readonly property color success: "#FFFFFF"
    readonly property color successSoft: "#222222"

    ListModel { id: groupModel }
    ListModel { id: subjectModel }
    ListModel { id: teacherModel }
    ListModel { id: filteredTeacherModel }
    ListModel { id: lessonTimeModel }

    ListModel {
        id: scheduleConflictModel
    }

    ListModel {
        id: dayModel

        ListElement { idValue: 1; title: "Понедельник" }
        ListElement { idValue: 2; title: "Вторник" }
        ListElement { idValue: 3; title: "Среда" }
        ListElement { idValue: 4; title: "Четверг" }
        ListElement { idValue: 5; title: "Пятница" }
        ListElement { idValue: 6; title: "Суббота" }
        ListElement { idValue: 7; title: "Воскресенье" }
    }

    ListModel {
        id: weekModel

        ListElement { idValue: 0; title: "Каждая неделя" }
        ListElement { idValue: 1; title: "Неделя 1" }
        ListElement { idValue: 2; title: "Неделя 2" }
    }

    Component.onCompleted: {
        page.prepareFromScheduleItem()
        Qt.callLater(page.loadEditorData)
    }

    onScheduleItemChanged: {
        page.prepareFromScheduleItem()
        page.tryApplyScheduleItem()
    }

    Timer {
        id: loadTimeoutTimer
        interval: 9000
        repeat: false

        onTriggered: {
            if (!page.loadingGroups && !page.loadingSubjects && !page.loadingTeachers && !page.loadingLessonTimes)
                return

            var subjectsWereLoading = page.loadingSubjects

            if (page.loadingGroups)
                page.fillGroupsFromSchedule([])

            if (page.loadingTeachers)
                page.fillTeachers([])

            if (page.loadingLessonTimes)
                page.fillLessonTimes([])

            page.loadingGroups = false
            page.loadingSubjects = false
            page.loadingTeachers = false
            page.loadingLessonTimes = false
            page.saving = false

            if (subjectsWereLoading && subjectModel.count === 0)
                page.errorText = "Дисциплины не загрузились. Проверьте таблицу Subject/Subjects на сервере."

            page.finishLoadingIfReady()
        }
    }

    Timer {
        id: saveTimeoutTimer
        interval: 9000
        repeat: false

        onTriggered: {
            if (!page.saving)
                return

            page.saving = false

            if (page.errorText.length === 0)
                page.errorText = "Сервер не ответил на сохранение строки расписания. Проверьте таблицу Schedule."
        }
    }

    Timer {
        id: subjectAddTimeoutTimer
        interval: 9000
        repeat: false

        onTriggered: {
            if (!page.addingSubject)
                return

            page.addingSubject = false

            if (page.errorText.length === 0)
                page.errorText = "Сервер не ответил на добавление дисциплины. Проверьте таблицу Subject."
        }
    }

    function normalizeCommandName(value) {
        var text = safeString(value)

        if (text.length === 0)
            return ""

        return text
                .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
                .replace(/[\s-]+/g, "_")
                .toLowerCase()
    }

    function responseCmd(obj) {
        if (!obj)
            return ""

        var keys = ["command", "cmd", "action", "method", "operation", "type"]

        for (var i = 0; i < keys.length; i++) {
            var key = keys[i]

            if (obj[key] !== undefined && obj[key] !== null)
                return normalizeCommandName(obj[key])
        }

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

    function normalizeForCompare(value) {
        return safeString(value).toLowerCase().replace(/\s+/g, " ")
    }

    function normalizeCabinet(value) {
        return safeString(value).toLowerCase().replace(/\s+/g, "")
    }

    function hasBadLineChars(value) {
        var text = safeString(value)
        return text.indexOf("\n") >= 0 || text.indexOf("\r") >= 0 || text.indexOf("\t") >= 0
    }

    function normalizeTableName(value) {
        var text = safeString(value)
        var key = text.replace(/[\s_-]+/g, "").toLowerCase()

        if (key === "subject" || key === "subjects")
            return "Subject"

        if (key === "teacher" || key === "teachers")
            return "Teacher"

        if (key === "lessontime" || key === "lessontimes")
            return "LessonTime"

        if (key === "schedule" || key === "schedules")
            return "Schedule"

        if (key === "scheduleview")
            return "ScheduleView"

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
        var value = firstDefined(obj, ["is_active", "isActive", "IsActive", "active", "Active"], undefined)

        if (value === undefined || value === null)
            return fallback

        return safeBool(value)
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

    function formatTime(value) {
        var text = safeString(value)

        if (text.length >= 5)
            return text.substring(0, 5)

        return text
    }

    function clearMessages() {
        page.errorText = ""
        page.successText = ""
    }

    function finishLoadingIfReady() {
        if (!page.loadingGroups && !page.loadingSubjects && !page.loadingTeachers && !page.loadingLessonTimes)
            loadTimeoutTimer.stop()

        page.tryApplyScheduleItem()
    }

    function indexById(model, idValue) {
        idValue = Number(idValue)

        if (!model)
            return -1

        for (var i = 0; i < model.count; i++) {
            if (Number(model.get(i).idValue) === idValue)
                return i
        }

        return -1
    }

    function selectedModelId(model, index, fallback) {
        if (!model || index < 0 || index >= model.count)
            return fallback

        return safeInt(model.get(index).idValue, fallback)
    }

    function dayTitleById(dayId) {
        for (var i = 0; i < dayModel.count; i++) {
            if (safeInt(dayModel.get(i).idValue, 0) === safeInt(dayId, 0))
                return safeString(dayModel.get(i).title)
        }

        return "День " + dayId
    }

    function weekTitleById(weekId) {
        weekId = safeInt(weekId, 0)

        if (weekId === 0)
            return "Каждая неделя"

        if (weekId === 1)
            return "Неделя 1"

        if (weekId === 2)
            return "Неделя 2"

        return "Неделя " + weekId
    }

    function lessonTitleByNumber(lessonNumber) {
        lessonNumber = safeInt(lessonNumber, 0)

        for (var i = 0; i < lessonTimeModel.count; i++) {
            if (safeInt(lessonTimeModel.get(i).idValue, 0) === lessonNumber)
                return safeString(lessonTimeModel.get(i).title)
        }

        return lessonNumber + " пара"
    }

    function weeksOverlap(a, b) {
        a = safeInt(a, 0)
        b = safeInt(b, 0)

        if (a === 0 || b === 0)
            return true

        return a === b
    }

    function subgroupsOverlap(a, b) {
        a = normalizeForCompare(a)
        b = normalizeForCompare(b)

        if (a.length === 0 || b.length === 0)
            return true

        return a === b
    }

    function sameEditingRow(item) {
        if (!item)
            return false

        var rowId = safeInt(item.idValue, 0)

        return page.isEditMode && rowId > 0 && rowId === page.editingScheduleId
    }

    function scheduleConflictTitle(item) {
        if (!item)
            return ""

        return safeString(item.groupName)
                + " · " + dayTitleById(item.dayOfWeek)
                + " · " + weekTitleById(item.weekType)
                + " · " + lessonTitleByNumber(item.lessonNumber)
                + (safeString(item.subjectTitle).length > 0 ? " · " + safeString(item.subjectTitle) : "")
    }

    function findGroupTimeConflict(groupName, dayOfWeek, lessonNumber, weekType, subgroup) {
        var targetGroup = normalizeForCompare(groupName)

        for (var i = 0; i < scheduleConflictModel.count; i++) {
            var item = scheduleConflictModel.get(i)

            if (page.sameEditingRow(item))
                continue

            if (!safeBool(item.isActive))
                continue

            if (normalizeForCompare(item.groupName) !== targetGroup)
                continue

            if (safeInt(item.dayOfWeek, 0) !== dayOfWeek)
                continue

            if (safeInt(item.lessonNumber, 0) !== lessonNumber)
                continue

            if (!page.weeksOverlap(item.weekType, weekType))
                continue

            if (!page.subgroupsOverlap(item.subgroup, subgroup))
                continue

            return item
        }

        return null
    }

    function findTeacherTimeConflict(teacherId, dayOfWeek, lessonNumber, weekType) {
        teacherId = safeInt(teacherId, 0)

        if (teacherId <= 0)
            return null

        for (var i = 0; i < scheduleConflictModel.count; i++) {
            var item = scheduleConflictModel.get(i)

            if (page.sameEditingRow(item))
                continue

            if (!safeBool(item.isActive))
                continue

            if (safeInt(item.dayOfWeek, 0) !== dayOfWeek)
                continue

            if (safeInt(item.lessonNumber, 0) !== lessonNumber)
                continue

            if (!page.weeksOverlap(item.weekType, weekType))
                continue

            var rowTeacherId = safeInt(item.teacherId, 0)
            var rowTeacherUserId = safeInt(item.teacherUserId, 0)

            if (rowTeacherId === teacherId || rowTeacherUserId === teacherId)
                return item
        }

        return null
    }

    function findCabinetTimeConflict(cabinet, dayOfWeek, lessonNumber, weekType) {
        var targetCabinet = normalizeCabinet(cabinet)

        if (targetCabinet.length === 0)
            return null

        for (var i = 0; i < scheduleConflictModel.count; i++) {
            var item = scheduleConflictModel.get(i)

            if (page.sameEditingRow(item))
                continue

            if (!safeBool(item.isActive))
                continue

            if (normalizeCabinet(item.cabinet) !== targetCabinet)
                continue

            if (safeInt(item.dayOfWeek, 0) !== dayOfWeek)
                continue

            if (safeInt(item.lessonNumber, 0) !== lessonNumber)
                continue

            if (!page.weeksOverlap(item.weekType, weekType))
                continue

            return item
        }

        return null
    }

    function scheduleValidationError(groupName, cabinet, subgroup, note, subjectId, dayOfWeek, weekType, lessonNumber) {
        groupName = safeString(groupName)
        cabinet = safeString(cabinet)
        subgroup = safeString(subgroup)
        note = safeString(note)

        if (groupName.length === 0)
            return "Выберите или добавьте группу."

        if (groupName.length > 40)
            return "Название группы слишком длинное. Максимум 40 символов."

        if (hasBadLineChars(groupName))
            return "Название группы должно быть в одну строку."

        if (subjectId <= 0)
            return "Выберите дисциплину."

        if (dayOfWeek < 1 || dayOfWeek > 7)
            return "Выберите корректный день недели."

        if (lessonNumber <= 0)
            return "Выберите корректную пару."

        if (weekType < 0 || weekType > 2)
            return "Выберите корректную неделю."

        if (cabinet.length > 30)
            return "Кабинет слишком длинный. Максимум 30 символов."

        if (hasBadLineChars(cabinet))
            return "Кабинет должен быть в одну строку."

        if (subgroup.length > 20)
            return "Подгруппа слишком длинная. Максимум 20 символов."

        if (hasBadLineChars(subgroup))
            return "Подгруппа должна быть в одну строку."

        if (note.length > 400)
            return "Примечание слишком длинное. Максимум 400 символов."

        if (page.formIsActive) {
            var groupConflict = page.findGroupTimeConflict(groupName, dayOfWeek, lessonNumber, weekType, subgroup)

            if (groupConflict !== null) {
                return "Конфликт расписания: у этой группы уже есть пара на это время: "
                        + page.scheduleConflictTitle(groupConflict)
            }

            var teacherConflict = page.findTeacherTimeConflict(page.selectedTeacherId, dayOfWeek, lessonNumber, weekType)

            if (teacherConflict !== null) {
                return "Конфликт преподавателя: выбранный преподаватель уже занят в это время: "
                        + page.scheduleConflictTitle(teacherConflict)
            }

            var cabinetConflict = page.findCabinetTimeConflict(cabinet, dayOfWeek, lessonNumber, weekType)

            if (cabinetConflict !== null) {
                return "Конфликт кабинета: этот кабинет уже занят в это время: "
                        + page.scheduleConflictTitle(cabinetConflict)
            }
        }

        return ""
    }

    function indexGroupByName(groupName) {
        groupName = safeString(groupName)

        if (groupName.length === 0)
            return -1

        var target = normalizeForCompare(groupName)

        for (var i = 0; i < groupModel.count; i++) {
            if (normalizeForCompare(groupModel.get(i).groupName) === target)
                return i
        }

        return -1
    }

    function selectGroupByIndex(index) {
        if (index < 0 || index >= groupModel.count)
            return

        page.selectedGroupIndex = index
        page.formGroupName = safeString(groupModel.get(index).groupName)
        page.clearMessages()
    }

    function groupExists(groupName) {
        return indexGroupByName(groupName) >= 0
    }

    function setGroupList(groups) {
        var selectedName = page.formGroupName

        groupModel.clear()

        groups.sort()

        for (var i = 0; i < groups.length; i++) {
            var name = safeString(groups[i])

            if (name.length === 0)
                continue

            if (indexGroupByName(name) >= 0)
                continue

            groupModel.append({
                idValue: i + 1,
                title: name,
                groupName: name
            })
        }

        page.selectedGroupIndex = indexGroupByName(selectedName)

        if (page.selectedGroupIndex < 0 && groupModel.count > 0 && selectedName.length === 0)
            page.selectedGroupIndex = 0

        if (page.selectedGroupIndex >= 0 && page.selectedGroupIndex < groupModel.count)
            page.formGroupName = safeString(groupModel.get(page.selectedGroupIndex).groupName)
    }

    function addLocalGroup(groupName) {
        groupName = safeString(groupName)

        if (groupName.length === 0)
            return

        var groups = []

        for (var i = 0; i < groupModel.count; i++) {
            var oldName = safeString(groupModel.get(i).groupName)

            if (oldName.length > 0 && groups.indexOf(oldName) < 0)
                groups.push(oldName)
        }

        if (groups.indexOf(groupName) < 0)
            groups.push(groupName)

        page.formGroupName = groupName
        page.setGroupList(groups)
        page.selectedGroupIndex = page.indexGroupByName(groupName)
    }

    function openAddGroupDialog() {
        page.newGroupName = page.formGroupName
        page.clearMessages()
        addGroupDialog.open()
    }

    function confirmAddGroup() {
        var name = safeString(page.newGroupName)

        if (name.length === 0) {
            page.errorText = "Введите название группы."
            return
        }

        if (name.length > 40) {
            page.errorText = "Название группы слишком длинное. Максимум 40 символов."
            return
        }

        if (hasBadLineChars(name)) {
            page.errorText = "Название группы должно быть в одну строку."
            return
        }

        if (page.groupExists(name)) {
            page.errorText = "Такая группа уже есть в списке."
            return
        }

        page.addLocalGroup(name)
        page.successText = "Группа добавлена в список. Она сохранится в расписании после создания строки."
        addGroupDialog.close()
    }

    function subjectExists(title, shortTitle) {
        var targetTitle = normalizeForCompare(title)
        var targetShort = normalizeForCompare(shortTitle)

        for (var i = 0; i < subjectModel.count; i++) {
            var item = subjectModel.get(i)
            var realTitle = normalizeForCompare(item.realTitle)
            var comboTitle = normalizeForCompare(item.title)
            var itemShort = normalizeForCompare(item.shortTitle)

            if (targetTitle.length > 0 && (realTitle === targetTitle || comboTitle === targetTitle))
                return true

            if (targetShort.length > 0 && itemShort === targetShort)
                return true
        }

        return false
    }

    function openAddSubjectDialog() {
        page.newSubjectTitle = ""
        page.newSubjectShortTitle = ""
        page.clearMessages()
        addSubjectDialog.open()
    }

    function confirmAddSubject() {
        var title = safeString(page.newSubjectTitle)
        var shortTitle = safeString(page.newSubjectShortTitle)

        if (title.length === 0) {
            page.errorText = "Введите название дисциплины."
            return
        }

        if (title.length > 100) {
            page.errorText = "Название дисциплины слишком длинное. Максимум 100 символов."
            return
        }

        if (shortTitle.length > 30) {
            page.errorText = "Короткое название слишком длинное. Максимум 30 символов."
            return
        }

        if (hasBadLineChars(title) || hasBadLineChars(shortTitle)) {
            page.errorText = "Название дисциплины должно быть в одну строку."
            return
        }

        if (page.subjectExists(title, shortTitle)) {
            page.errorText = "Такая дисциплина уже есть в списке."
            return
        }

        if (!Db.isConnect()) {
            page.errorText = "Нет соединения с сервером."
            Db.connectToServer()
            return
        }

        page.clearMessages()

        page.pendingSubjectSelectTitle = title
        page.pendingSubjectSelectShortTitle = shortTitle
        page.addingSubject = true
        subjectAddTimeoutTimer.restart()

        Db.addTableData("Subject", {
            title: title,
            Title: title,
            short_title: shortTitle,
            ShortTitle: shortTitle,
            is_active: 1,
            IsActive: 1
        })
    }

    function reloadSubjectsOnly() {
        if (!Db.isConnect())
            return

        page.loadingSubjects = true
        loadTimeoutTimer.restart()

        Db.getTable("Subject")
        Db.getTable("Subjects")
    }

    function loadEditorData() {
        page.clearMessages()

        if (!Db.isConnect()) {
            page.loadingGroups = false
            page.loadingSubjects = false
            page.loadingTeachers = false
            page.loadingLessonTimes = false
            page.saving = false

            page.errorText = "Нет соединения с сервером."
            Db.connectToServer()
            return
        }

        page.subjectFallbackSent = false

        page.loadingGroups = true
        page.loadingSubjects = true
        page.loadingTeachers = true
        page.loadingLessonTimes = true

        loadTimeoutTimer.restart()

        Db.getTable("ScheduleView")
        Db.getTable("Subject")
        Db.getTable("Subjects")
        Db.getTable("Teacher")
        Db.getTable("Teachers")
        Db.getTable("LessonTime")
        Db.getTable("LessonTimes")
    }

    function prepareFromScheduleItem() {
        page.dataApplied = false

        var item = page.scheduleItem

        if (!item) {
            page.editingScheduleId = -1
            page.formGroupName = ""
            page.formCabinet = ""
            page.formSubgroup = ""
            page.formNote = ""
            page.formIsActive = true
            page.selectedDayIndex = 0
            page.selectedWeekIndex = 0
            page.selectedGroupIndex = groupModel.count > 0 ? 0 : -1
            page.selectedSubjectIndex = subjectModel.count > 0 ? 0 : -1
            page.selectedLessonIndex = lessonTimeModel.count > 0 ? 0 : -1
            page.selectedTeacherId = 0
            page.selectedTeacherTitle = "Без преподавателя"
            page.selectedTeacherCabinet = ""

            if (page.selectedGroupIndex >= 0 && page.selectedGroupIndex < groupModel.count)
                page.formGroupName = safeString(groupModel.get(page.selectedGroupIndex).groupName)

            return
        }

        page.editingScheduleId = safeInt(firstDefined(item, ["idValue", "id", "Id", "ID"], -1), -1)
        page.formGroupName = safeString(firstDefined(item, ["groupName", "group_name", "GroupName"], ""))
        page.formCabinet = safeString(firstDefined(item, ["cabinet", "Cabinet", "room", "Room"], ""))
        page.formSubgroup = safeString(firstDefined(item, ["subgroup", "Subgroup"], ""))
        page.formNote = safeString(firstDefined(item, ["note", "Note", "comment", "Comment"], ""))
        page.formIsActive = activeValue(item, true)

        page.selectedDayIndex = indexById(dayModel, safeInt(firstDefined(item, ["dayOfWeek", "day_of_week", "DayOfWeek", "day", "Day"], 1), 1))
        if (page.selectedDayIndex < 0)
            page.selectedDayIndex = 0

        page.selectedWeekIndex = indexById(weekModel, safeInt(firstDefined(item, ["weekType", "week_type", "WeekType"], 0), 0))
        if (page.selectedWeekIndex < 0)
            page.selectedWeekIndex = 0

        page.selectedGroupIndex = indexGroupByName(page.formGroupName)

        if (page.formGroupName.length > 0 && page.selectedGroupIndex < 0)
            page.addLocalGroup(page.formGroupName)

        page.selectedTeacherId = safeInt(firstDefined(item, [
            "teacherId", "teacher_id", "TeacherId", "TeacherID",
            "teacherUserId", "teacher_user_id", "TeacherUserId", "TeacherUserID"
        ], 0), 0)
        page.selectedTeacherTitle = safeString(firstDefined(item, ["teacherName", "teacher_name", "TeacherName", "full_name", "fullName"], ""))

        if (page.selectedTeacherId <= 0) {
            page.selectedTeacherTitle = "Без преподавателя"
            page.selectedTeacherCabinet = ""
        } else if (page.selectedTeacherTitle.length === 0) {
            page.selectedTeacherTitle = "Преподаватель #" + page.selectedTeacherId
        }

        page.selectedTeacherCabinet = safeString(firstDefined(item, ["teacherCabinet", "teacher_cabinet", "TeacherCabinet", "cabinet", "Cabinet"], ""))
    }

    function tryApplyScheduleItem() {
        if (page.dataApplied)
            return

        if (page.loadingGroups || page.loadingSubjects || page.loadingTeachers || page.loadingLessonTimes)
            return

        var item = page.scheduleItem

        if (!item) {
            if (page.selectedGroupIndex < 0 && groupModel.count > 0) {
                page.selectedGroupIndex = 0
                page.formGroupName = safeString(groupModel.get(0).groupName)
            }

            if (page.selectedSubjectIndex < 0 && subjectModel.count > 0)
                page.selectedSubjectIndex = 0

            if (page.selectedLessonIndex < 0 && lessonTimeModel.count > 0)
                page.selectedLessonIndex = 0

            page.dataApplied = true
            return
        }

        page.selectedGroupIndex = indexGroupByName(page.formGroupName)

        if (page.formGroupName.length > 0 && page.selectedGroupIndex < 0) {
            page.addLocalGroup(page.formGroupName)
            page.selectedGroupIndex = indexGroupByName(page.formGroupName)
        }

        page.selectedSubjectIndex = indexById(subjectModel, safeInt(firstDefined(item, ["subjectId", "subject_id", "SubjectId", "SubjectID"], 0), 0))
        if (page.selectedSubjectIndex < 0 && subjectModel.count > 0)
            page.selectedSubjectIndex = 0

        page.selectedLessonIndex = indexById(lessonTimeModel, safeInt(firstDefined(item, ["lessonNumber", "lesson_number", "LessonNumber", "number", "Number"], 0), 0))
        if (page.selectedLessonIndex < 0 && lessonTimeModel.count > 0)
            page.selectedLessonIndex = 0

        page.selectTeacherById(
            safeInt(firstDefined(item, [
                "teacherId", "teacher_id", "TeacherId", "TeacherID",
                "teacherUserId", "teacher_user_id", "TeacherUserId", "TeacherUserID"
            ], 0), 0),
            safeString(firstDefined(item, ["teacherName", "teacher_name", "TeacherName", "full_name", "fullName"], "")),
            safeString(firstDefined(item, ["teacherCabinet", "teacher_cabinet", "TeacherCabinet", "cabinet", "Cabinet"], ""))
        )

        page.dataApplied = true
    }

    function normalizeScheduleConflictItem(src) {
        var subject = safeString(firstDefined(src, [
            "subject_short_title", "subjectShortTitle", "SubjectShortTitle",
            "subject_title", "subjectTitle", "SubjectTitle",
            "title", "Title", "subject", "Subject"
        ], ""))

        return {
            idValue: safeInt(firstDefined(src, ["id", "Id", "ID", "idValue"], 0), 0),
            groupName: safeString(firstDefined(src, ["group_name", "GroupName", "groupName"], "")),
            subjectTitle: subject.length > 0 ? subject : "Предмет",
            teacherId: safeInt(firstDefined(src, ["teacher_id", "teacherId", "TeacherId", "TeacherID"], 0), 0),
            teacherUserId: safeInt(firstDefined(src, ["teacher_user_id", "teacherUserId", "TeacherUserId", "TeacherUserID"], 0), 0),
            dayOfWeek: safeInt(firstDefined(src, ["day_of_week", "dayOfWeek", "DayOfWeek", "day", "Day"], 0), 0),
            weekType: safeInt(firstDefined(src, ["week_type", "weekType", "WeekType"], 0), 0),
            lessonNumber: safeInt(firstDefined(src, ["lesson_number", "lessonNumber", "LessonNumber", "number", "Number"], 0), 0),
            cabinet: safeString(firstDefined(src, ["cabinet", "Cabinet", "room", "Room"], "")),
            subgroup: safeString(firstDefined(src, ["subgroup", "Subgroup"], "")),
            isActive: activeValue(src, true)
        }
    }

    function fillGroupsFromSchedule(items) {
        var groups = []
        scheduleConflictModel.clear()

        for (var i = 0; i < items.length; i++) {
            var src = items[i]
            var groupName = safeString(firstDefined(src, ["group_name", "GroupName", "groupName"], ""))

            if (groupName.length > 0 && groups.indexOf(groupName) < 0)
                groups.push(groupName)

            scheduleConflictModel.append(page.normalizeScheduleConflictItem(src))
        }

        if (page.formGroupName.length > 0 && groups.indexOf(page.formGroupName) < 0)
            groups.push(page.formGroupName)

        page.setGroupList(groups)

        page.loadingGroups = false
        page.finishLoadingIfReady()
    }

    function fillSubjects(items) {
        subjectModel.clear()

        for (var i = 0; i < items.length; i++) {
            var src = items[i]

            var idValue = safeInt(firstDefined(src, ["id", "Id", "ID", "idValue"], 0), 0)
            var title = safeString(firstDefined(src, ["title", "Title", "name", "Name", "subject_title", "SubjectTitle"], ""))
            var shortTitle = safeString(firstDefined(src, ["short_title", "shortTitle", "ShortTitle"], ""))
            var active = activeValue(src, true)

            if (idValue <= 0 || title.length === 0)
                continue

            if (!active)
                continue

            subjectModel.append({
                idValue: idValue,
                title: shortTitle.length > 0 ? shortTitle + " · " + title : title,
                realTitle: title,
                shortTitle: shortTitle
            })
        }

        if (page.pendingSubjectSelectTitle.length > 0) {
            var foundIndex = -1

            for (var s = 0; s < subjectModel.count; s++) {
                var item = subjectModel.get(s)
                var realTitle = safeString(item.realTitle)
                var comboTitle = safeString(item.title)

                if (realTitle === page.pendingSubjectSelectTitle || comboTitle.indexOf(page.pendingSubjectSelectTitle) >= 0) {
                    foundIndex = s
                    break
                }
            }

            if (foundIndex >= 0) {
                page.selectedSubjectIndex = foundIndex
                page.pendingSubjectSelectTitle = ""
                page.pendingSubjectSelectShortTitle = ""
            }
        }

        if (page.selectedSubjectIndex < 0 && subjectModel.count > 0)
            page.selectedSubjectIndex = 0

        page.loadingSubjects = false
        page.finishLoadingIfReady()
    }

    function fillTeachers(items) {
        teacherModel.clear()

        teacherModel.append({
            idValue: 0,
            title: "Без преподавателя",
            cabinet: "",
            searchText: "без преподавателя"
        })

        for (var i = 0; i < items.length; i++) {
            var src = items[i]

            var idValue = safeInt(firstDefined(src, [
                "id", "Id", "ID", "idValue",
                "teacher_id", "TeacherId", "TeacherID",
                "user_id", "userId", "UserId", "UserID",
                "teacher_user_id", "teacherUserId", "TeacherUserId", "TeacherUserID"
            ], 0), 0)
            var lastName = safeString(firstDefined(src, ["LastName", "last_name", "lastName", "surname", "Surname"], ""))
            var firstName = safeString(firstDefined(src, ["Name", "name", "firstName", "first_name", "FirstName"], ""))
            var middleName = safeString(firstDefined(src, ["MiddleName", "middle_name", "middleName", "patronymic", "Patronymic"], ""))

            var fullName = safeString(firstDefined(src, [
                "fullName", "full_name",
                "teacher_name", "teacherName", "TeacherName",
                "fio", "Fio", "FIO"
            ], ""))

            if (fullName.length === 0)
                fullName = safeString((lastName + " " + firstName + " " + middleName).trim())

            var cabinet = safeString(firstDefined(src, ["Cabinet", "cabinet", "room", "Room"], ""))
            var department = safeString(firstDefined(src, ["Department", "department", "department_name", "DepartmentName"], ""))

            if (idValue <= 0)
                continue

            if (fullName.length === 0)
                fullName = "Преподаватель #" + idValue

            var title = department.length > 0 ? fullName + " · " + department : fullName
            var searchText = (title + " " + cabinet + " " + department + " " + idValue).toLowerCase()

            teacherModel.append({
                idValue: idValue,
                title: title,
                cabinet: cabinet,
                searchText: searchText
            })
        }

        page.rebuildTeacherFilter()

        page.loadingTeachers = false
        page.finishLoadingIfReady()
    }

    function fillLessonTimes(items) {
        lessonTimeModel.clear()

        for (var i = 0; i < items.length; i++) {
            var src = items[i]

            var lessonNumber = safeInt(firstDefined(src, ["lesson_number", "lessonNumber", "LessonNumber", "number", "Number", "id", "Id"], 0), 0)
            var start = formatTime(firstDefined(src, ["time_start", "timeStart", "TimeStart", "start_time", "StartTime"], ""))
            var end = formatTime(firstDefined(src, ["time_end", "timeEnd", "TimeEnd", "end_time", "EndTime"], ""))

            if (lessonNumber <= 0)
                continue

            lessonTimeModel.append({
                idValue: lessonNumber,
                title: start.length > 0 && end.length > 0
                       ? lessonNumber + " пара · " + start + "–" + end
                       : lessonNumber + " пара",
                timeText: start.length > 0 && end.length > 0 ? start + "–" + end : ""
            })
        }

        if (lessonTimeModel.count === 0) {
            lessonTimeModel.append({ idValue: 1, title: "1 пара", timeText: "" })
            lessonTimeModel.append({ idValue: 2, title: "2 пара", timeText: "" })
            lessonTimeModel.append({ idValue: 3, title: "3 пара", timeText: "" })
            lessonTimeModel.append({ idValue: 4, title: "4 пара", timeText: "" })
            lessonTimeModel.append({ idValue: 5, title: "5 пара", timeText: "" })
            lessonTimeModel.append({ idValue: 6, title: "6 пара", timeText: "" })
        }

        if (page.selectedLessonIndex < 0 && lessonTimeModel.count > 0)
            page.selectedLessonIndex = 0

        page.loadingLessonTimes = false
        page.finishLoadingIfReady()
    }

    function rebuildTeacherFilter() {
        filteredTeacherModel.clear()

        var query = page.teacherSearchText.trim().toLowerCase()

        for (var i = 0; i < teacherModel.count; i++) {
            var item = teacherModel.get(i)
            var idValue = safeInt(item.idValue, 0)

            if (idValue <= 0)
                continue

            var source = safeString(item.searchText)

            if (query.length === 0 || source.indexOf(query) >= 0) {
                filteredTeacherModel.append({
                    idValue: idValue,
                    title: safeString(item.title),
                    cabinet: safeString(item.cabinet)
                })
            }
        }
    }

    function selectNoTeacher() {
        page.selectedTeacherId = 0
        page.selectedTeacherTitle = "Без преподавателя"
        page.selectedTeacherCabinet = ""
        page.clearMessages()
    }

    function selectTeacher(idValue, title, cabinet) {
        page.selectedTeacherId = safeInt(idValue, 0)
        page.selectedTeacherTitle = safeString(title)
        page.selectedTeacherCabinet = safeString(cabinet)

        if (page.selectedTeacherId <= 0) {
            page.selectNoTeacher()
            return
        }

        if (page.selectedTeacherTitle.length === 0)
            page.selectedTeacherTitle = "Преподаватель #" + page.selectedTeacherId

        if (page.selectedTeacherCabinet.length > 0 && page.formCabinet.trim().length === 0)
            page.formCabinet = page.selectedTeacherCabinet

        page.clearMessages()
    }

    function selectTeacherById(idValue, fallbackName, fallbackCabinet) {
        idValue = safeInt(idValue, 0)

        if (idValue <= 0) {
            page.selectNoTeacher()
            return
        }

        for (var i = 0; i < teacherModel.count; i++) {
            var item = teacherModel.get(i)

            if (safeInt(item.idValue, 0) === idValue) {
                page.selectTeacher(idValue, safeString(item.title), safeString(item.cabinet))
                return
            }
        }

        page.selectTeacher(
            idValue,
            safeString(fallbackName).length > 0 ? fallbackName : "Преподаватель #" + idValue,
            fallbackCabinet
        )
    }

    function resetForm() {
        page.formCabinet = ""
        page.formSubgroup = ""
        page.formNote = ""
        page.formIsActive = true

        page.selectedGroupIndex = groupModel.count > 0 ? 0 : -1
        page.formGroupName = page.selectedGroupIndex >= 0 ? safeString(groupModel.get(page.selectedGroupIndex).groupName) : ""

        page.selectedSubjectIndex = subjectModel.count > 0 ? 0 : -1
        page.selectedLessonIndex = lessonTimeModel.count > 0 ? 0 : -1
        page.selectedDayIndex = 0
        page.selectedWeekIndex = 0

        page.teacherSearchText = ""
        page.selectNoTeacher()
        page.rebuildTeacherFilter()

        page.clearMessages()
    }

    function saveSchedule() {
        page.clearMessages()

        if (!Db.isConnect()) {
            page.errorText = "Нет соединения с сервером."
            Db.connectToServer()
            return
        }

        if (page.formGroupName.length === 0 && page.selectedGroupIndex >= 0 && page.selectedGroupIndex < groupModel.count)
            page.formGroupName = safeString(groupModel.get(page.selectedGroupIndex).groupName)

        var groupName = safeString(page.formGroupName)
        var cabinet = safeString(page.formCabinet)
        var subgroup = safeString(page.formSubgroup)
        var note = safeString(page.formNote)

        if (subjectModel.count === 0) {
            page.errorText = "Нет доступных дисциплин."
            return
        }

        if (lessonTimeModel.count === 0) {
            page.errorText = "Нет доступных пар."
            return
        }

        if (page.selectedSubjectIndex < 0 && subjectModel.count > 0)
            page.selectedSubjectIndex = 0

        if (page.selectedLessonIndex < 0 && lessonTimeModel.count > 0)
            page.selectedLessonIndex = 0

        var subjectId = selectedModelId(subjectModel, page.selectedSubjectIndex, 0)
        var dayOfWeek = selectedModelId(dayModel, page.selectedDayIndex, 1)
        var weekType = selectedModelId(weekModel, page.selectedWeekIndex, 0)
        var lessonNumber = selectedModelId(lessonTimeModel, page.selectedLessonIndex, 1)

        var validationError = page.scheduleValidationError(
                    groupName,
                    cabinet,
                    subgroup,
                    note,
                    subjectId,
                    dayOfWeek,
                    weekType,
                    lessonNumber
                    )

        if (validationError.length > 0) {
            page.errorText = validationError
            return
        }

        var data = {
            group_name: groupName,
            subject_id: subjectId,
            teacher_id: page.selectedTeacherId > 0 ? page.selectedTeacherId : null,
            day_of_week: dayOfWeek,
            week_type: weekType,
            lesson_number: lessonNumber,
            cabinet: cabinet,
            subgroup: subgroup,
            note: note,
            is_active: page.formIsActive ? 1 : 0
        }

        page.saving = true
        saveTimeoutTimer.restart()

        if (page.isEditMode)
            Db.updateTableData("Schedule", page.editingScheduleId, data)
        else
            Db.addTableData("Schedule", data)
    }

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
            event.accepted = true
            page.backRequested()
        }
    }

    Connections {
        target: Db
        ignoreUnknownSignals: true

        function onConnectedToServer() {
            if (groupModel.count === 0 || subjectModel.count === 0 || teacherModel.count === 0 || lessonTimeModel.count === 0)
                page.loadEditorData()
        }

        function onDisconnectedFromServer() {
            loadTimeoutTimer.stop()
            saveTimeoutTimer.stop()
            subjectAddTimeoutTimer.stop()

            page.loadingGroups = false
            page.loadingSubjects = false
            page.loadingTeachers = false
            page.loadingLessonTimes = false
            page.saving = false
            page.addingSubject = false

            page.errorText = "Соединение с сервером потеряно."
        }

        function onConnectionError(error) {
            loadTimeoutTimer.stop()
            saveTimeoutTimer.stop()
            subjectAddTimeoutTimer.stop()

            page.loadingGroups = false
            page.loadingSubjects = false
            page.loadingTeachers = false
            page.loadingLessonTimes = false
            page.saving = false
            page.addingSubject = false

            page.errorText = error || "Ошибка подключения к серверу."
        }

        function onResponseReceived(obj) {
            if (!obj)
                return

            var cmd = page.responseCmd(obj)
            var tableName = page.normalizeTableName(page.firstDefined(obj, ["table_name", "tableName", "table", "Table"], ""))

            if (cmd === "get_table") {
                if (obj.ok === false) {
                    if (tableName === "ScheduleView") {
                        if (groupModel.count === 0)
                            page.fillGroupsFromSchedule([])
                        return
                    }

                    if (tableName === "Teacher") {
                        if (teacherModel.count === 0)
                            page.fillTeachers([])
                        return
                    }

                    if (tableName === "LessonTime") {
                        if (lessonTimeModel.count === 0)
                            page.fillLessonTimes([])
                        return
                    }

                    if (tableName === "Subject")
                        return

                    return
                }

                if (tableName === "ScheduleView") {
                    page.fillGroupsFromSchedule(page.extractArray(obj))
                    return
                }

                if (tableName === "Subject") {
                    var subjectItems = page.extractArray(obj)

                    if (!page.loadingSubjects && subjectModel.count > 0 && subjectItems.length === 0)
                        return

                    page.fillSubjects(subjectItems)
                    return
                }

                if (tableName === "Teacher") {
                    var teacherItems = page.extractArray(obj)

                    if (!page.loadingTeachers && teacherModel.count > 1 && teacherItems.length === 0)
                        return

                    page.fillTeachers(teacherItems)
                    return
                }

                if (tableName === "LessonTime") {
                    var lessonItems = page.extractArray(obj)

                    if (!page.loadingLessonTimes && lessonTimeModel.count > 0 && lessonItems.length === 0)
                        return

                    page.fillLessonTimes(lessonItems)
                    return
                }
            }

            if ((cmd === "add_table_data" || cmd === "insert_table_data" || cmd === "create_table_data")
                    && (tableName === "Subject" || (page.addingSubject && tableName.length === 0))) {
                page.addingSubject = false
                subjectAddTimeoutTimer.stop()

                if (obj.ok === false) {
                    page.errorText = obj.error || "Не удалось добавить дисциплину."
                    return
                }

                page.successText = "Дисциплина добавлена."
                addSubjectDialog.close()
                page.reloadSubjectsOnly()
                return
            }

            if ((cmd === "add_table_data" || cmd === "insert_table_data" || cmd === "create_table_data")
                    && (tableName === "Schedule" || tableName.length === 0)) {
                page.saving = false
                saveTimeoutTimer.stop()

                if (obj.ok === false) {
                    page.errorText = obj.error || "Не удалось создать строку расписания."
                    return
                }

                page.successText = "Строка расписания успешно создана."
                page.scheduleSaved()
                return
            }

            if ((cmd === "update_table_data" || cmd === "edit_table_data")
                    && (tableName === "Schedule" || tableName.length === 0)) {
                page.saving = false
                saveTimeoutTimer.stop()

                if (obj.ok === false) {
                    page.errorText = obj.error || "Не удалось изменить строку расписания."
                    return
                }

                page.successText = "Строка расписания успешно обновлена."
                page.scheduleSaved()
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
        bottomPadding: page.contentBottomInset + 24

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

            FormCard {
                Layout.fillWidth: true
                Layout.leftMargin: 20
                Layout.rightMargin: 20
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
            }
        }
    }

    Dialog {
        id: addGroupDialog

        modal: true
        dim: true
        title: ""
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        width: Math.min(page.width - 40, 390)
        anchors.centerIn: parent

        background: Rectangle {
            color: page.surface
            radius: 0
            border.width: 1
            border.color: page.border
        }

        contentItem: ColumnLayout {
            spacing: 14

            Text {
                text: "Добавить группу"
                color: page.textMain
                font.pixelSize: 21
                font.bold: true

                Layout.fillWidth: true
            }

            Text {
                text: "Группа добавляется в список выбора. В базе она появится вместе с новой строкой расписания."
                color: page.textMuted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                lineHeight: 1.15

                Layout.fillWidth: true
            }

            AppField {
                text: page.newGroupName
                placeholderText: "Например: ИС-21"

                onTextChanged: {
                    if (page.newGroupName !== text)
                        page.newGroupName = text
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallButton {
                    text: "Отмена"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    onClicked: {
                        addGroupDialog.close()
                    }
                }

                Button {
                    id: confirmAddGroupButton

                    text: "Добавить"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    background: Rectangle {
                        radius: 0
                        color: confirmAddGroupButton.down ? "#AAAAAA" : "#FFFFFF"
                    }

                    contentItem: Text {
                        text: confirmAddGroupButton.text
                        color: "#000000"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        page.confirmAddGroup()
                    }
                }
            }
        }
    }

    Dialog {
        id: addSubjectDialog

        modal: true
        dim: true
        title: ""
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        width: Math.min(page.width - 40, 420)
        anchors.centerIn: parent

        background: Rectangle {
            color: page.surface
            radius: 0
            border.width: 1
            border.color: page.border
        }

        contentItem: ColumnLayout {
            spacing: 14

            Text {
                text: "Добавить дисциплину"
                color: page.textMain
                font.pixelSize: 21
                font.bold: true

                Layout.fillWidth: true
            }

            Text {
                text: "Дисциплина сохранится в таблицу Subject и после ответа сервера появится в списке."
                color: page.textMuted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                lineHeight: 1.15

                Layout.fillWidth: true
            }

            FieldLabel {
                text: "Название"
            }

            AppField {
                text: page.newSubjectTitle
                placeholderText: "Например: Математика"
                enabled: !page.addingSubject

                onTextChanged: {
                    if (page.newSubjectTitle !== text)
                        page.newSubjectTitle = text
                }
            }

            FieldLabel {
                text: "Короткое название"
            }

            AppField {
                text: page.newSubjectShortTitle
                placeholderText: "Необязательно"
                enabled: !page.addingSubject

                onTextChanged: {
                    if (page.newSubjectShortTitle !== text)
                        page.newSubjectShortTitle = text
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallButton {
                    text: "Отмена"
                    enabled: !page.addingSubject

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    onClicked: {
                        addSubjectDialog.close()
                    }
                }

                Button {
                    id: confirmAddSubjectButton

                    text: page.addingSubject ? "Добавление..." : "Добавить"
                    enabled: !page.addingSubject

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    background: Rectangle {
                        radius: 0
                        color: !confirmAddSubjectButton.enabled
                               ? page.surface3
                               : confirmAddSubjectButton.down
                                 ? "#AAAAAA"
                                 : "#FFFFFF"
                    }

                    contentItem: Text {
                        text: confirmAddSubjectButton.text
                        color: "#000000"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        page.confirmAddSubject()
                    }
                }
            }
        }
    }

    component HeaderCard: Rectangle {
        color: page.surface
        radius: 0
        border.width: 1
        border.color: page.border

        Layout.preferredHeight: headerRow.implicitHeight + 34

        RowLayout {
            id: headerRow

            anchors.fill: parent
            anchors.margins: 17
            spacing: 12

            IconButton {
                iconName: "back"
                enabled: !page.saving && !page.addingSubject

                Layout.preferredWidth: 48
                Layout.preferredHeight: 48

                onClicked: {
                    page.backRequested()
                }
            }

            Rectangle {
                Layout.preferredWidth: 58
                Layout.preferredHeight: 58
                radius: 0
                color: page.surface3
                border.width: 1
                border.color: page.border

                DrawIcon {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    name: "calendar"
                    iconColor: page.textMain
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: page.isEditMode ? "Редактирование" : "Новое расписание"
                    color: page.textMain
                    font.pixelSize: 25
                    font.bold: true
                    maximumLineCount: 1
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: page.loading
                          ? "Загрузка данных..."
                          : page.isEditMode
                            ? "Изменение строки расписания"
                            : "Создание строки расписания"
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

    component FormCard: Rectangle {
        color: page.surface
        radius: 0
        border.width: 1
        border.color: page.border

        Layout.preferredHeight: formColumn.implicitHeight + 34

        ColumnLayout {
            id: formColumn

            anchors.fill: parent
            anchors.margins: 17
            spacing: 12

            Text {
                text: page.isEditMode ? "Данные строки" : "Данные новой строки"
                color: page.textMain
                font.pixelSize: 20
                font.bold: true

                Layout.fillWidth: true
            }

            Text {
                text: "Заполните группу, дисциплину, преподавателя, день, пару и неделю. Перед сохранением проверяются конфликты."
                color: page.textMuted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                lineHeight: 1.15

                Layout.fillWidth: true
            }

            FieldLabel {
                text: "Группа"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                AppCombo {
                    model: groupModel
                    textRole: "title"
                    emptyText: page.loadingGroups ? "Загрузка групп..." : "Нет групп"
                    enabled: groupModel.count > 0 && !page.saving && !page.addingSubject
                    currentIndex: page.selectedGroupIndex

                    Layout.fillWidth: true

                    onActivated: function(index) {
                        page.selectGroupByIndex(index)
                    }
                }

                SmallButton {
                    text: "+"
                    enabled: !page.saving && !page.addingSubject

                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52

                    onClicked: {
                        page.openAddGroupDialog()
                    }
                }
            }

            FieldLabel {
                text: "Дисциплина"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                AppCombo {
                    model: subjectModel
                    textRole: "title"
                    emptyText: page.loadingSubjects ? "Загрузка дисциплин..." : "Нет дисциплин"
                    enabled: subjectModel.count > 0 && !page.saving && !page.addingSubject
                    currentIndex: page.selectedSubjectIndex

                    Layout.fillWidth: true

                    onActivated: function(index) {
                        page.selectedSubjectIndex = index
                        page.clearMessages()
                    }
                }

                SmallButton {
                    text: "+"
                    enabled: !page.saving && !page.addingSubject

                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52

                    onClicked: {
                        page.openAddSubjectDialog()
                    }
                }
            }

            FieldLabel {
                text: "Преподаватель"
            }

            SelectedTeacherBox {
                title: page.selectedTeacherTitle
                cabinet: page.selectedTeacherCabinet

                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                AppField {
                    text: page.teacherSearchText
                    placeholderText: "ФИО, кафедра или кабинет"
                    enabled: !page.saving && !page.addingSubject

                    Layout.fillWidth: true

                    onTextChanged: {
                        if (page.teacherSearchText !== text) {
                            page.teacherSearchText = text
                            page.rebuildTeacherFilter()
                        }

                        page.clearMessages()
                    }
                }

                SmallButton {
                    text: "×"
                    enabled: page.teacherSearchText.length > 0 && !page.saving && !page.addingSubject

                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 52

                    onClicked: {
                        page.teacherSearchText = ""
                        page.rebuildTeacherFilter()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SmallButton {
                    text: "Без преподавателя"
                    enabled: !page.saving && !page.addingSubject

                    Layout.fillWidth: true
                    Layout.preferredHeight: 44

                    onClicked: {
                        page.selectNoTeacher()
                    }
                }

                SmallButton {
                    text: "Очистить поиск"
                    enabled: page.teacherSearchText.length > 0 && !page.saving && !page.addingSubject

                    Layout.fillWidth: true
                    Layout.preferredHeight: 44

                    onClicked: {
                        page.teacherSearchText = ""
                        page.rebuildTeacherFilter()
                    }
                }
            }

            ScrollView {
                id: teacherScrollView

                visible: !page.loadingTeachers

                Layout.fillWidth: true
                Layout.preferredHeight: filteredTeacherModel.count <= 0
                                        ? 58
                                        : Math.min(filteredTeacherModel.count * 72, 300)

                clip: true
                contentWidth: availableWidth

                background: Rectangle {
                    color: "transparent"
                }

                ScrollBar.vertical.policy: filteredTeacherModel.count > 4 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: teacherScrollView.availableWidth
                    spacing: 8

                    Repeater {
                        model: filteredTeacherModel

                        TeacherOptionCard {
                            title: model.title
                            cabinet: model.cabinet
                            selected: page.selectedTeacherId === model.idValue

                            Layout.fillWidth: true

                            onClicked: {
                                page.selectTeacher(model.idValue, model.title, model.cabinet)
                            }
                        }
                    }

                    Text {
                        visible: filteredTeacherModel.count === 0
                        text: page.teacherSearchText.length > 0 ? "Преподаватель не найден" : "Преподаватели не загружены"
                        color: page.textMuted
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.WordWrap

                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                    }
                }
            }

            MessageRow {
                visible: page.loadingTeachers
                iconName: "clock"
                text: "Загружаю преподавателей..."
                iconColor: page.textMuted
                bgColor: page.surface2

                Layout.fillWidth: true
            }

            FieldLabel {
                text: "День недели"
            }

            AppCombo {
                model: dayModel
                textRole: "title"
                emptyText: "Выберите день"
                enabled: !page.saving && !page.addingSubject
                currentIndex: page.selectedDayIndex

                onActivated: function(index) {
                    page.selectedDayIndex = index
                    page.clearMessages()
                }
            }

            FieldLabel {
                text: "Пара"
            }

            AppCombo {
                model: lessonTimeModel
                textRole: "title"
                emptyText: page.loadingLessonTimes ? "Загрузка пар..." : "Нет пар"
                enabled: lessonTimeModel.count > 0 && !page.saving && !page.addingSubject
                currentIndex: page.selectedLessonIndex

                onActivated: function(index) {
                    page.selectedLessonIndex = index
                    page.clearMessages()
                }
            }

            FieldLabel {
                text: "Неделя"
            }

            AppCombo {
                model: weekModel
                textRole: "title"
                emptyText: "Выберите неделю"
                enabled: !page.saving && !page.addingSubject
                currentIndex: page.selectedWeekIndex

                onActivated: function(index) {
                    page.selectedWeekIndex = index
                    page.clearMessages()
                }
            }

            FieldLabel {
                text: "Кабинет"
            }

            AppField {
                text: page.formCabinet
                placeholderText: "Например: 301"
                enabled: !page.saving && !page.addingSubject

                onTextChanged: {
                    if (page.formCabinet !== text)
                        page.formCabinet = text

                    page.clearMessages()
                }
            }

            FieldLabel {
                text: "Подгруппа"
            }

            AppField {
                text: page.formSubgroup
                placeholderText: "Необязательно"
                enabled: !page.saving && !page.addingSubject

                onTextChanged: {
                    if (page.formSubgroup !== text)
                        page.formSubgroup = text

                    page.clearMessages()
                }
            }

            FieldLabel {
                text: "Примечание"
            }

            AppArea {
                text: page.formNote
                placeholderText: "Необязательно"
                enabled: !page.saving && !page.addingSubject

                onTextChanged: {
                    if (page.formNote !== text)
                        page.formNote = text

                    page.clearMessages()
                }
            }

            Rectangle {
                color: page.surface2
                radius: 0
                border.width: 1
                border.color: page.border

                Layout.fillWidth: true
                Layout.preferredHeight: activeRowLayout.implicitHeight + 24

                RowLayout {
                    id: activeRowLayout

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: "Показывать в расписании"
                            color: page.textSub
                            font.pixelSize: 14
                            font.bold: true

                            Layout.fillWidth: true
                        }

                        Text {
                            text: "Если выключить — строка останется в базе, но будет считаться скрытой."
                            color: page.textMuted
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap

                            Layout.fillWidth: true
                        }
                    }

                    Switch {
                        checked: page.formIsActive
                        enabled: !page.saving && !page.addingSubject

                        onCheckedChanged: {
                            if (page.formIsActive !== checked)
                                page.formIsActive = checked
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallButton {
                    text: page.isEditMode ? "Сбросить" : "Очистить"
                    enabled: !page.saving && !page.addingSubject

                    Layout.fillWidth: true
                    Layout.preferredHeight: 50

                    onClicked: {
                        if (page.isEditMode) {
                            page.prepareFromScheduleItem()
                            page.dataApplied = false
                            page.tryApplyScheduleItem()
                            page.clearMessages()
                        } else {
                            page.resetForm()
                        }
                    }
                }

                Button {
                    id: saveButton

                    text: page.saving
                          ? "Сохранение..."
                          : page.isEditMode
                            ? "Сохранить"
                            : "Создать"
                    enabled: !page.saving && !page.addingSubject && !page.loadingSubjects && !page.loadingLessonTimes

                    Layout.fillWidth: true
                    Layout.preferredHeight: 50

                    background: Rectangle {
                        radius: 0
                        color: !saveButton.enabled
                               ? page.surface3
                               : saveButton.down
                                 ? "#AAAAAA"
                                 : "#FFFFFF"
                    }

                    contentItem: Text {
                        text: saveButton.text
                        color: "#000000"
                        font.pixelSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        page.saveSchedule()
                    }
                }
            }
        }
    }

    component SelectedTeacherBox: Rectangle {
        id: box

        property string title: ""
        property string cabinet: ""

        radius: 0
        color: page.surface3
        border.width: 1
        border.color: page.border

        Layout.preferredHeight: content.implicitHeight + 24

        RowLayout {
            id: content

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 0
                color: "#FFFFFF"

                DrawIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    name: box.title === "Без преподавателя" ? "user" : "check"
                    iconColor: "#000000"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Выбран преподаватель"
                    color: page.textSub
                    font.pixelSize: 12
                    font.bold: true

                    Layout.fillWidth: true
                }

                Text {
                    text: box.title.length > 0 ? box.title : "Без преподавателя"
                    color: page.textMain
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    visible: box.cabinet.length > 0
                    text: "каб. " + box.cabinet
                    color: page.textSub
                    font.pixelSize: 12

                    Layout.fillWidth: true
                }
            }
        }
    }

    component TeacherOptionCard: Rectangle {
        id: card

        signal clicked()

        property string title: ""
        property string cabinet: ""
        property bool selected: false

        radius: 0
        color: selected ? page.surface3 : page.surface2
        border.width: selected ? 2 : 1
        border.color: selected ? "#FFFFFF" : page.border

        Layout.preferredHeight: rowContent.implicitHeight + 22

        RowLayout {
            id: rowContent

            anchors.fill: parent
            anchors.margins: 11
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 0
                color: card.selected ? "#FFFFFF" : page.surface3
                border.width: 1
                border.color: card.selected ? "#DDDDDD" : page.border

                DrawIcon {
                    anchors.centerIn: parent
                    width: 19
                    height: 19
                    name: card.selected ? "check" : "user"
                    iconColor: card.selected ? "#000000" : page.textMuted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: card.title
                    color: page.textMain
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    visible: card.cabinet.length > 0
                    text: "каб. " + card.cabinet
                    color: page.textMuted
                    font.pixelSize: 12

                    Layout.fillWidth: true
                }
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                card.clicked()
            }
        }
    }

    component MessageBox: Rectangle {
        id: box

        property string text: ""
        property bool danger: true

        color: box.danger ? "#333333" : "#222222"
        radius: 0
        border.width: 1
        border.color: box.danger ? "#555555" : "#555555"

        Layout.preferredHeight: messageRow.implicitHeight + 24

        RowLayout {
            id: messageRow

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 0
                color: box.danger ? "#222222" : "#111111"

                DrawIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    name: box.danger ? "warning" : "check"
                    iconColor: "#FFFFFF"
                }
            }

            Text {
                text: box.text
                color: "#FFFFFF"
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
        property color iconColor: page.textMuted
        property color bgColor: page.surface2

        radius: 0
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
                radius: 0
                color: "#222222"

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

    component AppField: TextField {
        id: control

        Layout.fillWidth: true
        Layout.preferredHeight: 52

        color: page.textMain
        placeholderTextColor: page.textMuted
        selectionColor: "#AAAAAA"
        selectedTextColor: "#000000"

        font.pixelSize: 15
        leftPadding: 16
        rightPadding: 16

        background: Rectangle {
            radius: 0
            color: control.activeFocus ? page.surface3 : page.surface2
            border.width: control.activeFocus ? 2 : 1
            border.color: control.activeFocus ? "#FFFFFF" : page.border
        }

        cursorDelegate: Rectangle {
            width: 2
            color: "#FFFFFF"
        }
    }

    component AppArea: TextArea {
        id: control

        Layout.fillWidth: true
        Layout.preferredHeight: 92

        color: page.textMain
        placeholderTextColor: page.textMuted
        selectionColor: "#AAAAAA"
        selectedTextColor: "#000000"

        font.pixelSize: 15
        leftPadding: 16
        rightPadding: 16
        topPadding: 14
        bottomPadding: 14
        wrapMode: TextArea.Wrap

        background: Rectangle {
            radius: 0
            color: control.activeFocus ? page.surface3 : page.surface2
            border.width: control.activeFocus ? 2 : 1
            border.color: control.activeFocus ? "#FFFFFF" : page.border
        }
    }

    component AppCombo: ComboBox {
        id: combo

        property string emptyText: "Нет данных"

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
            radius: 0
            color: combo.activeFocus ? page.surface3 : page.surface2
            border.width: combo.activeFocus ? 2 : 1
            border.color: combo.activeFocus ? "#FFFFFF" : page.border
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
                radius: 0
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
                radius: 0
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
            radius: 0
            color: !control.enabled ? page.surface3 : control.down ? page.surface3 : page.surface2
            border.width: 1
            border.color: page.border
        }

        contentItem: Text {
            text: control.text
            color: control.enabled ? page.textMain : page.textMuted
            font.pixelSize: control.text === "+" ? 22 : 13
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    component IconButton: Button {
        id: button

        property string iconName: ""

        background: Rectangle {
            radius: 0
            color: button.down ? page.surface3 : page.surface2
            border.width: 1
            border.color: page.border
        }

        contentItem: DrawIcon {
            name: button.iconName
            iconColor: button.enabled ? page.textMain : page.textMuted
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

            if (icon.name === "back") {
                ctx.beginPath()
                ctx.moveTo(px(0.62), py(0.24))
                ctx.lineTo(px(0.36), py(0.5))
                ctx.lineTo(px(0.62), py(0.76))
                ctx.stroke()
            } else if (icon.name === "calendar") {

                var calLeft = px(0.14)
                var calTop = py(0.22)
                var calW = s * 0.72
                var calH = s * 0.62
                ctx.strokeRect(calLeft, calTop, calW, calH)

                ctx.beginPath()
                ctx.moveTo(px(0.14), py(0.4))
                ctx.lineTo(px(0.86), py(0.4))
                ctx.moveTo(px(0.32), py(0.14))
                ctx.lineTo(px(0.32), py(0.28))
                ctx.moveTo(px(0.68), py(0.14))
                ctx.lineTo(px(0.68), py(0.28))
                ctx.stroke()


                var dotSize = s * 0.05
                ctx.fillRect(px(0.34) - dotSize / 2, py(0.56) - dotSize / 2, dotSize, dotSize)
                ctx.fillRect(px(0.5) - dotSize / 2, py(0.56) - dotSize / 2, dotSize, dotSize)
                ctx.fillRect(px(0.66) - dotSize / 2, py(0.56) - dotSize / 2, dotSize, dotSize)
            } else if (icon.name === "clock") {

                var clockSize = s * 0.68
                ctx.strokeRect(px(0.5) - clockSize / 2, py(0.5) - clockSize / 2, clockSize, clockSize)

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


                var wDotSize = s * 0.05
                ctx.fillRect(px(0.5) - wDotSize / 2, py(0.69) - wDotSize / 2, wDotSize, wDotSize)
            } else if (icon.name === "check") {

                var checkSize = s * 0.68
                ctx.strokeRect(px(0.5) - checkSize / 2, py(0.5) - checkSize / 2, checkSize, checkSize)

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.51))
                ctx.lineTo(px(0.46), py(0.63))
                ctx.lineTo(px(0.68), py(0.39))
                ctx.stroke()
            } else if (icon.name === "user") {

                var headSize = s * 0.32
                ctx.strokeRect(px(0.5) - headSize / 2, py(0.33) - headSize / 2, headSize, headSize)


                ctx.beginPath()
                ctx.moveTo(px(0.22), py(0.82))
                ctx.lineTo(px(0.22), py(0.58))
                ctx.lineTo(px(0.78), py(0.58))
                ctx.lineTo(px(0.78), py(0.82))
                ctx.stroke()
            } else if (icon.name === "chevronDown") {
                ctx.beginPath()
                ctx.moveTo(px(0.28), py(0.38))
                ctx.lineTo(px(0.5), py(0.62))
                ctx.lineTo(px(0.72), py(0.38))
                ctx.stroke()
            } else {

                var fallbackSize = s * 0.16
                ctx.fillRect(px(0.5) - fallbackSize / 2, py(0.5) - fallbackSize / 2, fallbackSize, fallbackSize)
            }
        }
    }
}