//@ pragma UseQApplication
// Calendar — Quickshell frontend for khal. Replaces scripts/rofi/calendar.sh
// (rofi + zenity). Bound to Mod+Shift+C. Resident daemon, toggled over IPC.
//
// khal/ikhal/ics work lives in scripts/quickshell/calctl.sh; this UI renders
// the list, the event actions, and the add-event form (with a month grid).
// "Edit" still hands off to ikhal — khal has no CLI editor worth replacing.
//
// Views: main | add | submenu | details | confirm
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root
    readonly property string calctl: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell/calctl.sh"

    // Space-galaxy palette (matches scripts/rofi/config.rasi)
    readonly property color bg:      "#e61e1e2e"
    readonly property color inputBg: "#d0313244"
    readonly property color outline: "#45475a"
    readonly property color accent:  "#cba6f7"   // mauve
    readonly property color selBg:   "#45475a"   // surface1
    readonly property color fg:      "#cdd6f4"
    readonly property color subtext: "#7f849c"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    // ── state ─────────────────────────────────────────────────────────────
    property var    events: []
    property string view: "main"
    property string curUid: ""
    property string curTitle: ""
    property var    details: ({ title: "", time: "", loc: "", desc: "" })
    property string confirmLabel: ""
    property var    confirmAction: null

    readonly property var monthNames: ["January","February","March","April","May","June",
                                        "July","August","September","October","November","December"]
    readonly property var dowNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]

    // ── process plumbing ──────────────────────────────────────────────────
    Process { id: act }
    function run(args) { act.command = ["bash", calctl].concat(args); act.running = true; }
    Process {
        id: q
        property var cb: null
        stdout: StdioCollector { onStreamFinished: { var f = q.cb; q.cb = null; if (f) f(text.trim()); } }
    }
    function query(args, cb) { q.cb = cb; q.command = ["bash", calctl].concat(args); q.running = true; }
    function reload() { query(["list"], function (t) { try { events = JSON.parse(t); } catch (e) { events = []; } }); }

    IpcHandler {
        target: "cal"
        function toggle(): void {
            if (win.visible) { win.visible = false; return; }
            view = "main"; mainSearch.text = ""; reload(); win.visible = true;
        }
    }
    Component.onCompleted: reload()

    function hide() { win.visible = false; }

    function openActions(uid, title) {
        curUid = uid; curTitle = title;
        query(["details", uid], function (t) { try { details = JSON.parse(t); } catch (e) {} view = "submenu"; });
    }
    function doDelete() {
        confirmLabel = "Delete \"" + curTitle + "\"?";
        confirmAction = function () { run(["delete", curUid]); reload(); view = "main"; };
        view = "confirm";
    }
    function submitAdd() {
        if (addTitle.text.trim() === "") return;
        run(["add", cal.isoDate(), addStart.value(), addEnd.value(), addTitle.text, addDetails.text]);
        reload(); view = "main";
    }

    PanelWindow {
        id: win
        visible: false
        anchors { top: false; bottom: false; left: false; right: false }
        implicitWidth: 640
        readonly property int maxH: 560
        implicitHeight: view === "main"
            ? Math.min(maxH, 84 + Math.max(1, mainList.count) * 40)
            : maxH
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-calendar"

        onVisibleChanged: if (visible) Qt.callLater(function () { mainSearch.forceActiveFocus(); })

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: bg
            border.color: outline
            border.width: 1

            FocusScope {
                anchors.fill: parent
                anchors.margins: 14
                Keys.onEscapePressed: { if (view === "main") hide(); else view = "main"; }

                // ═══ MAIN (upcoming list + action rows) ═════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 10; visible: view === "main"
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 46; radius: 0
                        color: inputBg; border.color: accent; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                            Text { text: "󰸗"; color: accent; font.family: uiFont; font.pixelSize: 18 }
                            TextField {
                                id: mainSearch
                                Layout.fillWidth: true; focus: view === "main"
                                color: fg; font.family: uiFont; font.pixelSize: 16; background: null
                                placeholderText: "Filter events…  (type to search, Enter opens)"
                                placeholderTextColor: subtext
                                onTextChanged: mainList.currentIndex = 0
                                Keys.onPressed: (e) => {
                                    var m = mainList.currentItem ? mainList.currentItem.rowData : null;
                                    if (e.key === Qt.Key_Down)    { mainList.incrementCurrentIndex(); e.accepted = true; }
                                    else if (e.key === Qt.Key_Up) { mainList.decrementCurrentIndex(); e.accepted = true; }
                                    else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                        if (m) { if (m.act === "add") view = "add";
                                                 else if (m.act === "ikhal") { run(["edit"]); hide(); }
                                                 else openActions(m.uid, m.title); }
                                        e.accepted = true;
                                    }
                                }
                            }
                        }
                    }
                    ListView {
                        id: mainList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: {
                            var qy = mainSearch.text.toLowerCase();
                            var rows = [{ act: "add", label: "󰃷  Add event" }, { act: "ikhal", label: "󰸗  Open ikhal" }];
                            for (var i = 0; i < events.length; i++) {
                                var lbl = events[i].when + "   " + events[i].title;
                                rows.push({ uid: events[i].uid, title: events[i].title, label: lbl });
                            }
                            return rows.filter(function (r) { return qy === "" || r.label.toLowerCase().indexOf(qy) !== -1; });
                        }
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            property var rowData: modelData
                            width: ListView.view.width; height: 40; radius: 0
                            color: index === mainList.currentIndex ? selBg : "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                Text { text: modelData.act ? "" : "󰃭"; color: modelData.act ? accent : subtext
                                       font.family: uiFont; font.pixelSize: 14 }
                                Text { text: modelData.label; color: fg; font.family: uiFont; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true
                                onEntered: mainList.currentIndex = index
                                onClicked: { if (modelData.act === "add") view = "add";
                                             else if (modelData.act === "ikhal") { run(["edit"]); hide(); }
                                             else openActions(modelData.uid, modelData.title); }
                            }
                        }
                    }
                }

                // ═══ ADD EVENT (month grid + fields) ════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 8; visible: view === "add"
                    onVisibleChanged: if (visible) Qt.callLater(function () { cal.today(); calGrid.forceActiveFocus(); })
                    Text { text: "Add event"; color: accent; font.family: uiFont; font.pixelSize: 15; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        // date field (typed, kept in sync with the grid)
                        Rectangle {
                            Layout.preferredWidth: 160; implicitHeight: 38; radius: 0
                            color: inputBg; border.color: accent; border.width: 1
                            TextField {
                                id: dateField; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                                color: fg; font.family: uiFont; font.pixelSize: 14; background: null
                                text: cal.isoDate()
                                onEditingFinished: cal.setFromIso(text)
                            }
                        }
                        Text { text: "arrows move · Enter → title"; color: subtext; font.family: uiFont; font.pixelSize: 11; Layout.fillWidth: true }
                    }

                    // ── month grid ──────────────────────────────────────────
                    Item {
                        id: cal
                        Layout.fillWidth: true; Layout.preferredHeight: 240
                        focus: view === "add"
                        property int yr: 2026
                        property int mo: 0          // 0-11
                        property int dy: 1
                        function today() { var t = new Date(); yr = t.getFullYear(); mo = t.getMonth(); dy = t.getDate(); }
                        function daysIn(yy, mm) { return new Date(yy, mm + 1, 0).getDate(); }
                        function isoDate() {
                            var mm = ("0" + (mo + 1)).slice(-2), dd = ("0" + dy).slice(-2);
                            return yr + "-" + mm + "-" + dd;
                        }
                        function setFromIso(s) {
                            var p = s.split("-"); if (p.length !== 3) return;
                            var yy = parseInt(p[0]), mm = parseInt(p[1]) - 1, dd = parseInt(p[2]);
                            if (isNaN(yy) || isNaN(mm) || isNaN(dd)) return;
                            yr = yy; mo = mm; dy = Math.min(Math.max(1, dd), daysIn(yy, mm));
                        }
                        function move(delta) {   // move selected day by delta, rolling months/years
                            var dt = new Date(yr, mo, dy + delta);
                            yr = dt.getFullYear(); mo = dt.getMonth(); dy = dt.getDate();
                        }
                        function stepMonth(delta) {
                            var dt = new Date(yr, mo + delta, 1);
                            yr = dt.getFullYear(); mo = dt.getMonth();
                            dy = Math.min(dy, daysIn(yr, mo));
                        }
                        Keys.onPressed: (e) => {
                            if (e.key === Qt.Key_Left)       { move(-1); e.accepted = true; }
                            else if (e.key === Qt.Key_Right) { move(1);  e.accepted = true; }
                            else if (e.key === Qt.Key_Up)    { move(-7); e.accepted = true; }
                            else if (e.key === Qt.Key_Down)  { move(7);  e.accepted = true; }
                            else if (e.key === Qt.Key_PageUp)   { stepMonth(-1); e.accepted = true; }
                            else if (e.key === Qt.Key_PageDown) { stepMonth(1);  e.accepted = true; }
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { addTitle.forceActiveFocus(); e.accepted = true; }
                        }
                        ColumnLayout {
                            anchors.fill: parent; spacing: 4
                            // header
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "‹"; color: accent; font.family: uiFont; font.pixelSize: 18
                                       MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: cal.stepMonth(-1) } }
                                Text { text: monthNames[cal.mo] + " " + cal.yr; color: fg; font.family: uiFont; font.pixelSize: 15; font.bold: true
                                       Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                Text { text: "›"; color: accent; font.family: uiFont; font.pixelSize: 18
                                       MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: cal.stepMonth(1) } }
                            }
                            // weekday header
                            GridLayout {
                                Layout.fillWidth: true; columns: 7; columnSpacing: 2; rowSpacing: 2
                                Repeater {
                                    model: 7
                                    Text { required property int index; text: dowNames[index]; color: subtext
                                           font.family: uiFont; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                                }
                            }
                            // day cells (6 rows × 7)
                            GridLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true; columns: 7; columnSpacing: 2; rowSpacing: 2
                                Repeater {
                                    model: 42
                                    delegate: Rectangle {
                                        required property int index
                                        // first weekday of the month, and this cell's day number
                                        property int firstDow: new Date(cal.yr, cal.mo, 1).getDay()
                                        property int dayNum: index - firstDow + 1
                                        property bool inMonth: dayNum >= 1 && dayNum <= cal.daysIn(cal.yr, cal.mo)
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: 0
                                        color: (inMonth && dayNum === cal.dy) ? selBg : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: inMonth ? dayNum : ""
                                            color: (inMonth && dayNum === cal.dy) ? fg : subtext
                                            font.family: uiFont; font.pixelSize: 13
                                        }
                                        MouseArea {
                                            anchors.fill: parent; enabled: inMonth
                                            onClicked: { cal.dy = dayNum; cal.forceActiveFocus(); }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── time / title / details ──────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true; spacing: 20
                        TimePicker { id: addStart; label: "Start" }
                        TimePicker { id: addEnd;   label: "End" }
                        Item { Layout.fillWidth: true }
                    }
                    Text { text: "leave Start hour blank for an all-day event"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                    CalField { id: addTitle; ph: "Title (required)"; onSubmit: submitAdd() }
                    CalField { id: addDetails; ph: "Details (optional)"; onSubmit: submitAdd() }
                    Text { text: "Enter (in Title) saves · Esc cancels"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                }

                // ═══ SUBMENU (event actions) ════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 6; visible: view === "submenu"
                    onVisibleChanged: if (visible) Qt.callLater(function () { subList.currentIndex = 0; subList.forceActiveFocus(); })
                    Text { text: "󰃭  " + curTitle; color: accent; font.family: uiFont; font.pixelSize: 15; font.bold: true; Layout.bottomMargin: 6 }
                    ListView {
                        id: subList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        focus: view === "submenu"; keyNavigationEnabled: true
                        model: [{ id: "view", t: "󰋽  View details" }, { id: "copy", t: "  Copy details" },
                                { id: "edit", t: "󰏫  Edit (ikhal)" }, { id: "del", t: "󰆴  Delete" }]
                        boundsBehavior: Flickable.StopAtBounds
                        Keys.onReturnPressed: if (model[currentIndex]) runSub(model[currentIndex].id)
                        Keys.onEnterPressed:  if (model[currentIndex]) runSub(model[currentIndex].id)
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: ListView.view.width; implicitHeight: 40; radius: 0
                            color: index === subList.currentIndex ? selBg : "transparent"
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12
                                   text: modelData.t; color: fg; font.family: uiFont; font.pixelSize: 14 }
                            MouseArea { anchors.fill: parent; hoverEnabled: true
                                onEntered: subList.currentIndex = index; onClicked: runSub(modelData.id) }
                        }
                    }
                    Text { text: "↑↓ move · Enter select · Esc back"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                }

                // ═══ DETAILS ════════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 8; visible: view === "details"
                    Text { text: details.title; color: accent; font.family: uiFont; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    Text { text: "When:  " + details.time; color: fg; font.family: uiFont; font.pixelSize: 13; visible: details.time !== "" }
                    Text { text: "Where: " + details.loc;  color: fg; font.family: uiFont; font.pixelSize: 13; visible: details.loc !== "" }
                    Text { text: details.desc; color: subtext; font.family: uiFont; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap; visible: details.desc !== "" }
                    Item { Layout.fillHeight: true }
                    Text { text: "Esc — back"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                }

                // ═══ CONFIRM ════════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 16; visible: view === "confirm"
                    Item { Layout.fillHeight: true }
                    Text { text: confirmLabel; color: fg; font.family: uiFont; font.pixelSize: 16; Layout.alignment: Qt.AlignHCenter
                           horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 14
                        Rectangle { implicitWidth: 120; implicitHeight: 42; radius: 0; color: selBg
                            Text { anchors.centerIn: parent; text: "Yes"; color: fg; font.family: uiFont; font.pixelSize: 15; font.bold: true }
                            MouseArea { anchors.fill: parent; onClicked: { var f = confirmAction; confirmAction = null; if (f) f(); } } }
                        Rectangle { implicitWidth: 120; implicitHeight: 42; radius: 0; color: inputBg; border.color: outline; border.width: 1
                            Text { anchors.centerIn: parent; text: "No"; color: fg; font.family: uiFont; font.pixelSize: 15 }
                            MouseArea { anchors.fill: parent; onClicked: view = "submenu" } }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    function runSub(id) {
        switch (id) {
        case "view": view = "details"; break;
        case "copy": run(["copy", curUid]); hide(); break;
        case "edit": run(["edit"]); hide(); break;
        case "del":  doDelete(); break;
        }
    }

    // hour : minute  AM/PM  time entry. value() -> "hh:mm AM" or "" if hour blank.
    component TimePicker: RowLayout {
        id: tp
        property string label: ""
        property bool pm: false
        function value() {
            var h = hourF.text.trim();
            if (h === "") return "";
            var mm = minF.text.trim() === "" ? "00" : ("0" + minF.text.trim()).slice(-2);
            return h + ":" + mm + " " + (pm ? "PM" : "AM");
        }
        spacing: 6
        Text { text: tp.label; color: subtext; font.family: uiFont; font.pixelSize: 12 }
        Rectangle {
            implicitWidth: 42; implicitHeight: 34; radius: 0; color: inputBg; border.color: accent; border.width: 1
            TextField { id: hourF; anchors.fill: parent; anchors.margins: 2; horizontalAlignment: TextInput.AlignHCenter
                color: fg; font.family: uiFont; font.pixelSize: 14; background: null
                maximumLength: 2; inputMethodHints: Qt.ImhDigitsOnly
                placeholderText: "hh"; placeholderTextColor: subtext }
        }
        Text { text: ":"; color: fg; font.family: uiFont; font.pixelSize: 15 }
        Rectangle {
            implicitWidth: 42; implicitHeight: 34; radius: 0; color: inputBg; border.color: accent; border.width: 1
            TextField { id: minF; anchors.fill: parent; anchors.margins: 2; horizontalAlignment: TextInput.AlignHCenter
                color: fg; font.family: uiFont; font.pixelSize: 14; background: null
                maximumLength: 2; inputMethodHints: Qt.ImhDigitsOnly
                placeholderText: "mm"; placeholderTextColor: subtext }
        }
        Rectangle {
            implicitWidth: 46; implicitHeight: 34; radius: 0
            color: tp.pm ? selBg : inputBg; border.color: accent; border.width: 1
            Text { anchors.centerIn: parent; text: tp.pm ? "PM" : "AM"; color: fg; font.family: uiFont; font.pixelSize: 13; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: tp.pm = !tp.pm }
        }
    }

    // labeled single-line input used by the add form
    component CalField: Rectangle {
        property string ph: ""
        property alias text: tf.text
        signal submit()
        Layout.fillWidth: true; implicitHeight: 38; radius: 0
        color: inputBg; border.color: accent; border.width: 1
        TextField {
            id: tf; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            color: fg; font.family: uiFont; font.pixelSize: 14; background: null
            placeholderText: ph; placeholderTextColor: subtext
            onAccepted: submit()
        }
    }
}
