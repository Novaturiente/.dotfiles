# pyright: ignore[all]
# ruff: noqa
# type: ignore

# Load settings made via the :set command from autoconfig.yml.
config.load_autoconfig(False)  # Set to True if you want to keep using autoconfig.yml

# Enable JavaScript clipboard access
c.content.javascript.clipboard = "access-paste"

# Theme
config.source("onedark.py")

# Tab settings
c.tabs.padding = {"top": 3, "bottom": 3, "left": 5, "right": 5}
c.tabs.title.alignment = "center"
c.tabs.favicons.scale = 1.4

# save session
c.auto_save.session = True

# last tab close action
c.tabs.last_close = "startpage"

# Enable dark mode for webpages
c.colors.webpage.bg = "#282828"
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.webpage.darkmode.policy.images = "never"

# Defauly to input mode
c.input.insert_mode.auto_enter = True
c.input.insert_mode.auto_load = True
c.input.insert_mode.leave_on_load = False

# Smooth scrolling
c.scrolling.smooth = True 

# Video auto play and location
c.content.autoplay = False
c.content.geolocation = False

# GPU accelearation
c.qt.args = [
    "ignore-gpu-blocklist",
    "enable-gpu-rasterization",
    "enable-accelerated-video-decode",
]

# Privacy and blocking
c.content.headers.user_agent = (
    "Mozilla/5.0 (X11; Linux x86_64; rv:68.0) Gecko/20100101 Firefox/68.0"
)
c.content.headers.accept_language = "en-US,en;q=0.5"
c.content.headers.custom = {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}
c.content.canvas_reading = False
c.content.webgl = False
c.content.cookies.accept = "no-3rdparty"
c.content.blocking.enabled = True
c.content.blocking.method = "both"

## Key bindings
# Map Alt+Right to next tab
config.bind("<Alt-Right>", "tab-next")
# Map Alt+Left to previous tab
config.bind("<Alt-Left>", "tab-prev")
# Open archive of broken pages
config.bind(",w", "open http://web.archive.org/{url}")
# Open page in zen-browser
config.bind("<Ctrl+Alt+t>", "spawn -d zen-browser {url} ;; tab-close")

# — Hint selection improvements —
# Add more elements to hinting for clickable areas (e.g. dropdowns/forms)
c.hints.selectors["all"].extend(
    [
        "[aria-haspopup]",  # dropdown elements (Keeper, etc.)
        '[role="link"]',
        '[role="button"]',
    ]
)

# For focusing scrollable frames (e.g. Jira, Confluence)
c.hints.selectors["frame"] = ["div", "header", "section", "nav"]

# — Opening links selectively —
config.bind(";f", "hint links run open {hint-url}")

# — Search & completion customization —
c.completion.open_categories = [
    "quickmarks",
    "searchengines",
    "bookmarks",
    "history",
]

# Add custom quick keyword-based search engines
c.url.searchengines = {
    "DEFAULT": "https://duckduckgo.com/?q={}",
    "g": "https://www.google.com/search?q={}",
    "w": "https://en.wikipedia.org/wiki/{}",
    "yt": "https://www.youtube.com/results?search_query={}",
    "aw": "https://wiki.archlinux.org/?search={}",
}

# Always search if input isn't a URL
c.url.auto_search = "naive"

# — Keybinding: search selected text —
config.bind(",g", "spawn --userscript qute_search -g", mode="normal")

# — Opening links in background via keyboard —
config.bind("<Ctrl-Shift-Right>", "open -t {url}")

# -- Cast current video
config.bind(",c", "hint links spawn --userscript cast.sh {hint-url}")
config.bind(",m", "hint links spawn mpv {hint-url}")
config.bind(",d", "spawn --userscript open_download")


c.url.start_pages = ["https://duckduckgo.com/?q=DuckDuckGo+AI+Chat&ia=chat&duckai=1"]
