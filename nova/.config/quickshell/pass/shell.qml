//@ pragma UseQApplication
// Password manager — Quickshell frontend for `pass`. Replaces scripts/rofi/passrofi.sh.
// Bound to Mod+Shift+P. Resident daemon toggled over IPC.
//
// SECURITY: this UI only ever sees entry NAMES. Every secret (password, TOTP,
// autotype) flows through scripts/quickshell/passctl.sh -> clipboard / wtype,
// never through QML. Views here just pick a name and dispatch a subcommand.
//
// Views: main | submenu | add | addtotp | attach | editseq | confirm
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
    readonly property color bg:      "#e606060c"
    readonly property color inputBg: "#d04a4a5a"
    readonly property color outline: "#4a4a5a"
    readonly property color accent:  "#8c52ff"
    readonly property color selBg:   "#8c52ff"
    readonly property color fg:      "#ffffff"
    readonly property color subtext: "#8a8f98"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    // ── state ───────────────────────────────────────────────────────────────
    property var    entries: []          // [{entry,domain,user}]
    property string view: "main"
    property string curEntry: ""         // entry under action (submenu/confirm)
    property bool   curHasOtp: false
    property string prefill: ""
    // add-totp flow
    property var    uriQueue: []         // otpauth uris pending attach
    property string curUri: ""
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
            reload();
            win.visible = true;
        }
    }

    Process { id: opener }
    Component.onCompleted: reload()      // prime at daemon boot

    // ── actions (all dispatch to passctl; window hides so focus returns) ──────
    function hide() { win.visible = false; }
    function copyEntry(e)   { run(["copy", e]); hide(); }
    function copyField(e,f) { run(["copy-field", e, f]); hide(); }
    function totp(e)        { run(["totp", e]); hide(); }
    function autotype(e)    { hide(); run(["autotype", e]); }   // hide first, then type
    function del(e)         { run(["delete", e]); reload(); }
    function removeTotp(e)  { run(["remove-totp", e]); }
    function editEntry(e)   { run(["edit", e]); hide(); }

    property var subModel: []
    function openSubmenu(e) {
        curEntry = e;
        query(["has-otp", e], function (t) {
            curHasOtp = (t === "yes");
            var m = [{ id: "cp", t: "Copy Password" }, { id: "cu", t: "Copy Username" }];
            if (curHasOtp) { m.push({ id: "ct", t: "Copy TOTP" }); m.push({ id: "rt", t: "Remove TOTP" }); }
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
        case "rt": confirmLabel = "Remove TOTP from " + curEntry + "?";
                   confirmAction = function () { removeTotp(curEntry); view = "main"; }; view = "confirm"; break;
        case "at": autotype(curEntry); break;
        case "ea": query(["get-autotype", curEntry], function (t) { seqField.text = t; view = "editseq"; }); break;
        case "ed": editEntry(curEntry); break;
        case "de": confirmLabel = "Delete " + curEntry + "?";
                   confirmAction = function () { del(curEntry); view = "main"; }; view = "confirm"; break;
        }
    }

    function submitAdd(url, user, pw) {
        if (url.trim() === "" || user.trim() === "") return;
        var domain = url.replace(/https?:\/\//, "").replace(/www\./, "").replace(/\/.*/, "");
        var entry = "web/" + domain + "/" + user;
        query(["exists", entry], function (t) {
            if (t === "yes") {
                confirmLabel = "Entry " + entry + " exists. Overwrite?";
                confirmAction = function () { run(["add", url, user, pw]); reload(); view = "main"; };
                view = "confirm";
            } else {
                run(["add", url, user, pw]); reload(); view = "main";
            }
        });
    }

    // add-totp: after we have a uri, go to attach picker (queue supports multi-import)
    function pushUris(uris) {
        uriQueue = uris.filter(function (u) { return u.indexOf("otpauth://") === 0; });
        nextUri();
    }
    function nextUri() {
        if (uriQueue.length === 0) { view = "main"; reload(); return; }
        curUri = uriQueue[0];
        uriQueue = uriQueue.slice(1);
        view = "attach";
    }
    function attachTo(target) {   // target = "web/..." or "" for new
        if (target === "") {
            query(["parse-uri", curUri], function (t) {
                var p = t.split("\t");
                run(["attach-totp", curUri, "--new", p[0] || "new", p[1] || "acct"]);
                nextUri();
            });
        } else {
            run(["attach-totp", curUri, target]);
            nextUri();
        }
    }

    function scanQr()  { hide(); query(["scan-qr"], function (t) {
        win.visible = true;
        if (t.indexOf("otpauth://") === 0) pushUris([t]); else view = "addtotp";
    }); }

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

        onVisibleChanged: if (visible) Qt.callLater(function () { focusScope.forceActiveFocus(); mainSearch.forceActiveFocus(); })

        Rectangle {
            anchors.fill: parent
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
                    else if (view === "attach") nextUri();   // skip this uri
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
                                        if (m && !m.action) openSubmenu(m.entry);   // Shift+Enter -> more options
                                        e.accepted = true;
                                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                                        if (m) { if (m.action === "add-pw") view = "add";
                                                 else if (m.action === "add-totp") view = "addtotp";
                                                 else copyEntry(m.entry); }
                                        e.accepted = true;
                                    } else if (e.key === Qt.Key_1 && (e.modifiers & Qt.AltModifier)) { if (m && !m.action) autotype(m.entry); e.accepted = true; }
                                    else if (e.key === Qt.Key_2 && (e.modifiers & Qt.AltModifier))   { if (m && !m.action) totp(m.entry); e.accepted = true; }
                                    else if (e.key === Qt.Key_3 && (e.modifiers & Qt.AltModifier))   { if (m && !m.action) openSubmenu(m.entry); e.accepted = true; }
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
                            var rows = [{ action: "add-pw", label: "+ Add Password" },
                                        { action: "add-totp", label: "+ Add TOTP" }];
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
                                    else if (modelData.action === "add-totp") view = "addtotp";
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
                    Text { text: "  " + curEntry; color: accent; font.family: uiFont; font.pixelSize: 15; font.bold: true; Layout.bottomMargin: 6 }
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

                // ═══ ADD TOTP (method) ══════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 8; visible: view === "addtotp"
                    Text { text: "Add TOTP"; color: accent; font.family: uiFont; font.pixelSize: 15; font.bold: true; Layout.bottomMargin: 4 }
                    Repeater {
                        model: [{ id: "qr", t: " Scan QR from screen" },
                                { id: "uri", t: " Enter URI manually" },
                                { id: "file", t: " Import from file" }]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; implicitHeight: 44; radius: 0
                            color: tma.containsMouse ? selBg : "transparent"
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 12
                                   text: modelData.t; color: fg; font.family: uiFont; font.pixelSize: 14 }
                            MouseArea {
                                id: tma; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (modelData.id === "qr") scanQr();
                                    else if (modelData.id === "uri") view = "uri";
                                    else fileLoader.running = true;   // list importable files
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text { text: "Esc — back"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                }

                // ═══ MANUAL URI ═════════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 10; visible: view === "uri"
                    Text { text: "otpauth:// URI"; color: accent; font.family: uiFont; font.pixelSize: 15; font.bold: true }
                    PassField { id: fUri; label: "otpauth://…"
                                onAccepted: { if (fUri.value.indexOf("otpauth://") === 0) pushUris([fUri.value]); } }
                    Item { Layout.fillHeight: true }
                    onVisibleChanged: if (visible) Qt.callLater(function () { fUri.value = ""; fUri.focusInput(); })
                }

                // ═══ IMPORT FILE (pick) ═════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 6; visible: view === "file"
                    Text { text: "Import TOTP from file"; color: accent; font.family: uiFont; font.pixelSize: 15; font.bold: true; Layout.bottomMargin: 4 }
                    ListView {
                        id: fileList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        model: root.fileChoices
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: ListView.view.width; height: 38; radius: 0
                            color: index === fileList.currentIndex ? selBg : "transparent"
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10
                                   text: modelData; color: fg; font.family: uiFont; font.pixelSize: 13; elide: Text.ElideLeft; width: parent.width - 20 }
                            MouseArea { anchors.fill: parent; hoverEnabled: true
                                onEntered: fileList.currentIndex = index
                                onClicked: query(["import-file", modelData], function (t) { pushUris(t.length ? t.split("\n") : []); }) }
                        }
                    }
                    Text { text: "Esc — back"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                }

                // ═══ ATTACH picker ══════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 6; visible: view === "attach"
                    Text { text: "Attach TOTP to…"; color: accent; font.family: uiFont; font.pixelSize: 15; font.bold: true; Layout.bottomMargin: 4 }
                    TextField {
                        id: attachSearch; Layout.fillWidth: true; color: fg; font.family: uiFont; font.pixelSize: 14; background: null
                        placeholderText: "filter…"; placeholderTextColor: subtext
                    }
                    ListView {
                        id: attachList
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                        model: {
                            var q = attachSearch.text.toLowerCase();
                            var rows = [{ entry: "", label: "+ Create new entry" }];
                            for (var i = 0; i < entries.length; i++) {
                                var lbl = entries[i].domain + " — " + entries[i].user;
                                if (q === "" || lbl.toLowerCase().indexOf(q) !== -1) rows.push({ entry: entries[i].entry, label: lbl });
                            }
                            return rows;
                        }
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            width: ListView.view.width; height: 38; radius: 0
                            color: index === attachList.currentIndex ? selBg : "transparent"
                            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10
                                   text: modelData.label; color: fg; font.family: uiFont; font.pixelSize: 13; elide: Text.ElideRight; width: parent.width - 20 }
                            MouseArea { anchors.fill: parent; hoverEnabled: true
                                onEntered: attachList.currentIndex = index
                                onClicked: attachTo(modelData.entry) }
                        }
                    }
                    Text { text: "Esc — skip"; color: subtext; font.family: uiFont; font.pixelSize: 11 }
                }

                // ═══ EDIT AUTOTYPE ══════════════════════════════════════════
                ColumnLayout {
                    anchors.fill: parent; spacing: 10; visible: view === "editseq"
                    Text { text: "Autotype sequence — " + curEntry; color: accent; font.family: uiFont; font.pixelSize: 14; font.bold: true }
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

    // list importable files (Desktop/Downloads) for the import-file view
    property var fileChoices: []
    Process {
        id: fileLoader
        command: ["bash", "-c",
            "find \"$HOME/Desktop\" \"$HOME/Downloads\" -maxdepth 2 -type f " +
            "\\( -name '*.txt' -o -name '*.json' -o -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.svg' \\) 2>/dev/null | sort"]
        stdout: StdioCollector { onStreamFinished: {
            fileChoices = text.trim().length ? text.trim().split("\n") : [];
            view = "file";
        } }
    }

    // reusable labeled input used by the add/uri forms
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
