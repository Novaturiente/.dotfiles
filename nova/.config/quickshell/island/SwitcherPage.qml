// Window switcher page (Alt+Tab): the Wayland foreign-toplevel list,
// filtered by title and app id. Tab / Shift+Tab cycle, Enter or click focuses.
import Quickshell
import Quickshell.Wayland
import QtQuick
import common

Page {
    id: page

    // Toplevels matching the search, in the order the compositor lists them.
    readonly property var windows: {
        const q = list.text.toLowerCase();
        return ToplevelManager.toplevels.values.filter(t => q === "" || ((t.title || "") + " " + (t.appId || "")).toLowerCase().includes(q));
    }

    onOpened: {
        list.reset();
        list.currentIndex = windows.length > 1 ? 1 : 0; // preselect the previous window
        Qt.callLater(() => list.focusField());
    }

    SearchList {
        id: list
        glyph: "\uf2d2" // nf-fa-window_restore
        placeholder: "Switch window…"
        emptyText: "No windows"
        model: page.windows.map(t => ({
                    title: t.title || "(untitled)",
                    sub: t.appId || "",
                    icon: Quickshell.iconPath(t.appId, "application-x-executable")
                }))
        onEscaped: page.closeRequested()
        onAccepted: index => {
            const t = page.windows[index];
            if (t)
                t.activate();
            page.closeRequested();
        }
        onKeyPressed: e => {
            if (e.key === Qt.Key_Backtab || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier)))
                list.move(-1);
            else if (e.key === Qt.Key_Tab)
                list.move(1);
            else
                return;
            e.accepted = true;
        }
    }
}
