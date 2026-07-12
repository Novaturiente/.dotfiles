c = c  # pyright: ignore
config = config  # pyright: ignore

# Load settings made via the :set command from autoconfig.yml.
config.load_autoconfig(False)  # Set to True if you want to keep using autoconfig.yml

# Theme
# config.source("onedark.py")
# import everforest
# everforest.set(c, scheme="dark", intensity="hard")
import modern_dark

modern_dark.setup(c)


# ============================================================================
# Tab Settings
# ============================================================================
c.url.start_pages = "https://search.novarch.site"
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
    "enable-gpu-rasterization",
    "enable-zero-copy",
    # vaapi crashes on Intel Meteor Lake + Mesa 26, so video hwdec stays off
    "disable-features=VaapiVideoDecoder,VaapiVideoEncoder,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL,UseChromeOSDirectVideoDecoder",
    # WebRTCPipeWireCapturer: required for screen sharing on Wayland
    "enable-features=WebRTCPipeWireCapturer,CanvasOopRasterization,ParallelDownloading",
]
c.qt.chromium.low_end_device_mode = "never"


# ============================================================================
# Privacy and Blocking Settings
# ============================================================================
# User agent is left at the default: it tracks the running Chromium version and
# already hides the QtWebEngine part. The site-specific quirks below send a
# Firefox UA to accounts.google.com on their own.
c.content.headers.accept_language = "en-US,en;q=0.9"
c.content.headers.custom = {"Sec-GPC": "1"}  # DNT is dead; GPC is enforceable
c.content.headers.do_not_track = None

# Block third-party cookies. The pattern below is matched against the FIRST-PARTY
# url (the page in the address bar), not the cookie's origin, so redirect-based
# SSO still works: you physically land on accounts.google.com during the
# handshake. Only silent-refresh flows in hidden iframes need an exception here.
c.content.cookies.accept = "no-3rdparty"
with config.pattern("*://*.google.com/*") as p:
    p.content.cookies.accept = "all"

c.content.blocking.enabled = True
c.content.blocking.method = "adblock"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/privacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/badware.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/unbreak.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/quick-fixes.txt",
    "https://secure.fanboy.co.nz/fanboy-annoyance.txt",
    "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
]
c.content.canvas_reading = True  # off breaks reCAPTCHA and Google sign-in
c.content.dns_prefetch = False
c.content.autoplay = False
c.content.tls.certificate_errors = "ask-block-thirdparty"


# ============================================================================
# HTTPS-only mode (qutebrowser has no built-in setting for this)
# ============================================================================
import ipaddress

from qutebrowser.api import interceptor
from qutebrowser.qt.core import QUrl


# Tailscale hands out 100.64.0.0/10 (CGNAT), which ipaddress does not call private
_TAILSCALE_NET = ipaddress.ip_network("100.64.0.0/10")


def _is_local(host: str) -> bool:
    """Private/loopback hosts stay on http: routers, captive portals, Tailscale."""
    if not host or host == "localhost" or host.endswith((".local", ".lan", ".internal")):
        return True
    try:
        addr = ipaddress.ip_address(host)
    except ValueError:
        return False
    return addr.is_private or addr.is_loopback or addr in _TAILSCALE_NET


def _upgrade_to_https(info: interceptor.Request) -> None:
    url = info.request_url
    if url.scheme() != "http" or _is_local(url.host()):
        return
    https_url = QUrl(url)
    https_url.setScheme("https")
    # ignore_unsupported: POST and friends can't be redirected; let them through
    info.redirect(https_url, ignore_unsupported=True)


interceptor.register(_upgrade_to_https)

# ============================================================================
# Web Feature Permissions
# ============================================================================
# "ask" prompts per site. True auto-grants to every site with no prompt.
c.content.geolocation = False
c.content.notifications.enabled = "ask"
c.content.media.audio_capture = "ask"
c.content.media.video_capture = "ask"
c.content.desktop_capture = "ask"
c.content.persistent_storage = "ask"
c.content.register_protocol_handler = "ask"
c.content.javascript.clipboard = "ask"
c.content.mouse_lock = "ask"
c.content.javascript.can_open_tabs_automatically = False

c.content.fullscreen.window = True
c.content.pdfjs = False
# Open downloaded PDFs (and other files via :download-open) in zathura
c.downloads.open_dispatcher = "zathura"
# all-interfaces leaks every NIC (incl. Tailscale) to any page's JS
c.content.webrtc_ip_handling_policy = "default-public-interface-only"
c.content.webgl = True  # off breaks Meet, Maps, Jira dashboards
c.content.local_storage = True
c.content.site_specific_quirks.enabled = True  # required for Google login
c.content.prefers_reduced_motion = False
c.content.default_encoding = "utf-8"
c.content.local_content_can_access_file_urls = True
c.content.unknown_url_scheme_policy = "allow-from-user-interaction"

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
# For focusing scrollable frames (e.g. Jira, Confluence) via :hint frame
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
    "DEFAULT": "https://search.novarch.site/search?q={}",
    "g": "https://www.google.com/search?q={}",
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
c.aliases["toggle-dark-mode"] = (
    "config-cycle colors.webpage.darkmode.enabled true false ;; reload ;; message-info 'Toggled Dark Mode'"
)
c.aliases["toggle-tabs-layout"] = (
    "config-cycle tabs.position left top ;; message-info 'Toggled Tabs Layout'"
)

# ============================================================================

# Bind to the aliases
config.bind("<Space>tg", "toggle-adblock")
config.bind("<Space>td", "toggle-dark-mode")
config.bind("<Space>tt", "toggle-tabs-layout")
# Open most recent download (PDF) in zathura via downloads.open_dispatcher
config.bind("<Space>z", "download-open")

# Window Management
config.bind("<Ctrl-n>", "open -w")

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
