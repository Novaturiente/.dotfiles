// Mod+S URL bar: novabrowser bookmarks + history, filtered as you type.
// Enter opens the highlighted url, or the typed text when nothing matches.
//
// Data + launch reuse the bash helpers (sqlite/window-focus live there):
//   scripts/quickshell/browser-urls.sh  -> JSON [{bookmark,title,url,icon}]
//   scripts/quickshell/browser-open.sh  -> resolve+open+focus a url/typed text
import QtQuick
import Quickshell
import Quickshell.Io
import common

Page {
    id: page

    readonly property string scriptDir: Quickshell.env("HOME") + "/.dotfiles/scripts/quickshell"
    property var allRows: []
    property var rows: []

    function applyFilter(q: string): void {
        const needle = q.trim().toLowerCase();
        if (needle === "") {
            rows = allRows;
            return;
        }
        const terms = needle.split(/\s+/);
        rows = allRows.filter(r => {
            const hay = (r.title + " " + r.url).toLowerCase();
            return terms.every(t => hay.indexOf(t) !== -1);
        });
    }

    function accept(): void {
        const choice = rows.length > 0 && search.current ? search.current.url : search.text;
        if (choice.trim() !== "") {
            opener.command = ["bash", scriptDir + "/browser-open.sh", choice];
            opener.running = true;
        }
        closeRequested();
    }

    onOpened: {
        search.reset();
        applyFilter("");
        loader.running = true;
        Qt.callLater(() => search.focusField());
    }

    Process {
        id: loader
        command: ["bash", page.scriptDir + "/browser-urls.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.allRows = JSON.parse(text);
                } catch (e) {
                    page.allRows = [];
                }
                page.applyFilter(search.text);
            }
        }
    }

    // Fire-and-forget; lives in the shell, so it survives the page closing.
    Process {
        id: opener
    }

    SearchList {
        id: search
        listWidth: 720
        glyph: "\uf0ac"
        placeholder: "Search bookmarks & history, or type a URL…"
        emptyText: "No matches — Enter opens what you typed"
        model: page.rows.map(r => ({
                    title: (r.bookmark ? "★ " : "") + r.title,
                    sub: r.url,
                    icon: r.icon ? "file://" + r.icon : "",
                    glyph: r.bookmark ? "\uf02e" : "\uf0ac",
                    url: r.url
                }))
        onTextChanged: page.applyFilter(text)
        onAccepted: page.accept()
        onEscaped: page.closeRequested()
    }
}
