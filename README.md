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
│   ├── quickshell/        # Launchers/controllers for the Quickshell menus
│   ├── rofi/              # Rofi menus (calendar, passwords, niri window switcher, tv-edit)
│   ├── keybindings/       # Extract keybindings from Hyprland/niri/nvim/qutebrowser configs
│   └── wm.sh              # Compositor shim: same answers under Hyprland and niri
├── system/
│   ├── novarch            # Compiled Rust binary — declarative package manager
│   ├── package/           # YAML package lists (one file per category)
│   ├── system/            # System config files (mirrors / filesystem)
│   │   ├── etc/           # TLP, PAM, sudoers, systemd units, udev, docker
│   │   └── usr/           # /usr/local/bin helpers (battery-limit, vpn-run, howdy-ir-pre)
│   ├── themes/            # Palettes + templates rendered by scripts/theme.sh
│   └── setup.sh           # First-boot system setup script
├── CLAUDE.md              # Agent guide: rules and orientation
└── CLAUDE-reference.md    # Detailed reference (scripts, system config, theming, hardware)
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
- Deploy system configs (`sudo cp -r system/system/. /`)
- Symlink home directory configs via `stow -d ~/.dotfiles -t ~ nova`
- Enable systemd services (`ly@tty2`, `battery-limit.timer`, `paccache.timer`, `pkgfile-update.timer`)
- Set zsh as default shell
- Configure the ufw firewall
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
| Window Manager | **Hyprland** (scrolling layout, Lua config) | `nova/.config/hypr/` |
| Fallback WM | Niri + DankMaterialShell | `nova/.config/niri/`, `nova/.config/DankMaterialShell/` |
| Login Manager | **Ly** (TUI, CMatrix animation) | `system/system/etc/ly/config.ini` |
| Shell (bar, OSD, notifications, launcher, wallpaper, power menu, clipboard) | **Quickshell island** (`qs -c island`) | `nova/.config/quickshell/island/` |
| Other menus | Quickshell (on demand) + Rofi | `nova/.config/quickshell/`, `nova/.config/rofi/` |
| Idle/Lock | **swayidle** + swaylock (5min lock, 10min screen off, no idle suspend) | `nova/.config/swayidle/` |
| Screenshots | grim + slurp + satty | `nova/.config/hypr/binds.lua` |
| Screen Record | wf-recorder, wl-screenrec | `scripts/record-script.sh` |
| Clipboard | wl-clipboard + cliphist | run by the island |

### Theming

- **Colours:** one palette drives everything. `scripts/theme.sh <name>` renders every themed config from `system/themes/templates/`; `Mod+Shift+T` opens a picker. Themes: catppuccin, tokyonight, rosepine, space-galaxy. See `system/themes/README.md`
- **GTK:** `adw-gtk3-dark` widgets, breeze-dark icons, Bibata cursor
- **Terminal font:** ZedMono Nerd Font (size 13)
- **Editor font:** JetBrains Mono NL Nerd Font (size 13–15)

## Shell & Terminal

| Tool | Details |
|------|---------|
| Shell | **zsh** (vi mode, custom powerline prompt) |
| Terminal | **Ghostty** (themed by `scripts/theme.sh`, transparent background, blur) |
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
   - `aliases.zsh` — aliases and helper functions (eza, trash, git, ssh, `cproj`)
   - `pluginload.zsh` — autopair, syntax-highlighting, inline suggestions; the Tab menu is native `menu select`
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
- **GUI:** none; Mod+N opens `ghostty -e nvim`
- **Layout:** `init.lua`, `lua/config/keymaps.lua`, one spec per plugin in `lua/plugins/`

## Package Management

Packages are organized into YAML files in `system/package/`. Each file is a simple list:

```yaml
- package-name
#- disabled-package
```

| File | Contents |
|------|----------|
| `base-system.yaml` | Kernel, firmware, networking, audio (pipewire), filesystems, power (TLP) |
| `terminal-tools.yaml` | zsh, ghostty, tmux, neovim, CLI tools (bat, fd, ripgrep, fzf, eza) |
| `windowmanager.yaml` | Niri, Ly, Quickshell, DMS, Rofi, fonts, themes, screenshot/recording/OCR tools (Hyprland is in `manual-install.yaml`) |
| `development.yaml` | Build tools, Rust/Python/Node/Go/Lua, LSPs, linters, lazygit |
| `work.yaml` | Java, Docker, databases (PostgreSQL, MySQL), Chrome, WPS Office, Zoom |
| `internet.yaml` | Qutebrowser, Zen Browser, KDE Connect, LocalSend, Thunderbird |
| `media.yaml` | mpv, playerctl, imv, imagemagick, easyeffects |
| `manual-install.yaml` | Packages installed by hand, incl. Hyprland, hyprpm, xdg-desktop-portal-hyprland, hyprsunset |
| `nvidia.yaml` | NVIDIA drivers (currently all disabled — Intel iGPU only) |
| `virtualization.yaml` | QEMU for local VMs |

