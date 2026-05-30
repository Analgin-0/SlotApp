import QtQuick
import QtQuick.Controls

Page {
    id: page

    property string appName: "SlotApp"
    property string statusText: ""
    property bool animationRunning: false
    readonly property bool play: visible && animationRunning

    property real phase: 0
    property real progressPhase: 0

    readonly property color bg: "#111318"
    readonly property color surface: "#181B21"
    readonly property color surface2: "#20242C"
    readonly property color border: "#313640"
    readonly property color textMain: "#F4F6F8"
    readonly property color textMuted: "#8D96A3"
    readonly property color accent: "#6EA8FE"
    readonly property color accentSoft: "#1C2B44"
    readonly property color success: "#6EE7A8"

    function sin(offset) {
        return Math.sin((page.phase + offset) * Math.PI / 180)
    }

    function cos(offset) {
        return Math.cos((page.phase + offset) * Math.PI / 180)
    }

    function setAppName(name) {
        appName = name && String(name).length > 0 ? name : "SlotApp"
    }

    function setStatusText(text) {
        statusText = text
    }

    function resetAnimationState() {
        phase = 0
        progressPhase = 0
    }

    function startAnimation() {
        resetAnimationState()
        animationRunning = true
        startProgressAnimation()
    }

    function stopAnimation() {
        animationRunning = false
        resetAnimationState()
        progressSequence.stop()
    }

    function getRandomDuration() {
        return Math.floor(Math.random() * (3000 - 1200 + 1)) + 1200
    }

    function startProgressAnimation() {
        if (!page.play)
            return

        forwardAnim.duration = getRandomDuration()
        backwardAnim.duration = getRandomDuration()
        progressSequence.restart()
    }


    NumberAnimation on phase {
        running: page.play
        from: 0
        to: 360000
        duration: 4200000
        loops: Animation.Infinite
        easing.type: Easing.Linear
    }

    SequentialAnimation {
            id: progressSequence
            running: false

            NumberAnimation {
                id: forwardAnim
                target: page
                property: "progressPhase"
                from: 0
                to: 1
                duration: 1800
                easing.type: Easing.InOutQuad
            }

            ScriptAction {
                script: {

                }
            }

            NumberAnimation {
                id: backwardAnim
                target: page
                property: "progressPhase"
                from: 1
                to: 0
                duration: 1800
                easing.type: Easing.InOutQuad
            }

            ScriptAction {
                script: {

                }
            }

            onFinished: {
                startProgressAnimation()
            }
        }

    Component.onCompleted: {
        if (visible)
            startAnimation()
    }

    onVisibleChanged: {
        if (visible)
            startAnimation()
        else
            stopAnimation()
    }

    background: Rectangle {
        anchors.fill: parent
        color: page.bg
    }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            width: 340
            height: 340
            radius: 170
            x: -148
            y: -112
            color: page.accent
            opacity: 0.075
        }

        Rectangle {
            width: 280
            height: 280
            radius: 140
            anchors.right: parent.right
            anchors.rightMargin: -116
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -92
            color: page.success
            opacity: 0.052
        }

        Rectangle {
            width: 180
            height: 180
            radius: 90
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.top: parent.top
            anchors.topMargin: 76
            color: page.accent
            opacity: 0.032
        }

        Item {
            id: centerBlock

            width: 330
            height: 460
            anchors.centerIn: parent

            Rectangle {
                id: haloOne

                width: 264
                height: 264
                radius: 132
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                color: page.accent
                scale: 1.06 + page.sin(0) * 0.06
                opacity: 0.064 + page.cos(0) * 0.036
            }

            Rectangle {
                id: haloTwo

                width: 206
                height: 206
                radius: 103
                anchors.horizontalCenter: parent.horizontalCenter
                y: 38
                color: page.success
                scale: 1.08 + page.sin(70) * 0.08
                opacity: 0.051 + page.cos(70) * 0.029
            }

            Item {
                id: diagonalLayer

                width: 260
                height: 210
                anchors.horizontalCenter: parent.horizontalCenter
                y: 36
                x: page.sin(30) * 10
                opacity: 0.44 + page.cos(30) * 0.08
                clip: true

                Repeater {
                    model: 7

                    Rectangle {
                        width: 160
                        height: 2
                        radius: 1
                        x: -22 + index * 24
                        y: 22 + index * 24
                        rotation: -24
                        color: index % 2 === 0 ? page.accent : page.success
                        opacity: index % 2 === 0 ? 0.18 : 0.10
                    }
                }
            }

            Item {
                id: orbitLayer

                width: 238
                height: 238
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20
                rotation: page.phase
                visible: false

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    x: parent.width / 2 - width / 2
                    y: 4
                    color: page.accent
                    opacity: 0.95
                    scale: 1.15 + page.sin(90) * 0.25
                }

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    x: parent.width - width - 23
                    y: parent.height / 2 - height / 2
                    color: page.success
                    opacity: 0.82
                    scale: 1.08 + page.sin(180) * 0.18
                }

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    x: 24
                    y: parent.height / 2 - height / 2
                    color: page.textMuted
                    opacity: 0.58
                    scale: 1.0 + page.sin(260) * 0.14
                }
            }

            Rectangle {
                id: portalGlow

                width: 192
                height: 150
                radius: 42
                anchors.horizontalCenter: parent.horizontalCenter
                y: 61
                rotation: -8 + page.sin(140) * 0.6
                color: page.accent
                scale: 1.04 + page.sin(20) * 0.04
                opacity: 0.15 + page.cos(20) * 0.05
            }

            Rectangle {
                id: portal

                width: 190
                height: 148
                radius: 42
                anchors.horizontalCenter: parent.horizontalCenter
                y: 60
                rotation: -8 + page.sin(120) * 0.8
                scale: 1.012 + page.sin(210) * 0.012
                color: page.surface
                border.width: 1
                border.color: page.border
                clip: true

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    radius: 34
                    color: page.surface2
                    border.width: 1
                    border.color: page.border
                }

                Rectangle {
                    id: softBeam

                    width: 72
                    height: parent.height + 54
                    x: (portal.width - width) / 2 + page.sin(0) * 58
                    y: -26
                    rotation: 18
                    opacity: 0.24 + page.cos(0) * 0.12

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#006EA8FE" }
                        GradientStop { position: 0.5; color: "#446EA8FE" }
                        GradientStop { position: 1.0; color: "#006EA8FE" }
                    }
                }

                Rectangle {
                    width: 72
                    height: 72
                    radius: 26
                    x: 18
                    y: 19
                    color: page.accentSoft
                    border.width: 1
                    border.color: "#284568"

                    Canvas {
                        anchors.centerIn: parent
                        width: 44
                        height: 44

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            ctx.strokeStyle = page.accent
                            ctx.fillStyle = page.success
                            ctx.lineWidth = 3.6
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"

                            ctx.beginPath()
                            ctx.moveTo(12, 10)
                            ctx.lineTo(30, 10)
                            ctx.quadraticCurveTo(35, 10, 35, 15)
                            ctx.lineTo(35, 32)
                            ctx.quadraticCurveTo(35, 37, 30, 37)
                            ctx.lineTo(12, 37)
                            ctx.quadraticCurveTo(7, 37, 7, 32)
                            ctx.lineTo(7, 15)
                            ctx.quadraticCurveTo(7, 10, 12, 10)
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.moveTo(15, 21)
                            ctx.lineTo(27, 21)
                            ctx.moveTo(15, 29)
                            ctx.lineTo(23, 29)
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.arc(33, 11, 4.2, 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                }

                Rectangle {
                    id: cardOne

                    width: 92
                    height: 42
                    radius: 16
                    x: 48
                    y: 80 + page.sin(40) * 4
                    rotation: -12 + page.sin(90) * 1.5
                    color: "#232A34"
                    opacity: 0.84 + page.cos(40) * 0.08
                    border.width: 1
                    border.color: page.border

                    Rectangle {
                        width: 38
                        height: 5
                        radius: 3
                        x: 13
                        y: 12
                        color: page.accent
                        opacity: 0.82
                    }

                    Rectangle {
                        width: 58
                        height: 5
                        radius: 3
                        x: 13
                        y: 24
                        color: page.textMuted
                        opacity: 0.38
                    }
                }

                Rectangle {
                    id: cardTwo

                    width: 76
                    height: 38
                    radius: 15
                    x: 112 + page.sin(170) * 4
                    y: 60
                    rotation: 9 + page.sin(210) * 1.3
                    color: "#1D2631"
                    opacity: 0.66 + page.cos(170) * 0.08
                    border.width: 1
                    border.color: "#284568"

                    Rectangle {
                        width: 28
                        height: 5
                        radius: 3
                        x: 12
                        y: 12
                        color: page.success
                        opacity: 0.76
                    }

                    Rectangle {
                        width: 44
                        height: 5
                        radius: 3
                        x: 12
                        y: 24
                        color: page.textMuted
                        opacity: 0.28
                    }
                }

                Rectangle {
                    id: cardThree

                    width: 64
                    height: 32
                    radius: 14
                    x: 88
                    y: 126 + page.sin(260) * 3
                    rotation: 3 + page.sin(300) * 1.2
                    color: page.surface2
                    opacity: 0.43 + page.cos(260) * 0.09
                    border.width: 1
                    border.color: page.border
                }
            }

            Text {
                id: appNameLabel

                width: parent.width - 34
                anchors.horizontalCenter: parent.horizontalCenter
                y: 318
                text: page.appName
                color: page.textMain
                font.pixelSize: 18
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 1
                elide: Text.ElideRight
                opacity: 1.0
            }

            Text {
                id: statusLabel

                width: parent.width - 34
                anchors.horizontalCenter: parent.horizontalCenter
                y: 346
                text: page.statusText.length > 0 ? page.statusText : "Загрузка..."
                color: page.textMuted
                font.pixelSize: 14
                font.bold: true
                opacity: 0.74 + page.sin(90) * 0.16
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }

            Rectangle {
                id: progressWrap

                width: 190
                height: 44
                radius: 22
                anchors.horizontalCenter: parent.horizontalCenter
                y: 392
                color: page.surface
                border.width: 1
                border.color: page.border

                Item {
                    id: progressTrack

                    width: 132
                    height: 14
                    anchors.centerIn: parent
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: page.surface2
                    }

                    Rectangle {
                        id: progressFill

                        height: 14
                        radius: 7
                        x: 0
                        width: 40 + page.progressPhase * 90
                        color: page.accent
                        opacity: 0.85
                    }

                    Rectangle {
                        id: progressSpark

                        width: 14
                        height: 14
                        radius: 7
                        x: Math.max(0, Math.min(progressTrack.width - width,
                                                progressFill.width - width / 2))
                        color: page.success
                        opacity: 1.0
                        scale: 1.08 + page.cos(0) * 0.08
                    }
                }
            }
        }
    }
}