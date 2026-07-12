c = c  # pyright: ignore
config = config  # pyright: ignore

# Load settings made via the :set command from autoconfig.yml.
# Must be True, otherwise "Always"/"Never" on a permission prompt is written to
# autoconfig.yml and then never read back, so every site re-asks on each restart.
# Globals set below still win over autoconfig; per-domain answers are what persist.
config.load_autoconfig(True)

# Theme
import catppuccin_mocha

catppuccin_mocha.setup(c)


# ============================================================================
# Fonts / UI legibility
# ============================================================================
# One family, one size, set in one place. 11pt beats the 10pt default on a
# 1080p 14" panel without eating vertical space.
c.fonts.default_family = "JetBrainsMonoNL Nerd Font"
c.fonts.default_size = "11pt"
c.fonts.web.family.standard = "SF Pro Display"
c.fonts.web.family.sans_serif = "SF Pro Display"
c.fonts.web.family.serif = "Noto Serif"
c.fonts.web.family.fixed = "JetBrainsMonoNL Nerd Font"
c.fonts.web.size.default = 16
c.fonts.web.size.minimum = 12  # kill unreadable 8px small print
c.fonts.hints = "bold 12pt JetBrainsMonoNL Nerd Font"
c.fonts.statusbar = "11pt JetBrainsMonoNL Nerd Font"


# ============================================================================
# Tab Settings
# ============================================================================
c.url.start_pages = "https://search.novarch.site"
c.tabs.position = "top"
c.tabs.title.format = "{audio}{index}: {current_title}"  # {audio} shows 🔊/🔇
c.tabs.title.format_pinned = "{audio}{index}"
c.tabs.padding = {"top": 5, "bottom": 5, "left": 8, "right": 8}
c.tabs.title.alignment = "left"
c.tabs.favicons.scale = 1
c.tabs.last_close = "startpage"
c.tabs.indicator.width = 3
c.tabs.min_width = 140  # stop tabs collapsing to unreadable slivers
c.tabs.max_width = 320
c.tabs.mousewheel_switching = False  # no more accidental tab changes on scroll


# ============================================================================
# Statusbar / window
# ============================================================================
c.statusbar.widgets = ["keypress", "url", "scroll", "history", "progress"]
c.statusbar.padding = {"top": 4, "bottom": 4, "left": 6, "right": 6}
c.window.title_format = "{current_title} — qutebrowser"
c.messages.timeout = 4000  # 2s default is too quick to actually read


# ============================================================================
# Zoom
# ============================================================================
c.zoom.default = "100%"
c.zoom.levels = [
    "25%", "33%", "50%", "67%", "75%", "90%",
    "100%", "110%", "125%", "150%", "175%", "200%", "250%", "300%",
]


# ============================================================================
# Session Management
# ============================================================================
c.auto_save.session = True


# ============================================================================
# Dark Mode Settings
# ============================================================================
# Ask sites for their own dark theme first. Sites that have one (github, etc.)
# use it as-is: Chromium's smart page policy skips force-darkening them.
c.colors.webpage.preferred_color_scheme = "dark"

# Force-dark the rest. lightness-cielab inverts lightness in CIELAB space, which
# keeps hues intact; smart image policy leaves photos alone but darkens diagrams.
c.colors.webpage.darkmode.enabled = True
c.colors.webpage.darkmode.algorithm = "lightness-cielab"
c.colors.webpage.darkmode.policy.page = "smart"
c.colors.webpage.darkmode.policy.images = "smart"

# Sites that look wrong force-darkened. Toggle with <Space>td (toggle_darkmode.py
# userscript), which rewrites this file; we re-apply it here on every start
# because runtime ":set -u" only reaches autoconfig.yml, which is not loaded.
_darkmode_excludes = config.configdir / "darkmode_excludes"
if _darkmode_excludes.exists():
    for _domain in _darkmode_excludes.read_text().split():
        with config.pattern(f"*://{_domain}/*") as p:
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
# Loopback, RFC1918, Tailscale CGNAT and dotless LAN names are exempt already.
# Anything else that must stay on http goes in https_excludes: <Space>th toggles
# the current site and re-sources this file.
import https_only

