# from fake_useragent import UserAgent
c = c  # pyright: ignore
config = config  # pyright: ignore

# ua = UserAgent(browsers=['Edge', 'Chrome','Firefox'],os=["Windows"])

# Load settings made via the :set command from autoconfig.yml.
config.load_autoconfig(False)  # Set to True if you want to keep using autoconfig.yml

# Enable JavaScript clipboard access
c.content.javascript.clipboard = "access-paste"

# Theme
config.source("themes/city-lights-theme.py")


# Tab settings
# c.tabs.position = "right"
# c.tabs.width = 125
c.tabs.title.format = "{current_title}"
c.tabs.padding = {"top": 5, "bottom": 5, "left": 0, "right": 0}
c.tabs.title.alignment = "center"
c.tabs.favicons.scale = 1

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
c.input.insert_mode.leave_on_load = True

# Smooth scrolling
c.scrolling.smooth = False

# GPU accelearation
c.qt.args = [
    "enable-gpu-rasterization",
    "enable-accelerated-video-decode",
    "enable-quic",
    "enable-zero-copy",
]

# Privacy and blocking
c.content.headers.user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36"
# c.content.javascript.enabled = False
c.content.canvas_reading = False
c.content.webgl = False
c.content.headers.accept_language = "en-US,en;q=0.5"
c.content.headers.referer = "same-domain"
c.content.headers.custom = {
    "Permissions-Policy": "geolocation=(), microphone=(), camera=(), interest-cohort=()"
}
c.content.cookies.accept = "no-3rdparty"
c.content.cache.appcache = False
c.content.headers.do_not_track = True
c.content.hyperlink_auditing = False
c.content.blocking.enabled = True
c.content.blocking.method = "both"
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
]
# Video auto play and location
c.content.autoplay = False
c.content.geolocation = False

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
c.completion.shrink = True
c.completion.open_categories = [
    "quickmarks",
    "bookmarks",
    "searchengines",
    "history",
]

# Add custom quick keyword-based search engines
c.url.searchengines = {
    "DEFAULT": "https://duckduckgo.com/?q={}",
    "g": "https://www.google.com/search?q={}",
    "yt": "https://www.youtube.com/results?search_query={}",
}

# Always search if input isn't a URL
c.url.auto_search = "naive"

c.url.start_pages = ["https://www.perplexity.ai/"]

## Key bindings
# Bind Escape in insert mode to blur the active element, then leave insert mode
c.bindings.key_mappings["<Ctrl-x>"] = "<Escape>"
config.bind(
    "<Escape>", "mode-leave ;; jseval -q document.activeElement.blur()", mode="insert"
)

config.bind("I", "hint inputs")
config.bind("h", "hint all hover")

# Map Alt+Right to next tab
config.bind("<Alt-Right>", "tab-next")
# Map Alt+Left to previous tab
config.bind("<Alt-Left>", "tab-prev")
# Open page in zen-browser
config.bind("<Ctrl+Alt+t>", "spawn -d floorp {url} ;; tab-close")

# -- Cast current video
config.bind(",c", "hint links spawn --userscript cast.sh {hint-url}")
config.bind(",m", "hint links spawn mpv {hint-url}")
config.bind(",D", "spawn --userscript open_download")
config.bind(",d", "hint links spawn --userscript download.sh {hint-url}")
config.bind(',v', 'spawn --userscript vibrance.sh')
