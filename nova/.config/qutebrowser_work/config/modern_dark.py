# Modern Professional Dark Theme (Zinc & Blue)

def setup(c):
    # Palette (Zinc-based)
    bg_default = "#18181b"  # Zinc 900
    bg_lighter = "#27272a"  # Zinc 800
    bg_selection = "#3f3f46" # Zinc 700
    fg_default = "#f4f4f5"  # Zinc 100
    fg_muted = "#a1a1aa"    # Zinc 400
    
    accent = "#3b82f6"      # Blue 500
    accent_dark = "#2563eb" # Blue 600
    
    error = "#ef4444"       # Red 500
    warning = "#f59e0b"     # Amber 500
    success = "#10b981"     # Emerald 500

    # Completion Widget
    c.colors.completion.fg = fg_default
    c.colors.completion.odd.bg = bg_default
    c.colors.completion.even.bg = bg_default
    c.colors.completion.category.fg = accent
    c.colors.completion.category.bg = bg_default
    c.colors.completion.category.border.top = bg_default
    c.colors.completion.category.border.bottom = bg_default
    c.colors.completion.item.selected.fg = fg_default
    c.colors.completion.item.selected.bg = bg_selection
    c.colors.completion.item.selected.border.top = bg_selection
    c.colors.completion.item.selected.border.bottom = bg_selection
    c.colors.completion.match.fg = accent
    c.colors.completion.scrollbar.fg = fg_muted
    c.colors.completion.scrollbar.bg = bg_default

    # Context Menu
    c.colors.contextmenu.disabled.bg = bg_lighter
    c.colors.contextmenu.disabled.fg = fg_muted
    c.colors.contextmenu.menu.bg = bg_default
    c.colors.contextmenu.menu.fg = fg_default
    c.colors.contextmenu.selected.bg = bg_selection
    c.colors.contextmenu.selected.fg = fg_default

    # Downloads
    c.colors.downloads.bar.bg = bg_default
    c.colors.downloads.start.fg = bg_default
    c.colors.downloads.start.bg = accent
    c.colors.downloads.stop.fg = bg_default
    c.colors.downloads.stop.bg = success
    c.colors.downloads.error.fg = fg_default
    c.colors.downloads.error.bg = error

    # Hints
    c.colors.hints.fg = bg_default
    c.colors.hints.bg = accent
    c.colors.hints.match.fg = fg_default
    c.hints.border = f"1px solid {bg_default}"

    # Keyhint
    c.colors.keyhint.fg = fg_default
    c.colors.keyhint.suffix.fg = fg_muted
    c.colors.keyhint.bg = bg_default

    # Messages
    c.colors.messages.error.fg = fg_default
    c.colors.messages.error.bg = error
    c.colors.messages.error.border = error
    c.colors.messages.warning.fg = bg_default
    c.colors.messages.warning.bg = warning
    c.colors.messages.warning.border = warning
    c.colors.messages.info.fg = fg_default
    c.colors.messages.info.bg = bg_lighter
    c.colors.messages.info.border = bg_lighter

    # Prompts
    c.colors.prompts.fg = fg_default
    c.colors.prompts.border = f"1px solid {bg_lighter}"
    c.colors.prompts.bg = bg_default
    c.colors.prompts.selected.bg = bg_selection

    # Status Bar
    c.colors.statusbar.normal.fg = fg_default
    c.colors.statusbar.normal.bg = bg_default
    c.colors.statusbar.insert.fg = bg_default
    c.colors.statusbar.insert.bg = accent
    c.colors.statusbar.passthrough.fg = bg_default
    c.colors.statusbar.passthrough.bg = accent_dark
    c.colors.statusbar.private.fg = fg_default
    c.colors.statusbar.private.bg = bg_lighter
    c.colors.statusbar.command.fg = fg_default
    c.colors.statusbar.command.bg = bg_default
    c.colors.statusbar.command.private.fg = fg_default
    c.colors.statusbar.command.private.bg = bg_default
    c.colors.statusbar.caret.fg = bg_default
    c.colors.statusbar.caret.bg = warning
    c.colors.statusbar.caret.selection.fg = bg_default
    c.colors.statusbar.caret.selection.bg = accent
    c.colors.statusbar.progress.bg = fg_default
    c.colors.statusbar.url.fg = fg_default
    c.colors.statusbar.url.error.fg = error
    c.colors.statusbar.url.hover.fg = accent
    c.colors.statusbar.url.success.http.fg = fg_default
    c.colors.statusbar.url.success.https.fg = success
    c.colors.statusbar.url.warn.fg = warning

    # Tabs
    c.colors.tabs.bar.bg = bg_default
    c.colors.tabs.indicator.start = accent
    c.colors.tabs.indicator.stop = accent_dark
    c.colors.tabs.indicator.error = error
    c.colors.tabs.odd.fg = fg_muted
    c.colors.tabs.odd.bg = bg_default
    c.colors.tabs.even.fg = fg_muted
    c.colors.tabs.even.bg = bg_default
    c.colors.tabs.pinned.odd.fg = fg_default
    c.colors.tabs.pinned.odd.bg = bg_selection
    c.colors.tabs.pinned.even.fg = fg_default
    c.colors.tabs.pinned.even.bg = bg_selection
    c.colors.tabs.pinned.selected.odd.fg = fg_default
    c.colors.tabs.pinned.selected.odd.bg = bg_selection
    c.colors.tabs.pinned.selected.even.fg = fg_default
    c.colors.tabs.pinned.selected.even.bg = bg_selection
    c.colors.tabs.selected.odd.fg = fg_default
    c.colors.tabs.selected.odd.bg = bg_selection
    c.colors.tabs.selected.even.fg = fg_default
    c.colors.tabs.selected.even.bg = bg_selection

    # Webpage
    # Note: Dark mode logic handles the actual content. 
    # These are for the brief flash before content loads or for plain text files.
    c.colors.webpage.bg = bg_default
