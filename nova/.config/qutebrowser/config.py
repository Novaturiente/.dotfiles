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
# URL Interceptors (tracking param stripping + privacy redirects)
# ============================================================================

import operator
from qutebrowser.api import interceptor
from qutebrowser.qt.core import QUrl, QUrlQuery

# --- Redirect to privacy-friendly frontends ---
REDIRECT_MAP = {
    "www.reddit.com": operator.methodcaller("setHost", "old.reddit.com"),
    "reddit.com": operator.methodcaller("setHost", "old.reddit.com"),
    "www.fandom.com": operator.methodcaller("setHost", "breezewiki.com"),
    "fandom.com": operator.methodcaller("setHost", "breezewiki.com"),
    "medium.com": operator.methodcaller("setHost", "freedium.cfd"),
}

def _redirect(info: interceptor.Request):
    if info.resource_type != interceptor.ResourceType.main_frame:
        return
    url = info.request_url
    redir = REDIRECT_MAP.get(url.host())
    if redir is not None and redir(url) is not False:
        info.redirect(url)

interceptor.register(_redirect)

# --- Strip tracking parameters from all URLs ---
TRACKING_PARAMS = {
    "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id",
    "fbclid", "fb_action_ids", "fb_action_types", "fb_source", "fb_ref",
    "gclid", "gclsrc", "dclid",
    "msclkid",
    "ysclid", "yclid",
    "_hsenc", "_hsmi", "__hstc", "__hsfp", "hsCtaTracking",
    "mc_cid", "mc_eid",
}

def _strip_tracking(info: interceptor.Request):
    url = info.request_url
    if not url.hasQuery():
        return
    query = QUrlQuery(url.query())
    items = query.queryItems()
    stripped = [(k, v) for k, v in items if k not in TRACKING_PARAMS]
    if len(stripped) < len(items):
        new_url = QUrl(url)
        new_query = QUrlQuery()
        for k, v in stripped:
            new_query.addQueryItem(k, v)
        new_url.setQuery(new_query)
        try:
            info.redirect(new_url)
        except Exception:
            pass

interceptor.register(_strip_tracking)

# ============================================================================
# Theme
# ============================================================================

config.source("themes/city-lights-theme.py")
# config.source("themes/pywal-theme.py")

# ============================================================================
# Page Appearance & Dark Mode
# ============================================================================

# Dark mode settings
c.colors.webpage.bg = "#1D252C"
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.preferred_color_scheme = "dark"
c.colors.webpage.darkmode.policy.images = "never"
c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.contrast = 0.0
c.colors.webpage.darkmode.threshold.foreground = 150
c.colors.webpage.darkmode.threshold.background = 205

# ============================================================================
# Tabs Configuration
# ============================================================================

# Tab display settings
c.tabs.position = "top"
# c.tabs.width = 125
c.tabs.title.format = "{current_title}"
c.tabs.title.alignment = "left"
c.tabs.padding = {"top": 5, "bottom": 5, "left": 5, "right": 5}
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
c.downloads.location.directory = "~/Downloads/"
c.downloads.remove_finished = 3000  # milliseconds

# ============================================================================
# Input Mode
# ============================================================================

# Default to insert mode for input fields
c.input.insert_mode.auto_enter = True
c.input.insert_mode.auto_load = True
c.input.insert_mode.leave_on_load = False

# ============================================================================
# Scrolling & Search
# ============================================================================

c.scrolling.smooth = True
c.search.ignore_case = "smart"
c.search.wrap = True

# ============================================================================
# Performance & Hardware Acceleration
# ============================================================================

c.qt.args = [
    # GPU compositing on (smooth scroll), video hwdec off (vaapi crashes on Intel Meteor Lake + Mesa 26)
    "enable-gpu-rasterization",
    "disable-features=VaapiVideoDecoder,VaapiVideoEncoder,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,UseChromeOSDirectVideoDecoder",
]
c.qt.chromium.low_end_device_mode = "never"

# ============================================================================
# Privacy & Security
# ============================================================================

# User agent (mimics Edge/Chrome on Windows)
# c.content.headers.user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"

# JavaScript settings
c.content.javascript.clipboard = "access-paste"
c.content.javascript.can_open_tabs_automatically = False

# Canvas reading enabled (required for Cloudflare challenges), WebGL disabled (fingerprinting)
c.content.canvas_reading = True
c.content.webgl = False

# Header privacy settings
c.content.headers.accept_language = "en-US,en;q=0.5"
c.content.headers.referer = "same-domain"
c.content.headers.do_not_track = True
c.content.headers.custom = {}

# Cookie settings
c.content.cookies.accept = "no-3rdparty"

# Tracking and fingerprinting protection
c.content.hyperlink_auditing = False
c.content.dns_prefetch = True

