# Catppuccin Mocha
# https://github.com/catppuccin/catppuccin — matches Ghostty/nvim/DMS.

ROSEWATER = "#f5e0dc"
FLAMINGO = "#f2cdcd"
PINK = "#f5c2e7"
MAUVE = "#cba6f7"
RED = "#f38ba8"
MAROON = "#eba0ac"
PEACH = "#fab387"
YELLOW = "#f9e2af"
GREEN = "#a6e3a1"
TEAL = "#94e2d5"
SKY = "#89dceb"
SAPPHIRE = "#74c7ec"
BLUE = "#89b4fa"
LAVENDER = "#b4befe"

TEXT = "#cdd6f4"
SUBTEXT1 = "#bac2de"
SUBTEXT0 = "#a6adc8"
OVERLAY2 = "#9399b2"
OVERLAY1 = "#7f849c"
OVERLAY0 = "#6c7086"
SURFACE2 = "#585b70"
SURFACE1 = "#45475a"
SURFACE0 = "#313244"
BASE = "#1e1e2e"
MANTLE = "#181825"
CRUST = "#11111b"


def setup(c):
    # --- Completion --------------------------------------------------------
    c.colors.completion.fg = TEXT
    c.colors.completion.odd.bg = MANTLE
    c.colors.completion.even.bg = BASE
    c.colors.completion.category.fg = MAUVE
    c.colors.completion.category.bg = CRUST
    c.colors.completion.category.border.top = CRUST
    c.colors.completion.category.border.bottom = CRUST
    c.colors.completion.item.selected.fg = CRUST
    c.colors.completion.item.selected.bg = LAVENDER
    c.colors.completion.item.selected.border.top = LAVENDER
    c.colors.completion.item.selected.border.bottom = LAVENDER
    c.colors.completion.item.selected.match.fg = RED
    c.colors.completion.match.fg = PEACH
    c.colors.completion.scrollbar.fg = SURFACE2
    c.colors.completion.scrollbar.bg = BASE

    # --- Context menu ------------------------------------------------------
    c.colors.contextmenu.menu.bg = BASE
    c.colors.contextmenu.menu.fg = TEXT
    c.colors.contextmenu.disabled.bg = SURFACE0
    c.colors.contextmenu.disabled.fg = OVERLAY0
    c.colors.contextmenu.selected.bg = LAVENDER
    c.colors.contextmenu.selected.fg = CRUST

    # --- Downloads ---------------------------------------------------------
    c.colors.downloads.bar.bg = CRUST
    c.colors.downloads.start.fg = CRUST
    c.colors.downloads.start.bg = BLUE
    c.colors.downloads.stop.fg = CRUST
    c.colors.downloads.stop.bg = GREEN
    c.colors.downloads.error.fg = CRUST
    c.colors.downloads.error.bg = RED

    # --- Hints -------------------------------------------------------------
    # Dark text on yellow: highest-contrast pairing in the palette.
    c.colors.hints.fg = CRUST
    c.colors.hints.bg = YELLOW
    c.colors.hints.match.fg = RED

    # --- Keyhint -----------------------------------------------------------
    c.colors.keyhint.fg = TEXT
    c.colors.keyhint.suffix.fg = YELLOW
    c.colors.keyhint.bg = CRUST

    # --- Messages ----------------------------------------------------------
    c.colors.messages.error.fg = CRUST
    c.colors.messages.error.bg = RED
    c.colors.messages.error.border = RED
    c.colors.messages.warning.fg = CRUST
    c.colors.messages.warning.bg = PEACH
    c.colors.messages.warning.border = PEACH
    c.colors.messages.info.fg = TEXT
    c.colors.messages.info.bg = SURFACE0
    c.colors.messages.info.border = SURFACE0

    # --- Prompts -----------------------------------------------------------
    c.colors.prompts.fg = TEXT
    c.colors.prompts.bg = SURFACE0
    c.colors.prompts.border = f"1px solid {LAVENDER}"
    c.colors.prompts.selected.bg = LAVENDER
    c.colors.prompts.selected.fg = CRUST

    # --- Statusbar ---------------------------------------------------------
    # Mode is signalled by background colour, so it is readable at a glance.
    c.colors.statusbar.normal.fg = TEXT
    c.colors.statusbar.normal.bg = MANTLE
    c.colors.statusbar.insert.fg = CRUST
    c.colors.statusbar.insert.bg = GREEN
    c.colors.statusbar.passthrough.fg = CRUST
    c.colors.statusbar.passthrough.bg = SKY
    c.colors.statusbar.command.fg = TEXT
    c.colors.statusbar.command.bg = SURFACE0
    c.colors.statusbar.private.fg = TEXT
    c.colors.statusbar.private.bg = SURFACE1
    c.colors.statusbar.command.private.fg = TEXT
    c.colors.statusbar.command.private.bg = SURFACE1
    c.colors.statusbar.caret.fg = CRUST
    c.colors.statusbar.caret.bg = MAUVE
    c.colors.statusbar.caret.selection.fg = CRUST
    c.colors.statusbar.caret.selection.bg = PINK
    c.colors.statusbar.progress.bg = BLUE
    c.colors.statusbar.url.fg = TEXT
    c.colors.statusbar.url.hover.fg = SKY
    c.colors.statusbar.url.success.http.fg = PEACH  # plain http: stands out
    c.colors.statusbar.url.success.https.fg = GREEN
    c.colors.statusbar.url.warn.fg = YELLOW
    c.colors.statusbar.url.error.fg = RED

    # --- Tabs --------------------------------------------------------------
    c.colors.tabs.bar.bg = CRUST
    c.colors.tabs.indicator.start = BLUE
    c.colors.tabs.indicator.stop = GREEN
    c.colors.tabs.indicator.error = RED
    c.colors.tabs.odd.fg = SUBTEXT0
    c.colors.tabs.odd.bg = MANTLE
    c.colors.tabs.even.fg = SUBTEXT0
    c.colors.tabs.even.bg = MANTLE
    # Selected tab: full-contrast text on a lifted surface, so it is obvious
    # which tab is active without squinting at a 1px indicator.
    c.colors.tabs.selected.odd.fg = TEXT
    c.colors.tabs.selected.odd.bg = SURFACE1
    c.colors.tabs.selected.even.fg = TEXT
    c.colors.tabs.selected.even.bg = SURFACE1
    c.colors.tabs.pinned.odd.fg = CRUST
    c.colors.tabs.pinned.odd.bg = TEAL
    c.colors.tabs.pinned.even.fg = CRUST
    c.colors.tabs.pinned.even.bg = TEAL
    c.colors.tabs.pinned.selected.odd.fg = TEXT
    c.colors.tabs.pinned.selected.odd.bg = SURFACE1
    c.colors.tabs.pinned.selected.even.fg = TEXT
    c.colors.tabs.pinned.selected.even.bg = SURFACE1

    # --- Webpage -----------------------------------------------------------
    # Shown before content paints and behind transparent pages: matching BASE
    # avoids a white flash on every navigation.
    c.colors.webpage.bg = BASE
