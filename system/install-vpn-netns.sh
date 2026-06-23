#!/usr/bin/env bash
# Install the Mullvad vpn-netns setup (isolated network namespace; only apps
# launched with `vpn-run` use the tunnel). Reproducible on any Arch box from a
# fresh clone of this repo.
#
# Usage:  sudo bash system/install-vpn-netns.sh /path/to/your-mullvad.conf
#
# The .conf is per-machine: download one from your Mullvad account page. Do NOT
# reuse the same WireGuard key on two machines at once — Mullvad binds one key
# to one peer, so concurrent use makes the handshake flap. Generate a separate
# config (= separate key) per device.
set -euo pipefail

DOT="$(cd "$(dirname "$0")/.." && pwd)"          # repo root, wherever it's cloned
CONF_SRC="${1:?usage: sudo bash install-vpn-netns.sh /path/to/mullvad.conf}"
[[ -r "$CONF_SRC" ]] || { echo "config not readable: $CONF_SRC" >&2; exit 1; }

# 1. WireGuard userspace tools (also listed in package/internet.yaml for novarch)
pacman -S --needed --noconfirm wireguard-tools

# 2. Scripts (root-owned, executable)
install -m 0755 "$DOT/system/system/usr/local/bin/mullvad-netns" /usr/local/bin/mullvad-netns
install -m 0755 "$DOT/system/system/usr/local/bin/vpn-run"        /usr/local/bin/vpn-run

# 3. Secret config — 600, root only, never in the repo
install -m 0600 "$CONF_SRC" /etc/wireguard/mullvad.conf

# 4. sudoers rule (validate before activating)
install -m 0440 "$DOT/system/system/etc/sudoers.d/vpn-run" /etc/sudoers.d/vpn-run
visudo -cf /etc/sudoers.d/vpn-run

# 5. systemd service — bring tunnel up now + on every boot
install -m 0644 "$DOT/system/system/etc/systemd/system/mullvad-netns.service" \
        /etc/systemd/system/mullvad-netns.service
systemctl daemon-reload
systemctl enable --now mullvad-netns.service

echo "--- verify: handshake should be recent, exit IP should be Mullvad ---"
ip netns exec vpn wg show
ip netns exec vpn curl -s https://am.i.mullvad.net/json || true
