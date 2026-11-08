// Toolbox island page (Mod+T): a menu of small tools (calculator, timer,
// stopwatch, alarms) plus a shortcut to the calendar page.
//
// Pages live as long as the shell, so the timer, stopwatch and alarms keep
// running with the page closed; the idle pill shows `pillText` while a timer or
// stopwatch runs. Alarms are one-shot (they switch off after ringing) and are
// kept in ~/.local/state/island/alarms.json. Ringing = a critical notification
// with no sound, which stays until dismissed.
//
// Parsing and formatting live in tools.js (checked by tools.test.js).
//
// Views: menu | calc | timer | stopwatch | alarm
import Quickshell
import Quickshell.Io
import QtQuick
import common
import "tools.js" as Tools

Page {
    id: page

    readonly property int pageWidth: 560
    property string view: "menu"
    // Set before opening to land on a tool instead of the menu (idle pill chip).
    property string startView: "menu"
    // A page that lives in the shell, e.g. "calendar".
    signal openPage(string m)

    // Wall clock for the running tools; ticks only while one runs.
    property real now: Date.now()
    Timer {
        interval: page.active && page.view === "stopwatch" ? 33 : 250
        running: page.timerRunning || page.swRunning
        repeat: true
        onTriggered: page.tick()
    }
    function tick() {
        now = Date.now();
        if (timerRunning && now >= timerEnd) {
            ring("Timer done", Tools.fmt(timerTotal) + " is up");
            timerReset();
        }
    }

    // Critical with no timeout: the island keeps the card up until dismissed.
    function ring(title, body) {
        Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Toolbox", "-i", "alarm-clock", title, body]);
    }

    // Shown in the idle pill; "" hides the chip there.
    readonly property string pillText: timerTotal > 0 ? String.fromCodePoint(0xF051B) + " " + Tools.fmt(timerLeft + 999)
        : swRunning ? String.fromCodePoint(0xF13AB) + " " + Tools.fmt(swElapsed) : ""
    readonly property string pillView: timerTotal > 0 ? "timer" : "stopwatch"

    function show(v) {
        view = v;
        Qt.callLater(() => {
            if (v === "menu") {
                menu.reset();
                menu.focusField();
            } else if (v === "calc")
                calcIn.focusField();
            else if (v === "timer" && timerTotal === 0)
                timerIn.focusField();
            else if (v === "alarm") {
                alarmList.reset();
                alarmList.focusField();
            } else
                (v === "timer" ? timerView : swView).forceActiveFocus();
        });
    }

    onOpened: {
        now = Date.now();
        show(startView);
        startView = "menu";
    }

    // ── Calculator ─────────────────────────────────────────────────────
    readonly property var calcResult: Tools.calc(calcIn.text)
    property var calcHistory: []
    property int calcSel: -1 // history line picked with Ctrl+J/K; -1 = the field
    function calcAccept() {
        if (!calcResult)
            return;
        Quickshell.execDetached(["wl-copy", calcResult]);
        calcHistory = [{ expr: calcIn.text, res: calcResult }].concat(calcHistory).slice(0, 5);
        calcIn.text = calcResult; // keep going from the answer
    }

    // ── Timer ──────────────────────────────────────────────────────────
    property real timerTotal: 0 // ms; 0 = no timer set
    property real timerEnd: 0 // epoch ms, while running
    property real timerPausedLeft: 0
    property bool timerRunning: false
    readonly property real timerLeft: timerRunning ? Math.max(0, timerEnd - now) : timerPausedLeft
    function timerStart(sec) {
        if (sec <= 0)
            return;
        now = Date.now();
        timerTotal = sec * 1000;
        timerEnd = now + timerTotal;
        timerRunning = true;
        show("timer");
    }
    function timerToggle() {
        now = Date.now();
        if (timerRunning)
            timerPausedLeft = timerEnd - now;
        else
            timerEnd = now + timerPausedLeft;
        timerRunning = !timerRunning;
    }
    function timerAdd(sec) {
        timerTotal += sec * 1000;
        if (timerRunning)
            timerEnd += sec * 1000;
        else
            timerPausedLeft += sec * 1000;
    }
    function timerReset() {
        timerRunning = false;
        timerTotal = 0;
        timerPausedLeft = 0;
        if (view === "timer")
            show("timer");
    }

    // ── Stopwatch ──────────────────────────────────────────────────────
    property real swBase: 0 // ms banked before the current run
    property real swStart: 0
    property bool swRunning: false
    property var laps: [] // elapsed ms at each lap, newest first
    readonly property real swElapsed: swBase + (swRunning ? now - swStart : 0)
    function swToggle() {
        now = Date.now();
        if (swRunning)
            swBase += now - swStart;
        else
            swStart = now;
        swRunning = !swRunning;
    }
    function swLap() {
        if (swRunning)
            laps = [swElapsed].concat(laps);
    }
    function swReset() {
        swRunning = false;
        swBase = 0;
        laps = [];
    }

    // ── Alarms ─────────────────────────────────────────────────────────
    // [{h, m, label, on, at}], sorted by time of day; `at` = epoch ms it rings.
    property var alarms: []
    function saveAlarms(list) {
        alarms = list.slice().sort((a, b) => a.h * 60 + a.m - (b.h * 60 + b.m));
        alarmFile.setText(JSON.stringify(alarms));
    }
    function addAlarm(text) {
        const a = Tools.parseAlarm(text);
        if (!a)
            return false;
        a.on = true;
        a.at = Tools.nextAt(a.h, a.m, new Date());
        saveAlarms(alarms.concat([a]));
        return true;
    }
    function toggleAlarm(i) {
        const list = alarms.slice();
        const a = Object.assign({}, list[i]);
        a.on = !a.on;
        if (a.on)
            a.at = Tools.nextAt(a.h, a.m, new Date());
        list[i] = a;
        saveAlarms(list);
    }
    function removeAlarm(i) {
        saveAlarms(alarms.filter((a, j) => j !== i));
    }
    function checkAlarms() {
        const t = Date.now();
        const due = alarms.filter(a => a.on && a.at <= t);
        if (!due.length)
            return;
        for (const a of due)
            ring("Alarm " + Tools.clock12(a.h, a.m), a.label || "Alarm");
        saveAlarms(alarms.map(a => a.on && a.at <= t ? Object.assign({}, a, { on: false }) : a));
    }
    FileView {
        id: alarmFile
        path: Quickshell.env("HOME") + "/.local/state/island/alarms.json"
        onLoaded: {
            try {
                page.alarms = JSON.parse(text());
            } catch (e) {
                page.alarms = [];
            }
        }
    }
    // Polling, not one long Timer: a timer's interval stalls across suspend, a
    // wall-clock check still fires (late) on wake.
    Timer {
        interval: 10000
        running: page.alarms.some(a => a.on)
        repeat: true
        triggeredOnStart: true
        onTriggered: page.checkAlarms()
    }
    // Refreshes "rings in" while the alarm list is open.
    SystemClock {
        id: minClock
        precision: SystemClock.Minutes
        enabled: page.active
    }

    Column {
        id: views
        width: page.pageWidth

        // ═══ MENU ═══════════════════════════════════════════════════════
        SearchList {
            id: menu
            visible: page.view === "menu"
            listWidth: page.pageWidth
            glyph: String.fromCodePoint(0xF0AD) // nf-fa-wrench
            placeholder: "Tools…"
            countText: ""
            emptyText: "No matching tool"
            model: {
                const next = page.alarms.filter(a => a.on).sort((a, b) => a.at - b.at)[0];
                const rows = [
                    { id: "calc", title: "Calculator", sub: "Type a sum; Enter copies the answer", glyph: String.fromCodePoint(0xF00EC) },
                    { id: "timer", title: "Timer", glyph: String.fromCodePoint(0xF051B),
                        sub: page.timerTotal > 0 ? Tools.fmt(page.timerLeft + 999) + " left" + (page.timerRunning ? "" : " (paused)") : "Count down from a duration" },
                    { id: "stopwatch", title: "Stopwatch", glyph: String.fromCodePoint(0xF13AB),
                        sub: page.swElapsed > 0 ? Tools.fmt(page.swElapsed) + (page.swRunning ? " running" : " (paused)") : "Time something, with laps" },
                    { id: "alarm", title: "Alarms", glyph: String.fromCodePoint(0xF0020),
                        sub: next ? "Next: " + Tools.clock12(next.h, next.m) + (next.label ? " · " + next.label : "") : "Ring at a time of day" },
                    { id: "calendar", title: "Calendar", sub: "Events and the month view", glyph: "󰸗" }
                ];
                const q = text.toLowerCase();
                return rows.filter(r => q === "" || r.title.toLowerCase().indexOf(q) !== -1);
            }
            onAccepted: (i, row) => {
                if (!row)
                    return;
                if (row.id === "calendar")
                    page.openPage("calendar");
                else
                    page.show(row.id);
            }
            onEscaped: page.closeRequested()
        }

        // ═══ CALCULATOR ═════════════════════════════════════════════════
        Column {
            visible: page.view === "calc"
            width: page.pageWidth
            spacing: Tokens.spacing.medium
            Keys.onEscapePressed: page.show("menu")

            Input {
                id: calcIn
                width: parent.width
                glyph: String.fromCodePoint(0xF00EC)
                field.placeholderText: "2 * (3 + 4)^2, sqrt(2), 17 % 5…"
                field.onAccepted: page.calcAccept()
                field.onTextChanged: page.calcSel = -1
                onKeyPressed: e => {
                    const n = page.calcHistory.length;
                    const ctrl = e.modifiers & Qt.ControlModifier;
                    if (ctrl && (e.key === Qt.Key_J || e.key === Qt.Key_N) && n)
                        page.calcSel = Math.min(n - 1, page.calcSel + 1);
                    else if (ctrl && (e.key === Qt.Key_K || e.key === Qt.Key_P))
                        page.calcSel = Math.max(-1, page.calcSel - 1);
                    else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && page.calcSel >= 0)
                        calcIn.text = page.calcHistory[page.calcSel].res;
                    else
                        return;
                    e.accepted = true;
                }
            }
            T {
                anchors.verticalCenter: undefined
                width: parent.width
                rightPadding: Tokens.padding.medium
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideLeft
                text: page.calcResult === null ? "…" : "= " + (page.calcResult || "0")
                color: page.calcResult === null ? Colors.subtext : Colors.accent
                font.pixelSize: Tokens.fontSize.extraLarge
                font.weight: Font.Medium
            }
            Repeater {
                model: page.calcHistory
                Rectangle {
                    required property var modelData
                    required property int index
                    width: page.pageWidth
                    height: 36
                    radius: Tokens.rounding.medium
                    color: index === page.calcSel ? Colors.surface2 : "transparent"
                    T {
                        x: Tokens.padding.medium
                        width: parent.width - 2 * Tokens.padding.medium
                        elide: Text.ElideRight
                        text: parent.modelData.expr + "  =  " + parent.modelData.res
                        color: Colors.subtext
                    }
                    StateLayer {
                        onClicked: {
                            calcIn.text = parent.modelData.res;
                            calcIn.focusField();
                        }
                    }
                }
            }
            Hint { text: "Enter copies the answer and keeps going from it · Ctrl+J/K + Enter or click reuses a line · Esc back" }
        }

        // ═══ TIMER ══════════════════════════════════════════════════════
        Column {
            id: timerView
            visible: page.view === "timer"
            width: page.pageWidth
            spacing: Tokens.spacing.large
            Keys.onEscapePressed: page.show("menu")
            Keys.onPressed: e => {
                if (page.timerTotal === 0)
                    return;
                if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                    page.timerToggle();
                else if (e.key === Qt.Key_R)
                    page.timerReset();
                else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal)
                    page.timerAdd(60);
                else
                    return;
                e.accepted = true;
            }

            // Not set: duration field + presets.
            Input {
                id: timerIn
                visible: page.timerTotal === 0
                width: parent.width
                glyph: String.fromCodePoint(0xF051B)
                field.placeholderText: "25m, 1h30m, 90s, 5:00…"
                field.onAccepted: {
                    page.timerStart(Tools.parseDuration(timerIn.text));
                    timerIn.text = "";
                }
                field.onTextChanged: presets.sel = -1
                onKeyPressed: e => {
                    const n = presets.model.length;
                    const ctrl = e.modifiers & Qt.ControlModifier;
                    if (ctrl && e.key === Qt.Key_L)
                        presets.sel = (presets.sel + 1) % n;
                    else if (ctrl && e.key === Qt.Key_H)
                        presets.sel = presets.sel <= 0 ? n - 1 : presets.sel - 1;
                    else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && presets.sel >= 0) {
                        const m = presets.model[presets.sel];
                        presets.sel = -1;
                        page.timerStart(m * 60);
                    } else
                        return;
                    e.accepted = true;
                }
            }
            Row {
                visible: page.timerTotal === 0
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Tokens.spacing.small
                Repeater {
                    id: presets
                    property int sel: -1 // preset picked with Ctrl+H/L; -1 = the field
                    model: [1, 5, 10, 15, 25, 60]
                    Btn {
                        required property int modelData
                        required property int index
                        selected: index === presets.sel
                        width: 80
                        text: modelData < 60 ? modelData + " min" : "1 hour"
                        onClicked: page.timerStart(modelData * 60)
                    }
                }
            }

            // Set: countdown, progress, controls.
            BigTime {
                visible: page.timerTotal > 0
                text: Tools.fmt(page.timerLeft + 999) // round up, so it ends on 0:00 not before
                dim: !page.timerRunning
            }
            Rectangle {
                visible: page.timerTotal > 0
                width: parent.width
                height: 6
                radius: 3
                color: Colors.surface1
                Rectangle {
                    width: parent.width * (page.timerTotal > 0 ? page.timerLeft / page.timerTotal : 0)
                    height: parent.height
                    radius: 3
                    color: Colors.accent
                }
            }
            Row {
                visible: page.timerTotal > 0
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Tokens.spacing.medium
                Btn { text: page.timerRunning ? "Pause" : "Resume"; selected: true; onClicked: page.timerToggle() }
                Btn { text: "+1 min"; onClicked: page.timerAdd(60) }
                Btn { text: "Reset"; onClicked: page.timerReset() }
            }
            Hint {
                text: page.timerTotal === 0 ? "Enter starts · a bare number means minutes · Ctrl+H/L pick a preset · Esc back"
                    : "Space/Enter pause · + one more minute · R reset · Esc back (keeps running)"
            }
        }

        // ═══ STOPWATCH ══════════════════════════════════════════════════
        Column {
            id: swView
            visible: page.view === "stopwatch"
            width: page.pageWidth
            spacing: Tokens.spacing.large
            Keys.onEscapePressed: page.show("menu")
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                    page.swToggle();
                else if (e.key === Qt.Key_L)
                    page.swLap();
                else if (e.key === Qt.Key_R)
                    page.swReset();
                else
                    return;
                e.accepted = true;
            }

            BigTime {
                text: Tools.fmt(page.swElapsed, true)
                dim: !page.swRunning
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Tokens.spacing.medium
                Btn { text: page.swRunning ? "Pause" : page.swElapsed > 0 ? "Resume" : "Start"; selected: true; onClicked: page.swToggle() }
                Btn { text: "Lap"; onClicked: page.swLap() }
                Btn { text: "Reset"; onClicked: page.swReset() }
            }
            Column {
                width: parent.width
                visible: page.laps.length > 0
                Repeater {
                    model: page.laps.slice(0, 5)
                    Item {
                        required property real modelData
                        required property int index
                        width: page.pageWidth
                        height: 30
                        T {
                            x: Tokens.padding.medium
                            text: "Lap " + (page.laps.length - parent.index)
                            color: Colors.subtext
                        }
                        T {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Tools.fmt(parent.modelData, true)
                        }
                        T {
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.padding.medium
                            text: "+" + Tools.fmt(parent.modelData - (page.laps[parent.index + 1] || 0), true)
                            color: Colors.subtext
                        }
                    }
                }
            }
            Hint { text: "Space start/pause · L lap · R reset · Esc back (keeps running)" }
        }

        // ═══ ALARMS ═════════════════════════════════════════════════════
        Column {
            visible: page.view === "alarm"
            width: page.pageWidth
            spacing: Tokens.spacing.small

            SearchList {
                id: alarmList
                listWidth: page.pageWidth
                glyph: String.fromCodePoint(0xF0020)
                placeholder: "Add: 7:30am Wake up"
                emptyText: "No alarms. Type a time and press Enter"
                // While typing: what Enter would add, or ? when it does not parse.
                countText: {
                    if (text.trim() === "")
                        return page.alarms.length + "";
                    const a = Tools.parseAlarm(text);
                    return a ? "Add " + Tools.clock12(a.h, a.m) : "?";
                }
                model: {
                    const t = minClock.date.getTime();
                    return page.alarms.map(a => ({
                                title: Tools.clock12(a.h, a.m) + (a.label ? "  ·  " + a.label : ""),
                                sub: a.on ? "Rings in " + Tools.fmtIn(a.at - t) : "Off",
                                glyph: String.fromCodePoint(0xF0020),
                                dim: !a.on
                            }));
                }
                onAccepted: i => {
                    if (alarmList.text.trim() !== "") {
                        if (page.addAlarm(alarmList.text))
                            alarmList.text = "";
                    } else if (page.alarms[i])
                        page.toggleAlarm(i);
                }
                onKeyPressed: e => {
                    if (e.key === Qt.Key_Delete && alarmList.text === "" && page.alarms[alarmList.currentIndex]) {
                        page.removeAlarm(alarmList.currentIndex);
                        e.accepted = true;
                    }
                }
                onEscaped: page.show("menu")
            }
            Hint { text: "Enter adds (or toggles the selected alarm) · Del removes · alarms ring once" }
        }
    }

    component Hint: T {
        anchors.verticalCenter: undefined
        width: page.pageWidth
        topPadding: Tokens.padding.small
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        color: Colors.subtext
        font.pixelSize: Tokens.fontSize.smaller
    }

    component BigTime: T {
        property bool dim
        anchors.verticalCenter: undefined
        width: page.pageWidth
        topPadding: Tokens.padding.medium
        horizontalAlignment: Text.AlignHCenter
        color: dim ? Colors.subtext : Colors.fg
        font.pixelSize: 56
        font.weight: Font.Light
        Behavior on color {
            CAnim {}
        }
    }

    // Search-field look from SearchList, with a leading glyph.
    component Input: Rectangle {
        id: input
        property alias field: tf
        property alias text: tf.text
        property string glyph
        // Seen before the field's own keys (it eats Ctrl+K and Ctrl+H); set e.accepted to take one.
        signal keyPressed(var e)
        function focusField() {
            tf.forceActiveFocus();
        }
        height: 50
        radius: Tokens.rounding.large
        color: Colors.inputBg
        border.width: 1
        border.color: tf.activeFocus ? Qt.alpha(Colors.accent, 0.6) : Colors.outline
        T {
            id: icon
            x: Tokens.padding.large
            text: parent.glyph
            color: Colors.accent
            font.pixelSize: Tokens.fontSize.large
        }
        StyledTextField {
            id: tf
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.small
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.small
            anchors.verticalCenter: parent.verticalCenter
            font.family: "SF Pro Display"
            font.pixelSize: Tokens.fontSize.larger
            background: null
            Keys.onPressed: e => input.keyPressed(e)
        }
    }

    component Btn: Rectangle {
        id: btn
        property string text
        property bool selected
        signal clicked
        width: 120
        height: 44
        radius: Tokens.rounding.medium
        color: selected ? Colors.accent : Colors.surface1
        T {
            anchors.centerIn: parent
            text: btn.text
            font.weight: Font.Medium
            color: btn.selected ? Colors.base : Colors.fg
        }
        StateLayer {
            onClicked: btn.clicked()
        }
    }
}