### novarch

Custom Rust binary that reads the YAML files and syncs installed packages declaratively:

```bash
novarch init     # Bootstrap — install all packages from all YAML files
novarch diff     # Preview what a sync would install/remove
novarch install  # Sync; removes tracked packages that no YAML declares any more
```

**AUR helper:** paru

## Scripts

Full list with details: `CLAUDE-reference.md` → Scripts.

### System Control (`scripts/`)

| Script | Purpose |
|--------|---------|
| `brightness.sh` | Adaptive brightness (1% step below 32%, 5% above) via brightnessctl |
| `volume.sh` | Media volume via playerctl |
| `battery-limit.sh` | Lenovo IdeaPad battery conservation mode (in `system/system/usr/local/bin/`) |
| `dns.sh` | Toggle Adguard DNS on a NetworkManager connection |
| `wm.sh` | Compositor shim (focused window, window list, focus, dpms, session name) for Hyprland and niri |

### Productivity

| Script | Purpose |
|--------|---------|
| `fix_grammar.sh` | Clipboard text → LLM API → grammar correction → paste back |
| `ocr_select.sh` | Region select → screenshot → RapidOCR → clipboard |
| `file_picker.sh` | Zenity file dialog → clipboard → ydotool paste |
| `calendar-notify.sh` | Parse khal events → schedule 10min-before notifications via `at` |
| `record-script.sh` | wf-recorder / wl-screenrec wrapper (full/region/audio modes) |

### Rofi Menus (`scripts/rofi/`)

| Script | Purpose |
|--------|---------|
| `calendar.sh` | khal calendar front-end |
| `passrofi.sh` | rbw password picker with per-domain autofill |
| `windows.sh` | Window switcher for niri |
| `tv-edit.sh` | Edit the TV output configuration |

### Keybindings cheat-sheet (`scripts/keybindings/`)

`Mod+Shift+/` opens a Quickshell cheat-sheet (`scripts/quickshell/keybindings.sh`). Its backend `scripts/quickshell/kbctl.sh` re-runs the extractors and shows the running compositor's binds (Hyprland or niri, picked by `wm.sh name`) plus neovim, qutebrowser and csvlens.

## System Configuration

### Power Management (TLP — `system/system/etc/tlp.conf`)

| Setting | AC | Battery |
|---------|-----|---------|
| CPU Governor | performance | powersave |
| Energy Perf. | performance | balance_power |
| Platform Profile | performance | low-power |
| WiFi Power Save | off | on |
| Turbo Boost | on | on |
| Sleep Mode | s2idle (modern standby) | |

No charge thresholds in TLP; `battery-limit.timer` toggles IdeaPad conservation mode instead.

### Boot

- systemd-boot (managed by `systemd-boot-manager`); no GRUB
- Kernel params: `zswap.enabled=0 nowatchdog quiet splash`

### Systemd Services

| Service | Purpose |
|---------|---------|
| `battery-limit.timer` | Runs battery limit script every 5 min |
| `paccache.timer` | Weekly; keeps 2 versions of installed packages |

Battery alerts come from the DMS `dankBatteryAlerts` plugin.

### Firewall (ufw)

- Incoming and routed: DROP by default; outgoing: ACCEPT
- Allow: SSH (22), KDE Connect (1714–1764 tcp/udp), 3000, 3001, mDNS/SSDP and 192.168.220.0/24 on wlan0

## Browsers

- **Primary:** Zen Browser
- **Secondary:** Qutebrowser (keyboard-driven, dark mode, follows the active theme)
- **Work:** Google Chrome

## File Management

- No terminal file manager package is installed; `Mod+E` opens `explorenova` in Ghostty
- **MIME defaults:** Zen (web), nvim (text, Markdown, CSV, code), zathura (PDF, epub), imv (images), mpv (media)

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
| **Swap** | 7.6 GB zram (zstd) + 8 GB swap file (`/swap/swapfile`) |
| **WiFi** | Intel AX211 (WiFi 6E, CNVi, Meteor Lake PCH) |
| **Bluetooth** | Intel AX211 (BT 5.3) |
| **Webcam** | Bison Integrated RGB Camera (USB) |
| **Card Reader** | O2 Micro SD/MMC Controller |
| **Ports** | Thunderbolt 4 (USB-C), USB 3.2 Gen 2x1 |
| **Display** | 14" 1920x1080 @ 60 Hz (eDP-1), intel_backlight |
| **Kernel** | linux-cachyos 7.2.x (PREEMPT_DYNAMIC, built with clang/LLD) |
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

- **Wayland-native** — all scripts assume Wayland (wl-copy, slurp, grim, ydotool, hyprctl / niri msg via `scripts/wm.sh`)
- **Nerd Fonts required** — icons used in rofi, Quickshell, prompts, and terminal configs
- System setup requires root privileges
- Sensitive files (.env, API keys, credentials) are not committed
