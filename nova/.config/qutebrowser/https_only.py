"""HTTPS-only mode with a per-host exclude list.

qutebrowser has no built-in HTTPS-only setting, so this upgrades http:// to
https:// in a request interceptor. Local services (Immich on novahome:2283,
routers, captive portals) are exempt, either by being obviously local or by
being listed in the `https_excludes` file, which <Space>th toggles.

Lives in its own module, not config.py, because config.py is re-executed on
every :config-source: module state survives that, so `_registered` keeps us from
stacking a duplicate interceptor on each reload.
"""

import ipaddress

from qutebrowser.api import interceptor
from qutebrowser.qt.core import QUrl

# Tailscale hands out 100.64.0.0/10 (CGNAT), which ipaddress does not call private
_TAILSCALE_NET = ipaddress.ip_network("100.64.0.0/10")

#: Hosts to leave on http, as "host" or "host:port". Mutated by setup().
EXCLUDES: set[str] = set()

_registered = False


def _is_local(host: str) -> bool:
    """Hosts that are never reachable over https anyway."""
    if not host or host == "localhost":
        return True
    # .ts.net is Tailscale MagicDNS (novahome.tail9d0106.ts.net)
    if host.endswith((".local", ".lan", ".internal", ".home", ".arpa", ".ts.net")):
        return True
    # A dotless name is a LAN hostname or Tailscale MagicDNS name (novahome,
    # nas, router) - it can never hold a public CA certificate.
    if "." not in host:
        return True
    try:
        addr = ipaddress.ip_address(host)
    except ValueError:
        return False
    return addr.is_private or addr.is_loopback or addr in _TAILSCALE_NET


def _excluded(url: QUrl) -> bool:
    host = url.host()
    port = url.port()
    return host in EXCLUDES or (port != -1 and f"{host}:{port}" in EXCLUDES)


def _upgrade(info: interceptor.Request) -> None:
    url = info.request_url
    if url.scheme() != "http" or _is_local(url.host()) or _excluded(url):
        return
    https_url = QUrl(url)
    https_url.setScheme("https")
    # ignore_unsupported: POST and friends cannot be redirected; let them through
    info.redirect(https_url, ignore_unsupported=True)


def setup(excludes) -> None:
    """(Re-)load the exclude list; register the interceptor exactly once."""
    global _registered
    EXCLUDES.clear()
    EXCLUDES.update(excludes)
    if not _registered:
        interceptor.register(_upgrade)
        _registered = True
