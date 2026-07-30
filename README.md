# Arch Linux Dotfiles

Complete system configuration for an Arch Linux (CachyOS kernel) setup on a Lenovo IdeaPad Slim 5 with Intel Core Ultra 5 (Meteor Lake). Managed with GNU Stow for symlink-based deployment and a custom Rust binary (`novarch`) for declarative package management.

## Repository Structure

```
.dotfiles/
├── nova/                  # Home directory configs (deployed via stow)
│   ├── .config/           # Application configurations (~70 apps)
│   ├── .fonts/            # Custom fonts (SF Pro Display, Steelfish)
│   ├── .gitconfig         # Git configuration
│   ├── .profile           # Base environment variables, XDG dirs
│   ├── .zprofile          # Login shell overrides
│   ├── .zshrc             # Main shell config
│   └── .tmux.conf         # Tmux configuration
├── scripts/               # Custom utility scripts
│   ├── rofi/              # Rofi launcher menus
│   └── keybindings/       # Auto-extract keybindings from app configs
├── system/
│   ├── novarch            # Compiled Rust binary — declarative package manager
│   ├── package/           # YAML package lists (one file per category)
│   ├── system/            # System config files (mirrors / filesystem)
│   │   ├── boot/          # GRUB theme (CyberSynchro)
│   │   └── etc/           # TLP, Ly, systemd services, GRUB defaults
│   └── setup.sh           # First-boot system setup script
└── CLAUDE.md
```

`nova/` mirrors the home directory — `nova/.config/ghostty/config` becomes `~/.config/ghostty/config` via stow.

## Quick Start

### Initial Setup

```bash
git clone git@github.com:Novaturiente/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles/system
./setup.sh
```

**The setup script will:**
- Copy `novarch` to `/usr/bin/` and run `novarch init`
- Deploy system configs (TLP, Ly, systemd services) to `/etc/`
- Symlink home directory configs via `stow -d ~/.dotfiles -t ~ nova`
- Enable systemd services (Ly display manager, batsignal, battery-limit timer)
- Set zsh as default shell
- Configure iptables firewall
- Reboot

### Stow Management

```bash
# Create symlinks
stow -d ~/.dotfiles -t ~ nova

# Remove symlinks
stow -d ~/.dotfiles -t ~ -D nova
```

## Desktop Environment

| Layer | Tool | Config |
|-------|------|--------|
| Window Manager | **Niri** (Wayland tiling compositor) | `nova/.config/niri/config.kdl` |
| Alt WM | Hyprland | `nova/.config/hypr/` |
| Login Manager | **Ly** (TUI, CMatrix animation) | `system/system/etc/ly/config.ini` |
| Panel | **Waybar** + DankMaterialShell | `nova/.config/waybar/` |
| Notifications | **swaync** | `nova/.config/swaync/` |
| Launcher | **Rofi** (Wayland) | `nova/.config/rofi/` |
| Wallpaper | **wpaperd** (random, 15min cycle) | `nova/.config/wpaperd/` |
| Idle/Lock | **swayidle** (5min lock, 10min suspend) | `nova/.config/swayidle/` |
| Screenshots | grim + slurp + satty | keybindings in niri config |
| Screen Record | wl-screenrec | `scripts/record-script.sh` |
| Clipboard | wl-clipboard + cliphist | autostarted in WM config |

### Theming

- **GTK/Qt:** Materia theme, WhiteSur icons, Bibata cursor
- **Terminal font:** IosevkaTerm Nerd Font (size 13)
- **Editor font:** JetBrains Mono NL Nerd Font (size 13–15)
- **Color schemes:** Catppuccin Mocha (Ghostty), Challenger Deep (Emacs)

## Shell & Terminal

