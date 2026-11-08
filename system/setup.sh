#!/usr/bin/env sh
# First-boot setup. Every path below is relative to the repo root.
cd ~/.dotfiles || exit 1

# novarch (https://github.com/Novaturiente/novarch): install it as a pacman package
# from the latest release, point it at the TOML package lists (no prompt), then install
# everything they declare: stow, zsh, ly, ufw, tlp, pkgfile and Hyprland are all needed
# below. sync shows its plan and asks before it changes anything.
# (Download, then run: with `curl | sh` a failed download would still exit 0.)
curl -fsSL -o /tmp/novarch-install.sh https://raw.githubusercontent.com/Novaturiente/novarch/main/install.sh &&
	sh /tmp/novarch-install.sh || exit 1
mkdir -p ~/.config/novarch
[ -e ~/.config/novarch/config.toml ] ||
	echo "packages_dir = \"$HOME/.dotfiles/system/packages\"" >~/.config/novarch/config.toml
novarch sync || exit 1

# System files: system/system mirrors /, so copy the whole tree onto it
# (tlp.conf, sleep.conf, logind, zram, docker, udev, units, /usr/local helpers, polkit, pam).
# Check the sudoers rule first: a broken file in sudoers.d locks sudo out.
visudo -cf system/system/etc/sudoers.d/vpn-run || exit 1
sudo cp -r system/system/. /
sudo chmod 0440 /etc/sudoers.d/vpn-run

# Login manager: Ly (installed from packages/windowmanager.toml).
# Ly is a TUI greeter running on its own VT; it needs no dedicated user.
sudo mkdir -p /etc/ly

# ~/.novacode must be a real folder before stow, or stow links the whole folder
# into the repo and novacode's sessions, logins and logs land in git.
mkdir -p ~/.config ~/.novacode

stow -d ~/.dotfiles -t ~ nova

# novacode (https://github.com/Novaturiente/novacode): the release binary goes to
# ~/.local/bin; its config (AGENTS.md, settings, MCP servers, skills) is stowed above.
curl -fsSL -o /tmp/novacode-install.sh https://raw.githubusercontent.com/Novaturiente/novacode/main/scripts/install.sh &&
	sh /tmp/novacode-install.sh || exit 1
# Packages at the tags pinned in the repo's lock file. Source and ref joined by '|',
# since git@ URLs contain '@'.
for p in $(jq -r 'to_entries[] | "\(.value.source)|\(.value.tag // .value.rev)"' nova/.novacode/packages.lock.json); do
	~/.local/bin/novacode install "${p%|*}" --ref "${p##*|}" || exit 1
done
# install rewrites the lock file by rename, which replaces the stowed symlink with a
# real file; put the link back (same pins, so nothing is lost).
ln -sf ~/.dotfiles/nova/.novacode/packages.lock.json ~/.novacode/packages.lock.json

# Mount point for novahome's home (sshfs in hyprland.lua; reached over Tailscale).
mkdir -p ~/server

# docker: run containers without sudo. input: ydotool. video: backlight.
# tss: TPM access for the rbw face unlock (usr/local/libexec/rbw-tpm-face-unseal).
sudo usermod -aG docker,input,video,tss "$(whoami)"

# Colours for every application, plus /etc/ly/config.ini and the Plymouth boot
# splash. Reads system/themes/current, so a fresh machine comes up on whichever
# theme is committed. Switch later with scripts/theme.sh <name> or Mod+Shift+T.
./scripts/theme.sh "$(cat system/themes/current)" --system

sudo systemctl daemon-reload
sudo systemctl enable ly@tty2.service

systemctl --user mask pulseaudio.service pulseaudio.socket

sudo systemctl enable paccache.timer
# CPU power average for the island's battery page (raw RAPL stays root-only).
sudo systemctl enable rapl-watts.service

# Services this laptop runs. tailscaled carries the sshfs mount to novahome,
# linux-enable-ir-emitter powers the IR camera for face unlock.
# mullvad-netns.service is enabled by install-vpn-netns.sh, once its config exists.
sudo systemctl enable NetworkManager.service bluetooth.service sshd.service \
	docker.service tailscaled.service tlp.service \
	linux-enable-ir-emitter.service

# Set zsh as default login shell
chsh "$(whoami)" -s "$(which zsh)"

# pkgfile: command-not-found handler + package/binary completion database
sudo pkgfile --update
sudo systemctl enable --now pkgfile-update.timer

# NOT automated, check by hand on new hardware:
# - /etc/mkinitcpio.conf HOOKS need `plymouth` (boot splash) and `resume`
#   (hibernate, with a swap file such as /swap/swapfile and resume= on the
#   kernel command line), and the kernel command line needs `quiet splash`.
# - Face unlock for sudo/swaylock needs the hand edits to /etc/pam.d/system-auth
#   described in system/HOWDY-FACE-AUTH.md.
# - The hyprglass Hyprland plugin is built by hand into
#   ~/.local/share/hyprglass/ (hyprland.lua loads it at startup).
# - After reboot: `sudo tailscale up` once, so the ~/server mount can reach novahome.
# - `novacode login claude` once (settings.json picks a claude/ model).
sudo mkinitcpio -P

# Firewall: ufw, deny incoming by default
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed
# SSH and dev servers (3000, 3001): only over Tailscale and from the LAN.
for port in 22 3000 3001; do
	sudo ufw allow in on tailscale0 to any port "$port" proto tcp
	sudo ufw allow from 192.168.0.0/16 to any port "$port" proto tcp
done
sudo ufw allow 1714:1764/tcp # KDE Connect
sudo ufw allow 1714:1764/udp
sudo ufw allow in on wlan0 to 224.0.0.251 port 5353 proto udp  # mDNS
sudo ufw allow in on wlan0 to 239.255.255.250 port 1900 proto udp  # SSDP
sudo ufw allow in on wlan0 from 192.168.220.0/24
sudo ufw --force enable
sudo systemctl enable ufw.service

sudo reboot