_https_excludes = config.configdir / "https_excludes"
https_only.setup(
    _https_excludes.read_text().split() if _https_excludes.exists() else []
)

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
# Home-row only: no reaching, and uppercase reads better on the yellow chip.
c.hints.chars = "asdfghjkl"
c.hints.uppercase = True
c.hints.radius = 3
c.hints.border = "1px solid #11111b"
c.hints.min_chars = 1

# For focusing scrollable frames (e.g. Jira, Confluence) via :hint frame
c.hints.selectors["frame"] = ["div", "header", "section", "nav"]


# ============================================================================
# Search & Completion Settings
# ============================================================================
c.completion.open_categories = [
    "searchengines",
    "quickmarks",
    "bookmarks",
    "history",
]
c.completion.height = "40%"
c.completion.scrollbar.width = 10
c.completion.timestamp_format = "%Y-%m-%d"

# Custom quick keyword-based search engines
c.url.searchengines = {
    "DEFAULT": "https://search.novarch.site/search?q={}",
    "g": "https://www.google.com/search?q={}",
    "gh": "https://github.com/search?q={}",
    "aw": "https://wiki.archlinux.org/index.php?search={}",
    "yt": "https://www.youtube.com/results?search_query={}",
}

# Always search if input isn't a URL
c.url.auto_search = "naive"


# ============================================================================
# Key Bindings
# ============================================================================
# Tab navigation
# "multiple" is per-window: the main window keeps its tab bar, while a one-tab
# web app window (qute-webapp.sh) has no chrome at all.
c.tabs.show = "multiple"
config.bind("<Alt-Right>", "tab-next")
config.bind("<Alt-Left>", "tab-prev")
config.bind("<Alt-h>", "tab-prev")
config.bind("<Alt-l>", "tab-next")
config.bind("<Alt-k>", "tab-prev")
config.bind("<Alt-j>", "tab-next")
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
# Per-domain: records the choice in darkmode_excludes so it survives a restart
c.aliases["toggle-dark-mode"] = "spawn --userscript toggle_darkmode.py"
# Per-host: records the choice in https_excludes, then re-sources the config
c.aliases["toggle-https"] = "spawn --userscript toggle_https.py"
c.aliases["toggle-tabs-layout"] = (
    "config-cycle tabs.position left top ;; message-info 'Toggled Tabs Layout'"
)

# ============================================================================

# Bind to the aliases
config.bind("<Space>tg", "toggle-adblock")
config.bind("<Space>td", "toggle-dark-mode")
config.bind("<Space>tt", "toggle-tabs-layout")
config.bind("<Space>th", "toggle-https")
# Open most recent download (PDF) in zathura via downloads.open_dispatcher
config.bind("<Space>z", "download-open")

# pass integration: fills credentials into the form directly, so secrets never
# pass through the clipboard (which sites can no longer read anyway).
config.bind("<Space>pp", "spawn --userscript qute-pass")
config.bind("<Space>pu", "spawn --userscript qute-pass --username-only")
config.bind("<Space>pw", "spawn --userscript qute-pass --password-only")
config.bind("<Space>pa", "spawn --userscript qute-pass-add")

# Window Management
config.bind("<Ctrl-n>", "open -w")

# Mode Exits
config.bind("<Alt-Backspace>", "mode-leave", mode="insert")
config.bind("<Alt-Backspace>", "mode-leave", mode="passthrough")
# No "jk" here: a partial keychain match is filtered out (modeman.py:297) and
# qutebrowser never replays it, so binding it would eat every literal "j" you
# type - "jam" would come out as "am". Single keys only.
config.bind("<Ctrl-[>", "mode-leave", mode="insert")
config.bind("<Ctrl-[>", "mode-leave", mode="passthrough")

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
