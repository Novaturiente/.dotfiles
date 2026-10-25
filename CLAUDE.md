# CLAUDE.md - Dotfiles Repository Guide

## Repository Overview

Personal dotfiles and system configuration for an Arch Linux (CachyOS kernel) setup on a **Lenovo IdeaPad Slim 5** with **Intel Core Ultra 5 (Meteor Lake)** integrated graphics. Managed via GNU Stow for symlink-based deployment and a custom Rust binary (`novarch`) for declarative package management.

**Remote:** `git@github.com:Novaturiente/.dotfiles.git`

## Repository Structure

```
.dotfiles/
├── nova/                  # Home directory configs (deployed via `stow -t ~ nova`)
│   ├── .config/           # XDG_CONFIG_HOME contents (~70 app configs)
│   ├── .fonts/            # Custom fonts (SF Pro Display, Steelfish)
│   ├── .gitconfig         # Git identity: Novaturiente <Novaturiente@proton.me>
│   ├── .password-store/   # GPG-encrypted passwords (pass)
│   ├── .profile           # Base env vars, XDG dirs, API keys
│   ├── .zprofile          # Login shell overrides
│   ├── .zshrc             # Main shell config (vi mode, zoxide, fzf, atuin)
│   └── .tmux.conf         # Tmux config (backtick prefix, vi mode)
├── scripts/               # Custom utility scripts
│   ├── rofi/              # Rofi menus (calendar, password, window switcher, tv-edit)
│   ├── quickshell/        # Quickshell menu launchers/controllers (bound in hypr/binds.lua)
│   ├── wm.sh              # Compositor shim: same answers under Hyprland and niri
│   └── keybindings/       # Auto-extract keybindings from niri/nvim/qutebrowser
├── system/
│   ├── packages/          # novarch TOML package lists (shared + hosts/<hostname>/)
│   ├── system/            # System config files (mirrors /etc structure)
│   │   ├── etc/           # TLP, Ly, PAM, systemd services, udev, sudoers
│   │   └── usr/           # /usr/local helpers (vpn-run, mullvad-netns, howdy-ir-pre)
│   └── setup.sh           # First-boot system setup script
└── .gitignore
```

## Key Tools & Conventions

### Package Management (`system/packages/`)
- **Format:** TOML, one key per file: `packages = ["name", ...]`; comments allowed, `# "name",` = disabled
- **Layout:** top-level files are shared (base-system, terminal-tools, windowmanager, development, work, internet, media, manual-installs, virtualization); `hosts/novarch/` holds this laptop's hardware (`hardware.toml`, `nvidia.toml` disabled)
- **novarch** (pacman package, github.com/Novaturiente/novarch) syncs installed packages declaratively. `novarch sync` **removes** any package it owns (state in `~/.local/state/novarch/managed.json`) that no file lists, so declare a package before relying on it; `novarch diff` previews the sync. Run it as the user, never with sudo
- **paru** is the AUR helper

### Dotfile Deployment
- Uses **GNU Stow**: `stow -d ~/.dotfiles -t ~ nova` creates symlinks from `nova/` into `$HOME`
- File paths under `nova/` mirror the home directory structure exactly
- Example: `nova/.config/ghostty/config` → `~/.config/ghostty/config`

### System Config Deployment
- Files under `system/system/` mirror the `/` filesystem structure
- Deployed as one tree by `setup.sh`: `sudo cp -r system/system/. /`
- Example: `system/system/etc/tlp.conf` → `/etc/tlp.conf`

## Desktop Environment Stack

Primary session is **Hyprland** with the **Quickshell island** as the shell. The old **niri** session is still in the repo as a fallback and runs the same island (DankMaterialShell was removed); scripts that talk to the compositor go through `scripts/wm.sh` so they run under both. Rows below describe Hyprland; niri differences are noted.

