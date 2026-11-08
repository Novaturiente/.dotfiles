// Calendar island page: a month grid with khal events and Kerala + India
// holidays marked, the selected day's events beside it, event actions and the
// add-event form.
//
// khal/ikhal/ics and holiday work lives in scripts/quickshell/calctl.sh. "Edit"
// hands off to ikhal — khal has no CLI editor worth replacing.
//
// Views: main | add | submenu | details | confirm
import Quickshell
import Quickshell.Io
import QtQuick
import common

Page {
    id: page

    readonly property string calctl: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell/calctl.sh"
    readonly property int pageWidth: 720
    readonly property int gridWidth: 336

    property string view: "main"
    property string curUid: ""
    property string curTitle: ""
    property string curDate: ""
    property var details: ({ title: "", time: "", loc: "", desc: "" })
    property bool confirmYes: false

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]
    readonly property var dowNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    // ── selected date, shared by the main grid and the add form ─────────
    property int yr: 2026
    property int mo: 0 // 0-11
    property int dy: 1
    property date now: new Date()
    readonly property string ym: yr + "-" + ("0" + (mo + 1)).slice(-2)
    function iso(d) { return ym + "-" + ("0" + d).slice(-2); }
    function isoDate() { return iso(dy); }
    function today() { const t = new Date(); now = t; yr = t.getFullYear(); mo = t.getMonth(); dy = t.getDate(); }
    function daysIn(yy, mm) { return new Date(yy, mm + 1, 0).getDate(); }
    function setFromIso(s) {
        const p = s.split("-");
        if (p.length !== 3) return;
        const yy = parseInt(p[0]), mm = parseInt(p[1]) - 1, dd = parseInt(p[2]);
        if (isNaN(yy) || isNaN(mm) || isNaN(dd)) return;
        yr = yy; mo = mm; dy = Math.min(Math.max(1, dd), daysIn(yy, mm));
    }
    function move(delta) { // move selected day by delta, rolling months/years
        const dt = new Date(yr, mo, dy + delta);
        yr = dt.getFullYear(); mo = dt.getMonth(); dy = dt.getDate();
    }
    // Plain letter key as "h" or, with Shift, "H"; "" for anything else. From
    // e.key, not e.text: virtual keyboards (wtype) can send Shift+g as text "g".
    function vimKey(e) {
        if (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier) || e.key < Qt.Key_A || e.key > Qt.Key_Z)
            return "";
        const c = String.fromCharCode(e.key); // Key_A..Key_Z are ASCII A..Z
        return e.modifiers & Qt.ShiftModifier ? c : c.toLowerCase();
    }
    function stepMonth(delta) {
        const dt = new Date(yr, mo + delta, 1);
        yr = dt.getFullYear(); mo = dt.getMonth();
        dy = Math.min(dy, daysIn(yr, mo));
    }

    // ── month data: { events: [{date, uid, time, title}], holidays: {iso: name} } ──
    property var month: ({ events: [], holidays: {} })
    readonly property var eventDays: {
        const s = {};
        for (const e of month.events) s[e.date] = true;
        return s;
    }
    readonly property var dayEvents: month.events.filter(e => e.date === isoDate())
    readonly property string dayHoliday: month.holidays[isoDate()] || ""
    onYmChanged: reload()

    Process {
        id: monthProc
        property string asked
        stdout: StdioCollector {
            onStreamFinished: {
                if (monthProc.asked !== page.ym) { // month changed while loading
                    page.reload();
                    return;
                }
                try { page.month = JSON.parse(text); } catch (e) { page.month = { events: [], holidays: {} }; }
            }
        }
    }
    // Runs again from onStreamFinished if the month changes mid-load.
    function reload() {
        if (monthProc.running) return;
        monthProc.asked = ym;
        monthProc.command = ["bash", calctl, "month", ym];
        monthProc.running = true;
    }

    // Fire-and-forget actions; every one may change events, so reload after.
    Process { id: act; onExited: page.reload() }
    function run(args) { act.command = ["bash", calctl].concat(args); act.running = true; }
    Process {
        id: q
        property var cb: null
        stdout: StdioCollector { onStreamFinished: { const f = q.cb; q.cb = null; if (f) f(text.trim()); } }
    }
    function query(args, cb) { q.cb = cb; q.command = ["bash", calctl].concat(args); q.running = true; }

    function showMain() {
        view = "main";
        Qt.callLater(() => mainGrid.forceActiveFocus());
    }
    // A day with events or a holiday shows its list; an empty day goes to the add form.
    function openDay() {
        if (dayEvents.length || dayHoliday) {
            dayList.reset();
            dayList.focusField();
        } else
            openAdd();
    }
    function openActions(uid, title) {
        curUid = uid;
        curTitle = title;
        curDate = isoDate();
        query(["details", uid, curDate], t => {
            try { details = JSON.parse(t); } catch (e) {}
            view = "submenu";
            subList.reset();
            Qt.callLater(() => subList.focusField());
        });
    }
    function openAdd() {
        view = "add";
        startPicker.clear();
        endPicker.clear();
        addTitle.text = "";
        addDetails.text = "";
        Qt.callLater(() => addGrid.forceActiveFocus());
    }
    function submitAdd() {
        if (addTitle.text.trim() === "")
            return;
        run(["add", isoDate(), startPicker.value(), endPicker.value(), addTitle.text, addDetails.text]);
        showMain();
    }
    function runSub(id) {
        switch (id) {
        case "view":
            view = "details";
            Qt.callLater(() => detailsView.forceActiveFocus());
            break;
        case "copy":
            run(["copy", curUid, curDate]);
            closeRequested();
            break;
        case "edit":
            run(["edit"]);
            closeRequested();
            break;
        case "del":
            confirmYes = false;
            view = "confirm";
            Qt.callLater(() => confirmView.forceActiveFocus());
            break;
        }
    }
    function confirm(yes) {
        if (yes) {
            run(["delete", curUid]);
            showMain();
        } else {
            view = "submenu";
            Qt.callLater(() => subList.focusField());
        }
    }

    onOpened: {
        today();
        reload();
        dayList.reset();
        showMain();
    }

    Column {
        width: page.pageWidth

        // ═══ MAIN ═══════════════════════════════════════════════════════
        Column {
            visible: page.view === "main"
            width: page.pageWidth
            spacing: Tokens.spacing.medium
            topPadding: Tokens.padding.small
            bottomPadding: Tokens.padding.small

            Row {
                spacing: Tokens.spacing.extraLarge

                MonthGrid {
                    id: mainGrid
                    onPicked: page.openDay()
                    onEscaped: page.closeRequested()
                    onTabbed: dayList.focusField()
                }

                Column {
                    id: dayCol
                    width: page.pageWidth - page.gridWidth - parent.spacing
                    spacing: Tokens.spacing.small

                    T {
                        anchors.verticalCenter: undefined
                        width: parent.width
                        leftPadding: Tokens.padding.small
                        text: Qt.formatDate(new Date(page.yr, page.mo, page.dy), "dddd, d MMMM yyyy")
                        font.weight: Font.Medium
                        font.pixelSize: Tokens.fontSize.larger
                    }
                    T {
                        anchors.verticalCenter: undefined
                        visible: page.dayHoliday !== ""
                        width: parent.width
                        leftPadding: Tokens.padding.small
                        text: page.dayHoliday
                        wrapMode: Text.WordWrap
                        color: Colors.red
                    }
                    SearchList {
                        id: dayList
                        listWidth: dayCol.width
                        maxRows: 6
                        glyph: "󰸗"
                        placeholder: "Filter this day…"
                        emptyText: "No matching events"
                        countText: page.dayEvents.length + ""
                        model: {
                            const qy = text.toLowerCase();
                            const rows = page.dayEvents.map(e => ({ uid: e.uid, title: e.title, sub: e.time || "All day", glyph: "󰃭" }));
                            rows.push({ act: "add", title: "Add event", sub: "On " + page.isoDate(), glyph: "󰃷" });
                            return rows.filter(r => qy === "" || (r.title + " " + r.sub).toLowerCase().indexOf(qy) !== -1);
                        }
                        onAccepted: (i, row) => {
                            if (!row) return;
                            if (row.act === "add") page.openAdd();
                            else page.openActions(row.uid, row.title);
                        }
                        onEscaped: mainGrid.forceActiveFocus()
                    }
                }
            }

            Label { text: "Arrows/hjkl move the day · g/G first/last · PgUp/PgDn or H/L month · Home/t today · Enter opens the day · Tab events · Esc closes" }
        }

        // ═══ ADD EVENT ══════════════════════════════════════════════════
        Column {
            visible: page.view === "add"
            width: page.pageWidth
            spacing: Tokens.spacing.large
            topPadding: Tokens.padding.small
            bottomPadding: Tokens.padding.medium
            Keys.onEscapePressed: page.showMain()

            T {
                anchors.verticalCenter: undefined
                text: "Add event"
                font.weight: Font.Medium
                font.pixelSize: Tokens.fontSize.larger
            }

            Row {
                spacing: Tokens.spacing.extraLarge

                // ── left: date field + month grid ──────────────────────
                Column {
                    width: page.gridWidth
                    spacing: Tokens.spacing.medium

                    Label { text: "Date" }
                    Input {
                        width: parent.width
                        field.text: page.isoDate()
                        field.placeholderText: "YYYY-MM-DD"
                        field.onEditingFinished: {
                            page.setFromIso(field.text);
                            field.text = Qt.binding(() => page.isoDate());
                        }
                    }
                    MonthGrid {
                        id: addGrid
                        activeFocusOnTab: true
                        onPicked: addTitle.focusField()
                        onEscaped: page.showMain()
                        onTabbed: addGrid.nextItemInFocusChain().forceActiveFocus()
                    }
                }

                // ── right: times, title, details ───────────────────────
                Column {
                    width: page.pageWidth - page.gridWidth - parent.spacing
                    spacing: Tokens.spacing.medium

                    TimePicker { id: startPicker; label: "Start" }
                    TimePicker { id: endPicker; label: "End" }
                    Label { text: "Leave Start hour blank for an all-day event" }

                    Item { width: 1; height: Tokens.spacing.small }

                    Label { text: "Title" }
                    Input {
                        id: addTitle
                        width: parent.width
                        field.placeholderText: "Title (required)"
                        field.onAccepted: page.submitAdd()
                    }
                    Label { text: "Details" }
                    Input {
                        id: addDetails
                        width: parent.width
                        field.placeholderText: "Details (optional)"
                        field.onAccepted: page.submitAdd()
                    }
                }
            }

            Label { text: "Arrows/hjkl move the day · H/L month · Enter → Title · Tab next field · Space AM/PM · Enter in Title saves · Esc cancels" }
        }

        // ═══ SUBMENU ════════════════════════════════════════════════════
        Column {
            visible: page.view === "submenu"
            width: page.pageWidth
            spacing: Tokens.spacing.small
            topPadding: Tokens.padding.small

            T {
                anchors.verticalCenter: undefined
                width: parent.width
                leftPadding: Tokens.padding.small
                text: "󰃭  " + page.curTitle
                elide: Text.ElideRight
                font.weight: Font.Medium
                font.pixelSize: Tokens.fontSize.larger
            }
            SearchList {
                id: subList
                listWidth: page.pageWidth
                glyph: "󰃭"
                placeholder: "Choose an action…"
                emptyText: "No matching action"
                model: {
                    const qy = text.toLowerCase();
                    return [
                        { id: "view", title: "View details", sub: "When, where and description", glyph: "󰋽" },
                        { id: "copy", title: "Copy details", sub: "Copy the event to the clipboard", glyph: "󰆏" },
                        { id: "edit", title: "Edit (ikhal)", sub: "Open the calendar in ikhal", glyph: "󰏫" },
                        { id: "del", title: "Delete", sub: "Remove this event", glyph: "󰆴" }
                    ].filter(r => qy === "" || r.title.toLowerCase().indexOf(qy) !== -1);
                }
                onAccepted: (i, row) => { if (row) page.runSub(row.id); }
                onEscaped: page.showMain()
            }
        }

        // ═══ DETAILS ════════════════════════════════════════════════════
        Column {
            id: detailsView
            visible: page.view === "details"
            width: page.pageWidth
            spacing: Tokens.spacing.medium
            padding: Tokens.padding.medium
            Keys.onEscapePressed: page.showMain()

            T {
                anchors.verticalCenter: undefined
                width: parent.width - 2 * parent.padding
                text: page.details.title || page.curTitle
                wrapMode: Text.WordWrap
                font.weight: Font.Medium
                font.pixelSize: Tokens.fontSize.large
            }
            DetailRow { label: "When"; value: page.details.time || "" }
            DetailRow { label: "Where"; value: page.details.loc || "" }
            T {
                anchors.verticalCenter: undefined
                visible: text !== ""
                width: parent.width - 2 * parent.padding
                topPadding: Tokens.padding.small
                text: page.details.desc || ""
                wrapMode: Text.WordWrap
                color: Colors.subtext
                lineHeight: 1.2
            }
            Label { topPadding: Tokens.padding.small; text: "Esc — back" }
        }

        // ═══ CONFIRM ════════════════════════════════════════════════════
        Column {
            id: confirmView
            visible: page.view === "confirm"
            width: page.pageWidth
            spacing: Tokens.spacing.extraLarge
            topPadding: Tokens.padding.extraLarge
            bottomPadding: Tokens.padding.extraLarge
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) page.showMain();
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab || page.vimKey(e) === "h" || page.vimKey(e) === "l") page.confirmYes = !page.confirmYes;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) page.confirm(page.confirmYes);
                else return;
                e.accepted = true;
            }

            T {
                anchors.verticalCenter: undefined
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Delete \"" + page.curTitle + "\"?"
                font.weight: Font.Medium
                font.pixelSize: Tokens.fontSize.large
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Tokens.spacing.large
                Button { text: "Yes"; selected: page.confirmYes; destructive: true; onClicked: page.confirm(true) }
                Button { text: "No"; selected: !page.confirmYes; onClicked: page.confirm(false) }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "←/→ or h/l choose · Enter confirm · Esc back"
            }
        }
    }

    // Month grid on the page's selected date. Red numbers = holidays, dot = events.
    // picked(): Enter or a click on a day. Esc/Tab are handed to the view.
    component MonthGrid: Item {
        id: grid
        signal picked
        signal escaped
        signal tabbed
        width: page.gridWidth
        height: calCol.implicitHeight + 2 * Tokens.padding.small
        Keys.onPressed: e => {
            const v = page.vimKey(e);
            if (e.key === Qt.Key_Left || v === "h") page.move(-1);
            else if (e.key === Qt.Key_Right || v === "l") page.move(1);
            else if (e.key === Qt.Key_Up || v === "k") page.move(-7);
            else if (e.key === Qt.Key_Down || v === "j") page.move(7);
            else if (e.key === Qt.Key_PageUp || v === "H") page.stepMonth(-1);
            else if (e.key === Qt.Key_PageDown || v === "L") page.stepMonth(1);
            else if (v === "g") page.dy = 1;
            else if (v === "G") page.dy = page.daysIn(page.yr, page.mo);
            else if (e.key === Qt.Key_Home || v === "t") page.today();
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) grid.picked();
            else if (e.key === Qt.Key_Escape) grid.escaped();
            else if (e.key === Qt.Key_Tab) grid.tabbed();
            else return;
            e.accepted = true;
        }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: "transparent"
            border.width: 1
            border.color: grid.activeFocus ? Qt.alpha(Colors.accent, 0.6) : Colors.outline
        }

        Column {
            id: calCol
            x: Tokens.padding.small
            y: Tokens.padding.small
            width: parent.width - 2 * Tokens.padding.small
            spacing: Tokens.spacing.small

            Item {
                width: parent.width
                height: 36
                T {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.medium
                    text: "‹"
                    color: Colors.accent
                    font.pixelSize: Tokens.fontSize.large
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { page.stepMonth(-1); grid.forceActiveFocus(); } }
                }
                T {
                    anchors.centerIn: parent
                    text: page.monthNames[page.mo] + " " + page.yr
                    font.weight: Font.Medium
                    font.pixelSize: Tokens.fontSize.larger
                    MouseArea { anchors.fill: parent; onClicked: { page.today(); grid.forceActiveFocus(); } }
                }
                T {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.padding.medium
                    text: "›"
                    color: Colors.accent
                    font.pixelSize: Tokens.fontSize.large
                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { page.stepMonth(1); grid.forceActiveFocus(); } }
                }
            }

            Grid {
                columns: 7
                Repeater {
                    model: 7
                    T {
                        required property int index
                        anchors.verticalCenter: undefined
                        width: calCol.width / 7
                        height: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: page.dowNames[index]
                        color: Colors.subtext
                        font.pixelSize: Tokens.fontSize.smaller
                    }
                }
            }

            // day cells (6 rows × 7)
            Grid {
                columns: 7
                Repeater {
                    model: 42
                    Item {
                        id: cell
                        required property int index
                        // first weekday of the month, and this cell's day number
                        readonly property int firstDow: new Date(page.yr, page.mo, 1).getDay()
                        readonly property int dayNum: index - firstDow + 1
                        readonly property bool inMonth: dayNum >= 1 && dayNum <= page.daysIn(page.yr, page.mo)
                        readonly property bool sel: inMonth && dayNum === page.dy
                        readonly property bool isToday: inMonth && dayNum === page.now.getDate()
                            && page.mo === page.now.getMonth() && page.yr === page.now.getFullYear()
                        readonly property bool holiday: inMonth && !!page.month.holidays[page.iso(dayNum)]
                        readonly property bool hasEvents: inMonth && !!page.eventDays[page.iso(dayNum)]
                        width: calCol.width / 7
                        height: 38
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Tokens.rounding.medium
                            color: cell.sel ? Colors.accent : cellHover.containsMouse && cell.inMonth ? Colors.surface1 : "transparent"
                            border.width: cell.isToday && !cell.sel ? 1 : 0
                            border.color: Colors.accent
                            T {
                                anchors.centerIn: parent
                                text: cell.inMonth ? cell.dayNum : ""
                                color: cell.sel ? Colors.base : cell.holiday ? Colors.red : cell.isToday ? Colors.accent : Colors.fg
                                font.weight: cell.sel || cell.isToday || cell.holiday ? Font.Medium : Font.Normal
                            }
                            Rectangle {
                                visible: cell.hasEvents
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                width: 5
                                height: 5
                                radius: 2.5
                                color: cell.sel ? Colors.base : Colors.accent
                            }
                        }
                        MouseArea {
                            id: cellHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: cell.inMonth
                            onClicked: { page.dy = cell.dayNum; grid.forceActiveFocus(); grid.picked(); }
                        }
                    }
                }
            }
        }
    }

    component Label: T {
        anchors.verticalCenter: undefined
        color: Colors.subtext
        font.pixelSize: Tokens.fontSize.smaller
    }

    component DetailRow: Row {
        property string label
        property string value
        visible: value !== ""
        spacing: Tokens.spacing.medium
        Label { width: 64; text: parent.label; anchors.baseline: valueText.baseline }
        T {
            id: valueText
            anchors.verticalCenter: undefined
            width: page.pageWidth - 64 - 2 * Tokens.padding.medium - Tokens.spacing.medium
            text: parent.value
            wrapMode: Text.WordWrap
        }
    }

    // Input box in the SearchList look; `field` is the text field inside.
    component Input: Rectangle {
        property alias field: tf
        property alias text: tf.text
        property bool centered: false
        function focusField() { tf.forceActiveFocus(); }
        height: 50
        radius: Tokens.rounding.large
        color: Colors.inputBg
        border.width: 1
        border.color: tf.activeFocus ? Qt.alpha(Colors.accent, 0.6) : Colors.outline
        StyledTextField {
            id: tf
            anchors.fill: parent
            anchors.leftMargin: parent.centered ? 0 : Tokens.padding.small
            anchors.rightMargin: parent.centered ? 0 : Tokens.padding.small
            horizontalAlignment: parent.centered ? TextInput.AlignHCenter : TextInput.AlignLeft
            leftPadding: parent.centered ? padding : padding + 4
            font.family: "SF Pro Display"
            font.pixelSize: Tokens.fontSize.larger
            background: null
        }
    }

    component Button: Rectangle {
        id: btn
        property string text
        property bool selected
        property bool destructive
        signal clicked
        width: 132
        height: 44
        radius: Tokens.rounding.medium
        color: !selected ? (bHover.containsMouse ? Colors.surface2 : Colors.surface1) : destructive ? Colors.red : Colors.accent
        border.width: activeFocus ? 2 : 0
        border.color: selected ? Colors.fg : Colors.accent
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                btn.clicked();
                e.accepted = true;
            }
        }
        T {
            anchors.centerIn: parent
            text: btn.text
            font.weight: Font.Medium
            font.pixelSize: Tokens.fontSize.larger
            color: !btn.selected ? Colors.fg : btn.destructive ? Colors.crust : Colors.base
        }
        MouseArea { id: bHover; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }

    // hour : minute  AM/PM. value() -> "h:mm AM" or "" if hour blank.
    component TimePicker: Row {
        id: tp
        property string label
        property bool pm: false
        function value() {
            const h = hourF.text.trim();
            if (h === "") return "";
            const mm = minF.text.trim() === "" ? "00" : ("0" + minF.text.trim()).slice(-2);
            return h + ":" + mm + " " + (pm ? "PM" : "AM");
        }
        function clear() { hourF.text = ""; minF.text = ""; pm = false; }
        spacing: Tokens.spacing.small

        Label { width: 56; anchors.verticalCenter: parent.verticalCenter; text: tp.label }
        Input {
            id: hourF
            width: 64
            centered: true
            field.maximumLength: 2
            field.inputMethodHints: Qt.ImhDigitsOnly
            field.placeholderText: "hh"
        }
        T { text: ":"; font.pixelSize: Tokens.fontSize.large }
        Input {
            id: minF
            width: 64
            centered: true
            field.maximumLength: 2
            field.inputMethodHints: Qt.ImhDigitsOnly
            field.placeholderText: "mm"
        }
        Item { width: Tokens.spacing.extraSmall; height: 1 }
        Button {
            width: 72
            activeFocusOnTab: true
            anchors.verticalCenter: parent.verticalCenter
            text: tp.pm ? "PM" : "AM"
            selected: tp.pm
            onClicked: tp.pm = !tp.pm
        }
    }
}