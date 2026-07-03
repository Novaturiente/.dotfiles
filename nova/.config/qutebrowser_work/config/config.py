c = c  # pyright: ignore
config = config  # pyright: ignore

# Load settings made via the :set command from autoconfig.yml.
config.load_autoconfig(False)  # Set to True if you want to keep using autoconfig.yml

# Enable full JavaScript clipboard access (copy + paste)
c.content.javascript.clipboard = "access"

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
# Dark Mode Settings (disabled for maximum compatibility)
# ============================================================================
c.colors.webpage.bg = "#282828"
c.colors.webpage.darkmode.enabled = False
c.colors.webpage.preferred_color_scheme = "auto"

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
    # GPU compositing on (smooth scroll), video hwdec off (vaapi crashes on Intel Meteor Lake + Mesa 26)
    "enable-gpu-rasterization",
    "enable-zero-copy",
    "ignore-gpu-blocklist",
    "num-raster-threads=4",
    "enable-quic",
    "disable-features=VaapiVideoDecoder,VaapiVideoEncoder,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,UseChromeOSDirectVideoDecoder",
    "enable-features=WebRTCPipeWireCapturer,CanvasOopRasterization,ParallelDownloading",
    # Allow WS:// from HTTPS (Mixed Content)
    "allow-running-insecure-content",
]
c.qt.chromium.low_end_device_mode = "never"


# ============================================================================
# Privacy and Blocking Settings
# ============================================================================
c.content.headers.user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
# Mimic Firefox for Google Login to bypass "Browser not supported"
config.set(
    "content.headers.user_agent",
    "Mozilla/5.0 (X11; Linux x86_64; rv:139.0) Gecko/20100101 Firefox/139.0",
    "https://accounts.google.com/*",
)
c.content.headers.accept_language = "en-US,en;q=0.9"
c.content.headers.referer = "always"
c.content.headers.custom = {}
c.content.cookies.accept = "all"
c.content.headers.do_not_track = None

c.content.blocking.enabled = True
c.content.blocking.method = "adblock"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
    "https://secure.fanboy.co.nz/fanboy-annoyance.txt",
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
]
c.content.canvas_reading = True
c.content.dns_prefetch = True
c.content.autoplay = True
c.content.geolocation = True

# ============================================================================
# Web Feature Permissions (Chrome-like defaults)
# ============================================================================
c.content.notifications.enabled = True
c.content.media.audio_capture = True
c.content.media.video_capture = True
c.content.desktop_capture = True
c.content.persistent_storage = True
c.content.register_protocol_handler = True
c.content.fullscreen.window = True
c.content.pdfjs = False
# Open downloaded PDFs (and other files via :download-open) in zathura
c.downloads.open_dispatcher = "zathura"
c.content.webrtc_ip_handling_policy = "all-interfaces"
c.content.webgl = True
c.content.local_storage = True
c.content.mouse_lock = True
c.content.javascript.can_open_tabs_automatically = True
c.content.site_specific_quirks.enabled = True
c.content.prefers_reduced_motion = False
c.content.default_encoding = "utf-8"
c.content.local_content_can_access_file_urls = True
c.content.unknown_url_scheme_policy = "allow-from-user-interaction"

# Allow Local Sync Bridge (ws://localhost) from HTTPS pages
c.content.local_content_can_access_remote_urls = True

# ============================================================================
# Download & External App Settings
# ============================================================================
config.bind("o", "cmd-set-text -s :open")
config.bind("O", "cmd-set-text -s :open -t")

c.downloads.location.directory = "~/Downloads/"
c.downloads.location.prompt = False
c.new_instance_open_target = "tab"

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
# config.bind("tt", "config-cycle tabs.show always never ;; message-info 'Toggled Tabs'") # Replaced by Space+tt for position

# External browser
config.bind("<Ctrl+Alt+t>", "spawn -d thorium-browser-avx2 {url} ;; tab-close")

# ============================================================================
# Key Bindings & Aliases
# ============================================================================

# Space is being used as a Leader Key.
# If it was previously bound to 'scroll', this binding is overridden or removed.
# We do not need to explicitly unbind it if it causes errors.

# Define meaningful aliases so they show up in the menu properly
c.aliases["toggle-adblock"] = (
    "config-cycle content.blocking.enabled true false ;; message-info 'Toggled Adblock'"
)
c.aliases["toggle-mobile-view"] = "spawn --userscript toggle_mobile_view"
c.aliases["toggle-dark-mode"] = (
    "config-cycle colors.webpage.darkmode.enabled true false ;; reload ;; message-info 'Toggled Dark Mode'"
)
c.aliases["bookmarks-search"] = "spawn --userscript rofi_bookmarks"
c.aliases["window-clone"] = "spawn --userscript open_cloned_window"
c.aliases["sync-toggle"] = "spawn --userscript sync_bridge.py"
c.aliases["toggle-tabs-layout"] = (
    "config-cycle tabs.position left top ;; message-info 'Toggled Tabs Layout'"
)

# ============================================================================

# Bind to the aliases
config.bind("<Space>tg", "toggle-adblock")
config.bind("<Space>td", "toggle-dark-mode")
config.bind("<Space>tm", "toggle-mobile-view")
config.bind("<Space>sb", "bookmarks-search")
config.bind("<Space>ts", "sync-toggle")
config.bind("<Space>tt", "toggle-tabs-layout")
# Open most recent download (PDF) in zathura via downloads.open_dispatcher
config.bind("<Space>z", "download-open")

# Window Management
config.bind("<Ctrl-n>", "open -w")  # Standard New Window
config.bind("<Ctrl-Shift-n>", "window-clone")  # Clone Window Size

# Mode Exits
config.bind("<Alt-Backspace>", "mode-leave", mode="insert")
config.bind("<Alt-Backspace>", "mode-leave", mode="passthrough")

# DevTools (web testing)
config.bind("<F12>", "devtools")
config.bind("<Ctrl-Shift-i>", "devtools")

# ============================================================================
# Spellcheck
# ============================================================================
c.spellcheck.languages = ["en-US"]

# ============================================================================
# Theme Overrides
# ============================================================================
c.colors.keyhint.fg = "#AAAAAA"  # Grey for the description/header
c.colors.keyhint.suffix.fg = "#FFFF00"  # Yellow for the keys to press
