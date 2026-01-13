# ============================================================================
# Qutebrowser Configuration
# ============================================================================
c = c  # pyright: ignore
config = config  # pyright: ignore

# ============================================================================
# Autoconfig
# ============================================================================

# Load settings from autoconfig.yml (set to True to merge with UI settings)
config.load_autoconfig(False)

# ============================================================================
# Theme
# ============================================================================

config.source("themes/city-lights-theme.py")
# config.source("themes/pywal-theme.py")

# ============================================================================
# Page Appearance & Dark Mode
# ============================================================================

# Dark mode settings
c.colors.webpage.bg = "#282828"
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.webpage.darkmode.policy.images = "never"

# ============================================================================
# Tabs Configuration
# ============================================================================

# Tab display settings
# c.tabs.position = "right"
# c.tabs.width = 125
c.tabs.title.format = "{current_title}"
c.tabs.title.alignment = "center"
c.tabs.padding = {"top": 5, "bottom": 5, "left": 0, "right": 0}
c.tabs.favicons.scale = 1
c.fonts.tabs.selected = "12pt default_family"
c.fonts.tabs.unselected = "10pt default_family"

# Tab behavior
c.tabs.last_close = "startpage"
c.tabs.select_on_remove = "last-used"

# ============================================================================
# Session Management
# ============================================================================

c.auto_save.session = True
c.session.lazy_restore = True

# ============================================================================
# Downloads
# ============================================================================

c.downloads.position = "bottom"
c.downloads.remove_finished = 3000  # milliseconds

# ============================================================================
# Input Mode
# ============================================================================

# Default to insert mode for input fields
c.input.insert_mode.auto_enter = True
c.input.insert_mode.auto_load = True
c.input.insert_mode.leave_on_load = True

# ============================================================================
# Mic
# ============================================================================

c.scrolling.smooth = True
c.search.ignore_case = "smart"
c.search.wrap = True

# ============================================================================
# Performance & Hardware Acceleration
# ============================================================================

c.qt.args = [
    "enable-gpu-rasterization",
    "enable-accelerated-video-decode",
    "enable-quic",
]

# ============================================================================
# Privacy & Security
# ============================================================================

# User agent (mimics Edge/Chrome on Windows)
c.content.headers.user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

# JavaScript settings
c.content.javascript.clipboard = "access-paste"
# c.content.javascript.enabled = False

# Canvas and WebGL (disabled for fingerprinting protection)
c.content.canvas_reading = False
c.content.webgl = False

# Header privacy settings
c.content.headers.accept_language = "en-US,en;q=0.5"
c.content.headers.referer = "same-domain"
c.content.headers.do_not_track = True
c.content.headers.custom = {
    "Permissions-Policy": "geolocation=(), microphone=(), camera=(), interest-cohort=()"
}

# Cookie settings
c.content.cookies.accept = "no-3rdparty"

# Tracking and fingerprinting protection
c.content.hyperlink_auditing = False
c.content.dns_prefetch = True

# Content blocking
c.content.blocking.enabled = True
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
]

# Media and location permissions
c.content.autoplay = False
c.content.geolocation = False

# Site compatibility
c.content.site_specific_quirks.enabled = True

# ============================================================================
# Site Specific Overrides
# ============================================================================

# Google Login (Fix "Browser not supported")
with config.pattern("*://accounts.google.com/*") as p:
    p.content.canvas_reading = True
    p.content.webgl = True
    p.content.blocking.enabled = False
    p.content.cookies.accept = "all"
    p.content.headers.referer = "always"
    p.content.headers.user_agent = "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0"

# Google Services (General)
with config.pattern("*://*.google.com/*") as p:
    p.content.geolocation = True

# ============================================================================
# Hint Selection & Navigation
# ============================================================================

# Enhanced hint selectors for better element detection
c.hints.selectors["all"].extend(
    [
        "[aria-haspopup]",  # Dropdown elements
        '[role="link"]',
        '[role="button"]',
    ]
)

# Frame scrolling selectors
c.hints.selectors["frame"] = ["div", "header", "section", "nav"]

# ============================================================================
# Completion & Search
# ============================================================================

# Completion settings
c.completion.shrink = True
c.completion.open_categories = [
    "quickmarks",
    "bookmarks",
    "searchengines",
    "history",
]

# Search engines
c.url.searchengines = {
    "DEFAULT": "https://duckduckgo.com/?q={}",
    "g": "https://www.google.com/search?q={}",
    "yt": "https://www.youtube.com/results?search_query={}",
}

# Auto-search behavior
c.url.auto_search = "naive"

# Start page
c.url.start_pages = ["https://www.perplexity.ai/"]

# ============================================================================
# Key Bindings
# ============================================================================

# Key mapping
c.bindings.key_mappings["<Ctrl-x>"] = "<Escape>"

# Insert mode - Escape behavior
config.bind(
    "<Escape>", "mode-leave ;; jseval -q document.activeElement.blur()", mode="insert"
)

# Hint mode bindings
config.bind("I", "hint inputs")
config.bind("h", "hint all hover")
config.bind(";f", "hint links run open {hint-url}")

# Load darkmode exclusions
import os

exclude_file = os.path.expanduser("~/.config/qutebrowser/darkmode_excludes")
if os.path.exists(exclude_file):
    with open(exclude_file, "r") as f:
        c.colors.webpage.darkmode.enabled = True  # Default to True
        for line in f:
            domain = line.strip()
            if domain:
                with config.pattern(f"*://{domain}/*") as p:
                    p.colors.webpage.darkmode.enabled = False

# Toggle dark mode binding


config.bind(",dm", "spawn --userscript toggle_darkmode.py")
config.bind(
    ",b",
    "spawn ~/.dotfiles/scripts/rofi/bookmarks.sh {url} ;; message-info 'Bookmark added'",
)


# Password Manager (Pass + Rofi)
config.bind(
    ",pl",
    'spawn --userscript qute-pass --dmenu-invocation "rofi -dmenu -p Login"',
)
config.bind(
    ",pu",
    'spawn --userscript qute-pass --username-only --dmenu-invocation "rofi -dmenu -p Login"',
)
config.bind(
    ",pp",
    'spawn --userscript qute-pass --password-only --dmenu-invocation "rofi -dmenu -p Login"',
)
config.bind(",pa", "spawn --userscript qute-pass-add")

# Tab navigation
config.bind("<Alt-Right>", "tab-next")
config.bind("<Alt-Left>", "tab-prev")

# External applications
config.bind("<Ctrl+Alt+t>", "spawn -d floorp {url} ;; tab-close")

# Media and video bindings
config.bind(",c", "hint links spawn --userscript cast.sh {hint-url}")
config.bind(",m", "hint links spawn mpv {hint-url}")
config.bind(",v", "spawn --userscript vibrance.sh")
