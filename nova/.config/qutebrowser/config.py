# Documentation:
#   https://qutebrowser.org/doc/help/configuring.html
#   https://qutebrowser.org/doc/help/settings.html

# Load settings made via the :set command from autoconfig.yml.
config.load_autoconfig(False)  # Set to True if you want to keep using autoconfig.yml

# Enable JavaScript clipboard access for specific site
config.set("content.javascript.clipboard", "access-paste", "https://github.com")

# Enable dark mode for webpages
config.set("colors.webpage.darkmode.enabled", True)
config.set("colors.webpage.darkmode.policy.page", "always")
config.set("colors.webpage.preferred_color_scheme", "dark")
config.bind("<Ctrl-/>", "spawn mpv {url}")
config.bind("xx", "hint links spawn mpv {hint-url}")
config.bind("xz", "hint links spawn mpv --add-to-queue {hint-url}")
config.set("content.autoplay", False)

# c.url.searchengines = {
#     'DEFAULT':  'https://google.com/search?hl=en&q={}'
# }
# c.url.start_pages = ["https://google.com"]
