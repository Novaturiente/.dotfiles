// Password manager page (Bitwarden vault via rbw), ported from pass/shell.qml.
//
// SECURITY: this page only ever sees entry UUIDs and labels. Every secret
// (password, TOTP, autotype) flows through scripts/quickshell/passctl.sh to the
// clipboard or wtype, never through QML.
//
// Views: main | submenu | add | editseq | confirm
import Quickshell
import Quickshell.Io
import QtQuick
import common

Page {
    id: page

    readonly property string passctl: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell/passctl.sh"

    // Set by the shell before opening: the focused window's domain.
    property string prefill: ""

    property var entries: []          // [{entry(uuid),domain,user}]
    property string view: "main"
    property string curEntry: ""      // uuid under action (submenu/confirm)
    property string curLabel: ""      // human label for the same entry
    property bool curHasOtp: false
    property var subModel: []
    property string confirmLabel: ""
    property var confirmAction: null  // function to run on Yes
    property int confirmSel: 1        // 0 Yes, 1 No: Enter on a fresh dialog is the safe answer

    // fire-and-forget (copy/totp/autotype/delete/set/...)
    Process { id: act }
    function run(args) { act.command = ["bash", passctl].concat(args); act.running = true; }

    // query with stdout callback (list/exists/get-autotype/has-otp)
    Process {
        id: q
        property var cb: null
        stdout: StdioCollector { onStreamFinished: { var f = q.cb; q.cb = null; if (f) f(text.trim()); } }
    }
    function query(args, cb) { q.cb = cb; q.command = ["bash", passctl].concat(args); q.running = true; }

    function reload() { query(["list"], function (t) { try { entries = JSON.parse(t); } catch (e) { entries = []; } }); }

    onOpened: {
        view = "main";
        mainList.reset();
        mainList.text = prefill;
        reload();          // passctl serializes the vault unlock (flock), so
        run(["sync"]);     // firing these concurrently prompts pinentry only once
        Qt.callLater(() => mainList.focusField());
    }

    onViewChanged: Qt.callLater(() => {
        if (view === "main") mainList.focusField();
        else if (view === "submenu") { subList.reset(); subList.focusField(); }
        else if (view === "add") { fUrl.value = ""; fUser.value = ""; fPw.value = ""; fUrl.focusInput(); }
        else if (view === "editseq") seqField.focusInput();
        else if (view === "confirm") { confirmSel = 1; confirmBox.forceActiveFocus(); }
    })

    function back() {
        if (view === "main") closeRequested();
        else view = "main";
    }

    // ── actions (all dispatch to passctl; the island closes so focus returns) ──
    function copyEntry(e)   { run(["copy", e]); closeRequested(); }
    function copyField(e,f) { run(["copy-field", e, f]); closeRequested(); }
    function totp(e)        { run(["totp", e]); closeRequested(); }
    function autotype(e)    { closeRequested(); run(["autotype", e]); }   // close first, then type
    function del(e)         { run(["delete", e]); reload(); }
    function editEntry(e)   { run(["edit", e]); closeRequested(); }

    function openSubmenu(e, label) {
        curEntry = e;
        curLabel = label;
        query(["has-otp", e], function (t) {
            curHasOtp = (t === "yes");
            var m = [{ id: "cp", title: "Copy Password", glyph: "\uf084" },
                     { id: "cu", title: "Copy Username", glyph: "\uf007" }];
            if (curHasOtp) m.push({ id: "ct", title: "Copy TOTP", glyph: "\uf017" });
            m.push({ id: "at", title: "Auto-type", glyph: "\uf11c" },
                   { id: "ea", title: "Edit Autotype", glyph: "\uf040" },
                   { id: "ed", title: "Edit", glyph: "\uf044" },
                   { id: "de", title: "Delete", glyph: "\uf1f8" });
            subModel = m;
            view = "submenu";
        });
    }
    function runSubAction(id) {
        switch (id) {
        case "cp": copyField(curEntry, "password"); break;
        case "cu": copyField(curEntry, "username"); break;
        case "ct": totp(curEntry); break;
        case "at": autotype(curEntry); break;
        case "ea": query(["get-autotype", curEntry], function (t) { seqField.value = t; view = "editseq"; }); break;
        case "ed": editEntry(curEntry); break;
        case "de": confirmLabel = "Delete " + curLabel + "?";
                   confirmAction = function () { del(curEntry); view = "main"; }; view = "confirm"; break;
        }
    }

    function submitAdd(url, user, pw) {
        if (url.trim() === "" || user.trim() === "") return;
        var name = url.replace(/https?:\/\//, "").replace(/www\./, "").replace(/\/.*/, "");
        query(["exists", name, user], function (t) {
            if (t === "yes") {
                confirmLabel = name + " (" + user + ") exists. Overwrite password?";
                confirmAction = function () { run(["add", url, user, pw]); reload(); view = "main"; };
                view = "confirm";
            } else {
                run(["add", url, user, pw]); reload(); view = "main";
            }
        });
    }

    function confirm(yes) {
        if (!yes) { view = "main"; return; }
        var f = confirmAction; confirmAction = null; if (f) f();
    }

    Column {
        width: 720
        spacing: Tokens.spacing.medium

        // ═══ MAIN ═══════════════════════════════════════════════════════
        SearchList {
            id: mainList
            visible: page.view === "main"
            glyph: "\u{f0349}" // nf-md-magnify (U+F002 is the fl ligature in SF Pro)
            placeholder: "Search…  Enter copy · Alt+1 type · Alt+2 TOTP · Shift+Enter/Alt+3 more"
            emptyText: page.entries.length ? "No matching entries" : "Vault empty or locked"
            countText: page.entries.length + ""
            model: {
                var q = text.toLowerCase();
                var rows = [{ action: "add-pw", label: "+ Add Password", title: "Add Password", sub: "New entry", glyph: "\uf067" }];
                for (var i = 0; i < page.entries.length; i++) {
                    var e = page.entries[i];
                    var lbl = e.domain + " — " + e.user;
                    if (q === "" || lbl.toLowerCase().indexOf(q) !== -1)
                        rows.push({ entry: e.entry, label: lbl, title: e.domain, sub: e.user, glyph: "\uf084" });
                }
                // action rows only when they match the query
                return rows.filter(function (r) { return q === "" || r.label.toLowerCase().indexOf(q) !== -1; });
            }
            onAccepted: (i, m) => {
                if (!m) return;
                if (m.action === "add-pw") page.view = "add";
                else page.copyEntry(m.entry);
            }
            onEscaped: page.back()
            onKeyPressed: e => {
                var m = current;
                var alt = e.modifiers & Qt.AltModifier;
                if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ShiftModifier)) {
                    if (m && !m.action) page.openSubmenu(m.entry, m.label);   // Shift+Enter -> more options
                } else if (alt && e.key === Qt.Key_1) { if (m && !m.action) page.autotype(m.entry); }
                else if (alt && e.key === Qt.Key_2) { if (m && !m.action) page.totp(m.entry); }
                else if (alt && e.key === Qt.Key_3) { if (m && !m.action) page.openSubmenu(m.entry, m.label); }
                else return;
                e.accepted = true;
            }
        }

        // ═══ SUBMENU ════════════════════════════════════════════════════
        Column {
            visible: page.view === "submenu"
            width: parent.width
            spacing: Tokens.spacing.small
            topPadding: Tokens.padding.small

            SectionTitle { text: page.curLabel }
            SearchList {
                id: subList
                glyph: "\uf03a"
                placeholder: "Filter actions…"
                model: {
                    var q = text.toLowerCase();
                    return page.subModel.filter(r => r.title.toLowerCase().indexOf(q) !== -1);
                }
                onAccepted: (i, m) => { if (m) page.runSubAction(m.id); }
                onEscaped: page.back()
            }
            Hint { text: "↑↓ move · Enter select · Esc back" }
        }

        // ═══ ADD PASSWORD ═══════════════════════════════════════════════
        Column {
            visible: page.view === "add"
            width: parent.width
            spacing: Tokens.spacing.large
            topPadding: Tokens.padding.small
            bottomPadding: Tokens.padding.small

            SectionTitle { text: "Add Password" }
            PassField { id: fUrl;  label: "URL";      onAccepted: fUser.focusInput() }
            PassField { id: fUser; label: "Username"; onAccepted: fPw.focusInput() }
            PassField { id: fPw;   label: "Password (empty = generate)"; masked: true
                        onAccepted: page.submitAdd(fUrl.value, fUser.value, fPw.value) }
            Hint { text: "Enter — save · Esc — cancel" }
        }

        // ═══ EDIT AUTOTYPE ══════════════════════════════════════════════
        Column {
            visible: page.view === "editseq"
            width: parent.width
            spacing: Tokens.spacing.large
            topPadding: Tokens.padding.small
            bottomPadding: Tokens.padding.small

            SectionTitle { text: "Autotype sequence — " + page.curLabel }
            PassField {
                id: seqField
                label: "Sequence"
                onAccepted: { page.run(["set-autotype", page.curEntry, seqField.value]); page.view = "main"; }
            }
            Hint { text: "tokens: username password otp :tab :enter :delay N — Enter saves" }
        }

        // ═══ CONFIRM ════════════════════════════════════════════════════
        Column {
            id: confirmBox
            visible: page.view === "confirm"
            width: parent.width
            spacing: Tokens.spacing.extraLarge
            topPadding: Tokens.padding.extraLarge
            bottomPadding: Tokens.padding.extraLarge

            Keys.onPressed: e => {
                if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab) page.confirmSel = 1 - page.confirmSel;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) page.confirm(page.confirmSel === 0);
                else if (e.key === Qt.Key_Escape) page.back();
                else return;
                e.accepted = true;
            }

            T {
                anchors.verticalCenter: undefined
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: page.confirmLabel
                font.weight: Font.Medium
                font.pixelSize: Tokens.fontSize.large
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Tokens.spacing.large
                Repeater {
                    model: ["Yes", "No"]
                    Rectangle {
                        id: btn
                        required property int index
                        required property string modelData
                        readonly property bool sel: index === page.confirmSel
                        width: 140
                        height: 44
                        radius: Tokens.rounding.medium
                        color: sel ? (index === 0 ? Colors.red : Colors.accent) : Colors.surface1
                        T {
                            anchors.centerIn: parent
                            text: btn.modelData
                            font.weight: Font.Medium
                            font.pixelSize: Tokens.fontSize.larger
                            color: btn.sel ? (btn.index === 0 ? Colors.crust : Colors.base) : Colors.fg
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: page.confirmSel = btn.index
                            onClicked: page.confirm(btn.index === 0)
                        }
                    }
                }
            }
            Hint {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "←→ choose · Enter confirm · Esc cancel"
            }
        }
    }

    component SectionTitle: T {
        anchors.verticalCenter: undefined
        leftPadding: Tokens.padding.small
        font.weight: Font.Medium
        font.pixelSize: Tokens.fontSize.larger
    }

    component Hint: T {
        anchors.verticalCenter: undefined
        leftPadding: Tokens.padding.small
        color: Colors.subtext
        font.pixelSize: Tokens.fontSize.smaller
    }

    // Labelled input used by the add and autotype forms.
    component PassField: Column {
        id: pf
        property string label: ""
        property alias value: tf.text
        property bool masked: false
        signal accepted
        function focusInput() { tf.forceActiveFocus(); }
        width: parent ? parent.width : 720
        spacing: Tokens.spacing.small

        T {
            anchors.verticalCenter: undefined
            leftPadding: Tokens.padding.small
            text: pf.label
            color: Colors.subtext
            font.pixelSize: Tokens.fontSize.smaller
        }
        Rectangle {
            width: parent.width
            height: 50
            radius: Tokens.rounding.large
            color: Colors.inputBg
            border.color: tf.activeFocus ? Qt.alpha(Colors.accent, 0.6) : Colors.outline
            border.width: 1
            StyledTextField {
                id: tf
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                font.family: "SF Pro Display"
                font.pixelSize: Tokens.fontSize.larger
                background: null
                echoMode: pf.masked ? TextInput.Password : TextInput.Normal
                onAccepted: pf.accepted()
                Keys.onEscapePressed: page.back()
            }
        }
    }
}