# Content blocking (both = adblock engine + hosts file simultaneously)
c.content.blocking.enabled = True
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances-cookies.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/annoyances-others.txt",
    "https://secure.fanboy.co.nz/fanboy-annoyance.txt",
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
    "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus&showintro=1&mimetype=plaintext",
]
c.content.blocking.hosts.lists = [
    "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts",
]

# Media and location permissions
c.content.autoplay = False
c.content.geolocation = False
c.content.notifications.enabled = False
c.content.media.audio_capture = False
c.content.media.video_capture = False
c.content.desktop_capture = False
c.content.mouse_lock = False
c.content.persistent_storage = False
c.content.register_protocol_handler = False
c.content.pdfjs = False
# Open downloaded PDFs (and other files via :download-open) in zathura
c.downloads.open_dispatcher = "zathura"
c.content.webrtc_ip_handling_policy = "disable-non-proxied-udp"
c.content.local_content_can_access_remote_urls = False
c.content.tls.certificate_errors = "block"

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

    p.content.headers.user_agent = "Mozilla/5.0 (X11; Linux x86_64; rv:139.0) Gecko/20100101 Firefox/139.0"

# Google Services (General)
with config.pattern("*://*.google.com/*") as p:
    p.content.geolocation = True

# ============================================================================
# External Editor
# ============================================================================

# Ctrl+E in insert mode opens the field in neovide
c.editor.command = ["neovide", "--nofork", "+{line}:{column}", "{file}"]

# ============================================================================
# Hint Selection & Navigation
# ============================================================================

# Home row hint characters (faster to type than default)
c.hints.chars = "asdfghjkl"
c.hints.uppercase = True
c.fonts.hints = "bold 13px default_family"
c.hints.border = "2px solid #cba6f7"
c.hints.radius = 3

# Enhanced hint selectors for better element detection
c.hints.selectors["all"].extend(
    [
        "[aria-haspopup]",  # Dropdown elements
        '[role="link"]',
        '[role="button"]',
        "[onclick]",
        "[data-action]",
        "summary",
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
    "DEFAULT": "https://www.startpage.com/do/dsearch?query={}",
    "g": "https://www.google.com/search?q={}",
    "d": "https://duckduckgo.com/?q={}",
    "yt": "https://www.youtube.com/results?search_query={}",
}

# Auto-search behavior
c.url.auto_search = "naive"

# Start page
c.url.start_pages = ["https://www.startpage.com/"]
c.url.default_page = "https://www.startpage.com/"

# ============================================================================
# Spellcheck
# ============================================================================

c.spellcheck.languages = ["en-US"]

# ============================================================================
# Key Bindings
# ============================================================================

# Key mapping
c.bindings.key_mappings["<Ctrl-x>"] = "<Escape>"

# Insert mode - Escape behavior
config.bind(
    "<Escape>", "mode-leave ;; jseval -q document.activeElement.blur()", mode="insert"
)

# Focus first visible input field and auto-enter insert mode (via auto_enter setting)
config.bind("i", "jseval -q (function(){var inputs=document.querySelectorAll('input:not([type=hidden]):not([type=submit]):not([type=button]):not([type=checkbox]):not([type=radio]):not([disabled]),textarea:not([disabled]),[contenteditable=true]');for(var i=0;i<inputs.length;i++){var r=inputs[i].getBoundingClientRect();if(r.width>0&&r.height>0&&r.top>=0&&r.top<window.innerHeight){inputs[i].focus();return}}})() ;; later 50 enter-mode insert")
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

# Dark mode toggles
config.bind("<Space>dm", "spawn --userscript toggle_darkmode.py")
config.bind("<Space>dM", "config-cycle colors.webpage.darkmode.enabled true false ;; reload ;; message-info 'Toggled global dark mode'")

# Wayback Machine
config.bind("<Space>wa", "open --tab https://web.archive.org/save/{url} ;; message-info 'Archiving page...'")
config.bind("<Space>wv", "open --tab https://web.archive.org/web/*/{url}")

# Tab navigation
config.bind("<Alt-Right>", "tab-next")
config.bind("<Alt-Left>", "tab-prev")
config.bind("<Space>tt", "config-cycle tabs.position left top ;; message-info 'Toggled Tabs Layout'")

# External applications
config.bind("<Ctrl+Alt+t>", "spawn -d thorium-browser-avx2 {url} ;; tab-close")

# Media and video bindings
config.bind("<Space>c", "hint links spawn --userscript cast.sh {hint-url}")
config.bind("<Space>m", "hint links spawn mpv --script-opts=sponsorblock_minimal-categories=sponsor {hint-url}")
config.bind("<Space>mp", "spawn --detach mpv --script-opts=sponsorblock_minimal-categories=sponsor --force-window=immediate {url}")
config.bind("<Space>v", "spawn --userscript vibrance.sh")
# Open most recent download (PDF) in zathura via downloads.open_dispatcher
config.bind("<Space>z", "download-open")
