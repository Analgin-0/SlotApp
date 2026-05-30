import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Item {
    id: page

    signal backRequested()
    signal taskCreated(var task)

    property bool active: visible
    property bool teachersLoaded: false
    property bool teachersLoading: false
    property bool teachersRequestPending: false

    property int contentTopInset: 0
    property int contentBottomInset: 0
    property int viewerRole: 1

    readonly property int desktopBreakpoint: 900
    readonly property bool desktopMode: page.width >= page.desktopBreakpoint
    readonly property int contentMaxWidth: 980
    readonly property int pageSideMargin: page.desktopMode ? 24 : 16
    readonly property bool compactMode: page.width < 430

    property Item lastFocusedField: null

    property date selectedDate: new Date()
    property int selectedHour: 10
    property int selectedMinute: 0
    property int selectedDuration: 30

    property int selectedTeacherId: -1
    property string selectedTeacherFullName: ""
    property string selectedTeacherDepartment: ""
    property string selectedTeacherCabinet: ""

    property string titleError: ""
    property string teacherError: ""
    property string studentError: ""
    property string durationError: ""

    property var selectedTopics: ["Другое"]
    property var teacherItems: []

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

    focus: true

    Keys.onReleased: function(event) {
        if (event.key === Qt.Key_Back || event.key === Qt.Key_Escape) {
            event.accepted = true
            page.hideKeyboardAndTakeFocus()
            page.backRequested()
        }
    }

    Component.onCompleted: {
        if (page.active) {
            page.forceActiveFocus()
            page.loadTeachers()
        }
    }

    onActiveChanged: {
        if (page.active) {
            page.forceActiveFocus()
            page.loadTeachers()
        }
    }

    function safeText(value) {
        if (value === undefined || value === null)
            return ""

        var text = String(value).trim()
        var lower = text.toLowerCase()

        if (lower === "null" || lower === "undefined")
            return ""

        return text
    }

    function hideKeyboardAndTakeFocus() {
        page.forceActiveFocus()
        Qt.inputMethod.hide()
    }

    function requestEnsureVisible(item) {
        if (!item)
            return

        page.lastFocusedField = item

        Qt.callLater(function() {
            if (page.lastFocusedField === item)
                page.ensureVisible(item)
        })

        ensureVisibleTimer.restart()
    }

    function ensureVisible(item) {
        if (!item || !scrollView || !scrollView.contentItem)
            return

        if (!item.visible)
            return

        var flick = scrollView.contentItem
        var pos = item.mapToItem(formColumn, 0, 0)

        var itemTop = pos.y
        var itemBottom = itemTop + item.height

        var visibleTop = flick.contentY
        var visibleBottom = flick.contentY + flick.height

        var topGap = page.desktopMode ? 18 : 14
        var bottomGap = page.desktopMode ? 26 : 34

        var targetY = flick.contentY

        if (itemTop < visibleTop + topGap)
            targetY = Math.max(0, itemTop - topGap)
        else if (itemBottom > visibleBottom - bottomGap)
            targetY = Math.max(0, itemBottom + bottomGap - flick.height)

        var maxY = Math.max(0, flick.contentHeight - flick.height)
        targetY = Math.min(targetY, maxY)

        if (Math.abs(targetY - flick.contentY) < 1)
            return

        scrollToAnimation.stop()
        scrollToAnimation.target = flick
        scrollToAnimation.to = targetY
        scrollToAnimation.start()
    }

    function loadTeachers() {
        if (!page.active)
            return

        if (page.teachersLoaded || page.teachersLoading)
            return

        page.teacherError = ""
        page.teachersLoading = true
        page.teachersRequestPending = true

        if (Db.isConnect()) {
            Db.getTeachers()
            return
        }

        Db.connectToServer()
    }

    function handleTeachersResponse(obj) {
        var items = []

        if (obj && obj.MyTable) {
            for (var i = 0; i < obj.MyTable.length; i++) {
                var src = obj.MyTable[i]

                var idValue = Number(src.idValue || src.id || 0)
                var fullName = safeText(src.fullName || src.full_name || src.teacher_name || src.TeacherName || "")
                var department = safeText(src.department || src.Department || "")
                var cabinet = safeText(src.cabinet || src.Cabinet || "")

                if (idValue <= 0)
                    continue

                items.push({
                    idValue: idValue,
                    fullName: fullName.length > 0 ? fullName : "Преподаватель #" + idValue,
                    department: department,
                    cabinet: cabinet
                })
            }
        }

        page.teacherItems = items
        page.teachersLoaded = true
        page.teachersLoading = false
        page.teachersRequestPending = false
        page.rebuildTeacherFilter()
    }

    Connections {
        target: Db

        function onConnectedToServer() {
            if (page.active && page.teachersRequestPending && !page.teachersLoaded)
                Db.getTeachers()
        }

        function onDisconnectedFromServer() {
            if (page.teachersLoading) {
                page.teachersLoading = false
                page.teachersRequestPending = false
                page.teacherError = "Соединение с сервером потеряно."
            }
        }

        function onConnectionError(error) {
            if (page.teachersLoading) {
                page.teachersLoading = false
                page.teachersRequestPending = false
                page.teacherError = error || "Ошибка подключения к серверу."
            }
        }

        function onResponseReceived(obj) {
            if (!obj)
                return

            if (obj.command === "get_table" && obj.table_name === "Teacher") {
                if (obj.ok === false) {
                    page.teachersLoading = false
                    page.teachersRequestPending = false
                    page.teacherError = obj.error || "Не удалось загрузить преподавателей."
                    return
                }

                page.handleTeachersResponse(obj)
                return
            }

            if (obj.command === "add_table_data" && obj.table_name === "Appointments") {
                if (obj.ok === false) {
                    page.teacherError = obj.error || "Не удалось создать запись."
                    return
                }

                page.taskCreated({})
                page.backRequested()
                return
            }
        }
    }

    ListModel {
        id: filteredTeacherModel
    }

    ListModel {
        id: topicModel

        ListElement { title: "Другое" }
        ListElement { title: "Курсовая работа" }
        ListElement { title: "Экзамен / Зачет" }
        ListElement { title: "Лабораторная работа" }
        ListElement { title: "Домашнее задание" }
        ListElement { title: "Научная работа" }
        ListElement { title: "Личный вопрос" }
    }

    ListModel {
        id: timeSlotModel

        ListElement { slot: "08:00" }
        ListElement { slot: "08:30" }
        ListElement { slot: "09:00" }
        ListElement { slot: "09:30" }
        ListElement { slot: "10:00" }
        ListElement { slot: "10:30" }
        ListElement { slot: "11:00" }
        ListElement { slot: "11:30" }
        ListElement { slot: "12:00" }
        ListElement { slot: "12:30" }
        ListElement { slot: "13:00" }
        ListElement { slot: "13:30" }
        ListElement { slot: "14:00" }
        ListElement { slot: "14:30" }
        ListElement { slot: "15:00" }
        ListElement { slot: "15:30" }
        ListElement { slot: "16:00" }
        ListElement { slot: "16:30" }
        ListElement { slot: "17:00" }
        ListElement { slot: "17:30" }
        ListElement { slot: "18:00" }
    }

    Timer {
        id: ensureVisibleTimer
        interval: 220
        repeat: false

        onTriggered: {
            if (page.lastFocusedField)
                page.ensureVisible(page.lastFocusedField)
        }
    }

    NumberAnimation {
        id: scrollToAnimation

        property: "contentY"
        duration: 170
        easing.type: Easing.OutCubic
    }

    function twoDigit(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function formattedDate() {
        return Qt.formatDate(selectedDate, "dd.MM.yyyy")
    }

    function shortDate(date) {
        return Qt.formatDate(date, "dd.MM")
    }

    function formattedTime() {
        return twoDigit(selectedHour) + ":" + twoDigit(selectedMinute)
    }

    function dateFromOffset(offset) {
        var now = new Date()
        return new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset)
    }

    function isSameDay(left, right) {
        return left.getFullYear() === right.getFullYear()
            && left.getMonth() === right.getMonth()
            && left.getDate() === right.getDate()
    }

    function quickDateTitle(offset) {
        if (offset === 0)
            return "Сегодня\n" + shortDate(dateFromOffset(offset))

        if (offset === 1)
            return "Завтра\n" + shortDate(dateFromOffset(offset))

        return Qt.formatDate(dateFromOffset(offset), "ddd") + "\n" + shortDate(dateFromOffset(offset))
    }

    function setDateOffset(offset) {
        selectedDate = dateFromOffset(offset)
    }

    function shiftDate(days) {
        selectedDate = new Date(
            selectedDate.getFullYear(),
            selectedDate.getMonth(),
            selectedDate.getDate() + days
        )
    }

    function setTimeFromString(value) {
        var parts = value.split(":")
        selectedHour = Number(parts[0])
        selectedMinute = Number(parts[1])
    }

    function shiftTime(minutes) {
        var total = selectedHour * 60 + selectedMinute + minutes
        var day = 24 * 60

        while (total < 0)
            total += day

        total = total % day

        selectedHour = Math.floor(total / 60)
        selectedMinute = total % 60
    }

    function durationByIndex(index) {
        if (index === 0)
            return 30

        if (index === 1)
            return 45

        if (index === 2)
            return 60

        return 90
    }

    function setDuration(value) {
        selectedDuration = value
        durationField.text = String(value)
        durationError = ""
    }

    function applyDurationFromField() {
        var value = Number(durationField.text.trim())

        if (isNaN(value) || value <= 0) {
            durationError = "Введите длительность в минутах."
            return false
        }

        selectedDuration = Math.round(value)
        durationField.text = String(selectedDuration)
        durationError = ""

        return true
    }

    function clearErrors() {
        titleError = ""
        teacherError = ""
        studentError = ""
        durationError = ""
    }

    function rebuildTeacherFilter() {
        filteredTeacherModel.clear()

        if (Number(viewerRole) !== 1)
            return

        var query = teacherSearchField.text.trim().toLowerCase()
        var firstId = -1
        var firstFullName = ""
        var firstDepartment = ""
        var firstCabinet = ""
        var selectedFound = false

        for (var i = 0; i < page.teacherItems.length; i++) {
            var item = page.teacherItems[i]

            var itemId = Number(item.idValue || 0)
            var itemFullName = safeText(item.fullName)
            var itemDepartment = safeText(item.department)
            var itemCabinet = safeText(item.cabinet)

            var source = (
                itemFullName + " " +
                itemDepartment + " " +
                itemCabinet
            ).toLowerCase()

            if (query.length === 0 || source.indexOf(query) >= 0) {
                if (firstId < 0) {
                    firstId = itemId
                    firstFullName = itemFullName
                    firstDepartment = itemDepartment
                    firstCabinet = itemCabinet
                }

                if (itemId === selectedTeacherId) {
                    selectedFound = true
                    selectedTeacherFullName = itemFullName
                    selectedTeacherDepartment = itemDepartment
                    selectedTeacherCabinet = itemCabinet
                }

                filteredTeacherModel.append({
                    idValue: itemId,
                    fullName: itemFullName,
                    department: itemDepartment,
                    cabinet: itemCabinet
                })
            }
        }

        if (filteredTeacherModel.count === 0) {
            selectedTeacherId = -1
            selectedTeacherFullName = ""
            selectedTeacherDepartment = ""
            selectedTeacherCabinet = ""
            return
        }

        if (selectedTeacherId < 0 || !selectedFound) {
            selectedTeacherId = firstId
            selectedTeacherFullName = firstFullName
            selectedTeacherDepartment = firstDepartment
            selectedTeacherCabinet = firstCabinet
        }

        fillCabinetFromTeacher()
    }

    function selectedTeacher() {
        if (Number(viewerRole) !== 1)
            return null

        if (selectedTeacherId < 0)
            return null

        return {
            idValue: selectedTeacherId,
            fullName: selectedTeacherFullName,
            department: selectedTeacherDepartment,
            cabinet: selectedTeacherCabinet
        }
    }

    function selectTeacher(idValue, fullName, department, cabinet) {
        selectedTeacherId = Number(idValue)
        selectedTeacherFullName = safeText(fullName)
        selectedTeacherDepartment = safeText(department)
        selectedTeacherCabinet = safeText(cabinet)

        teacherError = ""
        roomField.text = selectedTeacherCabinet
    }

    function fillCabinetFromTeacher() {
        if (Number(viewerRole) !== 1)
            return

        if (selectedTeacherCabinet.length <= 0)
            return

        if (roomField.text.trim().length === 0)
            roomField.text = selectedTeacherCabinet
    }

    function topicSelected(topic) {
        return selectedTopics.indexOf(topic) >= 0
    }

    function toggleTopic(topic) {
        var copy = selectedTopics.slice()
        var idx = copy.indexOf(topic)

        if (idx >= 0)
            copy.splice(idx, 1)
        else
            copy.push(topic)

        selectedTopics = copy
    }

    function finalReason() {
        var text = reasonArea.text.trim()

        if (selectedTopics.length > 0) {
            if (text.length > 0)
                text += "\n\n"

            text += "Темы: " + selectedTopics.join(", ")
        }

        return text.length > 0 ? text : "Без описания"
    }

    function saveTask() {
        clearErrors()

        if (!applyDurationFromField())
            return

        var title = titleField.text.trim()
        var duration = selectedDuration
        var room = roomField.text.trim()
        var teacher = selectedTeacher()

        if (title.length === 0) {
            titleError = "Введите тему консультации."
            return
        }

        if (Number(viewerRole) !== 1) {
            teacherError = "Создавать запись может только студент."
            return
        }

        if (!teacher) {
            teacherError = "Выберите преподавателя."
            return
        }

        if (duration <= 0) {
            durationError = "Выберите длительность."
            return
        }

        page.hideKeyboardAndTakeFocus()

        Db.addTableData("Appointments", {
            teacher_id: teacher.idValue,
            title: title,
            description: finalReason(),
            appointment_date: Qt.formatDate(page.selectedDate, "yyyy-MM-dd"),
            appointment_time: page.formattedTime(),
            duration_minutes: duration,
            cabinet: room
        })
    }

    Rectangle {
        anchors.fill: parent
        color: page.bg
    }

    ColumnLayout {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: page.contentTopInset + (page.desktopMode ? 18 : 10)
        anchors.bottomMargin: 8
        width: Math.max(0, Math.min(parent.width - page.pageSideMargin * 2, page.contentMaxWidth))
        spacing: page.desktopMode ? 14 : 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            SmallButton {
                id: backButton

                iconName: "back"

                Layout.preferredWidth: 48
                Layout.preferredHeight: 48

                onClicked: {
                    page.hideKeyboardAndTakeFocus()
                    page.backRequested()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Новая запись"
                    color: page.textMain
                    font.pixelSize: 26
                    font.bold: true
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: page.formattedDate() + " · " + page.formattedTime() + " · " + page.selectedDuration + " мин"
                    color: page.textMuted
                    font.pixelSize: 13
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }
        }

        ScrollView {
            id: scrollView

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentWidth: availableWidth
            contentHeight: formColumn.implicitHeight

            topPadding: 2
            bottomPadding: page.contentBottomInset + 28

            background: Rectangle {
                color: page.bg
            }

            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: formColumn

                width: Math.min(scrollView.availableWidth, page.contentMaxWidth)
                x: Math.max(0, Math.round((scrollView.availableWidth - width) / 2))
                spacing: page.desktopMode ? 16 : 14

                FormCard {
                    title: "Основное"
                    iconName: "topic"

                    FieldLabel {
                        text: "Короткая тема записи"
                    }

                    AppTextField {
                        id: titleField

                        error: page.titleError.length > 0
                        placeholderText: "Например: консультация по проекту"

                        onTextChanged: page.clearErrors()
                    }

                    ErrorText {
                        visible: page.titleError.length > 0
                        text: page.titleError
                    }

                    FieldLabel {
                        text: "Комментарий или подробности"
                    }

                    AppTextArea {
                        id: reasonArea
                        placeholderText: "Опишите вопрос, чтобы преподавателю было проще подготовиться"
                    }
                }

                FormCard {
                    title: "Темы для обсуждения"
                    iconName: "tags"

                    Text {
                        text: "Можно выбрать несколько вариантов"
                        color: page.textMuted
                        font.pixelSize: 13

                        Layout.fillWidth: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: page.width < 430 ? 1 : 2
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: topicModel

                            ChipButton {
                                text: model.title
                                selected: page.topicSelected(model.title)
                                allowWrap: false
                                textSize: 13

                                Layout.fillWidth: true
                                Layout.preferredHeight: 46

                                onClicked: page.toggleTopic(model.title)
                            }
                        }
                    }
                }

                FormCard {
                    title: "Преподаватель"
                    iconName: "user"

                    SelectedTeacherBox {
                        visible: page.viewerRole === 1 && page.selectedTeacherId >= 0

                        fullName: page.selectedTeacherFullName
                        department: page.selectedTeacherDepartment
                        cabinet: page.selectedTeacherCabinet
                    }

                    FieldLabel {
                        text: "Найти преподавателя"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        AppTextField {
                            id: teacherSearchField

                            placeholderText: "ФИО, кафедра или кабинет"

                            Layout.fillWidth: true

                            onTextChanged: {
                                page.clearErrors()
                                page.rebuildTeacherFilter()
                            }
                        }

                        SmallButton {
                            visible: teacherSearchField.text.length > 0
                            text: "×"

                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 52

                            onClicked: {
                                teacherSearchField.text = ""
                                page.rebuildTeacherFilter()
                            }
                        }
                    }

                    Text {
                        text: "Нажмите на карточку, чтобы выбрать преподавателя"
                        color: page.textMuted
                        font.pixelSize: 12

                        Layout.fillWidth: true
                    }

                    MessageRow {
                        visible: page.teachersLoading
                        iconName: "clock"
                        text: "Загружаю преподавателей..."
                        iconColor: page.accent
                        bgColor: page.accentSoft

                        Layout.fillWidth: true
                    }

                    ScrollView {
                        id: teacherListView

                        visible: !page.teachersLoading

                        Layout.fillWidth: true
                        Layout.preferredHeight: filteredTeacherModel.count <= 0
                                                ? 54
                                                : Math.min(filteredTeacherModel.count * 82, 320)

                        clip: true
                        contentWidth: availableWidth

                        background: Rectangle {
                            color: "transparent"
                        }

                        ScrollBar.vertical.policy: filteredTeacherModel.count > 4
                                                   ? ScrollBar.AsNeeded
                                                   : ScrollBar.AlwaysOff
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            width: teacherListView.availableWidth
                            spacing: 8

                            Repeater {
                                model: filteredTeacherModel

                                TeacherCard {
                                    fullName: model.fullName
                                    department: model.department
                                    cabinet: model.cabinet
                                    selected: page.selectedTeacherId === model.idValue

                                    onClicked: {
                                        page.selectTeacher(
                                            model.idValue,
                                            model.fullName,
                                            model.department,
                                            model.cabinet
                                        )
                                    }
                                }
                            }

                            Text {
                                visible: filteredTeacherModel.count === 0
                                text: page.teacherError.length > 0 ? page.teacherError : "Преподаватель не найден"
                                color: page.teacherError.length > 0 ? page.danger : page.textMuted
                                font.pixelSize: 14
                                font.bold: page.teacherError.length > 0
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap

                                Layout.fillWidth: true
                                Layout.preferredHeight: 54
                            }
                        }
                    }

                    ErrorText {
                        visible: page.teacherError.length > 0 && filteredTeacherModel.count > 0
                        text: page.teacherError
                    }
                }

                FormCard {
                    title: "Дата"
                    iconName: "calendar"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        SmallButton {
                            iconName: "chevronLeft"

                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 52

                            onClicked: page.shiftDate(-1)
                        }

                        Rectangle {
                            id: dateSelectBox

                            property bool hovered: dateHover.containsMouse
                            property bool pressed: dateTap.pressed

                            Layout.fillWidth: true
                            Layout.minimumWidth: 150
                            Layout.preferredHeight: 70

                            radius: 20
                            color: dateSelectBox.pressed ? page.surface3 : dateSelectBox.hovered && page.desktopMode ? page.surface3 : page.surface2
                            border.width: dateSelectBox.hovered && page.desktopMode ? 2 : 1
                            border.color: dateSelectBox.hovered && page.desktopMode ? "#284568" : page.border
                            scale: dateSelectBox.pressed ? 0.988 : dateSelectBox.hovered && page.desktopMode ? 1.004 : 1.0

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on border.color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                            MouseArea {
                                id: dateHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 40
                                    Layout.preferredHeight: 40
                                    radius: 14
                                    color: page.accentSoft
                                    border.width: 1
                                    border.color: "#284568"

                                    DrawIcon {
                                        anchors.centerIn: parent
                                        width: 22
                                        height: 22
                                        name: "calendar"
                                        iconColor: page.accent
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: page.formattedDate()
                                        color: page.textMain
                                        font.pixelSize: 18
                                        font.bold: true
                                        fontSizeMode: Text.Fit
                                        minimumPixelSize: 12
                                        elide: Text.ElideNone

                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: Qt.formatDate(page.selectedDate, "dddd")
                                        color: page.textMuted
                                        font.pixelSize: 12
                                        fontSizeMode: Text.Fit
                                        minimumPixelSize: 9
                                        elide: Text.ElideNone

                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: "Открыть календарь"
                                        color: page.accent
                                        font.pixelSize: 11
                                        font.bold: true

                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            TapHandler {
                                id: dateTap

                                gesturePolicy: TapHandler.DragThreshold

                                onTapped: dateDialog.open()
                            }
                        }

                        SmallButton {
                            iconName: "chevronRight"

                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 52

                            onClicked: page.shiftDate(1)
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: page.width < 430 ? 2 : 3
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: 7

                            ChipButton {
                                text: page.quickDateTitle(index)
                                selected: page.isSameDay(page.selectedDate, page.dateFromOffset(index))
                                allowWrap: true
                                textSize: 13

                                Layout.fillWidth: true
                                Layout.preferredHeight: 54

                                onClicked: page.setDateOffset(index)
                            }
                        }
                    }
                }

                FormCard {
                    title: "Время и место"
                    iconName: "clock"

                    FieldLabel {
                        text: "Время"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        TimeStepButton {
                            text: "-30"

                            Layout.preferredWidth: 45
                            Layout.preferredHeight: 48

                            onClicked: page.shiftTime(-30)
                        }

                        TimeStepButton {
                            text: "-15"

                            Layout.preferredWidth: 45
                            Layout.preferredHeight: 48

                            onClicked: page.shiftTime(-15)
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 92
                            Layout.preferredHeight: 52

                            radius: 18
                            color: page.surface2
                            border.width: 1
                            border.color: page.border

                            Text {
                                anchors.centerIn: parent
                                text: page.formattedTime()
                                color: page.textMain
                                font.pixelSize: 24
                                font.bold: true
                            }
                        }

                        TimeStepButton {
                            text: "+15"

                            Layout.preferredWidth: 45
                            Layout.preferredHeight: 48

                            onClicked: page.shiftTime(15)
                        }

                        TimeStepButton {
                            text: "+30"

                            Layout.preferredWidth: 45
                            Layout.preferredHeight: 48

                            onClicked: page.shiftTime(30)
                        }
                    }

                    Text {
                        text: "Быстро меняйте время кнопками или выберите готовый вариант ниже"
                        color: page.textMuted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap

                        Layout.fillWidth: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: timeSlotModel

                            ChipButton {
                                text: model.slot
                                selected: page.formattedTime() === model.slot
                                allowWrap: false
                                textSize: 14

                                Layout.fillWidth: true
                                Layout.preferredHeight: 44

                                onClicked: page.setTimeFromString(model.slot)
                            }
                        }
                    }

                    FieldLabel {
                        text: "Длительность"
                    }

                    AppTextField {
                        id: durationField

                        text: String(page.selectedDuration)
                        inputMethodHints: Qt.ImhDigitsOnly
                        placeholderText: "Минуты"

                        Layout.fillWidth: true

                        onEditingFinished: page.applyDurationFromField()

                        onTextChanged: {
                            page.durationError = ""
                        }
                    }

                    Text {
                        text: "Нажмите готовый вариант — он вставится в поле выше"
                        color: page.textMuted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap

                        Layout.fillWidth: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: 4

                            ChipButton {
                                property int durationValue: page.durationByIndex(index)

                                text: durationValue + " мин"
                                selected: page.selectedDuration === durationValue
                                allowWrap: false
                                textSize: 13

                                Layout.fillWidth: true
                                Layout.preferredHeight: 44

                                onClicked: page.setDuration(durationValue)
                            }
                        }
                    }

                    Text {
                        text: "Текущая длительность: " + page.selectedDuration + " мин"
                        color: page.textMuted
                        font.pixelSize: 12

                        Layout.fillWidth: true
                    }

                    ErrorText {
                        visible: page.durationError.length > 0
                        text: page.durationError
                    }

                    FieldLabel {
                        text: "Кабинет"
                    }

                    AppTextField {
                        id: roomField
                        placeholderText: "Например: 301"
                    }
                }

                PrimaryButton {
                    id: submitButton

                    text: "Записаться"

                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    Layout.bottomMargin: 16

                    onClicked: page.saveTask()
                }
            }
        }
    }

    Dialog {
        id: dateDialog

        modal: true
        dim: true
        title: ""

        width: Math.min(page.width - 32, 380)
        anchors.centerIn: parent

        property int pickerMonth: page.selectedDate.getMonth()
        property int pickerYear: page.selectedDate.getFullYear()

        onOpened: {
            pickerMonth = page.selectedDate.getMonth()
            pickerYear = page.selectedDate.getFullYear()
        }

        background: Rectangle {
            color: page.surface
            radius: 28
            border.width: 1
            border.color: page.border
        }

        contentItem: ColumnLayout {
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SmallButton {
                    text: "Назад"

                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 44

                    onClicked: dateDialog.close()
                }

                Text {
                    text: "Выберите дату"
                    color: page.textMain
                    font.pixelSize: 18
                    font.bold: true
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                SmallButton {
                    iconName: "chevronLeft"

                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44

                    onClicked: {
                        dateDialog.pickerMonth--

                        if (dateDialog.pickerMonth < 0) {
                            dateDialog.pickerMonth = 11
                            dateDialog.pickerYear--
                        }
                    }
                }

                Text {
                    text: dateDialog.monthName(dateDialog.pickerMonth) + " " + dateDialog.pickerYear
                    color: page.textMain
                    font.pixelSize: 17
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter

                    Layout.fillWidth: true
                }

                SmallButton {
                    iconName: "chevronRight"

                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44

                    onClicked: {
                        dateDialog.pickerMonth++

                        if (dateDialog.pickerMonth > 11) {
                            dateDialog.pickerMonth = 0
                            dateDialog.pickerYear++
                        }
                    }
                }
            }

            DayOfWeekRow {
                locale: Qt.locale("ru_RU")

                Layout.fillWidth: true

                delegate: Text {
                    text: shortName
                    color: page.textMuted
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MonthGrid {
                month: dateDialog.pickerMonth
                year: dateDialog.pickerYear
                locale: Qt.locale("ru_RU")

                Layout.fillWidth: true
                Layout.preferredHeight: 240

                delegate: Rectangle {
                    radius: 16
                    color: page.isSameDay(model.date, page.selectedDate)
                           ? page.accent
                           : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: model.day
                        color: page.isSameDay(model.date, page.selectedDate)
                               ? "#FFFFFF"
                               : model.month === dateDialog.pickerMonth
                                 ? page.textMain
                                 : page.textMuted
                        opacity: model.month === dateDialog.pickerMonth ? 1.0 : 0.45
                        font.bold: page.isSameDay(model.date, page.selectedDate)
                        font.pixelSize: 14
                    }
                }

                onClicked: function(date) {
                    page.selectedDate = new Date(date.getFullYear(), date.getMonth(), date.getDate())
                    dateDialog.close()
                }
            }

            SmallButton {
                text: "Сегодня"

                Layout.fillWidth: true
                Layout.preferredHeight: 46

                onClicked: {
                    page.selectedDate = new Date()
                    dateDialog.close()
                }
            }
        }

        function monthName(month) {
            var names = [
                "Январь", "Февраль", "Март", "Апрель",
                "Май", "Июнь", "Июль", "Август",
                "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
            ]

            return names[month]
        }
    }

    component FormCard: Rectangle {
        id: card

        default property alias content: cardColumn.data

        property string title: ""
        property string iconName: ""
        property bool hovered: formHover.hovered

        color: card.hovered && page.desktopMode ? page.surface2 : page.surface
        radius: 24
        border.width: 1
        border.color: card.hovered && page.desktopMode ? "#284568" : page.border
        scale: card.hovered && page.desktopMode ? 1.002 : 1.0

        implicitHeight: cardColumn.implicitHeight + 32

        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        HoverHandler {
            id: formHover
            enabled: page.desktopMode
        }

        ColumnLayout {
            id: cardColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 14
                    color: page.accentSoft
                    border.width: 1
                    border.color: "#284568"

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        name: card.iconName
                        iconColor: page.accent
                    }
                }

                Text {
                    text: card.title
                    color: page.textMain
                    font.pixelSize: 18
                    font.bold: true

                    Layout.fillWidth: true
                }
            }
        }
    }

    component FieldLabel: Text {
        color: page.textSub
        font.pixelSize: 13
        font.bold: true

        Layout.fillWidth: true
    }

    component AppTextField: TextField {
        id: control

        property bool error: false

        Layout.fillWidth: true
        Layout.preferredHeight: 52

        hoverEnabled: true

        font.pixelSize: 15
        color: page.textMain
        placeholderTextColor: page.textMuted
        selectionColor: page.accent
        selectedTextColor: "#FFFFFF"

        leftPadding: 16
        rightPadding: 16

        scale: activeFocus ? 1.002 : hovered && page.desktopMode ? 1.002 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        background: Rectangle {
            radius: 17
            color: control.activeFocus
                   ? page.surface3
                   : control.hovered && page.desktopMode
                     ? page.surface3
                     : page.surface2
            border.width: control.activeFocus || (control.hovered && page.desktopMode) ? 2 : 1
            border.color: control.error
                          ? page.danger
                          : control.activeFocus
                            ? page.accent
                            : control.hovered && page.desktopMode
                              ? "#284568"
                              : page.border

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }

        onActiveFocusChanged: {
            if (activeFocus)
                page.requestEnsureVisible(control)
        }
    }

    component AppTextArea: TextArea {
        id: control

        Layout.fillWidth: true
        Layout.preferredHeight: 104

        hoverEnabled: true

        font.pixelSize: 15
        color: page.textMain
        placeholderTextColor: page.textMuted
        selectionColor: page.accent
        selectedTextColor: "#FFFFFF"

        leftPadding: 16
        rightPadding: 16
        topPadding: 14
        bottomPadding: 14

        wrapMode: TextArea.Wrap

        scale: activeFocus ? 1.002 : hovered && page.desktopMode ? 1.002 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        background: Rectangle {
            radius: 17
            color: control.activeFocus
                   ? page.surface3
                   : control.hovered && page.desktopMode
                     ? page.surface3
                     : page.surface2
            border.width: control.activeFocus || (control.hovered && page.desktopMode) ? 2 : 1
            border.color: control.activeFocus
                          ? page.accent
                          : control.hovered && page.desktopMode
                            ? "#284568"
                            : page.border

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }
        }

        onActiveFocusChanged: {
            if (activeFocus)
                page.requestEnsureVisible(control)
        }
    }

    component SelectedTeacherBox: Rectangle {
        id: box

        property string fullName: ""
        property string department: ""
        property string cabinet: ""
        property bool hovered: selectedHover.hovered

        Layout.fillWidth: true
        Layout.preferredHeight: 76

        radius: 20
        color: box.hovered && page.desktopMode ? "#203553" : page.accentSoft
        border.width: 1
        border.color: box.hovered && page.desktopMode ? "#3D6697" : "#284568"

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        HoverHandler {
            id: selectedHover
            enabled: page.desktopMode
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40

                radius: 15
                color: page.accent

                DrawIcon {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    name: "check"
                    iconColor: "#FFFFFF"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Выбран преподаватель"
                    color: page.accent
                    font.pixelSize: 12
                    font.bold: true

                    Layout.fillWidth: true
                }

                Text {
                    text: fullName
                    color: page.textMain
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: department.length > 0 || cabinet.length > 0
                          ? department + (department.length > 0 && cabinet.length > 0 ? " · " : "") + (cabinet.length > 0 ? "каб. " + cabinet : "")
                          : "Данные не указаны"
                    color: page.textSub
                    font.pixelSize: 12
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }
        }
    }

    component TeacherCard: Rectangle {
        id: card

        signal clicked()

        property string fullName: ""
        property string department: ""
        property string cabinet: ""
        property bool selected: false
        property bool hovered: mouseArea.containsMouse

        Layout.fillWidth: true
        Layout.preferredHeight: 74

        radius: 20
        color: card.selected
               ? page.accentSoft
               : card.hovered && page.desktopMode
                 ? page.surface3
                 : page.surface2
        border.width: card.selected || (card.hovered && page.desktopMode) ? 2 : 1
        border.color: card.selected
                      ? page.accent
                      : card.hovered && page.desktopMode
                        ? "#284568"
                        : page.border
        scale: mouseArea.pressed ? 0.988 : card.hovered && page.desktopMode ? 1.004 : 1.0

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38

                radius: 15
                color: card.selected ? page.accent : card.hovered && page.desktopMode ? page.accentSoft : page.surface3
                border.width: 1
                border.color: card.selected || (card.hovered && page.desktopMode) ? "#7FB5FF" : page.border

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                DrawIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    name: card.selected ? "check" : "user"
                    iconColor: card.selected ? "#FFFFFF" : card.hovered && page.desktopMode ? page.accent : page.textMuted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: card.fullName
                    color: page.textMain
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }

                Text {
                    text: card.department + (card.department.length > 0 && card.cabinet.length > 0 ? " · " : "") + (card.cabinet.length > 0 ? "каб. " + card.cabinet : "")
                    color: card.hovered && page.desktopMode ? page.textSub : page.textMuted
                    font.pixelSize: 12
                    elide: Text.ElideRight

                    Layout.fillWidth: true
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: card.clicked()
        }
    }

    component ChipButton: Item {
        id: control

        signal clicked()

        property string text: ""
        property bool selected: false
        property bool allowWrap: false
        property int textSize: 14
        property bool hovered: mouseArea.containsMouse

        Layout.fillWidth: true
        opacity: enabled ? 1.0 : 0.45
        scale: mouseArea.pressed ? 0.97 : control.hovered && page.desktopMode ? 1.012 : 1.0

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
                if (control.selected)
                    return control.hovered && page.desktopMode ? "#203553" : page.accentSoft

                if (mouseArea.pressed)
                    return page.surface3

                if (control.hovered && page.desktopMode)
                    return page.surface3

                return page.surface2
            }
            border.width: control.selected || (control.hovered && page.desktopMode) ? 2 : 1
            border.color: control.selected ? page.accent : control.hovered && page.desktopMode ? "#284568" : page.border

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            text: control.text
            color: control.selected ? page.accent : control.hovered && page.desktopMode ? page.textMain : page.textSub
            font.pixelSize: control.textSize
            font.bold: control.selected
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: control.allowWrap ? Text.WordWrap : Text.NoWrap
            maximumLineCount: control.allowWrap ? 2 : 1
            elide: control.allowWrap ? Text.ElideNone : Text.ElideRight
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: control.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: control.clicked()
        }
    }

    component SmallButton: Item {
        id: control

        signal clicked()

        property string text: ""
        property string iconName: ""
        property bool hovered: mouseArea.containsMouse

        opacity: enabled ? 1.0 : 0.45
        scale: mouseArea.pressed ? 0.94 : control.hovered && page.desktopMode ? 1.05 : 1.0

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
                if (!control.enabled)
                    return page.surface2

                if (mouseArea.pressed)
                    return page.surface3

                if (control.hovered && page.desktopMode)
                    return page.accentSoft

                return page.surface2
            }
            border.width: 1
            border.color: control.hovered && page.desktopMode ? "#284568" : page.border

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        Text {
            visible: control.iconName.length === 0
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            text: control.text
            color: control.hovered && page.desktopMode ? page.accent : page.textMain
            font.pixelSize: 15
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: 1
            elide: Text.ElideRight
        }

        DrawIcon {
            visible: control.iconName.length > 0
            anchors.centerIn: parent
            width: 20
            height: 20
            name: control.iconName
            iconColor: control.hovered && page.desktopMode ? page.accent : page.textMain
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: control.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: control.clicked()
        }
    }

    component TimeStepButton: Item {
        id: control

        signal clicked()

        property string text: ""
        property bool hovered: mouseArea.containsMouse

        opacity: enabled ? 1.0 : 0.45
        scale: mouseArea.pressed ? 0.94 : control.hovered && page.desktopMode ? 1.05 : 1.0

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
                if (mouseArea.pressed)
                    return page.accentSoft

                if (control.hovered && page.desktopMode)
                    return page.accentSoft

                return page.surface2
            }
            border.width: 1
            border.color: mouseArea.pressed || (control.hovered && page.desktopMode) ? page.accent : page.border

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            text: control.text
            color: mouseArea.pressed || (control.hovered && page.desktopMode) ? page.accent : page.textSub
            font.pixelSize: 13
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: control.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: control.clicked()
        }
    }

    component PrimaryButton: Item {
        id: control

        signal clicked()

        property string text: ""
        property bool hovered: mouseArea.containsMouse

        opacity: enabled ? 1.0 : 0.45
        scale: mouseArea.pressed ? 0.975 : control.hovered && page.desktopMode ? 1.012 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: {
                if (!control.enabled)
                    return page.surface3

                if (mouseArea.pressed)
                    return "#255FA9"

                if (control.hovered && page.desktopMode)
                    return "#2B6CBE"

                return page.accent
            }
            border.width: 1
            border.color: control.hovered && page.desktopMode ? "#9CC7FF" : "#7FB5FF"

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            text: control.text
            color: "#FFFFFF"
            font.pixelSize: 16
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

            onClicked: control.clicked()
        }
    }

    component MessageRow: Rectangle {
        id: row

        property string iconName: ""
        property string text: ""
        property color iconColor: page.accent
        property color bgColor: page.surface2
        property bool hovered: msgHover.hovered

        radius: 18
        color: row.hovered && page.desktopMode ? page.surface3 : row.bgColor
        border.width: 1
        border.color: row.hovered && page.desktopMode ? "#284568" : page.border

        Layout.preferredHeight: msgLayout.implicitHeight + 22

        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        HoverHandler {
            id: msgHover
            enabled: page.desktopMode
        }

        RowLayout {
            id: msgLayout

            anchors.fill: parent
            anchors.margins: 11
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 13
                color: Qt.rgba(row.iconColor.r, row.iconColor.g, row.iconColor.b, 0.14)

                DrawIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    name: row.iconName
                    iconColor: row.iconColor
                }
            }

            Text {
                text: row.text
                color: page.textSub
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.WordWrap
                lineHeight: 1.15

                Layout.fillWidth: true
            }
        }
    }

    component ErrorText: Text {
        color: page.danger
        font.pixelSize: 12
        font.bold: true
        wrapMode: Text.WordWrap

        Layout.fillWidth: true
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
            } else if (icon.name === "chevronLeft") {
                ctx.beginPath()
                ctx.moveTo(px(0.62), py(0.28))
                ctx.lineTo(px(0.38), py(0.5))
                ctx.lineTo(px(0.62), py(0.72))
                ctx.stroke()
            } else if (icon.name === "chevronRight") {
                ctx.beginPath()
                ctx.moveTo(px(0.38), py(0.28))
                ctx.lineTo(px(0.62), py(0.5))
                ctx.lineTo(px(0.38), py(0.72))
                ctx.stroke()
            } else if (icon.name === "topic") {
                roundedRectPath(px(0.18), py(0.22), s * 0.64, s * 0.56, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.32), py(0.4))
                ctx.lineTo(px(0.68), py(0.4))
                ctx.moveTo(px(0.32), py(0.56))
                ctx.lineTo(px(0.58), py(0.56))
                ctx.stroke()
            } else if (icon.name === "tags") {
                ctx.beginPath()
                ctx.moveTo(px(0.18), py(0.34))
                ctx.lineTo(px(0.42), py(0.18))
                ctx.lineTo(px(0.82), py(0.58))
                ctx.lineTo(px(0.58), py(0.82))
                ctx.closePath()
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.42), py(0.36), s * 0.035, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.name === "user") {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.33), s * 0.16, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.22), py(0.82))
                ctx.quadraticCurveTo(px(0.25), py(0.58), px(0.5), py(0.58))
                ctx.quadraticCurveTo(px(0.75), py(0.58), px(0.78), py(0.82))
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

                ctx.beginPath()
                ctx.arc(px(0.34), py(0.58), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.5), py(0.58), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.66), py(0.58), s * 0.025, 0, Math.PI * 2)
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
            } else if (icon.name === "check") {
                ctx.beginPath()
                ctx.moveTo(px(0.28), py(0.52))
                ctx.lineTo(px(0.43), py(0.67))
                ctx.lineTo(px(0.74), py(0.36))
                ctx.stroke()
            } else {
                ctx.beginPath()
                ctx.arc(px(0.5), py(0.5), s * 0.08, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }
}