| Layer | Tool | Config Location |
|-------|------|-----------------|
| Window Manager | **Hyprland** (Lua config, `scrolling` layout ported from niri; binds mirror niri's). Fallback: **niri** (`nova/.config/niri/config.kdl`) | `nova/.config/hypr/hyprland.lua`, `binds.lua`, `colors.lua` (generated) |
| Session startup | `hyprland.lua` `hyprland.start` hook: imports env into systemd, starts `hyprland-session.target` (pulls `graphical-session.target`), stops `quickshell-notifications.service` and starts the island (niri's `modules/startup.kdl` does the same). Shutdown hook stops the target | `nova/.config/hypr/hyprland.lua`, `nova/.config/systemd/user/hyprland-session.target` |
| Login Manager | **Ly** (TUI greeter on tty2, `ly@tty2.service`) | `system/system/etc/ly/config.ini` |
| Bar / OSD / Notifications / Polkit / Wallpaper / Launcher / Power menu / Clipboard / URL bar / Window switcher / Calendar / Passwords / Keybindings | **Quickshell island** (`qs -c island`): top-centre pill that morphs into pages, driven by `qs -c island ipc call island toggle <page>` (`pass <domain>` via `scripts/quickshell/pass.sh`). List pages share `island/SearchList.qml`; larger pages live in `island/*Page.qml`. Notification popups stack top-right, never in the pill. Owns `org.freedesktop.Notifications` and the polkit agent under Hyprland. These pages don't exist under niri, whose binds call the same IPC | `nova/.config/quickshell/island/` |
| Other menus | **Quickshell** configs `launcher` and `theme` (fallbacks when the island isn't running), started on demand by `scripts/quickshell/*.sh` and quit once closed and idle; Rofi for a few helpers | `nova/.config/quickshell/`, `nova/.config/rofi/` |
| Menu motion / widgets | `common/` QML module: Material 3 Expressive curves (`Tokens`, `Anim`), ripple (`StateLayer`), and the `Styled*` widget set. Ported by hand from [caelestia-shell](https://github.com/caelestia-dots/shell); no compiled plugin. | `nova/.config/quickshell/common/` |
| Idle/Lock | **swayidle**: lock with swaylock (`scripts/lock.sh`) at 5 min, screen off at 10 min, never suspends on idle | `nova/.config/swayidle/config` |
| Screenshots | grim + slurp + satty | `nova/.config/hypr/binds.lua` |
| Screen Record | wf-recorder (region/audio), wl-screenrec (fullscreen) | `scripts/record-script.sh` |
| Clipboard | **cliphist** stores history (`wl-paste --watch cliphist store`, run by the island); Mod+V → island `clipboard` page. `clip-push.service` (`scripts/clip-push.sh`) is a second watcher that pushes copied images to novahome | `nova/.config/quickshell/island/shell.qml`, `nova/.config/hypr/binds.lua` |

## Reference (read on demand)

`CLAUDE-reference.md` holds the detail: shell and terminal, aliases, editors, scripts, system config (TLP, ufw, boot, systemd), theming, notifications, browsers, languages, MIME defaults, hardware.
- **Read** the matching section before touching any of those areas.
- **Update** it in the same change when you alter what it describes. Keep this file to rules and orientation only.

Rules you must know without reading it:
- **Theming:** never hand-edit a generated config (header says "generated by scripts/theme.sh"); edit `system/themes/templates/` or `system/themes/palettes/` and run `scripts/theme.sh <name>`.
- **Notifications:** the island is the notification server under both Hyprland and niri (startup stops `quickshell-notifications.service`, then starts the island). Read the Notifications section before changing that.
- **Compositor calls:** use `scripts/wm.sh` instead of raw `hyprctl`/`niri msg` in shared scripts, so they keep working under both sessions.

## Important Notes

- **Wayland-native:** All scripts assume Wayland (wl-copy, slurp, grim, ydotool, hyprctl / niri msg via `scripts/wm.sh`)
- **Hyprland packages** (`hyprland`, `hyprpm`, `xdg-desktop-portal-hyprland`, `hyprsunset`) are in `manual-installs.toml`; niri stays in `windowmanager.toml`. The `hyprglass` plugin is built by hand into `~/.local/share/hyprglass/`
- **Nerd Fonts required:** Icons used throughout rofi, quickshell, prompts, and terminal configs
- **Sensitive files:** API keys and credentials are stored in `.profile` and `.env` files — never commit actual values
