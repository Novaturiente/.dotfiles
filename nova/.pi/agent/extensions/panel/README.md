# panel — generic tmux side panel for pi extensions

One right-hand slot beside each top-level pi pane, with **tabs**. A tab is any TUI process
(the node viewer below, the file tree in `../file-tree`, ...). One tab shows at a time; the
others wait in windows of the hidden tmux session `pi-panels`, keeping their state.
Not an extension itself (no `index.ts`), just a library, a viewer and a small CLI.

## Tabs

```ts
import { openTab, showTab, closeTab, tab, visibleTab } from "../panel/lib.mjs";

openTab("files", { title: "Files", priority: 10, cmd: [process.execPath, TREE], width: "22%" });
```
- `openTab` starts the tab if it is not open, and shows it when the slot is empty or its
  `priority` is ≥ the shown tab's (the swarm viewer uses 20, the file tree 10).
- `closeTab(name)` kills it; if it was shown, the highest-priority remaining tab takes the slot.
- `showTab(name)` brings an open tab forward; `cycle()` shows the next one.
- Tab processes get `PI_PANEL_DIR` / `PI_PANEL_OWNER`; from a shell or another language use
  `node cli.mjs cycle` / `node cli.mjs close <tab>`. Convention: Tab = cycle, q = close own tab,
  draw a tab bar from `tabs/*.json` (the pane whose id is yours is the active one).
- Tab panes carry the tmux pane option `@slot=<name>`; tmux state saving skips them.

## Node viewer (tab "panel")

```ts
import { ensurePane, publish, setSource, remove, clearSource, panelEnv } from "../panel/lib.mjs";

setSource("procs", { title: "Processes", order: 20, newestFirst: false }); // header; lower order first; newestFirst reverses siblings
publish("procs", {
  id: "dev",                    // unique within the source
  parent: undefined,            // id of a parent node in the same source → tree
  label: "dev server",          // bold; may carry ANSI colour / Nerd Font glyphs
  tag: "pid 1234",              // dim text after the label, optional
  status: "running",            // picks the status glyph: running starting waiting queued done idle failed stopped
  icon: ["\uf0e7", 33],        // optional [glyph, ANSI colour] instead of the status glyph
  dim: false,                   // dim + strike the label (finished items)
  detail: "localhost:3000",     // dim line(s) under the label; string or string[]; ANSI colours allowed
  time: { ms: 0, since: Date.now() }, // right-aligned time: ms + (now - since); since ticks (yellow)
  order: 0,                     // sort among siblings (then id, numeric-aware)
  actions: {                    // Enter = "enter", any other single key = itself
    enter: { label: "logs", cmd: ["tmux", "display-popup", "-E", "less", "/tmp/dev.log"] },
    x: { label: "stop", cmd: ["kill", "1234"] },
  },
});
ensurePane({ title: "Procs" }); // open the viewer tab (no-op outside tmux)
remove("procs", "dev");
```

Actions run detached with `PANEL_SOURCE` and `PANEL_NODE` in their env; a non-zero exit
shows the last stderr line in the footer. Processes started from pi (e.g. subagents in
other tmux windows) publish into the same panel when they get `panelEnv()` in their env.
`hidePane()` closes the viewer tab but keeps the nodes; `isEmpty(except)` tells whether
other sources still have rows before you hide it; `busy(except)` tells whether any of their
rows is still in progress (status not done/failed/stopped/idle).

Current sources in the viewer tab (titled "Agent"): `todo` ("Todos", order 5, ../todo) and
`swarm` ("Subagents", order 10, `newestFirst`). A rule separates sections; the selected row is
highlighted only while the viewer pane has focus (tmux `focus-events on`). Each hides the tab only when the other has nothing in progress.

## Storage

`$XDG_RUNTIME_DIR/pi-panel/<tmux-server-pid>-<pane>/`
- `sources/<source>/_source.json` — `{ title, order }`
- `sources/<source>/<encodeURIComponent(id)>.json` — one node
- `tabs/<name>.json` — `{ name, title, priority, width, pane }`
- `owner` — the pi pane the slot belongs to

Node writes are atomic (tmp + rename); the viewer watches the directory and re-renders.
