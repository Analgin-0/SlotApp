import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import App.Core 1.0

Item {
    id: root

    focus: true

    signal logoutRequested()

    property int currentTab: 0
    property int viewerRole: 0

    property var homePageObj: null
    property var appointmentsPageObj: null
    property var schedulePageObj: null
    property var adminScheduleEditorItem: null

    property bool addUserLoading: false
    property string addUserError: ""
    property string addUserSuccess: ""

    readonly property bool isAdmin: Number(viewerRole) === 3
    readonly property int bottomBarHeight: 78

    property bool sideBarCollapsed: false
    readonly property int desktopBreakpoint: 900
    readonly property bool desktopNavigation: root.width >= root.desktopBreakpoint && !root.isInnerPage
    readonly property int sideBarExpandedWidth: 238
    readonly property int sideBarCollapsedWidth: 92
    readonly property int sideBarCurrentWidth: root.sideBarCollapsed ? root.sideBarCollapsedWidth : root.sideBarExpandedWidth

    readonly property int homePageIndex: 0
    readonly property int tasksPageIndex: 1
    readonly property int schedulePageIndex: 2
    readonly property int profilePageIndex: 3
    readonly property int adminUsersPageIndex: 4

    readonly property int addTaskPageIndex: 5
    readonly property int sessionsPageIndex: 6
    readonly property int changePasswordPageIndex: 7
    readonly property int resetPasswordPageIndex: 8
    readonly property int adminScheduleEditorPageIndex: 9

    readonly property bool isAdminUsersPage: root.currentTab === root.adminUsersPageIndex

    readonly property bool isAddTaskPage: root.currentTab === root.addTaskPageIndex
    readonly property bool isSessionsPage: root.currentTab === root.sessionsPageIndex
    readonly property bool isChangePasswordPage: root.currentTab === root.changePasswordPageIndex
    readonly property bool isResetPasswordPage: root.currentTab === root.resetPasswordPageIndex
    readonly property bool isAdminScheduleEditorPage: root.currentTab === root.adminScheduleEditorPageIndex

    readonly property bool isInnerPage: root.isAddTaskPage
                                    || root.isAdminUsersPage
                                    || root.isSessionsPage
                                    || root.isChangePasswordPage
                                    || root.isResetPasswordPage
                                    || root.isAdminScheduleEditorPage

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

    ListModel {
        id: appointmentsModel
    }

    Component.onCompleted: {
        root.hideKeyboardAndTakeFocus()

        Qt.callLater(function() {
            root.hideKeyboardAndTakeFocus()
        })

        if (Db.isConnect()) {
            Db.getMyProfile()
        } else {
            Db.connectToServer()
        }
    }

    onCurrentTabChanged: {
        root.hideKeyboardAndTakeFocus()

        Qt.callLater(function() {
            root.hideKeyboardAndTakeFocus()
        })
    }

    onViewerRoleChanged: {
        console.log("Main: viewerRole changed =", root.viewerRole)

        if (root.isAdmin && root.currentTab === root.tasksPageIndex)
            root.currentTab = root.homePageIndex

        if (!root.isAdmin && root.currentTab === root.adminUsersPageIndex)
            root.currentTab = root.homePageIndex

        if (!root.isAdmin && root.currentTab === root.adminScheduleEditorPageIndex)
            root.currentTab = root.homePageIndex

        root.refreshCurrentPage()
    }

    Timer {
        id: refreshHomeTimer
        interval: 180
        repeat: false

        onTriggered: {
            if (root.isAdmin)
                return

            if (root.currentTab !== root.homePageIndex)
                return

            if (root.homePageObj && typeof root.homePageObj.loadData === "function")
                root.homePageObj.loadData()
        }
    }

    Timer {
        id: refreshAppointmentsTimer
        interval: 180
        repeat: false

        onTriggered: {
            if (root.isAdmin)
                return

            if (root.currentTab !== root.tasksPageIndex)
                return

            if (root.appointmentsPageObj && typeof root.appointmentsPageObj.loadAppointments === "function")
                root.appointmentsPageObj.loadAppointments()
        }
    }

    Timer {
        id: refreshScheduleTimer
        interval: 180
        repeat: false

        onTriggered: {
            if (root.isAdmin)
                return

            if (root.currentTab !== root.schedulePageIndex)
                return

            if (root.schedulePageObj && typeof root.schedulePageObj.loadScheduleData === "function")
                root.schedulePageObj.loadScheduleData()
        }
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

    function hideKeyboardAndTakeFocus() {
        root.forceActiveFocus()
        Qt.inputMethod.hide()
    }

    function refreshCurrentPage() {
        if (root.viewerRole === 0)
            return

        if (root.isAdmin)
            return

        if (root.currentTab === root.homePageIndex) {
            refreshHomeTimer.restart()
            return
        }

        if (root.currentTab === root.tasksPageIndex) {
            refreshAppointmentsTimer.restart()
            return
        }

        if (root.currentTab === root.schedulePageIndex) {
            refreshScheduleTimer.restart()
            return
        }
    }

    function canOpenTab(index) {
        if (index === root.homePageIndex)
            return true

        if (index === root.profilePageIndex)
            return true

        if (index === root.schedulePageIndex)
            return true

        if (index === root.tasksPageIndex)
            return !root.isAdmin


        return false
    }

    function openTab(index) {
        if (!root.canOpenTab(index))
            return

        root.hideKeyboardAndTakeFocus()
        root.currentTab = index
        root.refreshCurrentPage()
    }

    function openAdminUsersPage() {
        if (!root.isAdmin)
            return

        root.hideKeyboardAndTakeFocus()
        root.currentTab = root.adminUsersPageIndex
    }

    function returnToAdminHomePage() {
        root.hideKeyboardAndTakeFocus()
        root.currentTab = root.homePageIndex
    }

    function openAddTaskPage() {
        if (Number(root.viewerRole) !== 1)
            return

        root.hideKeyboardAndTakeFocus()
        root.currentTab = root.addTaskPageIndex
    }

    function returnToAppointments() {
        root.hideKeyboardAndTakeFocus()

        if (root.isAdmin) {
            root.currentTab = root.homePageIndex
            return
        }

        root.currentTab = root.tasksPageIndex
        refreshAppointmentsTimer.restart()
        refreshHomeTimer.restart()
    }

    function openSessionsPage() {
        root.hideKeyboardAndTakeFocus()
        root.currentTab = root.sessionsPageIndex
    }

    function openChangePasswordPage() {
        root.hideKeyboardAndTakeFocus()
        root.currentTab = root.changePasswordPageIndex
    }

    function openResetPasswordPage() {
        root.hideKeyboardAndTakeFocus()
        root.currentTab = root.resetPasswordPageIndex
    }

    function returnToProfile() {
        root.hideKeyboardAndTakeFocus()
        root.currentTab = root.profilePageIndex
    }

    function returnToChangePasswordPage() {
        root.hideKeyboardAndTakeFocus()
        root.currentTab = root.changePasswordPageIndex
    }

    function openAdminScheduleCreatePage() {
        if (!root.isAdmin)
            return

        root.hideKeyboardAndTakeFocus()
        root.adminScheduleEditorItem = null
        root.currentTab = root.adminScheduleEditorPageIndex
    }

    function openAdminScheduleEditPage(scheduleItem) {
        if (!root.isAdmin)
            return

        root.hideKeyboardAndTakeFocus()
        root.adminScheduleEditorItem = scheduleItem || null
        root.currentTab = root.adminScheduleEditorPageIndex
    }

    function returnToAdminSchedulePage() {
        root.hideKeyboardAndTakeFocus()
        root.adminScheduleEditorItem = null
        root.currentTab = root.schedulePageIndex
    }

    function clearAddUserForm() {
        lastNameField.text = ""
        firstNameField.text = ""
        middleNameField.text = ""
        birthDateField.text = ""
        genderCombo.currentIndex = 0
        phoneField.text = ""

        loginField.text = ""
        passwordField.text = ""

        // Студент
        groupField.text = ""
        courseField.text = ""
        facultyField.text = ""
        specialityField.text = ""
        studentCardField.text = ""
        educationFormField.text = ""

        // Преподаватель
        departmentField.text = ""
        postField.text = ""
        teacherCabinetField.text = ""
        academicDegreeField.text = ""
        academicTitleField.text = ""

        roleCombo.currentIndex = 0
        root.addUserError = ""
        root.addUserSuccess = ""
        root.hideKeyboardAndTakeFocus()
    }

    function submitAddUser() {
        root.addUserError = ""
        root.addUserSuccess = ""

        if (!root.isAdmin) {
            root.addUserError = "Создавать пользователей может только администратор."
            return
        }

        var lastName = lastNameField.text.trim()
        var firstName = firstNameField.text.trim()
        var middleName = middleNameField.text.trim()
        var birthDate = birthDateField.text.trim()
        var gender = genderCombo.selectedGender
        var phone = phoneField.text.trim()

        var login = loginField.text.trim()
        var password = passwordField.text.trim()
        var role = roleCombo.selectedRole

        if (lastName.length === 0) {
            root.addUserError = "Введите фамилию."
            return
        }

        if (firstName.length === 0) {
            root.addUserError = "Введите имя."
            return
        }

        if (login.length === 0) {
            root.addUserError = "Введите логин или email."
            return
        }

        if (password.length < 4) {
            root.addUserError = "Пароль должен быть не менее 4 символов."
            return
        }

        if (role === 1 && groupField.text.trim().length === 0) {
            root.addUserError = "Для студента укажите группу."
            return
        }

        if (!Db.isConnect()) {
            root.addUserError = "Нет соединения с сервером."
            Db.connectToServer()
            return
        }

        root.hideKeyboardAndTakeFocus()
        root.addUserLoading = true

        var postVal = ""
        if (role === 2) {
            postVal = postField.text.trim()
        }

        var userData = {
            last_name: lastName,
            name: firstName,
            middle_name: middleName,
            birth_date: birthDate,
            gender: gender,
            phone: phone,
            login: login,
            password: password,
            role: role,
            post: postVal,

            LastName: lastName,
            Name: firstName,
            MiddleName: middleName,
            BirthDate: birthDate,
            Gender: gender,
            Phone: phone,
            Login: login,
            Password: password,
            Role: role,
            Post: postVal
        }

        var studentData = {}
        var teacherData = {}

        if (role === 1) {
            var courseVal = parseInt(courseField.text.trim())
            if (isNaN(courseVal)) courseVal = 0

            studentData = {
                group_name: groupField.text.trim(),
                course: courseVal,
                faculty: facultyField.text.trim(),
                speciality: specialityField.text.trim(),
                student_card_number: studentCardField.text.trim(),
                education_form: educationFormField.text.trim(),

                GroupName: groupField.text.trim(),
                Course: courseVal,
                Faculty: facultyField.text.trim(),
                Speciality: specialityField.text.trim(),
                StudentCardNumber: studentCardField.text.trim(),
                EducationForm: educationFormField.text.trim()
            }
        }

        if (role === 2) {
            teacherData = {
                department: departmentField.text.trim(),
                post: postVal,
                cabinet: teacherCabinetField.text.trim(),
                academic_degree: academicDegreeField.text.trim(),
                academic_title: academicTitleField.text.trim(),

                Department: departmentField.text.trim(),
                Post: postVal,
                Cabinet: teacherCabinetField.text.trim(),
                AcademicDegree: academicDegreeField.text.trim(),
                AcademicTitle: academicTitleField.text.trim()
            }
        }

        Db.createUser(userData, studentData, teacherData)
    }

    Rectangle {
        anchors.fill: parent
        color: root.bg
    }

    StackLayout {
        id: pages

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: desktopSideBar.visible ? desktopSideBar.width : 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: bottomBar.visible ? bottomBar.height : 0

        clip: true

        currentIndex: root.currentTab

        Loader {
            id: homeLoader

            Layout.fillWidth: true
            Layout.fillHeight: true

            active: true

            sourceComponent: {
                if (root.viewerRole === 0)
                    return loadingHomeComponent

                if (root.isAdmin)
                    return adminHomeComponent

                return userHomeComponent
            }

            onLoaded: {
                root.homePageObj = item
            }

            onSourceComponentChanged: {
                root.homePageObj = null
            }
        }

        Loader {
            id: appointmentsLoader

            Layout.fillWidth: true
            Layout.fillHeight: true

            active: root.currentTab === root.tasksPageIndex &&
                    !root.isAdmin &&
                    root.viewerRole !== 0

            sourceComponent: tasksPageComponent

            onLoaded: {
                root.appointmentsPageObj = item
            }

            onActiveChanged: {
                if (!active)
                    root.appointmentsPageObj = null
            }
        }

        Loader {
            id: scheduleLoader

            Layout.fillWidth: true
            Layout.fillHeight: true

            active: root.currentTab === root.schedulePageIndex &&
                    root.viewerRole !== 0

            sourceComponent: root.isAdmin ? adminScheduleComponent : userScheduleComponent

            onLoaded: {
                root.schedulePageObj = item
            }

            onActiveChanged: {
                if (!active)
                    root.schedulePageObj = null
            }

            onSourceComponentChanged: {
                root.schedulePageObj = null
            }
        }

        ProfilePage {
            id: profilePage

            contentBottomInset: 0

            Layout.fillWidth: true
            Layout.fillHeight: true

            onSessionsRequested: {
                root.openSessionsPage()
            }

            onChangePasswordRequested: {
                root.openChangePasswordPage()
            }

            onLogoutRequested: {
                root.hideKeyboardAndTakeFocus()
                root.logoutRequested()
            }
        }

        Item {
            id: addUserPage

            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                anchors.fill: parent
                color: root.bg
            }

            ScrollView {
                id: addUserScroll

                anchors.fill: parent
                clip: true

                contentWidth: availableWidth
                contentHeight: addUserColumn.implicitHeight

                topPadding: 20
                bottomPadding: 26

                background: Rectangle {
                    color: root.bg
                }

                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    id: addUserColumn

                    width: addUserScroll.availableWidth
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        spacing: 12

                        Button {
                            id: backFromAddUserButton

                            hoverEnabled: true

                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            Layout.alignment: Qt.AlignVCenter

                            scale: down ? 0.94 : hovered ? 1.05 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }

                            background: Rectangle {
                                radius: 16
                                color: backFromAddUserButton.down ? root.surface3
                                      : backFromAddUserButton.hovered ? root.accentSoft
                                      : root.surface2
                                border.width: 1
                                border.color: backFromAddUserButton.hovered ? root.accent : root.border

                                Behavior on color {
                                    ColorAnimation { duration: 130 }
                                }

                                Behavior on border.color {
                                    ColorAnimation { duration: 130 }
                                }
                            }

                            contentItem: Text {
                                text: "‹"
                                color: backFromAddUserButton.hovered ? root.accent : root.textMain
                                font.pixelSize: 30
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter

                                Behavior on color {
                                    ColorAnimation { duration: 130 }
                                }
                            }

                            onClicked: {
                                root.returnToAdminHomePage()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 58
                            Layout.preferredHeight: 58
                            radius: 20
                            color: root.accentSoft
                            border.width: 1
                            border.color: "#284568"

                            DrawIcon {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                name: "adminUsers"
                                iconColor: root.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: "Пользователи"
                                color: root.textMain
                                font.pixelSize: 28
                                font.bold: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }

                            Text {
                                text: "Создание нового аккаунта"
                                color: root.textMuted
                                font.pixelSize: 14
                                maximumLineCount: 1
                                elide: Text.ElideRight

                                Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle {
                        color: root.surface
                        radius: 26
                        border.width: 1
                        border.color: root.border

                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        Layout.preferredHeight: hintRow.implicitHeight + 28

                        RowLayout {
                            id: hintRow

                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 15
                                color: root.surface2

                                DrawIcon {
                                    anchors.centerIn: parent
                                    width: 23
                                    height: 23
                                    name: "info"
                                    iconColor: root.accent
                                }
                            }

                            Text {
                                text: "Заполните основные поля.\nДля студентов нужна группа, для преподавателей можно указать кафедру и кабинет."
                                color: root.textSub
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                lineHeight: 1.15

                                Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle {
                        color: root.surface
                        radius: 26
                        border.width: 1
                        border.color: root.border

                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        Layout.preferredHeight: formColumn.implicitHeight + 36

                        ColumnLayout {
                            id: formColumn

                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 13

                            FormSectionTitle {
                                title: "Личные данные"
                                iconName: "user"
                            }

                            FieldLabel { text: "Фамилия" }
                            AppField { id: lastNameField; placeholderText: "Введите фамилию" }

                            FieldLabel { text: "Имя" }
                            AppField { id: firstNameField; placeholderText: "Введите имя" }

                            FieldLabel { text: "Отчество" }
                            AppField { id: middleNameField; placeholderText: "Введите отчество (необязательно)" }

                            FieldLabel { text: "Дата рождения" }
                            AppField { id: birthDateField; placeholderText: "ГГГГ-ММ-ДД" }

                            FieldLabel { text: "Пол" }
                            ComboBox {
                                id: genderCombo

                                model: ["Не указан", "Мужской", "Женский"]

                                property string selectedGender: currentIndex === 0 ? "" : currentText

                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                font.pixelSize: 15

                                background: Rectangle {
                                    radius: 17
                                    color: genderCombo.activeFocus ? root.surface3 : root.surface2
                                    border.width: genderCombo.activeFocus ? 2 : 1
                                    border.color: genderCombo.activeFocus ? root.accent : root.border
                                }

                                contentItem: Text {
                                    text: genderCombo.displayText
                                    color: root.textMain
                                    font.pixelSize: 15
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 16
                                    rightPadding: 44
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                }

                                indicator: DrawIcon {
                                    x: genderCombo.width - width - 16
                                    y: genderCombo.topPadding + (genderCombo.availableHeight - height) / 2
                                    width: 20
                                    height: 20
                                    name: "chevronDown"
                                    iconColor: root.textMuted
                                }

                                popup: Popup {
                                    y: genderCombo.height + 6
                                    width: genderCombo.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 6

                                    background: Rectangle {
                                        color: root.surface2
                                        radius: 18
                                        border.width: 1
                                        border.color: root.border
                                    }

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: genderCombo.popup.visible ? genderCombo.delegateModel : null
                                        currentIndex: genderCombo.highlightedIndex
                                    }
                                }

                                delegate: ItemDelegate {
                                    width: genderCombo.width - 12
                                    height: 44

                                    background: Rectangle {
                                        radius: 14
                                        color: highlighted ? root.surface3 : "transparent"
                                    }

                                    contentItem: Text {
                                        text: modelData
                                        color: root.textMain
                                        font.pixelSize: 15
                                        font.bold: genderCombo.currentIndex === index
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 10
                                    }
                                }
                            }

                            FieldLabel { text: "Телефон" }
                            AppField { id: phoneField; placeholderText: "+7 (999) 000-00-00" }

                            FormDivider {}

                            FormSectionTitle {
                                title: "Доступ"
                                iconName: "lock"
                            }

                            FieldLabel { text: "Логин / email" }
                            AppField {
                                id: loginField
                                placeholderText: "Введите логин или email"
                                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                            }

                            FieldLabel { text: "Пароль" }
                            AppField {
                                id: passwordField
                                placeholderText: "Введите пароль"
                                echoMode: TextInput.Password
                            }

                            FieldLabel { text: "Роль" }
                            ComboBox {
                                id: roleCombo

                                model: ["Студент", "Преподаватель", "Администратор"]

                                property int selectedRole: currentIndex + 1

                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                font.pixelSize: 15

                                background: Rectangle {
                                    radius: 17
                                    color: roleCombo.activeFocus ? root.surface3 : root.surface2
                                    border.width: roleCombo.activeFocus ? 2 : 1
                                    border.color: roleCombo.activeFocus ? root.accent : root.border
                                }

                                contentItem: Text {
                                    text: roleCombo.displayText
                                    color: root.textMain
                                    font.pixelSize: 15
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: 16
                                    rightPadding: 44
                                    maximumLineCount: 1
                                    elide: Text.ElideRight
                                }

                                indicator: DrawIcon {
                                    x: roleCombo.width - width - 16
                                    y: roleCombo.topPadding + (roleCombo.availableHeight - height) / 2
                                    width: 20
                                    height: 20
                                    name: "chevronDown"
                                    iconColor: root.textMuted
                                }

                                popup: Popup {
                                    y: roleCombo.height + 6
                                    width: roleCombo.width
                                    implicitHeight: contentItem.implicitHeight
                                    padding: 6

                                    background: Rectangle {
                                        color: root.surface2
                                        radius: 18
                                        border.width: 1
                                        border.color: root.border
                                    }

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: roleCombo.popup.visible ? roleCombo.delegateModel : null
                                        currentIndex: roleCombo.highlightedIndex
                                    }
                                }

                                delegate: ItemDelegate {
                                    width: roleCombo.width - 12
                                    height: 44

                                    background: Rectangle {
                                        radius: 14
                                        color: highlighted ? root.surface3 : "transparent"
                                    }

                                    contentItem: Text {
                                        text: modelData
                                        color: root.textMain
                                        font.pixelSize: 15
                                        font.bold: roleCombo.currentIndex === index
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 10
                                    }
                                }
                            }

                            // ═══════════════════════════════════════════
                            // ПОЛЯ ДЛЯ СТУДЕНТА (РОЛЬ 1)
                            // ═══════════════════════════════════════════
                            FieldLabel { visible: roleCombo.selectedRole === 1; text: "Группа" }
                            AppField { id: groupField; visible: roleCombo.selectedRole === 1; placeholderText: "Например: ИС-21" }

                            FieldLabel { visible: roleCombo.selectedRole === 1; text: "Курс" }
                            AppField { id: courseField; visible: roleCombo.selectedRole === 1; placeholderText: "Например: 3" }

                            FieldLabel { visible: roleCombo.selectedRole === 1; text: "Факультет" }
                            AppField { id: facultyField; visible: roleCombo.selectedRole === 1; placeholderText: "Например: ФИТ" }

                            FieldLabel { visible: roleCombo.selectedRole === 1; text: "Специальность" }
                            AppField { id: specialityField; visible: roleCombo.selectedRole === 1; placeholderText: "Например: Программная инженерия" }

                            FieldLabel { visible: roleCombo.selectedRole === 1; text: "Номер зачетной книжки" }
                            AppField { id: studentCardField; visible: roleCombo.selectedRole === 1; placeholderText: "Например: 123456" }

                            FieldLabel { visible: roleCombo.selectedRole === 1; text: "Форма обучения" }
                            AppField { id: educationFormField; visible: roleCombo.selectedRole === 1; placeholderText: "Например: Очная" }

                            // ═══════════════════════════════════════════
                            // ПОЛЯ ДЛЯ ПРЕПОДАВАТЕЛЯ (РОЛЬ 2)
                            // ═══════════════════════════════════════════
                            FieldLabel { visible: roleCombo.selectedRole === 2; text: "Кафедра" }
                            AppField { id: departmentField; visible: roleCombo.selectedRole === 2; placeholderText: "Например: Информатика" }

                            FieldLabel { visible: roleCombo.selectedRole === 2; text: "Должность" }
                            AppField { id: postField; visible: roleCombo.selectedRole === 2; placeholderText: "Например: Доцент" }

                            FieldLabel { visible: roleCombo.selectedRole === 2; text: "Кабинет" }
                            AppField { id: teacherCabinetField; visible: roleCombo.selectedRole === 2; placeholderText: "Например: 301" }

                            FieldLabel { visible: roleCombo.selectedRole === 2; text: "Ученая степень" }
                            AppField { id: academicDegreeField; visible: roleCombo.selectedRole === 2; placeholderText: "Например: Кандидат техн. наук" }

                            FieldLabel { visible: roleCombo.selectedRole === 2; text: "Ученое звание" }
                            AppField { id: academicTitleField; visible: roleCombo.selectedRole === 2; placeholderText: "Например: Доцент" }

                            MessageBox {
                                visible: root.addUserError.length > 0
                                text: root.addUserError
                                iconName: "warning"
                                bgColor: root.dangerSoft
                                fgColor: "#FFD7DA"
                                iconColor: root.danger

                                Layout.fillWidth: true
                            }

                            MessageBox {
                                visible: root.addUserSuccess.length > 0
                                text: root.addUserSuccess
                                iconName: "check"
                                bgColor: root.successSoft
                                fgColor: "#DDFBE9"
                                iconColor: root.success

                                Layout.fillWidth: true
                            }

                            AppWideButton {
                                id: createUserBtn

                                text: root.addUserLoading ? "Создание..." : "Создать пользователя"
                                enabled: !root.addUserLoading
                                loading: root.addUserLoading

                                Layout.topMargin: 4

                                normalColor: root.accent
                                hoverColor: "#7DB3FF"
                                pressColor: "#5B95EA"
                                disabledColor: root.surface3
                                textColor: "#FFFFFF"
                                showBorder: false

                                onClicked: {
                                    root.submitAddUser()
                                }
                            }

                            AppWideButton {
                                id: clearFormButton

                                text: "Очистить форму"
                                enabled: !root.addUserLoading

                                Layout.preferredHeight: 48

                                normalColor: root.surface2
                                hoverColor: root.surface3
                                pressColor: "#252A33"
                                disabledColor: root.surface2
                                textColor: root.textMain
                                borderColor: root.border
                                showBorder: true

                                onClicked: {
                                    root.clearAddUserForm()
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                    }
                }
            }
        }

        Loader {
            id: addTaskLoader

            Layout.fillWidth: true
            Layout.fillHeight: true

            active: root.currentTab === root.addTaskPageIndex
            sourceComponent: addTaskPageComponent
        }

        Loader {
            id: sessionsLoader

            Layout.fillWidth: true
            Layout.fillHeight: true

            active: root.currentTab === root.sessionsPageIndex
            sourceComponent: sessionsPageComponent
        }

        Loader {
            id: changePasswordLoader

            Layout.fillWidth: true
            Layout.fillHeight: true

            active: root.currentTab === root.changePasswordPageIndex
            sourceComponent: changePasswordPageComponent
        }

        Loader {
            id: resetPasswordLoader

            Layout.fillWidth: true
            Layout.fillHeight: true

            active: root.currentTab === root.resetPasswordPageIndex
            sourceComponent: resetPasswordPageComponent
        }

        Loader {
            id: adminScheduleEditorLoader

            Layout.fillWidth: true
            Layout.fillHeight: true

            active: root.currentTab === root.adminScheduleEditorPageIndex
            sourceComponent: adminScheduleEditorPageComponent
        }
    }

    Component {
        id: loadingHomeComponent

        Item {
            Rectangle {
                anchors.fill: parent
                color: root.bg
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 360)
                spacing: 14

                BusyIndicator {
                    running: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                }

                Text {
                    text: "Загрузка профиля..."
                    color: root.textMain
                    font.pixelSize: 22
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Text {
                    text: "Определяем роль пользователя."
                    color: root.textMuted
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }

    Component {
        id: userHomeComponent

        HomePage {
            viewerRole: root.viewerRole
            contentBottomInset: 0
        }
    }

    Component {
        id: tasksPageComponent

        TasksPage {
            active: root.currentTab === root.tasksPageIndex && !root.isAdmin
            tasksModel: appointmentsModel
            viewerRole: root.viewerRole
            bottomInset: 0

            onAddTaskRequested: {
                root.openAddTaskPage()
            }
        }
    }

    Component {
        id: userScheduleComponent

        SchedulePage {
            active: root.currentTab === root.schedulePageIndex && !root.isAdmin
            viewerRole: root.viewerRole
            contentBottomInset: 0
        }
    }

    Component {
        id: addTaskPageComponent

        AddTaskPage {
            active: root.currentTab === root.addTaskPageIndex
            viewerRole: root.viewerRole
            contentTopInset: 0
            contentBottomInset: 0

            onBackRequested: {
                root.returnToAppointments()
            }

            onTaskCreated: function(task) {
                root.returnToAppointments()
            }
        }
    }

    Component {
        id: sessionsPageComponent

        SessionsPage {
            onBackRequested: {
                root.returnToProfile()
            }
        }
    }

    Component {
        id: changePasswordPageComponent

        ChangePasswordPage {
            onBackRequested: {
                root.returnToProfile()
            }

            onForgotPasswordRequested: {
                root.openResetPasswordPage()
            }

            onPasswordChanged: {
                root.returnToProfile()
            }
        }
    }

    Component {
        id: resetPasswordPageComponent

        ResetPasswordPage {
            onBackRequested: {
                root.returnToChangePasswordPage()
            }
        }
    }

    Component {
        id: adminHomeComponent

        Item {
            Rectangle {
                anchors.fill: parent
                color: root.bg
            }

            ScrollView {
                id: adminHomeScroll

                anchors.fill: parent
                clip: true
                contentWidth: availableWidth
                contentHeight: adminHomeColumn.implicitHeight

                topPadding: 22
                bottomPadding: 26

                background: Rectangle {
                    color: root.bg
                }

                ColumnLayout {
                    id: adminHomeColumn

                    width: adminHomeScroll.availableWidth
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 58
                            Layout.preferredHeight: 58
                            radius: 20
                            color: root.accentSoft
                            border.width: 1
                            border.color: "#284568"

                            DrawIcon {
                                anchors.centerIn: parent
                                width: 30
                                height: 30
                                name: "adminUsers"
                                iconColor: root.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: "Админ-панель"
                                color: root.textMain
                                font.pixelSize: 30
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "Пользователи и расписание"
                                color: root.textMuted
                                font.pixelSize: 14
                                Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle {
                        color: root.surface
                        radius: 26
                        border.width: 1
                        border.color: root.border

                        Layout.fillWidth: true
                        Layout.leftMargin: 20
                        Layout.rightMargin: 20
                        Layout.preferredHeight: adminCardColumn.implicitHeight + 34

                        ColumnLayout {
                            id: adminCardColumn

                            anchors.fill: parent
                            anchors.margins: 17
                            spacing: 12

                            Text {
                                text: "Для администратора"
                                color: root.textMain
                                font.pixelSize: 21
                                font.bold: true
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "Здесь доступны создание пользователей и управление расписанием."
                                color: root.textMuted
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                lineHeight: 1.2
                                Layout.fillWidth: true
                            }

                            AppWideButton {
                                id: goUsersButton

                                text: "Создать пользователя"

                                normalColor: root.accent
                                hoverColor: "#7DB3FF"
                                pressColor: "#5B95EA"
                                textColor: "#FFFFFF"
                                showBorder: false

                                onClicked: {
                                    root.openAdminUsersPage()
                                }
                            }

                            AppWideButton {
                                id: goScheduleButton

                                text: "Открыть расписание"

                                normalColor: root.surface2
                                hoverColor: root.surface3
                                pressColor: "#252A33"
                                textColor: root.textMain
                                borderColor: root.border
                                showBorder: true

                                onClicked: {
                                    root.openTab(root.schedulePageIndex)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: adminScheduleComponent

        AdminSchedulePage {
            contentTopInset: 0
            contentBottomInset: 0

            onBackRequested: {
                root.openTab(root.homePageIndex)
            }

            onCreateRequested: {
                root.openAdminScheduleCreatePage()
            }

            onEditRequested: function(scheduleItem) {
                root.openAdminScheduleEditPage(scheduleItem)
            }
        }
    }

    Component {
        id: adminScheduleEditorPageComponent

        AdminScheduleEditorPage {
            contentTopInset: 0
            contentBottomInset: 0
            scheduleItem: root.adminScheduleEditorItem

            onBackRequested: {
                root.returnToAdminSchedulePage()
            }

            onScheduleSaved: {
                root.returnToAdminSchedulePage()
            }
        }
    }

    Connections {
        target: Db
        ignoreUnknownSignals: true

        function onConnectedToServer() {
            if (root.viewerRole === 0)
                Db.getMyProfile()
        }

        function onResponseReceived(response) {
            if (!response)
                return

            var cmd = root.responseCmd(response)

            if (cmd === "get_my_profile" && response.ok && response.user) {
                var roleValue = Number(response.user.role || response.user.Role || 0)

                if (roleValue > 0)
                    root.viewerRole = roleValue
            }

            if (!root.addUserLoading)
                return

            if (cmd !== "create_user")
                return

            root.addUserLoading = false

            if (response.ok) {
                root.addUserSuccess = "Пользователь успешно создан!"
                root.addUserError = ""
                root.clearAddUserForm()
            } else {
                root.addUserError = response.error || "Не удалось создать пользователя."
                root.addUserSuccess = ""
            }
        }

        function onDisconnectedFromServer() {
            if (root.addUserLoading) {
                root.addUserLoading = false
                root.addUserError = "Соединение с сервером потеряно."
            }
        }

        function onConnectionError(error) {
            if (root.addUserLoading) {
                root.addUserLoading = false
                root.addUserError = error || "Ошибка подключения."
            }
        }
    }

    Connections {
        target: root.homePageObj
        ignoreUnknownSignals: true

        function onScheduleRequested() {
            root.openTab(root.schedulePageIndex)
        }

        function onAppointmentsRequested() {
            if (!root.isAdmin)
                root.openTab(root.tasksPageIndex)
        }

        function onProfileRequested() {
            root.openTab(root.profilePageIndex)
        }

        function onAddUserRequested() {
            if (root.isAdmin)
                root.openAdminUsersPage()
        }

        function onLogoutRequested() {
            root.hideKeyboardAndTakeFocus()
            root.logoutRequested()
        }

        function onViewerRoleChanged() {
            if (root.homePageObj && root.homePageObj.viewerRole !== undefined) {
                var roleValue = Number(root.homePageObj.viewerRole)

                if (roleValue > 0)
                    root.viewerRole = roleValue
            }
        }
    }

    Connections {
        target: root.schedulePageObj
        ignoreUnknownSignals: true

        function onLogoutRequested() {
            root.hideKeyboardAndTakeFocus()
            root.logoutRequested()
        }
    }

    Rectangle {
        id: desktopSideBar

        visible: root.desktopNavigation

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        width: visible ? root.sideBarCurrentWidth : 0
        color: root.bg
        clip: true
        z: 2

        Behavior on width {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: root.border
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 14
            anchors.bottomMargin: 14
            spacing: 8

            Item {
                id: sideBarHeader

                Layout.fillWidth: true
                Layout.preferredHeight: root.sideBarCollapsed ? 92 : 58

                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    id: sideBarLogo

                    width: 44
                    height: 44
                    radius: 16
                    color: root.accentSoft
                    border.width: 1
                    border.color: "#284568"

                    x: root.sideBarCollapsed ? Math.round((sideBarHeader.width - width) / 2) : 0
                    y: root.sideBarCollapsed ? 2 : Math.round((sideBarHeader.height - height) / 2)

                    Behavior on x {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    DrawIcon {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        name: root.isAdmin ? "adminUsers" : "slotLogo"
                        iconColor: root.accent
                    }
                }

                Column {
                    id: sideBarTitleColumn

                    visible: opacity > 0.01
                    opacity: root.sideBarCollapsed ? 0.0 : 1.0
                    spacing: 2

                    anchors.left: sideBarLogo.right
                    anchors.leftMargin: 10
                    anchors.right: sideBarCollapseButton.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: sideBarLogo.verticalCenter

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutQuad
                        }
                    }

                    Text {
                        width: parent.width
                        text: root.isAdmin ? "Админ-панель" : "SlotApp"
                        color: root.textMain
                        font.pixelSize: 17
                        font.bold: true
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.isAdmin ? "Управление" : "Навигация"
                        color: root.textMuted
                        font.pixelSize: 12
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }

                SideBarCollapseButton {
                    id: sideBarCollapseButton

                    width: 34
                    height: 34

                    x: root.sideBarCollapsed ? Math.round((sideBarHeader.width - width) / 2) : sideBarHeader.width - width
                    y: root.sideBarCollapsed ? 56 : Math.round((sideBarHeader.height - height) / 2)

                    Behavior on x {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.border
            }

            SideNavButton {
                title: "Главная"
                iconType: "home"
                active: root.currentTab === root.homePageIndex

                onClicked: {
                    root.openTab(root.homePageIndex)
                }
            }

            SideNavButton {
                visible: !root.isAdmin
                title: "Записи"
                iconType: "tasks"
                active: root.currentTab === root.tasksPageIndex

                onClicked: {
                    root.openTab(root.tasksPageIndex)
                }
            }

            SideNavButton {
                title: "Расписание"
                iconType: "calendar"
                active: root.currentTab === root.schedulePageIndex

                onClicked: {
                    root.openTab(root.schedulePageIndex)
                }
            }

            SideNavButton {
                title: "Профиль"
                iconType: "user"
                active: root.currentTab === root.profilePageIndex

                onClicked: {
                    root.openTab(root.profilePageIndex)
                }
            }


            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    Rectangle {
        id: bottomBar

        visible: !root.isInnerPage && !root.desktopNavigation

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        height: root.bottomBarHeight
        color: root.bg
        z: 100

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.border
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 22
            color: root.bg
            opacity: 0.92
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 6
            anchors.bottomMargin: 8
            spacing: 6

            NavButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "Главная"
                iconType: "home"
                active: root.currentTab === root.homePageIndex

                onClicked: {
                    root.openTab(root.homePageIndex)
                }
            }

            NavButton {
                visible: !root.isAdmin

                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "Записи"
                iconType: "tasks"
                active: root.currentTab === root.tasksPageIndex

                onClicked: {
                    root.openTab(root.tasksPageIndex)
                }
            }

            NavButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "Распис."
                iconType: "calendar"
                active: root.currentTab === root.schedulePageIndex

                onClicked: {
                    root.openTab(root.schedulePageIndex)
                }
            }

            NavButton {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "Профиль"
                iconType: "user"
                active: root.currentTab === root.profilePageIndex

                onClicked: {
                    root.openTab(root.profilePageIndex)
                }
            }

        }
    }

    component AppWideButton: Button {
        id: control

        property color normalColor: root.surface2
        property color hoverColor: root.surface3
        property color pressColor: root.surface3
        property color disabledColor: root.surface3
        property color textColor: root.textMain
        property color borderColor: root.border
        property bool showBorder: true
        property bool loading: false
        property int radiusValue: 18

        hoverEnabled: true

        Layout.fillWidth: true
        Layout.preferredHeight: 54

        opacity: enabled ? 1.0 : 0.62
        scale: !enabled ? 1.0 : down ? 0.985 : hovered ? 1.012 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        background: Rectangle {
            radius: control.radiusValue
            color: !control.enabled ? control.disabledColor
                  : control.down ? control.pressColor
                  : control.hovered ? control.hoverColor
                  : control.normalColor
            border.width: control.showBorder ? 1 : 0
            border.color: control.hovered && control.enabled ? root.accent : control.borderColor

            Behavior on color {
                ColorAnimation { duration: 130 }
            }

            Behavior on border.color {
                ColorAnimation { duration: 130 }
            }
        }

        contentItem: RowLayout {
            spacing: 10

            Item {
                Layout.fillWidth: true
            }

            BusyIndicator {
                running: control.loading
                visible: control.loading

                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
            }

            Text {
                text: control.text
                color: control.textColor
                font.pixelSize: 15
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                maximumLineCount: 1
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation { duration: 130 }
                }
            }

            Item {
                Layout.fillWidth: true
            }
        }
    }

    component FieldLabel: Text {
        color: root.textSub
        font.pixelSize: 13
        font.bold: true

        Layout.fillWidth: true
    }

    component AppField: TextField {
        id: control

        Layout.fillWidth: true
        Layout.preferredHeight: 52

        color: root.textMain
        placeholderTextColor: root.textMuted
        selectionColor: root.accent
        selectedTextColor: "#FFFFFF"

        font.pixelSize: 15
        leftPadding: 16
        rightPadding: 16

        background: Rectangle {
            radius: 17
            color: control.activeFocus ? root.surface3 : root.surface2
            border.width: control.activeFocus ? 2 : 1
            border.color: control.activeFocus ? root.accent : root.border
        }
    }

    component FormSectionTitle: RowLayout {
        id: section

        property string title: ""
        property string iconName: ""

        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 34
            Layout.preferredHeight: 34
            radius: 12
            color: root.accentSoft

            DrawIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                name: section.iconName
                iconColor: root.accent
            }
        }

        Text {
            text: section.title
            color: root.textMain
            font.pixelSize: 18
            font.bold: true

            Layout.fillWidth: true
        }
    }

    component FormDivider: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        color: root.border
    }

    component MessageBox: Rectangle {
        id: box

        property string text: ""
        property string iconName: ""
        property color bgColor: root.surface2
        property color fgColor: root.textMain
        property color iconColor: root.accent

        radius: 18
        color: bgColor
        border.width: 1
        border.color: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.35)

        Layout.preferredHeight: messageRow.implicitHeight + 22

        RowLayout {
            id: messageRow

            anchors.fill: parent
            anchors.margins: 11
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 13
                color: Qt.rgba(iconColor.r, iconColor.g, iconColor.b, 0.14)

                DrawIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    name: box.iconName
                    iconColor: box.iconColor
                }
            }

            Text {
                text: box.text
                color: box.fgColor
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.WordWrap
                lineHeight: 1.15

                Layout.fillWidth: true
            }
        }
    }

    component SideBarCollapseButton: Item {
        id: collapseButton

        signal clicked()

        property bool hovered: mouseArea.containsMouse

        opacity: enabled ? 1.0 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: collapseButton.hovered ? root.surface2 : "transparent"
            border.width: collapseButton.hovered ? 1 : 0
            border.color: root.border

            Behavior on color {
                ColorAnimation {
                    duration: 130
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.sideBarCollapsed ? "›" : "‹"
            color: root.textSub
            font.pixelSize: 24
            font.bold: true
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                root.sideBarCollapsed = !root.sideBarCollapsed
                collapseButton.clicked()
            }
        }
    }

    component SideNavButton: Item {
        id: sideBtn

        property string title: ""
        property string iconType: ""
        property bool active: false
        property bool hovered: mouseArea.containsMouse

        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: root.sideBarCollapsed ? 58 : 52

        opacity: enabled ? 1.0 : 0.45

        scale: mouseArea.pressed ? 0.985 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: sideBtn.active ? root.accentSoft : sideBtn.hovered ? root.surface2 : "transparent"
            border.width: sideBtn.active || sideBtn.hovered ? 1 : 0
            border.color: sideBtn.active ? "#284568" : root.border

            Behavior on color {
                ColorAnimation {
                    duration: 130
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: 130
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                sideBtn.clicked()
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.sideBarCollapsed ? 8 : 13
            anchors.rightMargin: root.sideBarCollapsed ? 8 : 13
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: root.sideBarCollapsed ? Qt.AlignHCenter | Qt.AlignVCenter : Qt.AlignVCenter
                radius: 14
                color: sideBtn.active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12) : "transparent"

                DrawIcon {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    name: sideBtn.iconType
                    iconColor: sideBtn.active ? root.accent : sideBtn.hovered ? root.textSub : root.textMuted
                }
            }

            Text {
                visible: !root.sideBarCollapsed
                text: sideBtn.title
                color: sideBtn.active ? root.textMain : sideBtn.hovered ? root.textSub : root.textMuted
                font.pixelSize: 14
                font.bold: sideBtn.active
                maximumLineCount: 1
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }
    }

    component NavButton: Item {
        id: navBtn

        property string title: ""
        property string iconType: ""
        property bool active: false

        signal clicked()

        opacity: enabled ? 1.0 : 0.45

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: 20
            color: navBtn.active ? root.surface2 : "transparent"
            border.width: navBtn.active ? 1 : 0
            border.color: root.border
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                navBtn.clicked()
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 20
                color: root.surface3
                opacity: parent.pressed ? 0.65 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 110
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            anchors.topMargin: 6
            anchors.bottomMargin: 4
            spacing: 4

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: navBtn.active ? 44 : 36
                Layout.preferredHeight: 30
                radius: 15
                color: navBtn.active ? root.accentSoft : "transparent"

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 140
                    }
                }

                DrawIcon {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    name: navBtn.iconType
                    iconColor: navBtn.active ? root.accent : root.textMuted
                }
            }

            Text {
                text: navBtn.title
                color: navBtn.active ? root.textMain : root.textMuted
                font.pixelSize: 11
                font.bold: navBtn.active
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 1
                elide: Text.ElideRight

                Layout.fillWidth: true
            }
        }
    }

    component DrawIcon: Canvas {
        id: icon

        property string name: ""
        property color iconColor: root.textMain

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

            if (icon.name === "slotLogo") {
                roundedRectPath(px(0.16), py(0.18), s * 0.68, s * 0.64, s * 0.14)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.33), py(0.18))
                ctx.lineTo(px(0.33), py(0.82))
                ctx.moveTo(px(0.67), py(0.18))
                ctx.lineTo(px(0.67), py(0.82))
                ctx.moveTo(px(0.16), py(0.50))
                ctx.lineTo(px(0.84), py(0.50))
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.245), py(0.34), s * 0.035, 0, Math.PI * 2)
                ctx.arc(px(0.50), py(0.34), s * 0.035, 0, Math.PI * 2)
                ctx.arc(px(0.755), py(0.34), s * 0.035, 0, Math.PI * 2)
                ctx.arc(px(0.245), py(0.66), s * 0.035, 0, Math.PI * 2)
                ctx.arc(px(0.50), py(0.66), s * 0.035, 0, Math.PI * 2)
                ctx.arc(px(0.755), py(0.66), s * 0.035, 0, Math.PI * 2)
                ctx.fill()
            } else if (icon.name === "home") {
                ctx.beginPath()
                ctx.moveTo(px(0.15), py(0.48))
                ctx.lineTo(px(0.5), py(0.18))
                ctx.lineTo(px(0.85), py(0.48))
                ctx.stroke()

                roundedRectPath(px(0.25), py(0.46), s * 0.5, s * 0.36, s * 0.06)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.43), py(0.82))
                ctx.lineTo(px(0.43), py(0.62))
                ctx.lineTo(px(0.57), py(0.62))
                ctx.lineTo(px(0.57), py(0.82))
                ctx.stroke()
            } else if (icon.name === "tasks") {
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
                ctx.arc(px(0.34), py(0.56), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.5), py(0.56), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.66), py(0.56), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.34), py(0.7), s * 0.025, 0, Math.PI * 2)
                ctx.arc(px(0.5), py(0.7), s * 0.025, 0, Math.PI * 2)
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
            } else if (icon.name === "adminUsers") {
                ctx.beginPath()
                ctx.arc(px(0.36), py(0.30), s * 0.12, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.15), py(0.76))
                ctx.quadraticCurveTo(px(0.18), py(0.58), px(0.36), py(0.58))
                ctx.quadraticCurveTo(px(0.54), py(0.58), px(0.58), py(0.76))
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.66), py(0.34), s * 0.10, 0, Math.PI * 2)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.52), py(0.74))
                ctx.quadraticCurveTo(px(0.55), py(0.60), px(0.66), py(0.60))
                ctx.quadraticCurveTo(px(0.80), py(0.60), px(0.84), py(0.74))
                ctx.stroke()
            } else if (icon.name === "lock") {
                roundedRectPath(px(0.2), py(0.42), s * 0.6, s * 0.38, s * 0.08)
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.5), py(0.42), s * 0.19, Math.PI, 0, false)
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(px(0.5), py(0.6), s * 0.03, 0, Math.PI * 2)
                ctx.fill()

                ctx.beginPath()
                ctx.moveTo(px(0.5), py(0.63))
                ctx.lineTo(px(0.5), py(0.7))
                ctx.stroke()
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