// ==UserScript==
// @name        transparent-bg
// @description Strip the page background on listed hosts, so niri's blur shows through.
// @include     *
// @run-at      document-start
// ==/UserScript==

// Generated from ~/.config/qutebrowser/transparent_sites by toggle_transparent.py.
// A greasemonkey script rather than content.user_stylesheets, because that
// setting takes no URL pattern - it is all-sites or nothing.
const HOSTS = ["search.novarch.site"];

if (HOSTS.includes(location.host)) {
    const inject = () => {
        const style = document.createElement("style");
        style.textContent =
            "html,body{background:transparent !important;background-color:transparent !important}";
        (document.head || document.documentElement).appendChild(style);
    };
    // document-start runs before <html> exists, so documentElement can be null
    if (document.documentElement) {
        inject();
    } else {
        document.addEventListener("readystatechange", inject, { once: true });
    }
}
