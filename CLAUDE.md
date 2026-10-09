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
│   ├── quickshell/        # Quickshell menu launchers/controllers (bound in niri)
│   └── keybindings/       # Auto-extract keybindings from niri/nvim/qutebrowser
├── system/
│   ├── novarch            # Compiled Rust binary - declarative package manager
│   ├── novarch.back       # Backup of previous novarch version
│   ├── package/           # YAML package lists (one file per category)
│   ├── system/            # System config files (mirrors /etc structure)
│   │   ├── etc/           # TLP, Ly, PAM, systemd services, udev, sudoers
│   │   └── usr/           # /usr/local helpers (vpn-run, mullvad-netns, howdy-ir-pre)
│   └── setup.sh           # First-boot system setup script
└── .gitignore
```

## Key Tools & Conventions

### Package Management (`system/package/`)
- **Format:** Simple YAML lists — each file is an array of package names (`- package-name`)
- **Commented packages** (`#- package-name`) are disabled/not installed
- **Categories:** base-system, terminal-tools, windowmanager, development, work, internet, media, manual-install, nvidia (disabled), virtualization
- **novarch** reads these YAML files and syncs installed packages declaratively. `novarch install` **removes** any package it tracks (state in `/var/lib/novarch/state.yaml`) that no YAML declares, so declare a package before relying on it; `novarch diff` previews the sync
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

| Layer | Tool | Config Location |
|-------|------|-----------------|
| Window Manager | **Niri** (Wayland tiling compositor) | `nova/.config/niri/config.kdl` |
| Login Manager | **Ly** (TUI greeter on tty2, `ly@tty2.service`) | `system/system/etc/ly/config.ini` |
| Panel / Wallpaper / Lock / OSD | **DankMaterialShell** (`dms`, Quickshell-based) | `nova/.config/DankMaterialShell/`, `nova/.config/niri/dms/` |
| Notifications | Own Quickshell daemon, ported from caelestia-shell. Runs as `quickshell-notifications.service`, **not** under niri startup. | `nova/.config/quickshell/notifications/` |
| Launcher / menus | **Quickshell** menus, started on demand by `scripts/quickshell/*.sh` and quit once closed and idle (nothing resident); Rofi for a few helpers | `nova/.config/quickshell/`, `nova/.config/rofi/` |
| Menu motion / widgets | `common/` QML module: Material 3 Expressive curves (`Tokens`, `Anim`), ripple (`StateLayer`), and the `Styled*` widget set. Ported by hand from [caelestia-shell](https://github.com/caelestia-dots/shell); no compiled plugin. | `nova/.config/quickshell/common/` |
| Idle/Lock | **swayidle**: lock with swaylock (`scripts/lock.sh`) at 5 min, screen off at 10 min, never suspends on idle | `nova/.config/swayidle/config` |
| Screenshots | grim + slurp + satty | bound in niri config |
| Screen Record | wf-recorder (region/audio), wl-screenrec (fullscreen) | `scripts/record-script.sh` |
| Clipboard | **cliphist** stores history (`wl-paste --watch cliphist store`, run by the island shell `qs -c island`); Mod+V → `dms ipc call clipboard toggle`. `clip-push.service` (`scripts/clip-push.sh`) is a second watcher that pushes copied images to novahome | `nova/.config/quickshell/island/shell.qml`, `nova/.config/niri/dms/binds.kdl` |

## Reference (read on demand)

`CLAUDE-reference.md` holds the detail: shell and terminal, aliases, editors, scripts, system config (TLP, ufw, boot, systemd), theming, notifications, browsers, languages, MIME defaults, hardware.
- **Read** the matching section before touching any of those areas.
- **Update** it in the same change when you alter what it describes. Keep this file to rules and orientation only.

Rules you must know without reading it:
- **Theming:** never hand-edit a generated config (header says "generated by scripts/theme.sh"); edit `system/themes/templates/` or `system/themes/palettes/` and run `scripts/theme.sh <name>`.
- **Notifications:** popups come from `quickshell-notifications.service`, not DMS; DMS's notification centre is intentionally empty. Don't "fix" that without reading the Notifications section.

## Important Notes

- **Wayland-native:** All scripts assume Wayland (wl-copy, slurp, grim, ydotool, niri msg)
- **Nerd Fonts required:** Icons used throughout rofi, quickshell, prompts, and terminal configs
- **Sensitive files:** API keys and credentials are stored in `.profile` and `.env` files — never commit actual values
