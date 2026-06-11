import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page

    signal loginRequested(string login, string password)
    signal forgotPasswordRequested()

    property var focusedField: null

    readonly property int contentMaxWidth: 560


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

    readonly property color hoverSurface: "#1A1A1A"
    readonly property color hoverBorder: "#777777"
    readonly property color primaryBase: "#333333"
    readonly property color primaryHover: "#444444"
    readonly property color primaryDown: "#222222"
    readonly property color primaryBorder: "#FFFFFF"
    readonly property color primaryBorderHover: "#CCCCCC"

    background: Rectangle {
        color: page.bg
    }

    function showError(text) {
        errorText.text = text
    }

    function clearError() {
        errorText.text = ""
    }

    function setLoading(loading) {
        loginButton.enabled = !loading
        loginButton.text = loading ? "Вход..." : "Войти"
    }

    function scrollToY(y, immediate) {
        var flick = scrollView.contentItem
        if (!flick)
            return

        var maxY = Math.max(0, flick.contentHeight - flick.height)
        var targetY = Math.max(0, Math.min(y, maxY))

        scrollAnimation.stop()

        if (immediate) {
            flick.contentY = targetY
            return
        }

        if (Math.abs(flick.contentY - targetY) < 1)
            return

        scrollAnimation.target = flick
        scrollAnimation.from = flick.contentY
        scrollAnimation.to = targetY
        scrollAnimation.start()
    }

    function ensureVisible(item) {
        var flick = scrollView.contentItem
        if (!item || !flick)
            return

        var pos = item.mapToItem(rootColumn, 0, 0)
        var itemTop = pos.y
        var itemBottom = itemTop + item.height

        var topMargin = 12
        var bottomMargin = 24

        var visibleTop = flick.contentY + topMargin
        var visibleBottom = flick.contentY + flick.height - bottomMargin

        var newY = flick.contentY

        if (itemBottom > visibleBottom) {
            newY += itemBottom - visibleBottom
        } else if (itemTop < visibleTop) {
            newY -= visibleTop - itemTop
        }

        page.scrollToY(newY, false)
    }

    Timer {
        id: ensureVisibleTimer
        interval: 160
        repeat: false
        onTriggered: {
            page.ensureVisible(page.focusedField)
        }
    }

    NumberAnimation {
        id: scrollAnimation
        property: "contentY"
        duration: 220
        easing.type: Easing.OutCubic
    }

    Connections {
        target: Qt.inputMethod

        function onVisibleChanged() {
            if (Qt.inputMethod.visible && page.focusedField)
                ensureVisibleTimer.restart()
        }
    }

    ScrollView {
        id: scrollView

        anchors.fill: parent
        clip: true

        background: Rectangle {
            color: page.bg
        }

        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        onHeightChanged: {
            if (Qt.inputMethod.visible && page.focusedField)
                ensureVisibleTimer.restart()
        }

        ColumnLayout {
            id: rootColumn

            width: scrollView.availableWidth
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
            }

            Rectangle {
                id: titleCard

                Layout.fillWidth: true
                Layout.maximumWidth: page.contentMaxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.preferredHeight: titleRow.implicitHeight + 28

                color: titleHover.hovered ? page.hoverSurface : page.surface
                border.width: 1
                border.color: titleHover.hovered ? page.hoverBorder : page.border
                scale: titleHover.hovered ? 1.002 : 1.0
                transformOrigin: Item.Center

                Behavior on scale {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutQuad
                    }
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

                HoverHandler {
                    id: titleHover
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: page.accent
                    opacity: titleHover.hovered ? 0.12 : 0.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                RowLayout {
                    id: titleRow

                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 58
                        color: page.accentSoft
                        border.width: 1
                        border.color: "#555555"

                        DrawIcon {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            name: "slot"
                            iconColor: page.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Text {
                            text: "SlotApp"
                            color: page.textMain
                            font.pixelSize: 32
                            font.bold: true
                            maximumLineCount: 1
                            elide: Text.ElideRight

                            Layout.fillWidth: true
                        }

                        Text {
                            text: "Вход в аккаунт"
                            color: page.textMuted
                            font.pixelSize: 14
                            maximumLineCount: 1
                            elide: Text.ElideRight

                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
            }

            Rectangle {
                id: card

                color: cardHover.hovered ? page.hoverSurface : page.surface
                border.width: 1
                border.color: cardHover.hovered ? page.hoverBorder : page.border
                scale: cardHover.hovered ? 1.002 : 1.0
                transformOrigin: Item.Center

                Layout.fillWidth: true
                Layout.maximumWidth: page.contentMaxWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.leftMargin: 24
                Layout.rightMargin: 24
                Layout.preferredHeight: cardColumn.implicitHeight + 44

                Behavior on scale {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutQuad
                    }
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

                HoverHandler {
                    id: cardHover
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: page.accent
                    opacity: cardHover.hovered ? 0.10 : 0.0

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
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.topMargin: 24
                    anchors.bottomMargin: 20

                    spacing: 10

                    Text {
                        text: "Авторизация"
                        color: page.textMain
                        font.pixelSize: 22
                        font.bold: true

                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Введите логин и пароль вашей учётной записи."
                        color: page.textMuted
                        font.pixelSize: 14
                        lineHeight: 1.25
                        wrapMode: Text.WordWrap

                        Layout.fillWidth: true
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 14
                    }

                    Text {
                        text: "Логин"
                        color: page.textSub
                        font.pixelSize: 13
                        font.bold: true
                        leftPadding: 2

                        Layout.fillWidth: true
                    }

                    AppTextField {
                        id: loginField

                        placeholderText: "Введите логин"

                        Layout.fillWidth: true

                        onTextChanged: {
                            page.clearError()
                        }

                        onAccepted: {
                            passwordField.forceActiveFocus()
                        }

                        onFocusActivated: {
                            page.focusedField = loginField
                            ensureVisibleTimer.restart()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                    }

                    Text {
                        text: "Пароль"
                        color: page.textSub
                        font.pixelSize: 13
                        font.bold: true
                        leftPadding: 2

                        Layout.fillWidth: true
                    }

                    AppTextField {
                        id: passwordField

                        placeholderText: "Введите пароль"
                        echoMode: TextInput.Password

                        Layout.fillWidth: true

                        onTextChanged: {
                            page.clearError()
                        }

                        onAccepted: {
                            loginButton.clicked()
                        }

                        onFocusActivated: {
                            page.focusedField = passwordField
                            ensureVisibleTimer.restart()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                    }

                    Rectangle {
                        id: errorBox

                        visible: opacity > 0 || Layout.preferredHeight > 0
                        clip: true

                        color: page.dangerSoft
                        border.width: 1
                        border.color: "#FFFFFF"

                        Layout.fillWidth: true
                        Layout.preferredHeight: errorText.text !== "" ? (errorText.implicitHeight + 20) : 0
                        opacity: errorText.text !== "" ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                color: "#333333"

                                DrawIcon {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    name: "warning"
                                    iconColor: page.danger
                                }
                            }

                            Text {
                                id: errorText

                                color: "#FFFFFF"
                                font.pixelSize: 13
                                font.bold: true
                                wrapMode: Text.WordWrap
                                verticalAlignment: Text.AlignVCenter

                                Layout.fillWidth: true
                            }
                        }
                    }

                    AppButton {
                        id: loginButton

                        text: "Войти"
                        enabled: true

                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        baseColor: page.primaryBase
                        hoverColor: page.primaryHover
                        downColor: page.primaryDown
                        disabledColor: page.surface3
                        borderBase: page.primaryBorder
                        borderHover: page.primaryBorderHover
                        borderDown: page.primaryBorderHover
                        borderDisabled: page.border
                        contentColor: loginButton.enabled ? "#FFFFFF" : page.textMuted
                        textPixelSize: 16
                        textBold: true
                        hoverScale: 1.004
                        downScale: 0.986
                        innerGlow: true

                        onClicked: {
                            page.clearError()

                            var login = loginField.text.trim()
                            var password = passwordField.text

                            if (login.length === 0 || password.length === 0) {
                                page.showError("Введите логин и пароль.")
                                return
                            }

                            page.loginRequested(login, password)
                        }
                    }

                    AppButton {
                        id: forgotButton

                        text: "Забыли пароль?"

                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 44

                        baseColor: "transparent"
                        hoverColor: "#222222"
                        downColor: "#111111"
                        disabledColor: "transparent"
                        borderBase: "transparent"
                        borderHover: "#555555"
                        borderDown: "#777777"
                        borderDisabled: "transparent"
                        borderAlwaysVisible: false
                        contentColor: "#FFFFFF"
                        textPixelSize: 14
                        textBold: true
                        hoverScale: 1.006
                        downScale: 0.986
                        innerGlow: false

                        onClicked: {
                            page.forgotPasswordRequested()
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.minimumHeight: 24
                Layout.fillHeight: true
            }
        }
    }

    component AppButton: Rectangle {
        id: button

        property string text: ""
        property color baseColor: page.surface2
        property color hoverColor: page.surface3
        property color downColor: page.surface3
        property color disabledColor: page.surface3
        property color borderBase: page.border
        property color borderHover: page.hoverBorder
        property color borderDown: page.hoverBorder
        property color borderDisabled: page.border
        property color contentColor: page.textMain
        property int textPixelSize: 16
        property bool textBold: true
        property bool borderAlwaysVisible: true
        property bool innerGlow: false
        property real hoverScale: 1.004
        property real downScale: 0.986

        readonly property bool hovered: mouseArea.containsMouse && button.enabled
        readonly property bool down: mouseArea.pressed && button.enabled

        signal clicked()

        implicitWidth: buttonText.implicitWidth + 32
        implicitHeight: 44

        color: !enabled ? disabledColor : (down ? downColor : (hovered ? hoverColor : baseColor))
        border.width: borderAlwaysVisible || hovered || down ? 1 : 0
        border.color: !enabled ? borderDisabled : (down ? borderDown : (hovered ? borderHover : borderBase))
        scale: !enabled ? 1.0 : (down ? downScale : (hovered ? hoverScale : 1.0))
        transformOrigin: Item.Center
        opacity: enabled ? 1.0 : 0.76

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

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            color: "transparent"
            border.width: 1
            border.color: "#FFFFFF"
            opacity: button.innerGlow && button.hovered ? 0.13 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutQuad
                }
            }
        }

        Text {
            id: buttonText

            anchors.centerIn: parent
            text: button.text
            color: button.contentColor
            font.pixelSize: button.textPixelSize
            font.bold: button.textBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
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

    component AppTextField: Rectangle {
        id: field

        property alias text: input.text
        property alias placeholderText: placeholder.text
        property alias echoMode: input.echoMode

        signal accepted()
        signal focusActivated()

        function forceActiveFocus() {
            input.forceActiveFocus()
        }

        height: 56
        implicitHeight: 56

        Layout.preferredHeight: 56

        color: input.activeFocus ? page.surface3 : (fieldHover.hovered ? "#333333" : page.surface2)
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? page.accent : (fieldHover.hovered ? page.hoverBorder : page.border)
        scale: input.activeFocus ? 1.002 : (fieldHover.hovered ? 1.001 : 1.0)
        transformOrigin: Item.Center

        HoverHandler {
            id: fieldHover
            cursorShape: Qt.IBeamCursor
        }

        Behavior on scale {
            NumberAnimation {
                duration: 110
                easing.type: Easing.OutQuad
            }
        }

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

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: page.accentSoft
            opacity: input.activeFocus ? 0.12 : (fieldHover.hovered ? 0.07 : 0.0)

            Behavior on opacity {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutQuad
                }
            }
        }

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 0
            anchors.bottomMargin: 0

            color: page.textMain
            selectionColor: page.accent
            selectedTextColor: "#000000"
            font.pixelSize: 16

            verticalAlignment: TextInput.AlignVCenter
            clip: true

            echoMode: TextInput.Normal

            cursorDelegate: Rectangle {
                width: 2
                color: page.accent
                visible: input.activeFocus
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    field.focusActivated()
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

            color: page.textMuted
            font.pixelSize: 16
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight

            enabled: false
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

            if (icon.name === "slot") {

                rectPath(px(0.16), py(0.20), s * 0.68, s * 0.60)
                ctx.stroke()

                ctx.beginPath()
                ctx.moveTo(px(0.34), py(0.20))
                ctx.lineTo(px(0.34), py(0.80))
                ctx.moveTo(px(0.66), py(0.20))
                ctx.lineTo(px(0.66), py(0.80))
                ctx.stroke()


                ctx.fillRect(px(0.5) - s * 0.08, py(0.5) - s * 0.08, s * 0.16, s * 0.16)
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


                ctx.fillRect(px(0.5) - s * 0.025, py(0.69) - s * 0.025, s * 0.05, s * 0.05)
            } else {

                ctx.fillRect(px(0.5) - s * 0.08, py(0.5) - s * 0.08, s * 0.16, s * 0.16)
            }
        }
    }
}