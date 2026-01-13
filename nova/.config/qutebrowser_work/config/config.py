c = c  # pyright: ignore
config = config  # pyright: ignore

# Load settings made via the :set command from autoconfig.yml.
config.load_autoconfig(False)  # Set to True if you want to keep using autoconfig.yml

# Enable JavaScript clipboard access
c.content.javascript.clipboard = "access-paste"

# Theme
# config.source("onedark.py")
# import everforest
# everforest.set(c, scheme="dark", intensity="hard")
import modern_dark

modern_dark.setup(c)


# ============================================================================
# Tab Settings
# ============================================================================
c.url.start_pages = "https://google.com"
c.tabs.position = "top"
c.tabs.title.format = "{current_title}"
c.tabs.padding = {"top": 5, "bottom": 5, "left": 5, "right": 5}
c.tabs.title.alignment = "left"
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

# Load darkmode exclusions
import os

exclude_file = os.path.expanduser("~/.config/qutebrowser_work/config/darkmode_excludes")
if os.path.exists(exclude_file):
    with open(exclude_file, "r") as f:
        c.colors.webpage.darkmode.enabled = True
        for line in f:
            domain = line.strip()
            if domain:
                with config.pattern(f"*://{domain}/*") as p:
                    p.colors.webpage.darkmode.enabled = False

# Toggle dark mode binding
# Toggle dark mode binding (Moved to Aliases section below)

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
# Performance & GPU Acceleration
# ============================================================================
c.qt.args = [
    "enable-gpu-rasterization",
    "enable-accelerated-video-decode",
    "ignore-gpu-blocklist",
    "enable-zero-copy",
    # Allow WS:// form HTTPS (Mixed Content)
    "allow-running-insecure-content",
]


# ============================================================================
# Privacy and Blocking Settings
# ============================================================================
c.content.headers.user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"
# Mimic Firefox for Google Login to bypass "Browser not supported"
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0",
    "https://accounts.google.com/*",
)
# c.content.javascript.enabled = False
c.content.headers.accept_language = "en-US,en;q=0.5"
c.content.headers.referer = "same-domain"
c.content.headers.custom = {}
c.content.cookies.accept = "all"
c.content.headers.do_not_track = True

c.content.blocking.enabled = True
c.content.blocking.method = "adblock"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
    "https://secure.fanboy.co.nz/fanboy-annoyance.txt",  # Blocks social widgets, popups, annoyances
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",  # Blocks cookie consent banners
]
c.content.canvas_reading = True  # Crucial for Cloudflare verification
c.content.dns_prefetch = True
c.content.autoplay = True
c.content.geolocation = True

# Allow Local Sync Bridge (ws://localhost) from HTTPS pages
c.content.local_content_can_access_remote_urls = True
# c.content.javascript.can_access_clipboard = True # Already set above

config.bind("o", "cmd-set-text -s :open")
config.bind("O", "cmd-set-text -s :open -t")

c.downloads.location.directory = "~/Downloads/"

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
    "searchengines",
    "history",
]

# Custom quick keyword-based search engines
c.url.searchengines = {
    "DEFAULT": "https://www.google.com/search?q={}",
}

# Always search if input isn't a URL
c.url.auto_search = "naive"


# ============================================================================
# Key Bindings
# ============================================================================
# Tab navigation
c.tabs.show = "always"
config.bind("<Alt-Right>", "tab-next")
config.bind("<Alt-Left>", "tab-prev")
config.bind("<Ctrl-Shift-Right>", "open -t {url}")
config.bind("<Ctrl-Shift-Right>", "open -t {url}")
# config.bind("tt", "config-cycle tabs.show always never ;; message-info 'Toggled Tabs'") # Replaced by Space+tt for position

# External browser
config.bind("<Ctrl+Alt+t>", "spawn -d zen-browser {url} ;; tab-close")

config.bind(
    ",b",
    "spawn ~/.dotfiles/scripts/rofi/bookmarks.sh {url} ;; message-info 'Bookmark added'",
)

# ============================================================================
# Key Bindings & Aliases
# ============================================================================

# Space is being used as a Leader Key.
# If it was previously bound to 'scroll', this binding is overridden or removed.
# We do not need to explicitly unbind it if it causes errors.

# Define meaningful aliases so they show up in the menu properly
c.aliases["login-choose"] = (
    'spawn --userscript qute-pass --dmenu-invocation "rofi -dmenu -p Login"'
)
c.aliases["login-username"] = (
    'spawn --userscript qute-pass --username-only --dmenu-invocation "rofi -dmenu -p Login"'
)
c.aliases["login-password"] = (
    'spawn --userscript qute-pass --password-only --dmenu-invocation "rofi -dmenu -p Login"'
)
c.aliases["password-add"] = "spawn --userscript qute-pass-add"
c.aliases["password-fill-auto"] = "spawn --userscript password_fill"
c.aliases["toggle-adblock"] = (
    "config-cycle content.blocking.enabled true false ;; message-info 'Toggled Adblock'"
)
c.aliases["toggle-mobile-view"] = "spawn --userscript toggle_mobile_view"
c.aliases["toggle-dark-mode"] = "spawn --userscript toggle_darkmode.py"
c.aliases["bookmarks-search"] = "spawn --userscript rofi_bookmarks"
c.aliases["window-clone"] = "spawn --userscript open_cloned_window"
c.aliases["sync-toggle"] = "spawn --userscript sync_bridge.py"
c.aliases["toggle-tabs-layout"] = (
    "config-cycle tabs.position left top ;; message-info 'Toggled Tabs Layout'"
)

# ============================================================================

# Bind to the aliases
config.bind("<Space>pl", "login-choose")
config.bind("<Space>pu", "login-username")
config.bind("<Space>pp", "login-password")
config.bind("<Space>pa", "password-add")
config.bind("<Space>pf", "password-fill-auto")

config.bind("<Space>tg", "toggle-adblock")
config.bind("<Space>td", "toggle-dark-mode")
config.bind("<Space>tm", "toggle-mobile-view")
config.bind("<Space>sb", "bookmarks-search")
config.bind("<Space>ts", "sync-toggle")
config.bind("<Space>tt", "toggle-tabs-layout")

# Window Management
config.bind("<Ctrl-n>", "open -w")  # Standard New Window
config.bind("<Ctrl-Shift-n>", "window-clone")  # Clone Window Size

# Mode Exits
config.bind("<Alt-Backspace>", "mode-leave", mode="insert")
config.bind("<Alt-Backspace>", "mode-leave", mode="passthrough")

# ============================================================================
# Theme Overrides
# ============================================================================
c.colors.keyhint.fg = "#AAAAAA"  # Grey for the description/header
c.colors.keyhint.suffix.fg = "#FFFF00"  # Yellow for the keys to press