| Tool | Details |
|------|---------|
| Shell | **zsh** (vi mode, custom powerline prompt) |
| Terminal | **Ghostty** (Catppuccin Mocha, 50% opacity, blur) |
| Multiplexer | **tmux** (prefix: backtick `` ` ``, vi mode) |
| History | **atuin** (synced) |
| Navigation | **zoxide**, **fzf** |
| ls | **eza** (icons, color) |
| cat | **bat** |
| find | **fd** |
| grep | **ripgrep** |

### Shell Config Loading Order

1. `.profile` — XDG dirs, base environment
2. `.zprofile` — login shell overrides
3. `.zshrc` — sources `.profile`, then loads from `~/.config/zsh/`:
   - `variables.zsh` — editor, PATH, locale
   - `aliases.zsh` — 80+ aliases (eza, trash-put, rsync, git, podman)
   - `pluginload.zsh` — autopair, fast-syntax-highlighting, autosuggestions, autocomplete
   - `prompt.zsh` — powerline prompt with git branch and language detection

### Notable Aliases

| Alias | Replacement |
|-------|-------------|
| `rm` | `trash-put` |
| `cp` | `rsync` |
| `ls/la/ll/lt` | `eza` variants |
| `gadd` | auto-stage + commit |

## Editors

### Neovim (primary)

- **Config:** `nova/.config/nvim/` (Lua-based, lazy.nvim)
- **Leader:** Space
- **Tabs:** 4 spaces
- **GUI:** Neovide (90% opacity, blur, cursor trail)
- **Modules:** `plugins.lua`, `keybindinds.lua`, `ui.lua`, `coding.lua`, `autostart.lua`, `orgsetup.lua`

### Doom Emacs (secondary)

- **Config:** `nova/.config/doom/`
- **Theme:** doom-challenger-deep
- **Evil mode** (vim keybindings)
- Used for org-mode and as PDF viewer

## Package Management

Packages are organized into YAML files in `system/package/`. Each file is a simple list:

```yaml
- package-name
#- disabled-package
```

| File | Contents |
|------|----------|
| `base-system.yaml` | Kernel, firmware, networking, audio (pipewire), filesystems, power (TLP) |
| `terminal-tools.yaml` | zsh, ghostty, tmux, neovim, yazi, CLI tools (bat, fd, ripgrep, fzf, eza) |
| `windowmanager.yaml` | Niri, Ly, Waybar, Rofi, fonts, themes, screenshot/recording tools |
| `development.yaml` | Build tools, Rust/Python/Node/Go/Lua, LSPs, linters, lazygit, tesseract OCR |
| `work.yaml` | Java, Docker, databases (PostgreSQL, MySQL), Chrome, WPS Office, Zoom |
| `internet.yaml` | Qutebrowser, Zen Browser, KDE Connect, LocalSend, Thunderbird |
| `media.yaml` | mpv, playerctl, imv, imagemagick, easyeffects |
| `gaming.yaml` | Wine/Proton/GameMode (currently all disabled) |
| `nvidia.yaml` | NVIDIA drivers (currently all disabled — Intel iGPU only) |
| `virtualization.yaml` | Empty |

### novarch

Custom Rust binary that reads the YAML files and syncs installed packages declaratively:

```bash
novarch init    # Bootstrap — install all packages from all YAML files
```

**AUR helper:** paru

## Scripts

### System Control (`scripts/`)

| Script | Purpose |
|--------|---------|
| `brightness.sh` | Adaptive brightness (1% step below 32%, 5% above) via brightnessctl |
| `volume.sh` | Media volume via playerctl |
| `mute.sh` | Mute toggle via pamixer |
| `idle.sh` | Toggle swayidle daemon |
| `battery-limit.sh` | Lenovo IdeaPad battery conservation mode |
| `dns.sh` | Toggle Adguard DNS on a NetworkManager connection |
| `wallpaper.sh` | Random wallpaper rotation (30min, swaybg) |

### Productivity

| Script | Purpose |
|--------|---------|
| `fix_grammar.sh` | Clipboard text → LLM API → grammar correction → paste back |
| `ocr_select.sh` | Region select → screenshot → Tesseract OCR → clipboard |
| `file_picker.sh` | Zenity file dialog → clipboard → ydotool paste |
| `calendar-notify.sh` | Parse khal events → schedule 10min-before notifications via `at` |
| `record-script.sh` | wl-screenrec wrapper (full/region/audio modes) |

### Rofi Menus (`scripts/rofi/`)

| Script | Purpose |
|--------|---------|
| `bookmarks.sh` | Browser bookmark manager with title fetching |
| `clipboard.sh` | Clipboard history with image preview via cliphist |
| `find.sh` | File finder in dotfiles → open in neovide |
| `power.sh` | Logout/shutdown/reboot with confirmation |
| `tools.sh` | File operations (copy, move, rename, delete, restore via trash) |

### Keybinding Extractors (`scripts/keybindings/`)

Auto-extracts keybindings from niri, neovim, and qutebrowser configs into a unified rofi menu via `keybindings.sh`.

## System Configuration

### Power Management (TLP — `system/system/etc/tlp.conf`)

| Setting | AC | Battery |
|---------|-----|---------|
| CPU Governor | performance | powersave |
| Energy Perf. | performance | balance_power |
| Platform Profile | performance | low-power |
| WiFi Power Save | off | on |
| Turbo Boost | on | on |
| Battery Charge | Start: 75%, Stop: 80% | |
| Sleep Mode | s2idle (modern standby) | |

### Boot

- GRUB with CyberSynchro theme, 3s timeout
- Kernel params: `loglevel=3 quiet splash i915.enable_psr=1`

### Systemd Services

| Service | Purpose |
|---------|---------|
| `battery-limit.timer` | Runs battery limit script every 5 min |
| `batsignal.service` | Battery notifications (critical: 10%, warning: 30%, full: 95%) |

### Firewall (iptables)

- INPUT: DROP by default
- Allow: established/related connections, loopback, KDE Connect (1714–1764), SSH (22)
- OUTPUT: ACCEPT

## Browsers

- **Primary:** Zen Browser
- **Secondary:** Qutebrowser (keyboard-driven, dark mode, city-lights theme)
- **Work:** Google Chrome, Thorium (separate qutebrowser profile)

## File Management

- **Primary:** Yazi (custom keybindings: mount menu, SMB shares, drag-drop)
- **Secondary:** Ranger (miller columns, kitty image preview)
- **MIME defaults:** Zen (web), Emacs (PDF), imv (images), mpv (media), Ranger (dirs)

## Hardware

| Component | Details |
|-----------|---------|
| **Laptop** | Lenovo IdeaPad Slim 5 14IMH9 (Board: LNVNB161216) |
| **BIOS** | N7CN34WW (2025-09-24) |
| **CPU** | Intel Core Ultra 5 125H (Meteor Lake) — 14 cores / 18 threads, up to 4.5 GHz |
| | 6 P-cores (HT) + 8 E-cores (no HT), 18 MB L3 cache |
| **GPU** | Intel Arc Graphics (Meteor Lake-P, i915 driver) — 256 MB dedicated + shared |
| | VAAPI hardware decode, vulkan-intel, no discrete GPU |
| **NPU** | Intel Meteor Lake NPU (neural accelerator for AI workloads) |
| **RAM** | 16 GB (15.2 GiB usable), soldered |
| **Storage** | Samsung PM9C1a 1 TB NVMe SSD (DRAM-less) |
| | Partition layout: 2 GB EFI (`/boot`, vfat) + 952 GB root/home (btrfs) |
| **Swap** | 15.2 GB zram (compressed RAM swap) + 24 GB swap file/partition |
| **WiFi** | Intel AX211 (WiFi 6E, CNVi, Meteor Lake PCH) |
| **Bluetooth** | Intel AX211 (BT 5.3) |
| **Webcam** | Bison Integrated RGB Camera (USB) |
| **Card Reader** | O2 Micro SD/MMC Controller |
| **Ports** | Thunderbolt 4 (USB-C), USB 3.2 Gen 2x1 |
| **Display** | 14" 1920x1080 @ 60 Hz (eDP-1), intel_backlight |
| **Kernel** | linux-cachyos 6.19.x (PREEMPT_DYNAMIC, built with clang/LLD) |
| **Filesystem** | Btrfs (root + home on single partition) |
| **Networking** | Tailscale VPN, Docker/Podman bridge networks |

## Disaster Recovery

### 1. Bootstrap Network (Live USB)

```bash
iwctl station wlan0 connect <SSID>
```

### 2. Restore Secrets

These files are **not** in the repository — restore from an encrypted backup:

```bash
# GPG keys (for pass)
gpg --import private-key.asc
gpg --import-ownertrust ownertrust.txt

# SSH keys
mkdir -p ~/.ssh
cp /backup/id_ed25519 ~/.ssh/
chmod 600 ~/.ssh/id_ed25519
```

### 3. Clone & Provision

```bash
git clone git@github.com:Novaturiente/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles/system
./setup.sh
```

## Notes

- **Wayland-native** — all scripts assume Wayland (wl-copy, slurp, grim, ydotool)
- **Nerd Fonts required** — icons used in rofi, prompts, waybar, and terminal configs
- System setup requires root privileges
- Sensitive files (.env, API keys, credentials) are not committed
