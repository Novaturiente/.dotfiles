import json
import os

# Load pywal colors
colors_path = os.path.expanduser("~/.cache/wal/colors.json")
with open(colors_path) as f:
    colors = json.load(f)

# Optional: Load autoconfig
config.load_autoconfig()

# Apply colors
c.colors.completion.fg = colors["special"]["foreground"]
c.colors.completion.odd.bg = colors["special"]["background"]
c.colors.completion.even.bg = colors["colors"]["color0"]
c.colors.completion.category.fg = colors["colors"]["color4"]
c.colors.completion.category.bg = colors["special"]["background"]
c.colors.completion.category.border.top = colors["special"]["background"]
c.colors.completion.category.border.bottom = colors["special"]["background"]
c.colors.completion.item.selected.fg = colors["special"]["background"]
c.colors.completion.item.selected.bg = colors["colors"]["color4"]
c.colors.completion.item.selected.border.top = colors["colors"]["color4"]
c.colors.completion.item.selected.border.bottom = colors["colors"]["color4"]
c.colors.completion.match.fg = colors["colors"]["color6"]

c.colors.statusbar.normal.fg = colors["special"]["foreground"]
c.colors.statusbar.normal.bg = colors["special"]["background"]
c.colors.statusbar.insert.fg = colors["special"]["background"]
c.colors.statusbar.insert.bg = colors["colors"]["color4"]
c.colors.statusbar.command.fg = colors["special"]["foreground"]
c.colors.statusbar.command.bg = colors["special"]["background"]
c.colors.statusbar.url.success.http.fg = colors["colors"]["color2"]
c.colors.statusbar.url.success.https.fg = colors["colors"]["color2"]

c.colors.tabs.bar.bg = colors["special"]["background"]
c.colors.tabs.odd.fg = colors["special"]["foreground"]
c.colors.tabs.odd.bg = colors["colors"]["color0"]
c.colors.tabs.even.fg = colors["special"]["foreground"]
c.colors.tabs.even.bg = colors["colors"]["color0"]
c.colors.tabs.selected.odd.fg = colors["special"]["background"]
c.colors.tabs.selected.odd.bg = colors["colors"]["color4"]
c.colors.tabs.selected.even.fg = colors["special"]["background"]
c.colors.tabs.selected.even.bg = colors["colors"]["color4"]

c.colors.hints.fg = colors["special"]["background"]
c.colors.hints.bg = colors["colors"]["color3"]
