c = c  # pyright: ignore
config = config  # pyright: ignore

# Load settings made via the :set command from autoconfig.yml.
config.load_autoconfig(False)  # Set to True if you want to keep using autoconfig.yml

# Enable JavaScript clipboard access
c.content.javascript.clipboard = "access-paste"

# Theme
# config.source("onedark.py")
import everforest

everforest.set(c, scheme="dark", intensity="hard")


# ============================================================================
# Tab Settings
# ============================================================================
c.tabs.title.format = "{current_title}"
c.tabs.padding = {"top": 5, "bottom": 5, "left": 0, "right": 0}
c.tabs.title.alignment = "center"
c.tabs.favicons.scale = 1
c.tabs.last_close = "startpage"


# ============================================================================
# Session Management
# ============================================================================
c.auto_save.session = True


# ============================================================================
# Dark Mode Settings
# ============================================================================
c.colors.webpage.bg = "#282828"
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.webpage.darkmode.policy.images = "never"


# ============================================================================
# Input Mode Settings
# ============================================================================
c.input.insert_mode.auto_enter = True
c.input.insert_mode.auto_load = True
c.input.insert_mode.leave_on_load = False


# ============================================================================
# Scrolling Settings
# ============================================================================
c.scrolling.smooth = True


# ============================================================================
# GPU Acceleration
# ============================================================================
c.qt.args = [
    "enable-gpu-rasterization",
    "enable-accelerated-video-decode",
    "enable-quic",
]


# ============================================================================
# Privacy and Blocking Settings
# ============================================================================
c.content.headers.user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
# c.content.javascript.enabled = False
c.content.headers.accept_language = "en-US,en;q=0.5"
c.content.headers.referer = "same-domain"
c.content.headers.custom = {
    "Permissions-Policy": "geolocation=(), microphone=(), camera=(), interest-cohort=()"
}
c.content.cookies.accept = "no-3rdparty"
c.content.headers.do_not_track = True
c.content.blocking.enabled = True
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
]
c.content.dns_prefetch = True
c.content.autoplay = False
c.content.geolocation = False


# ============================================================================
# Hint Selection Settings
# ============================================================================
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


# ============================================================================
# Search & Completion Settings
# ============================================================================
c.completion.open_categories = [
    "quickmarks",
    "searchengines",
    "bookmarks",
    "history",
]

# Custom quick keyword-based search engines
c.url.searchengines = {
    "DEFAULT": "https://www.google.com/search?q={}",
    "d": "https://duckduckgo.com/?q={}",
    "w": "https://en.wikipedia.org/wiki/{}",
    "yt": "https://www.youtube.com/results?search_query={}",
    "aw": "https://wiki.archlinux.org/?search={}",
}

# Always search if input isn't a URL
c.url.auto_search = "naive"


# ============================================================================
# Key Bindings
# ============================================================================
# Tab navigation
config.bind("<Alt-Right>", "tab-next")
config.bind("<Alt-Left>", "tab-prev")
config.bind("<Ctrl-Shift-Right>", "open -t {url}")

# Web archive
config.bind(",w", "open http://web.archive.org/{url}")

# External browser
config.bind("<Ctrl+Alt+t>", "spawn -d zen-browser {url} ;; tab-close")

# Custom userscripts
config.bind(",v", "spawn --userscript vibrance.sh")
config.bind(
    ",b",
    "spawn ~/.dotfiles/scripts/rofi/bookmarks.sh {url} ;; message-info 'Bookmark added'",
)

# Hint links
config.bind(";f", "hint links run open {hint-url}")
