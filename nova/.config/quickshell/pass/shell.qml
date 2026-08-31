//@ pragma UseQApplication
// Password manager — Quickshell frontend for the Bitwarden vault (via rbw).
// Bound to Mod+Shift+P. Resident daemon toggled over IPC.
//
// SECURITY: this UI only ever sees entry UUIDs and labels. Every secret (password,
// TOTP, autotype) flows through scripts/quickshell/passctl.sh -> clipboard / wtype,
// never through QML. Views here just pick an entry and dispatch a subcommand.
//
// TOTP codes are readable here; adding/removing a TOTP is done in the Bitwarden
// web vault — rbw cannot write the totp field.
//
// Views: main | submenu | add | editseq | confirm
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ShellRoot {
    id: root
    readonly property string passctl: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell/passctl.sh"

    // Space-galaxy palette (matches scripts/rofi/config.rasi)
    readonly property color bg:      "#e61e1e2e"
    readonly property color inputBg: "#d0313244"
    readonly property color outline: "#45475a"
    readonly property color accent:  "#cba6f7"   // mauve
    readonly property color selBg:   "#45475a"   // surface1
    readonly property color fg:      "#cdd6f4"
    readonly property color subtext: "#7f849c"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    // ── state ───────────────────────────────────────────────────────────────
    property var    entries: []          // [{entry(uuid),domain,user}]
    property string view: "main"
    property string curEntry: ""         // uuid under action (submenu/confirm)
    property string curLabel: ""         // human label for the same entry
    property bool   curHasOtp: false
    property string prefill: ""
    // confirm flow
    property string confirmLabel: ""
    property var    confirmAction: null  // function to run on Yes

    // ── process plumbing ─────────────────────────────────────────────────────
    // fire-and-forget (copy/totp/autotype/delete/set/...)
    Process { id: act }
    function run(args) { act.command = ["bash", passctl].concat(args); act.running = true; }

    // query with stdout callback (list/exists/get-autotype/scan-qr/import-file/parse-uri)
    Process {
        id: q
        property var cb: null
        stdout: StdioCollector { onStreamFinished: { var f = q.cb; q.cb = null; if (f) f(text.trim()); } }
    }
    function query(args, cb) { q.cb = cb; q.command = ["bash", passctl].concat(args); q.running = true; }

    function reload() { query(["list"], function (t) { try { entries = JSON.parse(t); } catch (e) { entries = []; } }); }

    // ── IPC: open with focused-domain prefill (captured before we steal focus) ─
    IpcHandler {
        target: "pass"
        function open(domain: string): void {
            if (win.visible) { win.visible = false; return; }
            prefill = domain || "";
            view = "main";
            mainSearch.text = "";        // clear stale filter (onTextChanged resets currentIndex)
            reload();                    // passctl serializes the vault unlock (flock), so
            run(["sync"]);               // firing these concurrently prompts pinentry only once
            win.visible = true;
        }
    }

    Process { id: opener }
    // No boot-time reload: it would fire rbw at login (vault locked) and pop a
    // pinentry no one asked for. open() reloads anyway, after pass.sh unlocks.

    // ── actions (all dispatch to passctl; window hides so focus returns) ──────
    function hide() { win.visible = false; }
    function copyEntry(e)   { run(["copy", e]); hide(); }
    function copyField(e,f) { run(["copy-field", e, f]); hide(); }
    function totp(e)        { run(["totp", e]); hide(); }
    function autotype(e)    { hide(); run(["autotype", e]); }   // hide first, then type
    function del(e)         { run(["delete", e]); reload(); }
    function editEntry(e)   { run(["edit", e]); hide(); }

    property var subModel: []
    function openSubmenu(e, label) {
        curEntry = e;
        curLabel = label;
        query(["has-otp", e], function (t) {
            curHasOtp = (t === "yes");
            var m = [{ id: "cp", t: "Copy Password" }, { id: "cu", t: "Copy Username" }];
            if (curHasOtp) m.push({ id: "ct", t: "Copy TOTP" });
            m.push({ id: "at", t: "Auto-type" }, { id: "ea", t: "Edit Autotype" },
                   { id: "ed", t: "Edit" }, { id: "de", t: "Delete" });
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
        case "ea": query(["get-autotype", curEntry], function (t) { seqField.text = t; view = "editseq"; }); break;
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

    // ── window ────────────────────────────────────────────────────────────────
    PanelWindow {
        id: win
        visible: false
        anchors { top: false; bottom: false; left: false; right: false }
        implicitWidth: 720
        // Auto-fit height to the main list, capped at maxH. Other views (forms,
        // submenu) use the full height. overhead = margins(28)+search(46)+gap(10).
        readonly property int maxH: 540
        implicitHeight: view === "main"
            ? Math.min(maxH, 84 + Math.max(1, mainList.count) * 42)
            : maxH
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-pass"

        // ponytail: open-only expand-from-centre; close hides instantly
        property real anim: 0
        Behavior on anim { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        onVisibleChanged: { anim = visible ? 1 : 0; if (visible) Qt.callLater(function () { focusScope.forceActiveFocus(); mainSearch.forceActiveFocus(); }) }

        Rectangle {
            anchors.fill: parent
            transform: Scale { origin.y: win.height / 2; yScale: win.anim }
            radius: 4
            color: bg
            border.color: outline
            border.width: 1

            FocusScope {
                id: focusScope
                anchors.fill: parent
                anchors.margins: 14

                // global Esc handling per view
                Keys.onEscapePressed: {
                    if (view === "main") hide();
                    else view = "main";
                }

                // ═══ MAIN ═══════════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    visible: view === "main"

                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 46; radius: 0
                        color: inputBg; border.color: accent; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 10
                            Text { text: ""; color: accent; font.family: uiFont; font.pixelSize: 18 }
                            TextField {
                                id: mainSearch
                                Layout.fillWidth: true; focus: view === "main"
                                color: fg; font.family: uiFont; font.pixelSize: 16; background: null
                                placeholderText: "Search…  Enter copy · Alt+1 type · Alt+2 TOTP · Shift+Enter/Alt+3 more"
                                placeholderTextColor: subtext
                                text: prefill
                                onTextChanged: mainList.currentIndex = 0
                                Keys.onPressed: (e) => {
                                    var m = mainList.currentItem ? mainList.currentItem.rowData : null;
                                    if (e.key === Qt.Key_Down)      { mainList.incrementCurrentIndex(); e.accepted = true; }
                                    else if (e.key === Qt.Key_Up)   { mainList.decrementCurrentIndex(); e.accepted = true; }
                                    else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && (e.modifiers & Qt.ShiftModifier)) {
                                        if (m && !m.action) openSubmenu(m.entry, m.label);   // Shift+Enter -> more options
                                        e.accepted = true;
                                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                        if (m) { if (m.action === "add-pw") view = "add";
                                                 else copyEntry(m.entry); }
                                        e.accepted = true;
                                    } else if (e.key === Qt.Key_1 && (e.modifiers & Qt.AltModifier)) { if (m && !m.action) autotype(m.entry); e.accepted = true; }
                                    else if (e.key === Qt.Key_2 && (e.modifiers & Qt.AltModifier))   { if (m && !m.action) totp(m.entry); e.accepted = true; }
                                    else if (e.key === Qt.Key_3 && (e.modifiers & Qt.AltModifier))   { if (m && !m.action) openSubmenu(m.entry, m.label); e.accepted = true; }
                                }
                            }
                        }
                    }

                    ListView {
                        id: mainList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: {
                            var q = mainSearch.text.toLowerCase();
                            var rows = [{ action: "add-pw", label: "+ Add Password" }];
                            for (var i = 0; i < entries.length; i++) {
                                var e = entries[i];
                                var lbl = e.domain + " — " + e.user;
                                if (q === "" || lbl.toLowerCase().indexOf(q) !== -1)
                                    rows.push({ entry: e.entry, label: lbl });
                            }
                            // action rows only when they match the query
                            return rows.filter(function (r) { return q === "" || r.label.toLowerCase().indexOf(q) !== -1; });
                        }
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            property var rowData: modelData
                            width: ListView.view.width; height: 42; radius: 0
                            color: index === mainList.currentIndex ? selBg : "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
                                Text {
                                    text: modelData.action ? "" : ""
                                    color: modelData.action ? accent : subtext
                                    font.family: uiFont; font.pixelSize: 15
                                }
                                Text { text: modelData.label; color: fg; font.family: uiFont; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true
                                onEntered: mainList.currentIndex = index
                                onClicked: {
                                    if (modelData.action === "add-pw") view = "add";
                                    else copyEntry(modelData.entry);
                                }
                            }
                        }
                    }
                }

                // ═══ SUBMENU ════════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 6; visible: view === "submenu"
                    onVisibleChanged: if (visible) Qt.callLater(function () { subList.currentIndex = 0; subList.forceActiveFocus(); })
                    Text { text: "  " + curLabel; color: accent; font.family: uiFont; font.pixelSize: 15; font.bold: true; Layout.bottomMargin: 6 }
                    ListView {
                        id: subList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        focus: view === "submenu"
                        keyNavigationEnabled: true
                        model: subModel
                        boundsBehavior: Flickable.StopAtBounds
                        Keys.onReturnPressed: if (subModel[currentIndex]) runSubAction(subModel[currentIndex].id)
                        Keys.onEnterPressed:  if (subModel[currentIndex]) runSubAction(subModel[currentIndex].id)
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: ListView.view.width; implicitHeight: 40; radius: 0
                            color: index === subList.currentIndex ? selBg : "transparent"
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12
                                   text: modelData.t; color: fg; font.family: uiFont; font.pixelSize: 14 }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true
                                onEntered: subList.currentIndex = index
                                onClicked: runSubAction(modelData.id)
                            }
                        }
                    }
                    Text { text: "↑↓ move · Enter select · Esc back"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                }

                // ═══ ADD PASSWORD ═══════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 10; visible: view === "add"
                    Text { text: "Add Password"; color: accent; font.family: uiFont; font.pixelSize: 15; font.bold: true }
                    PassField { id: fUrl;  label: "URL";      onAccepted: fUser.focusInput() }
                    PassField { id: fUser; label: "Username"; onAccepted: fPw.focusInput() }
                    PassField { id: fPw;   label: "Password (empty = generate)"; masked: true
                                onAccepted: submitAdd(fUrl.value, fUser.value, fPw.value) }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        Text { text: "Enter — save · Esc — cancel"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                    }
                    Item { Layout.fillHeight: true }
                    onVisibleChanged: if (visible) Qt.callLater(function () { fUrl.value = ""; fUser.value = ""; fPw.value = ""; fUrl.focusInput(); })
                }

                // ═══ EDIT AUTOTYPE ══════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 10; visible: view === "editseq"
                    Text { text: "Autotype sequence — " + curLabel; color: accent; font.family: uiFont; font.pixelSize: 14; font.bold: true }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 44; radius: 0
                        color: inputBg; border.color: accent; border.width: 1
                        TextField {
                            id: seqField; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                            color: fg; font.family: uiFont; font.pixelSize: 15; background: null
                            onAccepted: { run(["set-autotype", curEntry, seqField.text]); view = "main"; }
                        }
                    }
                    Text { text: "tokens: username password otp :tab :enter :delay N — Enter saves"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                    Item { Layout.fillHeight: true }
                    onVisibleChanged: if (visible) Qt.callLater(function () { seqField.forceActiveFocus() })
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
                            MouseArea { anchors.fill: parent; onClicked: view = "main" } }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // reusable labeled input used by the add form
    component PassField: ColumnLayout {
        id: pf
        property string label: ""
        property alias value: tf.text
        property bool masked: false
        signal accepted()
        function focusInput() { tf.forceActiveFocus() }
        Layout.fillWidth: true; spacing: 3
        Text { text: pf.label; color: subtext; font.family: uiFont; font.pixelSize: 11 }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 42; radius: 0
            color: inputBg; border.color: accent; border.width: 1
            TextField {
                id: tf; anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                color: fg; font.family: uiFont; font.pixelSize: 15; background: null
                echoMode: pf.masked ? TextInput.Password : TextInput.Normal
                onAccepted: pf.accepted()
            }
        }
    }
}
