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


    readonly property color bg: "#000000"
    readonly property color surface: "#111111"
    readonly property color surface2: "#222222"
    readonly property color border: "#555555"
    readonly property color textMain: "#FFFFFF"
    readonly property color textMuted: "#AAAAAA"
    readonly property color accent: "#FFFFFF"
    readonly property color accentSoft: "#333333"
    readonly property color success: "#CCCCCC"

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
            x: -148
            y: -112
            color: page.accent
            opacity: 0.075
        }

        Rectangle {
            width: 280
            height: 280
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
                    x: parent.width / 2 - width / 2
                    y: 4
                    color: page.accent
                    opacity: 0.95
                    scale: 1.15 + page.sin(90) * 0.25
                }

                Rectangle {
                    width: 7
                    height: 7
                    x: parent.width - width - 23
                    y: parent.height / 2 - height / 2
                    color: page.success
                    opacity: 0.82
                    scale: 1.08 + page.sin(180) * 0.18
                }

                Rectangle {
                    width: 6
                    height: 6
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
                        GradientStop { position: 0.0; color: "#00FFFFFF" }
                        GradientStop { position: 0.5; color: "#44FFFFFF" }
                        GradientStop { position: 1.0; color: "#00FFFFFF" }
                    }
                }

                Rectangle {
                    width: 72
                    height: 72
                    x: 18
                    y: 19
                    color: page.accentSoft
                    border.width: 1
                    border.color: page.border

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

                            ctx.lineCap = "square"
                            ctx.lineJoin = "miter"


                            ctx.beginPath()
                            ctx.moveTo(12, 10)
                            ctx.lineTo(35, 10)
                            ctx.lineTo(35, 37)
                            ctx.lineTo(7, 37)
                            ctx.lineTo(7, 10)
                            ctx.lineTo(12, 10)
                            ctx.stroke()


                            ctx.beginPath()
                            ctx.moveTo(15, 21)
                            ctx.lineTo(27, 21)
                            ctx.moveTo(15, 29)
                            ctx.lineTo(23, 29)
                            ctx.stroke()


                            ctx.fillRect(29, 7, 8, 8)
                        }
                    }
                }

                Rectangle {
                    id: cardOne

                    width: 92
                    height: 42
                    x: 48
                    y: 80 + page.sin(40) * 4
                    rotation: -12 + page.sin(90) * 1.5
                    color: "#111111"
                    opacity: 0.84 + page.cos(40) * 0.08
                    border.width: 1
                    border.color: page.border

                    Rectangle {
                        width: 38
                        height: 5
                        x: 13
                        y: 12
                        color: page.accent
                        opacity: 0.82
                    }

                    Rectangle {
                        width: 58
                        height: 5
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
                    x: 112 + page.sin(170) * 4
                    y: 60
                    rotation: 9 + page.sin(210) * 1.3
                    color: "#050505"
                    opacity: 0.66 + page.cos(170) * 0.08
                    border.width: 1
                    border.color: page.border

                    Rectangle {
                        width: 28
                        height: 5
                        x: 12
                        y: 12
                        color: page.success
                        opacity: 0.76
                    }

                    Rectangle {
                        width: 44
                        height: 5
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
                        color: page.surface2
                    }

                    Rectangle {
                        id: progressFill

                        height: 14
                        x: 0
                        width: 40 + page.progressPhase * 90
                        color: page.accent
                        opacity: 0.85
                    }

                    Rectangle {
                        id: progressSpark

                        width: 14
                        height: 14
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